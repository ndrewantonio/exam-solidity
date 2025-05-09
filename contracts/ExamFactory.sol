// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ExamImplementation.sol";
import "../enums/ExamEnums.sol";
import "../structs/ExamStructs.sol";

/**
 * @title ExamFactory
 * @notice This contract allows the creation of exam contracts using the Clone Factory pattern.
 * It manages the creation, storage, and retrieval of exam contracts.
 */
contract ExamFactory is Ownable {
    using Clones for address;

    // --------------------------------------------------
    // State Variables
    // --------------------------------------------------

    /// @notice Address of the ExamImplementation contract
    address public immutable examImplementation;

    /// @notice The ERC20 token used for funding (IDRX).
    IERC20 public idrxToken;

    /// @notice Fee for creating an exam on ETH
    uint256 public constant examCreationFee = 0.0001 ether;

    /// @notice Fee for creating an exam on IDRX
    uint256 public constant examCreationFeeIDRX = 1000;

    /// @notice Total tokens managed by the contract.
    uint256 public totalManagedFund;

    /// @notice List of all created exams
    ExamStructs.ExamCreationConfig[] public listOfCreatedExams;

    string public baseURI;

    /// @notice Mapping of exam address => exam config
    mapping(address => ExamStructs.ExamConfig) public examConfigByAddress;

    /// @notice Mapping of exam address => verified status
    mapping(address => bool) public verifiedExamContract;

    /// @notice Mapping of author address => created exam addresses
    mapping(address => address[]) public examsByAuthor;

    /// @notice Mapping of participant address => exam data being enrolled
    mapping(address => ExamStructs.ExamHistory[])
        public examsEnrolledByParticipant;

    // --------------------------------------------------
    // Events
    // --------------------------------------------------

    /// @notice Event emitted when an exam is created.
    event ExamCreated(address indexed author, address examContractAddress);

    /// @notice Event emitted when a participant joins an exam.
    event ParticipantJoinedExam(
        address indexed participant,
        address examAddress
    );

    // --------------------------------------------------
    // Constructor
    // --------------------------------------------------

    /**
     * @notice Constructor to initialize the ExamFactory contract.
     * @param _examImplementation The address of the ExamImplementation contract.
     * @param _tokenAddress The address of the ERC20 token used for funding.
     */
    constructor(
        address _examImplementation,
        address _tokenAddress
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(
            _examImplementation != address(0),
            "Invalid implementation address"
        );
        idrxToken = IERC20(_tokenAddress);
        examImplementation = _examImplementation;

        // Approve max amount (not recommended for production)
        idrxToken.approve(address(this), type(uint256).max);
    }

    /**
     * @notice Checks if an exam code already exists.
     * @param _examCode The exam code to check.
     * @return True if the exam code exists, false otherwise.
     */
    function checkExistingExamCode(
        string memory _examCode
    ) internal view returns (bool) {
        for (uint256 i = 0; i < listOfCreatedExams.length; i++) {
            if (
                keccak256(
                    abi.encodePacked(listOfCreatedExams[i].examConfig.examCode)
                ) == keccak256(abi.encodePacked(_examCode))
            ) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Creates a new exam contract.
     * @param _config The title of the exam.
     */
    function createExam(
        ExamStructs.ExamCreationConfig calldata _config
    ) public payable {
        require(
            !checkExistingExamCode(_config.examConfig.examCode),
            "Exam code already exists. Please choose a different one."
        );
        require(
            msg.value == examCreationFee,
            "Insufficient fee sent for exam creation"
        );
        require(
            bytes(_config.examConfig.examTitle).length > 5,
            "Exam title cannot be empty"
        );
        require(
            bytes(_config.examConfig.examCode).length > 3,
            "Exam code cannot be empty"
        );
        require(
            bytes(_config.tokenConfig.tokenName).length > 3,
            "Token name cannot be empty"
        );
        require(
            bytes(_config.tokenConfig.tokenSymbol).length > 2,
            "Token symbol cannot be empty"
        );

        // Create a clone of the ExamImplementation contract
        address examAddress = examImplementation.clone();

        // Properly initialize the cloned contract
        ExamImplementation(examAddress).initialize(_config);

        // Store the exam data
        listOfCreatedExams.push(_config);

        // Store the address of the created exam contract in the author's list
        examsByAuthor[_config.examConfig.initialOwner].push(examAddress);
        examConfigByAddress[examAddress] = _config.examConfig;
        verifiedExamContract[examAddress] = true;

        emit ExamCreated(_config.examConfig.initialOwner, examAddress);
    }

    /**
     * @notice Tracks the participant enrolling in an exam.
     * @dev This function is called by the ExamImplementation contract.
     * @param _examAddress The address of the exam contract.
     * @param _participant The address of the participant.
     */
    function trackEnrolledExam(
        address _examAddress,
        address _participant,
        ExamEnums.ExamStatus status
    ) external {
        // Only allow ExamImplementation contracts to call this
        require(verifiedExamContract[msg.sender], "Unauthorized caller");

        ExamStructs.ExamConfig memory _examConfig = examConfigByAddress[
            _examAddress
        ];

        ExamStructs.ExamHistory memory newHistory = ExamStructs.ExamHistory({
            examConfig: _examConfig,
            status: status
        });

        // Push mapping exam data to the participant
        examsEnrolledByParticipant[_participant].push(newHistory);
    }

    /**
     * @notice Get a range of exams
     * @dev This function is called by the ExamImplementation contract.
     * @param start The starting index (0-based)
     * @param count The number of exams to return
     * @return A partial array of Exam structs
     */
    function getExamsByRange(
        uint start,
        uint count
    ) public view returns (ExamStructs.ExamCreationConfig[] memory) {
        require(start < listOfCreatedExams.length, "Start index out of bounds");

        uint end = start + count;
        if (end > listOfCreatedExams.length) {
            end = listOfCreatedExams.length;
        }

        ExamStructs.ExamCreationConfig[]
            memory exams = new ExamStructs.ExamCreationConfig[](end - start);
        for (uint i = start; i < end; i++) {
            exams[i - start] = listOfCreatedExams[i];
        }

        return exams;
    }

    /**
     * @notice Retrieves the list of all created exams.
     * @return examAddresses The addresses of the created exams.
     * @return examCodes The codes of the created exams.
     * @return examCount The number of created exams.
     */
    function getExamsByAuthor(
        address _author
    )
        public
        view
        returns (
            address[] memory examAddresses,
            string[] memory examCodes,
            uint256 examCount
        )
    {
        uint256 count = examsByAuthor[_author].length;
        require(count > 0, "No exams found for this author");

        examAddresses = new address[](count);
        examCodes = new string[](count);

        for (uint256 i = 0; i < count; i++) {
            address examAddr = examsByAuthor[_author][i];

            for (uint256 j = 0; j < listOfCreatedExams.length; j++) {
                if (listOfCreatedExams[j].examConfig.examAddress == examAddr) {
                    examAddresses[i] = listOfCreatedExams[j]
                        .examConfig
                        .examAddress;
                    examCodes[i] = listOfCreatedExams[j].examConfig.examCode;
                    break;
                }
            }
        }

        return (examAddresses, examCodes, count);
    }

    /**
     * @notice Retrieves the list of all created exams.
     * @return The addresses of the created exams.
     */
    function getExamByCode(
        string memory _examCode
    ) public view returns (address) {
        for (uint256 i = 0; i < listOfCreatedExams.length; i++) {
            if (
                keccak256(
                    abi.encodePacked(listOfCreatedExams[i].examConfig.examCode)
                ) == keccak256(abi.encodePacked(_examCode))
            ) {
                return listOfCreatedExams[i].examConfig.examAddress;
            }
        }
        revert("Exam not found");
    }

    /**
     * @notice Withdraws the contract balance to the owner's address.
     */
    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        require(success, "Withdraw failed");
    }
}

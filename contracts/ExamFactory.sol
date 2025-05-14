// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ExamImplementation.sol";
import "../enums/ExamEnums.sol";
import "../structs/ExamStructs.sol";
import "../structs/CertificateStructs.sol";

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
    IERC20 public immutable idrxToken;

    /// @notice Fee for creating an exam on ETH
    uint256 public constant examCreationFee = 0.0001 ether;

    /// @notice Fee for creating an exam on IDRX
    uint256 public constant examCreationFeeIDRX = 1000;

    /// @notice  Base URI for IPFS (will be appended with tokenId.json)
    string private baseTokenURI;

    /// @notice List of all created exams
    ExamStructs.Exam[] private listOfCreatedExams;

    /// @notice Mapping of exam code => boolean exist
    mapping(string => bool) private codeExists;

    /// @notice Mapping [examCode] => ExamStructs.Exam
    mapping(string => ExamStructs.Exam) private examByCode;

    /// @notice Mapping [examAddress] => boolean verified
    mapping(address => bool) public verifiedExamContract;

    /// @notice Mapping [participantAddress] => ExamStructs.ExamHistory[]
    mapping(address => ExamStructs.ExamHistory[]) private examHistory;

    /// @notice Mapping [participantAddress][examCode] => index
    mapping(address => mapping(string => uint256)) private examHistoryToIndex;

    /// @notice Mapping [participantAddress][certificateId] => examCode
    mapping(address => mapping(string => string))
        public certificateIdToExamCode;

    /// @notice Mapping [participantAddress][examCode] => true if status enrolled, else false
    mapping(address => mapping(string => ExamEnums.ExamStatus))
        private statusOfExam;

    // --------------------------------------------------
    // Events
    // --------------------------------------------------

    /// @notice Event emitted when an exam is created.
    event ExamCreated(address indexed author, address examContractAddress);

    /// @notice Event emitted when a participant joins an exam.
    event TrackExamHistory(
        address indexed participant,
        address examAddress,
        string examCode,
        ExamEnums.ExamStatus status
    );

    // --------------------------------------------------
    // Constructor
    // --------------------------------------------------

    /**
     * @notice Constructor to initialize the ExamFactory contract.
     * @param _examImplementation The address of the ExamImplementation contract.
     */
    constructor(
        address _examImplementation,
        address _idrxTokenAddress
    ) Ownable(msg.sender) {
        require(
            _examImplementation != address(0),
            "Invalid implementation address"
        );
        idrxToken = IERC20(_idrxTokenAddress);
        examImplementation = _examImplementation;
    }

    // --------------------------------------------------
    // READ Functions
    // --------------------------------------------------

    /**
     * @notice Get all exams with pagination
     * @param _page Desired page for the data
     * @param _take Data count for each page
     */
    function getAllExams(
        uint256 _page,
        uint256 _take
    )
        public
        view
        returns (
            ExamStructs.Exam[] memory,
            uint256 currentPage,
            uint256 itemsPerPage,
            uint256 totalPages,
            bool hasPreviousPage,
            bool hasNextPage
        )
    {
        require(_page >= 1, "Invalid page start");
        require(_take > 0, "Items per page must be > 0");

        uint256 totalExams = listOfCreatedExams.length;
        uint256 start = (_page - 1) * _take;

        // Calculate total pages using ceiling division
        totalPages = (totalExams + _take - 1) / _take;

        // Prevent out-of-bounds access
        if (start >= totalExams) {
            return (
                new ExamStructs.Exam[](0),
                _page,
                _take,
                totalPages,
                false,
                false
            ); // Return empty if beyond range
        }

        uint256 end = start + _take;
        if (end > totalExams) {
            end = totalExams;
        }

        ExamStructs.Exam[] memory exams = new ExamStructs.Exam[](end - start);
        for (uint256 i = start; i < end; i++) {
            exams[i - start] = listOfCreatedExams[i];
        }

        // Pagination flags
        hasPreviousPage = (_page > 1);
        hasNextPage = (_page < totalPages);

        return (exams, _page, _take, totalPages, hasPreviousPage, hasNextPage);
    }

    /**
     * @notice Get all available exams
     */
    function getAvailableExams()
        public
        view
        returns (ExamStructs.AvailableExam[] memory)
    {
        ExamStructs.AvailableExam[]
            memory available = new ExamStructs.AvailableExam[](
                listOfCreatedExams.length
            );

        for (uint256 i = 0; i < listOfCreatedExams.length; i++) {
            ExamEnums.ExamStatus currentStatus = statusOfExam[msg.sender][
                listOfCreatedExams[i].examConfig.examCode
            ];

            if (
                ExamEnums.ExamStatus.ENROLLED == currentStatus ||
                ExamEnums.ExamStatus.NOTENROLLED == currentStatus
            ) {
                available[i] = ExamStructs.AvailableExam({
                    exam: listOfCreatedExams[i],
                    status: currentStatus
                });
            }
        }

        return available;
    }

    /**
     * @notice Checks if an exam code already exists.
     * @param _examCode The exam code to check.
     * @return True if the exam code exists, false otherwise.
     */
    function checkExistingExamCode(
        string memory _examCode
    ) public view returns (bool) {
        // Return true if exists
        return codeExists[_examCode];
    }

    /**
     * @notice Get exam data by exam code.
     * @param _examCode The exam code to check.
     * @return exam struct of exam.
     */
    function getExamByCode(
        string memory _examCode
    ) public view returns (ExamStructs.Exam memory exam) {
        require(checkExistingExamCode(_examCode), "Invalid exam code");
        return examByCode[_examCode];
    }

    /**
     * @notice Get all exam history of participant by status.
     * @param _participant address of participant.
     * @return memory exam history of participant.
     */
    function getAllExamHistory(
        address _participant
    ) public view returns (ExamStructs.ExamHistory[] memory) {
        return examHistory[_participant];
    }

    /**
     * @notice Get exam history of participant by status.
     * @param _participant address of participant.
     * @param _status status of the exam.
     * @return memory exam history of participant.
     */
    function getExamHistoryByStatus(
        address _participant,
        ExamEnums.ExamStatus _status
    ) public view returns (ExamStructs.ExamHistory[] memory) {
        ExamStructs.ExamHistory[] storage history = examHistory[_participant];
        ExamStructs.ExamHistory[] memory temp = new ExamStructs.ExamHistory[](
            history.length
        );
        uint256 index = 0;

        for (uint256 i = 0; i < history.length; i++) {
            if (history[i].status == _status) {
                temp[index] = history[i];
                index++;
            }
        }

        // Resize the array to remove empty slots
        ExamStructs.ExamHistory[]
            memory filteredHistory = new ExamStructs.ExamHistory[](index);

        for (uint256 i = 0; i < index; i++) {
            filteredHistory[i] = temp[i];
        }

        return filteredHistory;
    }

    /**
     * @notice Verify data of certificate.
     * @param _participant address of participant.
     * @param _certificateId.
     * @return memory CertificateStructs.Certificate.
     */
    function verifyCertificate(
        address _participant,
        string memory _certificateId
    ) public view returns (CertificateStructs.Certificate memory) {
        string memory examCode = certificateIdToExamCode[_participant][
            _certificateId
        ];

        if (bytes(examCode).length == 0) {
            revert("This exam has not been submitted by this address.");
        } else {
            ExamStructs.Exam memory exam = getExamByCode(examCode);
            uint256 index = examHistoryToIndex[_participant][examCode];

            ExamStructs.ExamHistory memory history = examHistory[_participant][
                index
            ];

            return
                CertificateStructs.Certificate({
                    certificateId: _certificateId,
                    examTitle: exam.examConfig.examTitle,
                    examDescription: exam.examConfig.examDescription,
                    dateIssued: history.examResult.submittedAt,
                    issuer: "Validia",
                    contractAddress: exam.addressConfig.examAddress
                });
        }
    }

    // --------------------------------------------------
    // WRITE Functions
    // --------------------------------------------------

    /**
     * @notice Creates a new exam contract.
     * @param _examConfig Request config for create exam.
     * @param _tokenConfig Request config for token.
     */
    function createExam(
        ExamStructs.ExamConfig calldata _examConfig,
        ExamStructs.TokenConfig calldata _tokenConfig
    ) public payable {
        require(
            !checkExistingExamCode(_examConfig.examCode),
            "Exam code already exists. Please choose a different one."
        );
        require(
            msg.value == examCreationFee,
            "Insufficient fee sent for exam creation"
        );
        require(
            bytes(_examConfig.examTitle).length > 5,
            "Exam title cannot be empty"
        );
        require(
            bytes(_examConfig.examCode).length > 3,
            "Exam code cannot be empty"
        );
        require(
            bytes(_tokenConfig.tokenName).length > 3,
            "Token name cannot be empty"
        );
        require(
            bytes(_tokenConfig.tokenSymbol).length > 2,
            "Token symbol cannot be empty"
        );

        // Create a clone of the ExamImplementation contract
        address examAddress = examImplementation.clone();

        ExamStructs.Exam memory _exam = ExamStructs.Exam({
            addressConfig: ExamStructs.AddressConfig({
                initialOwner: msg.sender,
                examAddress: examAddress
            }),
            examConfig: _examConfig,
            tokenConfig: _tokenConfig
        });

        // Properly initialize the cloned contract
        ExamImplementation(examAddress).initialize(
            address(this),
            address(idrxToken),
            baseTokenURI,
            _exam
        );

        // Store the exam data
        listOfCreatedExams.push(_exam);
        // Store exam code exist to true
        codeExists[_exam.examConfig.examCode] = true;
        // Store the exam data by exam code
        examByCode[_exam.examConfig.examCode] = _exam;
        // Store exam address
        verifiedExamContract[examAddress] = true;

        emit ExamCreated(_exam.addressConfig.initialOwner, examAddress);
    }

    /**
     * @notice Tracks the exam history of the participant.
     * @dev This function is called by the ExamImplementation contract.
     * @param _participant The address of the participant.
     * @param _examCode The history of participant exam.
     * @param _result The address of the participant.
     * @param _status The history of participant exam.
     */
    function trackExamHistory(
        address _participant,
        string memory _examCode,
        ExamStructs.ExamResult calldata _result,
        ExamEnums.ExamStatus _status
    ) external {
        // Only allow ExamImplementation contracts to call this
        require(verifiedExamContract[msg.sender], "Unauthorized caller");
        require(checkExistingExamCode(_examCode), "Exam code does not exist.");

        // Get exam data by code
        ExamStructs.Exam memory _exam = examByCode[_examCode];

        if (_status == ExamEnums.ExamStatus.ENROLLED) {
            statusOfExam[_participant][_examCode] = ExamEnums
                .ExamStatus
                .ENROLLED;
            // Store exam history
            examHistory[_participant].push(
                ExamStructs.ExamHistory({
                    examAddress: _exam.addressConfig.examAddress,
                    examCode: _exam.examConfig.examCode,
                    examTitle: _exam.examConfig.examTitle,
                    examDescription: _exam.examConfig.examDescription,
                    examResult: _result,
                    status: _status
                })
            );
            // Store exam history index
            examHistoryToIndex[_participant][_examCode] =
                examHistory[_participant].length -
                1;
        } else {
            statusOfExam[_participant][_examCode] = _status;

            // Get current exam history by index
            uint256 index = examHistoryToIndex[_participant][_examCode];
            ExamStructs.ExamHistory storage _current = examHistory[
                _participant
            ][index];

            // Update exam history
            _current.examResult.submittedAt = _result.submittedAt;
            _current.examResult.timeTaken = _result.timeTaken;
            _current.examResult.correctAnswers = _result.correctAnswers;
            _current.examResult.score = _result.score;
            _current.status = _status;
        }

        emit TrackExamHistory(
            _participant,
            _exam.addressConfig.examAddress,
            _examCode,
            _status
        );
    }

    function setCertificateToExamCode(
        address _participant,
        string memory _examCode,
        string memory _certificateId
    ) external {
        // Only allow ExamImplementation contracts to call this
        require(verifiedExamContract[msg.sender], "Unauthorized caller");
        require(checkExistingExamCode(_examCode), "Exam code does not exist.");

        certificateIdToExamCode[_participant][_certificateId] = _examCode;
    }

    /**
     * @notice Setter baseTokenURI for ERC721 metadata.
     */
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseTokenURI = _newBaseURI;
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol"; // Import Initializable
import "@openzeppelin/contracts/utils/Strings.sol"; // Import Strings library

import "./ExamFactory.sol";
import "../enums/ExamEnums.sol";
import "../structs/ExamStructs.sol";

/**
 * @title ExamImplementation
 * @notice This contract represents the implementation of an exam.
 */
contract ExamImplementation is ERC721Enumerable, Ownable, Initializable {
    // --------------------------------------------------
    // State Variables
    // --------------------------------------------------

    /// @notice Address of the ExamFactory contract
    address public factoryAddress;

    /// @notice The ERC20 token used for funding (IDRX).
    IERC20 public idrxToken;

    /// @notice Variables for exam details
    string public examCode;
    string public examTitle;
    string public examDescription;
    uint256 public durationInMinutes;
    uint256 public totalQuestion;
    uint256 public minimumScore;

    /// @notice Variables for exam costs
    uint256 public examWeiCost;
    uint256 public examIdrxCost;

    /// @notice Variables for NFT minting
    string public tokenName;
    string public tokenSymbol;
    string public baseURI;

    /// @notice Mapping of participant address => boolean
    mapping(address => bool) public isParticipant;

    /// @notice Mapping of participant address => boolean is submitted exam
    mapping(address => bool) public hasSubmittedExam;

    /// @notice Mapping of participant address => exam result submission
    mapping(address => ExamStructs.ExamResult) public examResultByAddress;

    // --------------------------------------------------
    // Events
    // --------------------------------------------------

    event ParticipantRegistered(address indexed participant);

    event ExamSubmitted(
        address indexed student,
        string timeTaken,
        string submittedAt,
        uint256 correctAnswers,
        uint256 score
    );

    // --------------------------------------------------
    // Constructor
    // --------------------------------------------------

    /**
     * @notice Constructor (since Clones require an initialize function)
     */
    constructor() ERC721(tokenName, tokenSymbol) Ownable(msg.sender) {}

    /**
     * @notice Initializes the contract with the given parameters.
     * @param _config The object to create exam.
     */
    function initialize(
        ExamStructs.ExamCreationConfig memory _config
    ) public initializer {
        // Initialize address
        factoryAddress = _config.factoryAddress;
        idrxToken = IERC20(_config.idrxTokenAddress);

        // Set the initial owner of the contract
        _transferOwnership(_config.examConfig.initialOwner);

        // Initialize the exam details
        examCode = _config.examConfig.examCode;
        examTitle = _config.examConfig.examTitle;
        examDescription = _config.examConfig.examDescription;
        durationInMinutes = _config.examConfig.durationInMinutes;
        totalQuestion = _config.examConfig.totalQuestion;
        minimumScore = _config.examConfig.minimumScore;
        examWeiCost = _config.examConfig.examWeiCost;
        examIdrxCost = _config.examConfig.examIdrxCost;

        // Reinitialize ERC721 with name and symbol
        tokenName = _config.tokenConfig.tokenName;
        tokenSymbol = _config.tokenConfig.tokenSymbol;
    }

    /**
     * @notice Register an address to participate the exam.
     * @dev This function allows the owner to register a participant for the exam.
     * @param _participant The address of the participant.
     */
    function registerParticipant(address _participant) external onlyOwner {
        require(!isParticipant[_participant], "Participant already registered");
        isParticipant[_participant] = true;
        emit ParticipantRegistered(_participant);
    }

    /**
     * @notice Enroll the exam with a specific code.
     * @dev This function allows a participant to enroll the exam by providing the correct exam code and paying the required fee.
     * @param _examCode The code for the exam.
     * @param _participant The address of the participant.
     */
    function enrollExam(
        string memory _examCode,
        address _participant
    ) public payable {
        require(
            keccak256(abi.encodePacked(examCode)) ==
                keccak256(abi.encodePacked(_examCode)),
            "Incorrect exam code."
        );
        require(
            msg.value == examWeiCost,
            string(
                abi.encodePacked(
                    "Insufficient fee, must be ",
                    Strings.toString(examWeiCost / 1e18),
                    " ETH"
                )
            )
        );
        isParticipant[_participant] = true;

        ExamFactory(factoryAddress).trackEnrolledExam(
            address(this),
            msg.sender,
            ExamEnums.ExamStatus.ENROLLED
        );

        emit ParticipantRegistered(_participant);
    }

    /**
     * @notice Submit the exam with the given parameters.
     * @dev This function allows a participant to submit their exam results and mint an NFT certificate if they meet the score requirement.
     * @param _timeTaken The time taken to complete the exam.
     * @param _submittedAt The date of the exam submission.
     * @param _correctAnswers The number of correct answers.
     * @param _score The score obtained in the exam.
     */
    function submitExam(
        string memory _timeTaken,
        string memory _submittedAt,
        uint256 _correctAnswers,
        uint256 _score
    ) public {
        require(
            isParticipant[msg.sender],
            "You are not a registered participant"
        );
        require(!hasSubmittedExam[msg.sender], "Exam already submitted");

        ExamEnums.ExamStatus status = _score >= minimumScore
            ? ExamEnums.ExamStatus.PASSED
            : ExamEnums.ExamStatus.FAILED;

        examResultByAddress[msg.sender] = ExamStructs.ExamResult({
            score: _score,
            correctAnswers: _correctAnswers,
            submittedAt: _submittedAt,
            timeTaken: _timeTaken,
            status: status
        });

        ExamFactory(factoryAddress).trackEnrolledExam(
            address(this),
            msg.sender,
            status
        );

        // Only proceed with NFT minting if score meets minimum requirement
        if (status == ExamEnums.ExamStatus.PASSED) {
            // Get current supply of NFTs
            uint256 supply = totalSupply();
            // Mint the NFT certificate
            _safeMint(msg.sender, supply + 1);
        }

        hasSubmittedExam[msg.sender] = true;

        emit ExamSubmitted(
            msg.sender,
            _timeTaken,
            _submittedAt,
            _correctAnswers,
            _score
        );
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

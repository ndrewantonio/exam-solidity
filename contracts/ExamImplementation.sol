// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./ExamFactory.sol";
import "../enums/ExamEnums.sol";
import "../structs/ExamStructs.sol";

/**
 * @title ExamImplementation
 * @notice This contract represents the implementation of an exam.
 */
contract ExamImplementation is
    Initializable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    // --------------------------------------------------
    // State Variables
    // --------------------------------------------------

    /// @notice Address of the ExamFactory contract
    address public factoryAddress;

    /// @notice The ERC20 token used for funding (IDRX).
    IERC20 public idrxToken;

    /// @notice Total IDRX managed by the contract.
    uint256 public totalManagedIDRX;

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
    string private baseTokenURI;

    /// @notice Mapping [participantAddress] => boolean
    mapping(address => bool) public isParticipant;

    /// @notice Mapping [participantAddress] => boolean is submitted exam
    mapping(address => bool) public hasSubmittedExam;

    /// @notice Mapping [participantAddress] => ExamStructs.ExamResult
    mapping(address => ExamStructs.ExamResult) public examResultByAddress;

    /// @notice Mapping [participantAddress] => ExamEnums.ExamStatus
    mapping(address => ExamEnums.ExamStatus) public participantStatus;

    mapping(address => string) private certificateIdByAddress;

    // --------------------------------------------------
    // Events
    // --------------------------------------------------

    event InitializeExam(
        address indexed examAddress,
        address owner,
        string examCode
    );

    event ParticipantRegistered(address indexed participant);

    event ExamSubmitted(
        address indexed student,
        string timeTaken,
        string submittedAt,
        uint256 correctAnswers,
        uint256 score
    );

    event IDRXWithdrawn(address indexed owner, uint256 amount);

    // --------------------------------------------------
    // Constructor
    // --------------------------------------------------

    /**
     * @notice Constructor (since Clones require an initialize function)
     */
    constructor() {}

    // --------------------------------------------------
    // READ Functions
    // -------------------------------------------------

    /**
     * @notice Get certificate Id by address
     * @return String of certificate Id if available.
     */
    function getCertificateId(
        address _address
    ) public view returns (string memory) {
        require(
            bytes(certificateIdByAddress[_address]).length != 0,
            "No certificate ID for this address"
        );
        return certificateIdByAddress[_address];
    }

    /**
     * @notice Override function from ERC721Upgradable
     * @return baseURI for the ERC721 metadata.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @notice Override function from ERC721Upgradable
     * @return string tokenURI for the ERC721 metadata.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            totalSupply() >= tokenId,
            "ERC721Metadata: URI query for nonexistent token"
        );

        return _baseURI();
    }

    // --------------------------------------------------
    // WRITE Functions
    // -------------------------------------------------

    /**
     * @notice Initializes the contract with the given parameters.
     * @param _idrxTokenAddress The address of IDRX token.
     * @param _factoryAddress The address of exam factory.
     * @param _initBaseURI The baseURI for IPFS ERC721 metadata.
     * @param _config The exam config.
     */
    function initialize(
        address _factoryAddress,
        address _idrxTokenAddress,
        string memory _initBaseURI,
        ExamStructs.Exam calldata _config
    ) public initializer {
        // Initialize ERC721
        __ERC721_init(
            _config.tokenConfig.tokenName,
            _config.tokenConfig.tokenSymbol
        );
        __ERC721Enumerable_init();
        __Ownable_init(msg.sender);

        // Set the initial owner of the contract
        _transferOwnership(_config.addressConfig.initialOwner);

        // Initialize address
        factoryAddress = _factoryAddress;
        idrxToken = IERC20(_idrxTokenAddress);

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
        baseTokenURI = _initBaseURI;

        emit InitializeExam(address(this), owner(), examCode);
    }

    /**
     * @notice Enroll the exam.
     * @param _participant address of participant
     * @dev Private function to enroll exam.
     */
    function enroll(address _participant) private {
        require(!isParticipant[_participant], "Participant already registered");
        isParticipant[_participant] = true;

        // Store exam result by participant address
        examResultByAddress[_participant] = ExamStructs.ExamResult({
            timeTaken: "",
            submittedAt: "",
            correctAnswers: 0,
            score: 0
        });

        participantStatus[_participant] = ExamEnums.ExamStatus.ENROLLED;

        ExamFactory(factoryAddress).trackExamHistory(
            _participant,
            examCode,
            ExamStructs.ExamResult({
                timeTaken: "",
                submittedAt: "",
                correctAnswers: 0,
                score: 0
            }),
            ExamEnums.ExamStatus.ENROLLED
        );

        emit ParticipantRegistered(_participant);
    }

    /**
     * @notice Enroll the exam by paying the required cost.
     * @dev Payable using ETH.
     */
    function enrollExamETH() public payable {
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

        enroll(msg.sender);
    }

    /**
     * @notice Enroll the exam by paying the required cost.
     * @dev Payable using IDRX Token.
     */
    function enrollExamIDRX(uint256 _amount) public {
        require(
            _amount == examIdrxCost,
            string(
                abi.encodePacked(
                    "Insufficient fee, must be ",
                    Strings.toString(examIdrxCost),
                    " IDRX"
                )
            )
        );

        uint256 idrxRealAmount = _amount * 100;
        // Need approval
        require(
            idrxToken.approve(msg.sender, idrxRealAmount),
            "Approval failed"
        );

        // Transfer tokens (will auto-revert on failure)
        idrxToken.safeTransferFrom(msg.sender, owner(), idrxRealAmount);

        totalManagedIDRX += _amount;
        enroll(msg.sender);
    }

    /**
     * @notice Enroll address only by owner to participate the exam.
     * @dev This function allows the owner to enroll a participant for the exam.
     * @param _participant The address of the participant.
     */
    function enrollParticipant(address _participant) public onlyOwner {
        enroll(_participant);
    }

    /**
     * @notice Submit the exam with the given parameters.
     * @dev This function allows a participant to submit their exam results and mint an NFT certificate if they meet the score requirement.
     * @param _result The result of the exam.
     */
    function submitExam(ExamStructs.ExamResult calldata _result) public {
        require(
            isParticipant[msg.sender],
            "You are not a registered participant"
        );
        require(!hasSubmittedExam[msg.sender], "Exam already submitted");
        require(
            participantStatus[msg.sender] == ExamEnums.ExamStatus.ENROLLED,
            "Status invalid for submission"
        );
        require(
            _result.score >= 0 && _result.score <= 100,
            "Score out of bounds"
        );

        // Set final status for submission
        ExamEnums.ExamStatus finalStatus = _result.score >= minimumScore
            ? ExamEnums.ExamStatus.PASSED
            : ExamEnums.ExamStatus.FAILED;

        // Update status for participant
        participantStatus[msg.sender] = finalStatus;

        // Update the result after submission
        ExamStructs.ExamResult storage _current = examResultByAddress[
            msg.sender
        ];
        _current.timeTaken = _result.timeTaken;
        _current.submittedAt = _result.submittedAt;
        _current.correctAnswers = _result.correctAnswers;
        _current.score = _result.score;

        // Send to main contract to track exam history
        ExamFactory(factoryAddress).trackExamHistory(
            msg.sender,
            examCode,
            _result,
            finalStatus
        );

        // Only proceed with NFT minting if score meets minimum requirement
        if (finalStatus == ExamEnums.ExamStatus.PASSED) {
            // Get current supply of NFTs
            uint256 tokenId = totalSupply() + 1;
            // Mint the NFT certificate
            _safeMint(msg.sender, tokenId);

            string memory certificateId = string(
                abi.encodePacked(examCode, Strings.toString(tokenId))
            );

            certificateIdByAddress[msg.sender] = certificateId;

            ExamFactory(factoryAddress).setCertificateToExamCode(
                msg.sender,
                examCode,
                certificateId
            );
        }

        hasSubmittedExam[msg.sender] = true;

        emit ExamSubmitted(
            msg.sender,
            _result.timeTaken,
            _result.submittedAt,
            _result.correctAnswers,
            _result.score
        );
    }

    /**
     * @notice Setter baseURI for ERC721 metadata.
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

    /**
     * @notice Withdraws IDRX to the owner's address.
     */
    function withdrawIDRX() public onlyOwner {
        uint256 contractBalance = idrxToken.balanceOf(address(this));
        require(contractBalance > 0, "0 IDRX to withdraw");

        idrxToken.safeTransfer(owner(), contractBalance);

        emit IDRXWithdrawn(owner(), contractBalance);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../enums/ExamEnums.sol";

library ExamStructs {
    struct AddressConfig {
        address initialOwner;
        address examAddress;
    }

    struct ExamConfig {
        // Exam metadata
        string examCode;
        string examTitle;
        string examDescription;
        // Exam settings
        uint256 durationInMinutes;
        uint256 totalQuestion;
        uint256 minimumScore;
        // Cost settings
        uint256 examWeiCost;
        uint256 examIdrxCost;
    }

    struct TokenConfig {
        string tokenName;
        string tokenSymbol;
    }

    struct Exam {
        AddressConfig addressConfig;
        ExamConfig examConfig;
        TokenConfig tokenConfig;
    }

    // for exam that never been submitted
    struct AvailableExam {
        Exam exam;
        ExamEnums.ExamStatus status;
    }

    struct ExamResult {
        string timeTaken;
        string submittedAt;
        uint256 correctAnswers;
        uint256 score;
    }

    struct ExamHistory {
        address examAddress;
        string examCode;
        string examTitle;
        string examDescription;
        ExamResult examResult;
        ExamEnums.ExamStatus status;
    }
}

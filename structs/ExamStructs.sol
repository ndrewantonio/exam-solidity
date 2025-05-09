// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../enums/ExamEnums.sol";

library ExamStructs {
    struct ExamConfig {
        address initialOwner;
        address examAddress;
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

    struct ExamCreationConfig {
        address factoryAddress;
        address idrxTokenAddress;
        ExamConfig examConfig;
        TokenConfig tokenConfig;
    }

    struct ExamHistory {
        ExamConfig examConfig;
        ExamEnums.ExamStatus status;
    }

    struct ExamResult {
        uint256 score;
        uint256 correctAnswers;
        string submittedAt;
        string timeTaken;
        ExamEnums.ExamStatus status;
    }
}

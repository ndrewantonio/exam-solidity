// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ExamEnums {
    enum ExamStatus {
        NOTENROLLED,
        ENROLLED,
        PASSED,
        FAILED
    }

    enum QuestionType {
        MULTIPLE_CHOICE,
        TRUE_FALSE,
        SHORT_ANSWER,
        ESSAY
    }

    enum DifficultyLevel {
        EASY,
        MEDIUM,
        HARD,
        EXPERT
    }
}

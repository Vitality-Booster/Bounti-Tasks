// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface SharedTypes {

    // @dev "DOES_NOT_EXIST" exists as a default value for this enum
    enum TaskStatus {DOES_NOT_EXIST, PENDING, IN_PROCESS, REVIEW, COMPLETED}

    // @dev "NOT_RELATED" exists as a default value for this enum
    enum TaskRole {NOT_RELATED, WORKER, REVIEWER}

    struct TaskDataForCalculation {
        uint prize;
        uint percentageForReviewers;
        uint[] reviewersIndexes;
        uint[] workersIndexes;
    }
}

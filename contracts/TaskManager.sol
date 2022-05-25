// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract TaskManager {

    // !!!review function should be done as well!!!

    enum TaskStatus {PENDING, IN_PROCESS, REVIEW, COMPLETED}

    struct Task {
        string id;
        address daoContract;
        address taskOwner;
        // @dev This is an array that keeps track of task workers indexes from the "allWorkers" array
        uint[] workersIndexes;
        // @dev This is an array that keeps track of task reviewers indexes from the "allReviewers" array
        uint[] reviewersIndexes;
        uint prize;
        // @dev This value shows the percentage of prize that will be paid to reviewers.
        // (This percentage will not be withdrawn from "prize", it will be paid separately)
        uint percentageForReviewers;
        TaskStatus status;
        // @dev Use this boolean in order to check if a Task was already created and exists in a map or not
        bool initialized;
    }

    struct Reviewer {
        address walletAddress;
        // @dev This map has a worker address as a key and a number as a value. Number shows a review for a particular worker.
        mapping(address => uint) reviewPerWorker;
        bool reviewCompleted;
    }

    struct Worker {
        address walletAddress;
        bool workCompleted;
    }

    // @dev This struct was created only in order to avoid "Stack too deep" exception in Remove Reviewers and Workers
    struct ForRemove {
        uint i;
        uint index;
        uint[] indexes;
    }

    // @dev This struct is created to simplify work around for "completeTask" function
    struct ReviewedWorker {
        address walletAddress;
        uint totalGrade;
    }

    // @dev This struct will be used to send needed data about a Task to the front-end
    struct TaskToGet {
        address daoContract;
        address taskOwner;
        uint prize;
        uint percentageForReviewers;
        TaskStatus status;
    }

    // @dev Storing all tasks in a map, where a key is a task id
    mapping(string => Task) private allTasks;

    // @dev This array stores ids of all the tasks, so that I could make use of array functions,
    // but didn't have to store all the Tasks doubled (in a mapping and in an array)
    string[] private tasksIds;

    Reviewer[] private allReviewers;
    Worker[] private allWorkers;

    // @dev Checks if the message sender is a task owner
    modifier isTaskOwner(string calldata id) {
        require(allTasks[id].taskOwner == msg.sender, "Only owner of the task can do that");
        _;
    }

    modifier taskExists(string calldata id) {
        require(allTasks[id].initialized, "The specified task does not exist");
        _;
    }

    // @dev Checks if the message sender has not been assigned as a worker yet. If they were, throw an exception.
    modifier isNotWorker(string calldata id) {
        uint[] memory workersIndexes = allTasks[id].workersIndexes;
        for (uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            require(allWorkers[index].walletAddress != msg.sender, "You have already been assigned as a worker");
        }
        _;
    }

    // @dev Checks if the message sender has not been assigned as a reviewer yet. If they were, throw an exception.
    modifier isNotReviewer(string calldata id) {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;
        for (uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            require(allReviewers[index].walletAddress != msg.sender, "You have already been assigned as a reviewer");
        }
        _;
    }

    // @dev Checks if the message sender has been assigned as a reviewer. If they were not, throw an exception.
    modifier isReviewer(string calldata id) {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;
        for (uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            if (allReviewers[index].walletAddress == msg.sender) {
                _;
            }
        }
        // Is it logical to have a "revert" in the end of the function just to get an exception?
        revert("You were not assigned as a reviewer. Only an assigned reviewer is allowed to do this");
    }

    // @dev Checks if the message sender has been assigned as a worker. If they were not, throw an exception.
    modifier isWorker(string calldata id) {
        uint[] memory workersIndexes = allTasks[id].workersIndexes;
        for (uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            if (allWorkers[index].walletAddress == msg.sender) {
                _;
            }
        }
        // Is it logical to have a "revert" in the end of the function just to get an exception?
        revert("You were not assigned as a worker. Only an assigned worker is allowed to do this");
    }

    modifier checkTaskStatus(string calldata id, TaskStatus status) {
        require(allTasks[id].status == status, "You can't do this action at current Task stage");
        _;
    }

    constructor() {

    }

    // @dev Creates a task, with provided daoContract and TaskId and message sender becomes a task owner
    function createTask(address daoContract, string memory id, uint prize, uint percentageForReviewers) public returns(bool) {
        require(!allTasks[id].initialized, "A task with this id already exists");
        allTasks[id].daoContract = daoContract;
        allTasks[id].taskOwner = msg.sender;
        allTasks[id].id = id;
        allTasks[id].initialized = true;
        allTasks[id].prize = prize;
        allTasks[id].percentageForReviewers = percentageForReviewers;
        allTasks[id].status = TaskStatus.PENDING;
        tasksIds.push(id);
        return true;
    }

    // @dev Makes a message sender a worker for the task
    // May be will need to add a verification where we check if the message sender is from the task DAO or not
    function addWorker(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isNotWorker(id) isNotReviewer(id) public returns(bool) {
        // @dev Adding a new Worker to the array
        uint index = allWorkers.length;
        allWorkers.push();
        allWorkers[index].walletAddress = msg.sender;
        // @dev Adding new Worker index to the array "workersIndexes" inside Task struct
        allTasks[id].workersIndexes.push(index);
        return true;
    }

    // @dev Makes a message sender a reviewer for the task
    // May be will need to add a verification where we check if the message sender is from the task DAO or not
    function addReviewer(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isNotWorker(id) isNotReviewer(id) public returns(bool) {
        // @dev Adding a new Reviewer to the array
        uint reviewerIndex = allReviewers.length;
        allReviewers.push();
        allReviewers[reviewerIndex].walletAddress = msg.sender;
        // @dev Adding new Reviewer index to the array "reviewersIndexes" inside Task struct
        allTasks[id].reviewersIndexes.push(reviewerIndex);
        return true;
    }

    function removeTask(string calldata id)
    taskExists(id) isTaskOwner(id) checkTaskStatus(id, TaskStatus.PENDING) public returns(bool) {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;
        for (uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            delete allReviewers[index];
        }

        // @dev Firstly, delete the task from mapping
        delete allTasks[id];
        // @dev Then delete the task from array
        for (uint i = 0; i < tasksIds.length; i++) {
            if (compareStrings(tasksIds[i], id)) {
                delete tasksIds[i];
                break;
            }
        }
        return true;
    }

    function removeWorker(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isWorker(id) public returns(bool) {
        // This array is created only in order to reduce amount of code
        ForRemove memory forRemove;
        forRemove.indexes = allTasks[id].workersIndexes;

        for ( ; forRemove.i < forRemove.indexes.length; forRemove.i++) {
            forRemove.index = forRemove.indexes[forRemove.i];
            if (allWorkers[forRemove.i].walletAddress == msg.sender) {
                // @dev Firstly, delete the index inside "workersIndexes" array which is inside the Task
                allTasks[id].workersIndexes[forRemove.i] = allTasks[id].workersIndexes[forRemove.indexes.length - 1];
                allTasks[id].workersIndexes.pop();
                // @dev Then delete the exact reviewer from allWorkers
                delete allWorkers[forRemove.index];
                return true;
            }
        }
        return false;
    }

    function removeReviewer(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isReviewer(id) public returns(bool) {
        ForRemove memory forRemove;
        forRemove.indexes = allTasks[id].reviewersIndexes;

        for ( ; forRemove.i < forRemove.indexes.length; forRemove.i++) {
            forRemove.index = forRemove.indexes[forRemove.i];
            if (allReviewers[forRemove.i].walletAddress == msg.sender) {
                // @dev Firstly, delete the index inside "reviewersIndexes" array which is inside the Task
                allTasks[id].reviewersIndexes[forRemove.i] = allTasks[id].reviewersIndexes[forRemove.indexes.length - 1];
                allTasks[id].reviewersIndexes.pop();
                // @dev Then delete the exact reviewer from allReviewers
                delete allReviewers[forRemove.index];
                return true;
            }
        }
        return false;
    }

    function getTask(string calldata id)
    taskExists(id) public view returns (TaskToGet memory, address[] memory, address[] memory) {
        TaskToGet memory taskData;
        taskData.daoContract = allTasks[id].daoContract;
        taskData.taskOwner = allTasks[id].taskOwner;
        taskData.percentageForReviewers = allTasks[id].percentageForReviewers;
        taskData.prize = allTasks[id].prize;
        taskData.status = allTasks[id].status;

        address[] memory workers = getAllWorkers(id);
        address[] memory reviewers = getAllReviewers(id);

        return (taskData, workers, reviewers);
    }

    function getAllDaoTasks(address daoContract) public view returns(string[] memory) {
        // Creating a limited array with a length (size, etc.) equal to tasksIds.length
        string[] memory daoTaskIds = new string[] (tasksIds.length);
        uint taskIndex = 0;
        for (uint i = 0; i < tasksIds.length; i++) {
            if (allTasks[tasksIds[i]].daoContract == daoContract) {
                daoTaskIds[taskIndex] = tasksIds[i];
                taskIndex++;
            }
        }
        return daoTaskIds;
    }

    function beginTask(string calldata id)
    isTaskOwner(id) taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) public returns(bool) {
        allTasks[id].status = TaskStatus.IN_PROCESS;
        return true;
    }

    // @dev Function that compares incoming strings as Solidity can't do it by default
    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function completeWorkerPart(string calldata id)
    taskExists(id) isWorker(id) checkTaskStatus(id, TaskStatus.IN_PROCESS) public {
        // @dev Counts how many workers have completed their parts.
        // If everyone completed it, then makes task status equal "REVIEW"
        uint finishedWorkers = 0;
        for(uint i = 0; i < allTasks[id].workersIndexes.length; i++) {
            uint index = allTasks[id].workersIndexes[i];
            if (allWorkers[index].walletAddress == msg.sender) {
                allWorkers[index].workCompleted = true;
            }
            if (allWorkers[index].workCompleted) {
                ++finishedWorkers;
                // if (finishedWorkers == allTasks[id].workersIndexes.length) {
                //     allTasks[id].status = TaskStatus.REVIEW;
                // }
            }
        }
    }

    function reviewTask(string calldata id, address[] memory reviewedWorkers, uint[] memory workerGrades)
    taskExists(id) isReviewer(id) checkTaskStatus(id, TaskStatus.REVIEW) public {
        Reviewer storage reviewer = getReviewer(id, msg.sender);
        for (uint i = 0; i < workerGrades.length; i++) {
            address worker = reviewedWorkers[i];
            uint grade = workerGrades[i];
            reviewer.reviewPerWorker[worker] = grade;
        }
        reviewer.reviewCompleted = true;
        // Should I have it there as that means that the last person to review will have to pay gas?
        if (isReviewCompleted(id)) {
            completeTask(id);
        }
    }

    function getReviewer(string calldata id, address walletAddress) private view returns(Reviewer storage) {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;

        for(uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            if (allReviewers[index].walletAddress == walletAddress) {
                return allReviewers[index];
            }
        }
        revert("No assigned reviewer found");
    }

    function getWorker(string calldata id, address walletAddress) private view returns(Worker storage) {
        uint[] memory workersIndexes = allTasks[id].workersIndexes;

        for(uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            if (allWorkers[index].walletAddress == walletAddress) {
                return allWorkers[index];
            }
        }
        revert("No assigned worker found");
    }

    function getAllReviewers(string calldata id) private view returns(address[] memory) {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;
        address[] memory reviewers = new address[] (reviewersIndexes.length);

        for(uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            reviewers[i] = allReviewers[index].walletAddress;
        }

        return reviewers;
    }

    function getAllWorkers(string calldata id) private view returns(address[] memory) {
        uint[] memory workersIndexes = allTasks[id].workersIndexes;
        address[] memory workers = new address[] (workersIndexes.length);

        for(uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            workers[i] = allWorkers[index].walletAddress;
        }

        return workers;
    }

    function isReviewCompleted(string calldata id) private view returns (bool) {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;

        for(uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            // @dev If at least one of the reviewers did not complete a review, then the false is returned
            if (!allReviewers[index].reviewCompleted) {
                return false;
            }
        }
        return true;
    }

    function askForImprovements(string calldata id, address walletAddress)
    taskExists(id) isReviewer(id) checkTaskStatus(id, TaskStatus.REVIEW) public {
        Worker storage worker = getWorker(id, walletAddress);
        worker.workCompleted = false;
        allTasks[id].status = TaskStatus.IN_PROCESS;
    }

    function completeTask(string calldata id) private {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;
        ReviewedWorker[] memory workers = new ReviewedWorker[] (allTasks[id].workersIndexes.length);
        uint totalReviews;
        address[] memory workerWallets = getAllWorkers(id);

        for (uint i = 0; i < workerWallets.length; i++) {
            workers[i].walletAddress = workerWallets[i];
        }

        for (uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            for (uint k = 0; k < workers.length; k++) {
                address wallet = workers[k].walletAddress;
                workers[k].totalGrade += allReviewers[index].reviewPerWorker[wallet];
                totalReviews += allReviewers[index].reviewPerWorker[wallet];
            }
            // @dev Paying Reviewers
            uint price = allTasks[id].prize * allTasks[id].percentageForReviewers / 100 / reviewersIndexes.length;
            // There should be transfer method
        }

        // @dev Paying Workers
        for (uint i = 0; i < workers.length; i++) {
            uint price = allTasks[id].prize * workers[i].totalGrade / totalReviews;
            // There should be transfer method
        }
    }
}

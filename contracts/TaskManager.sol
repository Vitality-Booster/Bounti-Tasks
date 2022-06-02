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
        bool needImprovements; // @dev Shows if a Reviewer demanded for improvements from workers
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

    struct MemberToPay {
        address walletAddress;
        uint reward;
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
                break;
            }

            if (i == reviewersIndexes.length - 1) {
                revert("You were not assigned as a reviewer. Only an assigned reviewer is allowed to do this");
            }
        }
        if (reviewersIndexes.length == 0) {
            revert("You were not assigned as a reviewer. Only an assigned reviewer is allowed to do this");
        }
    }

    // @dev Checks if the message sender has been assigned as a worker. If they were not, throw an exception.
    modifier isWorker(string calldata id) {
        uint[] memory workersIndexes = allTasks[id].workersIndexes;
        for (uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            if (allWorkers[index].walletAddress == msg.sender) {
                _;
                break;
            }

            if (i == workersIndexes.length - 1) {
                revert("You were not assigned as a worker. Only an assigned worker is allowed to do this");
            }
        }
        if (workersIndexes.length == 0) {
            revert("You were not assigned as a worker. Only an assigned worker is allowed to do this");
        }
    }

    modifier checkTaskStatus(string calldata id, TaskStatus status) {
        require(allTasks[id].status == status, "You can't do this action at current Task stage");
        _;
    }

    modifier enoughMembers(string calldata id) {
        uint workersCount = allTasks[id].workersIndexes.length;
        uint reviewersCount = allTasks[id].reviewersIndexes.length;
        require(workersCount >= 1 && reviewersCount >= 1, "In order to begin a task, it should have at least 1 reviewer and 1 worker");
        _;
    }

    constructor() {

    }

    // @dev Creates a task, with provided daoContract and TaskId and message sender becomes a task owner
    function createTask(address daoContract, string memory id, uint prize, uint percentageForReviewers) public {
        require(!allTasks[id].initialized, "A task with this id already exists");
        allTasks[id].daoContract = daoContract;
        allTasks[id].taskOwner = msg.sender;
        allTasks[id].id = id;
        allTasks[id].initialized = true;
        allTasks[id].prize = prize;
        allTasks[id].percentageForReviewers = percentageForReviewers;
        allTasks[id].status = TaskStatus.PENDING;
        tasksIds.push(id);
    }

    // @dev Makes a message sender a worker for the task
    // May be will need to add a verification where we check if the message sender is from the task DAO or not
    function addWorker(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isNotWorker(id) isNotReviewer(id) public {
        // @dev Adding a new Worker to the array
        uint index = allWorkers.length;
        allWorkers.push();
        allWorkers[index].walletAddress = msg.sender;
        // @dev Adding new Worker index to the array "workersIndexes" inside Task struct
        allTasks[id].workersIndexes.push(index);
    }

    // @dev Makes a message sender a reviewer for the task
    // May be will need to add a verification where we check if the message sender is from the task DAO or not
    function addReviewer(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isNotWorker(id) isNotReviewer(id) public {
        // @dev Adding a new Reviewer to the array
        uint reviewerIndex = allReviewers.length;
        allReviewers.push();
        allReviewers[reviewerIndex].walletAddress = msg.sender;
        // @dev Adding new Reviewer index to the array "reviewersIndexes" inside Task struct
        allTasks[id].reviewersIndexes.push(reviewerIndex);
    }

    function removeTask(string calldata id)
    taskExists(id) isTaskOwner(id) checkTaskStatus(id, TaskStatus.PENDING) public {
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
    }

    function removeWorker(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isWorker(id) public {
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
                break;
            }
        }
    }

    function removeReviewer(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) isReviewer(id) public {
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
                break;
            }
        }
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
    isTaskOwner(id) taskExists(id) checkTaskStatus(id, TaskStatus.PENDING) enoughMembers(id) public {
        allTasks[id].status = TaskStatus.IN_PROCESS;
    }

    // @dev Function that compares incoming strings as Solidity can't do it by default
    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function completeWorkerPart(string calldata id)
    taskExists(id) isWorker(id) checkTaskStatus(id, TaskStatus.IN_PROCESS) public {
        // @dev Counts how many workers have completed their parts.
        // If everyone completed it, then makes task status equal "REVIEW"
        for(uint i = 0; i < allTasks[id].workersIndexes.length; i++) {
            uint index = allTasks[id].workersIndexes[i];
            if (allWorkers[index].walletAddress == msg.sender) {
                allWorkers[index].workCompleted = true;
            }
        }
        if (isAllWorkCompleted(id)) {
            allTasks[id].status = TaskStatus.REVIEW;
            resetReviewers(id);
        }
    }

    // @dev Checks if all workers completed their parts
    function isAllWorkCompleted(string calldata id) private view returns (bool) {
        uint finishedWorkers = 0;
        for(uint i = 0; i < allTasks[id].workersIndexes.length; i++) {
            uint index = allTasks[id].workersIndexes[i];
            if (allWorkers[index].workCompleted) {
                finishedWorkers++;
            }
        }
        if (allTasks[id].workersIndexes.length == finishedWorkers) {
            return true;
        }
        return false;
    }

    function resetReviewers(string calldata id) private {
        uint[] memory reviewerIndexes = allTasks[id].reviewersIndexes;

        for (uint i = 0; i < reviewerIndexes.length; i++) {
            uint index = reviewerIndexes[i];
            allReviewers[index].needImprovements = false;
            allReviewers[index].reviewCompleted = false;
        }
    }

    function reviewTask(string calldata id, address[] calldata reviewedWorkers, uint[] calldata grades)
    checkTaskStatus(id, TaskStatus.REVIEW) public {
        executeReview(id, reviewedWorkers, grades);

        if (isReviewCompleted(id)) {
            allTasks[id].status = TaskStatus.COMPLETED;
            completeAllWork(id);
        }
    }

    function executeReview(string calldata id, address[] calldata reviewedWorkers, uint[] calldata grades)
    isReviewer(id) private {
        Reviewer storage reviewer = getReviewer(id, msg.sender);
        for (uint i = 0; i < grades.length; i++) {
            address worker = reviewedWorkers[i];
            uint grade = grades[i];
            // @dev That makes a grade not exceed its limits: 1 is minimum, 10 is maximum
            if (grade < 1) {
                grade = 1;
            }
            if (grade > 10) {
                grade = 10;
            }
            reviewer.reviewPerWorker[worker] = grade;
        }
        reviewer.reviewCompleted = true;
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
            if (!allReviewers[index].reviewCompleted) {
                return false;
            }
        }
        return true;
    }

    function askForImprovements(string calldata id, address[] calldata walletAddresses)
    taskExists(id) isReviewer(id) checkTaskStatus(id, TaskStatus.REVIEW) public {

        executeAskForImprovements(id, walletAddresses);

        if (shouldBeImproved(id)) {
            allTasks[id].status = TaskStatus.IN_PROCESS;
        }
        else if (isReviewCompleted(id)) {
            // As "executeAskForImprovements" turns value "reviewCompleted" to "true", it means that askForImprovement also counts as completing a review.
            // And there we check if everyone finished reviewing task.
            // If they did and the task didn't go to the IN_PROCESS yet, then the majority thinks that it should not be improved and it can move to the COMPLETED state
            allTasks[id].status = TaskStatus.COMPLETED;
            completeAllWork(id);
        }
    }

    function executeAskForImprovements(string calldata id, address[] calldata walletAddresses) private {
        for (uint i = 0; i < walletAddresses.length; i++) {
            Worker storage worker = getWorker(id, walletAddresses[i]);
            worker.workCompleted = false;
        }

        Reviewer storage currentReviewer = getReviewer(id, msg.sender);

        // "reviewCompleted" value is turn into "true", so that if the majority of reviewers still decide that the task is completed,
        //  then it was possible to complete the task
        currentReviewer.reviewCompleted = true;
        currentReviewer.needImprovements = true;

    }

    // @dev Checks if the task should be improved according to reviewers feedback
    // If the majority (>= 50%) of reviewers said that it should be improved, then return "true", otherwise returns "false"
    function shouldBeImproved(string calldata id) private view returns(bool) {
        uint[] memory reviewerIndexes = allTasks[id].reviewersIndexes;


        uint residual = reviewerIndexes.length % 2;

        // @dev keeps track of a number of reviewers that asked for improvements
        uint requiredImprovements;

        for (uint i = 0; i < reviewerIndexes.length; i++) {
            uint index = reviewerIndexes[i];
            if (allReviewers[index].needImprovements) {
                requiredImprovements++;
            }
        }

        // I add residual to the length, because it can be only equal to "1" or "0" and
        // when you add it to the length then the sum will be able to be devided by 2 without a residual
        // Quick example: if length = 6, then residual = 6 % 2 = 0, then requiredImprovements should be equal to or more than ( (6 + 0) / 2);
        // if length = 7, then residual = 7 % 2 = 1, then requiredImprovements should be equal to or more than ( (7 + 1) / 2)
        if (requiredImprovements >= ((reviewerIndexes.length + residual) / 2)) {
            return true;
        }
        return false;
    }

    // @dev This function must be executed only when the Task moves to the "COMPLETED" status
    // It is done, as when the Task moves to completed, some workers may have their "workCompleted" property set to "false" due to
    // reviewers that may have asked for improvements from them
    function completeAllWork(string calldata id) private {
        uint[] memory workersIndexes = allTasks[id].workersIndexes;

        for (uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            allWorkers[index].workCompleted = true;
        }
    }

    function completeTask(string calldata id)
    taskExists(id) checkTaskStatus(id, TaskStatus.COMPLETED) public view returns(MemberToPay[] memory) {
        return calculateRewards(id);
    }

    // This struct stores the majority of local variables needed for "calculateRewards" function.
    // This was done in order to avoid "Stack too deep" exception
    struct CalculateRewardsLocals {
        uint[] reviewersIndexes; // Shares the same logic as other "reviewersIndexes" throughout th code
        ReviewedWorker[] workers; // An array of structs that keeps track of total grade per worker
        uint totalReviews; // Total grades of all workers (needed to calculate a reward per every worker)
        address[] workerWallets; // Getting wallets but not an array of Worker struct, as I need only wallets there
        uint reviewersResidual; // A residual/rest that we get while calculating totalReviewersReward
        uint totalReviewersReward; // A total reward for all reviewers
        uint restRewardReviewers; // A residual/rest that we get while calculating a singleReviewerReward
        uint singleReviewerReward; // A reward for every reviewer (it is equal for all reviewers), but its not the final reward (check the function)
        uint restRewardWorkers; // A residual/rest that we get while calculating a reward for every worker
    }

    // In order to better understand the workflow of this function remember:
    // Solidity can't work with decimals. So I had to create a work-around for calculating all rewards and keep them integer
    // That is why I am calculating residual/rest for all the rewards
    // Then I give this residual/rest of total rewards to the workers/reviewers and was trying to make it as fair as I could (check code for details)
    function calculateRewards(string calldata id) private view returns(MemberToPay[] memory) {
        CalculateRewardsLocals memory locals;
        locals.reviewersIndexes = allTasks[id].reviewersIndexes;
        locals.workers = new ReviewedWorker[] (allTasks[id].workersIndexes.length);
        MemberToPay[] memory members = new MemberToPay[] (locals.reviewersIndexes.length + locals.workers.length);
        locals.workerWallets = getAllWorkers(id);
        locals.reviewersResidual = (allTasks[id].prize * allTasks[id].percentageForReviewers) % uint(100);

        // If the residual/rest, aka reviewersResidual, is not equal to "0", I add one more coin/token to totalReviewersReward, no need to thank me :)
        if (locals.reviewersResidual == 0) {
            locals.totalReviewersReward = allTasks[id].prize * allTasks[id].percentageForReviewers / uint(100);
        }
        else {
            locals.totalReviewersReward = (allTasks[id].prize * allTasks[id].percentageForReviewers - locals.reviewersResidual) / uint(100) + uint(1);
        }

        locals.restRewardReviewers = locals.totalReviewersReward % locals.reviewersIndexes.length;
        locals.singleReviewerReward = (locals.totalReviewersReward - locals.restRewardReviewers) / locals.reviewersIndexes.length;

        // Adding all the Workers' wallet addresses to "workers" array
        for (uint i = 0; i < locals.workerWallets.length; i++) {
            locals.workers[i].walletAddress = locals.workerWallets[i];
        }

        // Going through all the Reviewers to get grades for every Worker and to calculate Reviewers' rewards
        for (uint i = 0; i < locals.reviewersIndexes.length; i++) {
            uint index = locals.reviewersIndexes[i];
            // There we cycle through all workers that reviewers reviewed and get the worker's grade from the reviewer
            for (uint k = 0; k < locals.workers.length; k++) {
                address wallet = locals.workers[k].walletAddress;
                locals.workers[k].totalGrade += allReviewers[index].reviewPerWorker[wallet];
                locals.totalReviews += allReviewers[index].reviewPerWorker[wallet];
            }
            // There we add a reviewer in a final array as well as their reward
            members[i].walletAddress = allReviewers[i].walletAddress;
            members[i].reward = locals.singleReviewerReward;
            // In case of having residual/rest "restRewardReviewers" we add One (1) to a reviewer and withdraw One (1) from "restRewardReviewers"
            // "restRewardReviewers" will certainly become 0 before the end of the loop, as initially it will for sure be less then number of all reviewers
            if (locals.restRewardReviewers != 0) {
                members[i].reward++;
                locals.restRewardReviewers--;
            }
        }

        // Firstly I put this value the whole reward amount, then I will substract every from it every reward for a single Worker.
        // That way in the end of the loop I will get the residual/rest of the the total reward for all workers
        locals.restRewardWorkers = allTasks[id].prize;
        for (uint i = 0; i < locals.workers.length; i++) {
            uint residual = allTasks[id].prize * locals.workers[i].totalGrade % locals.totalReviews;
            uint reward = (allTasks[id].prize * locals.workers[i].totalGrade - residual) / locals.totalReviews;
            members[locals.reviewersIndexes.length + i].walletAddress = locals.workers[i].walletAddress;
            members[locals.reviewersIndexes.length + i].reward = reward;
            locals.restRewardWorkers -= reward;
        }

        // In the end of the previous loop we got restRewardWorkers value and
        // here we give cycle through all workers and give them one (1) token/coin that is withdrawn from "restRewardWorkers" variable
        for (uint i = 0; locals.restRewardWorkers > 0; i++) {
            // In case we went through all workers but restRewardWorkers variable is not empty yet,
            // then we go to the first worker and begin the cycle again.
            // That's why we make "i" equal "0" at some point
            if (i == locals.workers.length) {
                i = 0;
            }
            members[locals.reviewersIndexes.length + i].reward++;
            locals.restRewardWorkers--;
        }

        return members;
    }
}

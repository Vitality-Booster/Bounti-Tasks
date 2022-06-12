// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./TaskManager.sol";
import "./ITaskMemberManager.sol";
import "./ITaskManager.sol";

contract TaskMemberManager is OwnableUpgradeable, ITaskMemberManager {

    // !!! MAKE USE OF OPENZEPPELIN OwnableUgradable package !!! //

    // @dev A TaskManager proxy contract that we need to execute a number of functions
    address taskProxy;

    // @dev "string" is a taskId and "address" is a task member
    mapping(string => mapping(address => SharedTypes.TaskRole)) memberRoles;

    // @dev Shares the same logic as previous mapping, but there we keep track of ids from arrays
    // I didn't make separate arrays for Reviewers and Workers, as it will be easy to identify
    // if a member is a Reviewer or a Worker by checking with previous mapping
    mapping(string => mapping(address => uint)) memberIndexes;

    Reviewer[] private allReviewers;
    Worker[] private allWorkers;

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

    // @dev This struct is created to simplify work around for "completeTask" function
    struct ReviewedWorker {
        address walletAddress;
        uint totalGrade;
    }

    struct MemberToPay {
        address walletAddress;
        uint reward;
    }

    modifier onlyTaskProxy() {
        require(msg.sender == taskProxy, "You are not allowed to do that");
        _;
    }

    modifier onlyParticularRole(string calldata id, SharedTypes.TaskRole role) {
        require(memberRoles[id][msg.sender] == role, "You don't have rights to do that");
        _;
    }

    modifier onlyParticularStatus(string calldata id, SharedTypes.TaskStatus status) {
        require(ITaskManager(taskProxy).checkTaskStatus(id, status), "You can't do this action at current Task stage");
        _;
    }

    function setTaskProxy(address _taskProxy) onlyOwner public {
        taskProxy = _taskProxy;
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    // @dev Makes a message sender a worker for the task
    // May be will need to add a verification where we check if the message sender is from the task DAO or not
    function addWorker(string calldata id)
    onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) public {
        require(memberRoles[id][msg.sender] == SharedTypes.TaskRole.NOT_RELATED, "You have already been assigned to this task");
        memberRoles[id][msg.sender] = SharedTypes.TaskRole.WORKER;

        // @dev Adding a new Worker to the array
        uint index = allWorkers.length;
        memberIndexes[id][msg.sender] = index;
        allWorkers.push();
        allWorkers[index].walletAddress = msg.sender;

        // @dev Adding a new Worker index to the array "workersIndexes" inside Task struct
        ITaskManager(taskProxy).addMemberIndex(id, SharedTypes.TaskRole.WORKER, index);
    }

    // @dev Makes a message sender a reviewer for the task
    // May be will need to add a verification where we check if the message sender is from the task DAO or not
    function addReviewer(string calldata id)
    onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) public {
        require(memberRoles[id][msg.sender] == SharedTypes.TaskRole.NOT_RELATED, "You have already been assigned to this task");
        memberRoles[id][msg.sender] = SharedTypes.TaskRole.REVIEWER;

        // @dev Adding a new Reviewer to the array
        uint index = allReviewers.length;
        memberIndexes[id][msg.sender] = index;
        allReviewers.push();
        allReviewers[index].walletAddress = msg.sender;

        // @dev Adding a new Reviewer index to the array "reviewersIndexes" inside Task struct
        ITaskManager(taskProxy).addMemberIndex(id, SharedTypes.TaskRole.REVIEWER, index);
    }

    function removeMember(string calldata id)
    onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) public {
        SharedTypes.TaskRole role = memberRoles[id][msg.sender];
        require(role != SharedTypes.TaskRole.NOT_RELATED, "You have not been assigned to this task");
        uint index = memberIndexes[id][msg.sender];
        ITaskManager(taskProxy).removeMember(id, role, index);
        if (role == SharedTypes.TaskRole.WORKER) {
            delete allWorkers[index];
        }
        else if (role == SharedTypes.TaskRole.REVIEWER) {
            delete allReviewers[index];
        }
    }

    function removeAllMembers(string calldata id, uint[] calldata workersIndexes, uint[] calldata reviewersIndexes)
    onlyTaskProxy() override external {
        for (uint i = 0; i < workersIndexes.length; i++) {
            deleteMember(id, workersIndexes[i], SharedTypes.TaskRole.WORKER);
        }
        for (uint i = 0; i < reviewersIndexes.length; i++) {
            deleteMember(id, reviewersIndexes[i], SharedTypes.TaskRole.REVIEWER);
        }
    }

    function deleteMember(string calldata id, uint index, SharedTypes.TaskRole role) private {
        address walletAddress;
        // @dev Firstly remove a worker or a reviewer from a respectful array
        if (role == SharedTypes.TaskRole.WORKER) {
            walletAddress = allWorkers[index].walletAddress;
            delete allWorkers[index];
        }
        else if (role == SharedTypes.TaskRole.REVIEWER) {
            walletAddress = allReviewers[index].walletAddress;
            delete allReviewers[index];
        }

        // @dev Secondly, delete a member records from mappings
        delete memberIndexes[id][walletAddress];
        delete memberRoles[id][walletAddress];
    }

    function completeWorkerPart(string calldata id)
    onlyParticularRole(id, SharedTypes.TaskRole.WORKER) onlyParticularStatus(id, SharedTypes.TaskStatus.IN_PROCESS) public {
        // @dev Counts how many workers have completed their parts.
        // If everyone completed it, then makes task status equal "REVIEW"
        uint index = memberIndexes[id][msg.sender];
        allWorkers[index].workCompleted = true;
        if (isAllWorkCompleted(id)) {
            ITaskManager(taskProxy).changeStatus(id, SharedTypes.TaskStatus.REVIEW);
            resetReviewers(id);
        }
    }

    // @dev Checks if all workers completed their parts
    function isAllWorkCompleted(string calldata id) private view returns (bool) {
        uint[] memory indexes = ITaskManager(taskProxy).getMemberIndexes(id, SharedTypes.TaskRole.WORKER);

        for(uint i = 0; i < indexes.length; i++) {
            uint index = indexes[i];
            if (!allWorkers[index].workCompleted) {
                return false;
            }
        }
        return true;
    }

    function resetReviewers(string calldata id) private {
        uint[] memory indexes = ITaskManager(taskProxy).getMemberIndexes(id, SharedTypes.TaskRole.REVIEWER);

        for (uint i = 0; i < indexes.length; i++) {
            uint index = indexes[i];
            allReviewers[index].needImprovements = false;
            allReviewers[index].reviewCompleted = false;
        }
    }

    function reviewTask(string calldata id, address[] calldata reviewedWorkers, uint[] calldata grades)
    onlyParticularStatus(id, SharedTypes.TaskStatus.REVIEW) public {
        checkReviewedWorkers(id, reviewedWorkers);
        executeReview(id, reviewedWorkers, grades);

        if (isReviewCompleted(id)) {
            ITaskManager(taskProxy).changeStatus(id, SharedTypes.TaskStatus.COMPLETED);
            completeAllWork(id);
        }
    }

    // @dev Checks if there are no duplications of workers in the array
    // and if the reviewed workers are really workers for this task
    function checkReviewedWorkers(string calldata id, address[] calldata reviewedWorkers) private view {
        uint[] memory realWorkersIndexes = ITaskManager(taskProxy).getMemberIndexes(id, SharedTypes.TaskRole.WORKER);
        uint secondLimit;
        if (realWorkersIndexes.length > reviewedWorkers.length) {
            secondLimit = realWorkersIndexes.length;
        }
        else {
            secondLimit = reviewedWorkers.length;
        }
        for (uint i = 0; i < reviewedWorkers.length; i++) {
            bool existInTask = false; // If a Worker from reviewedWorkers exists in Task indexes that we got, turns to true
            uint index = memberIndexes[id][reviewedWorkers[i]];
            for (uint k = 0; k < secondLimit; k++) {
                // Check if the Worker exists in a Task indexes
                if (k < realWorkersIndexes.length && !existInTask) {
                    if (index == realWorkersIndexes[k]) {
                        existInTask = true;
                    }
                    if (k == (realWorkersIndexes.length - 1) && !existInTask) {
                        revert("You are trying to grade a person, who was not assigned as a Worker for this task");
                    }
                }
                require(reviewedWorkers.length > (i + k + 1)); // So that we didn't go beyond array limits

                // Check if a Reviewer is not trying to review some person several times
                require(reviewedWorkers[i] != reviewedWorkers[i + k + 1], "You can not have more than 1 reviews for a single worker");
            }
        }
    }

    // @dev Checks if all Reviewers completed reviewing
    // @dev Both "actual reviewing" and "asking for implementation" are considered as completing a review process
    function isReviewCompleted(string calldata id) private view returns (bool) {
        uint[] memory indexes = ITaskManager(taskProxy).getMemberIndexes(id, SharedTypes.TaskRole.REVIEWER);

        for(uint i = 0; i < indexes.length; i++) {
            uint index = indexes[i];
            if (!allReviewers[index].reviewCompleted) {
                return false;
            }
        }
        return true;
    }

    function executeReview(string calldata id, address[] calldata reviewedWorkers, uint[] calldata grades)
    onlyParticularRole(id, SharedTypes.TaskRole.REVIEWER) private {
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

    function getAllReviewers(uint[] calldata reviewersIndexes)
    onlyTaskProxy() override external view returns(address[] memory) {
        address[] memory reviewers = new address[] (reviewersIndexes.length);

        for(uint i = 0; i < reviewersIndexes.length; i++) {
            uint index = reviewersIndexes[i];
            reviewers[i] = allReviewers[index].walletAddress;
        }

        return reviewers;
    }

    function getAllWorkers(uint[] calldata workersIndexes)
    onlyTaskProxy() override external view returns(address[] memory) {
        address[] memory workers = new address[] (workersIndexes.length);

        for(uint i = 0; i < workersIndexes.length; i++) {
            uint index = workersIndexes[i];
            workers[i] = allWorkers[index].walletAddress;
        }

        return workers;
    }

    function askForImprovements(string calldata id, address[] calldata walletAddresses)
    onlyParticularRole(id, SharedTypes.TaskRole.REVIEWER) onlyParticularStatus(id, SharedTypes.TaskStatus.REVIEW) public {
        executeAskForImprovements(id, walletAddresses);

        if (shouldBeImproved(id)) {
            ITaskManager(taskProxy).changeStatus(id, SharedTypes.TaskStatus.IN_PROCESS);
        }
        else if (isReviewCompleted(id)) {
            // As "executeAskForImprovements" turns value "reviewCompleted" to "true", it means that askForImprovement also counts as completing a review.
            // And there we check if everyone finished reviewing task.
            // If they did and the task didn't go to the IN_PROCESS yet, then the majority thinks that it should not be improved and it can move to the COMPLETED state
            ITaskManager(taskProxy).changeStatus(id, SharedTypes.TaskStatus.COMPLETED);
            completeAllWork(id);
        }
    }

    function getReviewer(string calldata id, address walletAddress) private view returns(Reviewer storage) {
        uint index = memberIndexes[id][walletAddress];
        return allReviewers[index];
    }

    function getWorker(string calldata id, address walletAddress) private view returns(Worker storage) {
        uint index = memberIndexes[id][walletAddress];
        return allWorkers[index];
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
        uint[] memory indexes = ITaskManager(taskProxy).getMemberIndexes(id, SharedTypes.TaskRole.REVIEWER);

        uint residual = indexes.length % 2;

        // @dev Keeps track of a number of reviewers that asked for improvements
        uint requiredImprovements;

        for (uint i = 0; i < indexes.length; i++) {
            uint index = indexes[i];
            if (allReviewers[index].needImprovements) {
                requiredImprovements++;
            }
        }

        // I add residual to the length, because it can be only equal to "1" or "0" and
        // when you add it to the length then the sum will be able to be devided by 2 without a residual
        // Quick example: if length = 6, then residual = 6 % 2 = 0, then requiredImprovements should be equal to or more than ( (6 + 0) / 2);
        // if length = 7, then residual = 7 % 2 = 1, then requiredImprovements should be equal to or more than ( (7 + 1) / 2)
        if (requiredImprovements >= ((indexes.length + residual) / 2)) {
            return true;
        }
        return false;
    }

    // @dev This function must be executed only when the Task moves to the "COMPLETED" status
    // It is done, as when the Task moves to completed, some workers may have their "workCompleted" property set to "false" due to
    // reviewers that may have asked for improvements from them
    function completeAllWork(string calldata id) private {
        uint[] memory indexes = ITaskManager(taskProxy).getMemberIndexes(id, SharedTypes.TaskRole.WORKER);

        for (uint i = 0; i < indexes.length; i++) {
            uint index = indexes[i];
            allWorkers[index].workCompleted = true;
        }
    }

    function completeTask(string calldata id)
    onlyParticularStatus(id, SharedTypes.TaskStatus.COMPLETED) public view returns(MemberToPay[] memory) {
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
        SharedTypes.TaskDataForCalculation memory data = ITaskManager(taskProxy).getTaskDataForCalculation(id);
        locals.reviewersIndexes = data.reviewersIndexes;
        locals.workers = new ReviewedWorker[] (data.workersIndexes.length);
        MemberToPay[] memory membersToPay = new MemberToPay[] (locals.reviewersIndexes.length + locals.workers.length);
        locals.workerWallets = this.getAllWorkers(data.workersIndexes);
        locals.reviewersResidual = (data.prize * data.percentageForReviewers) % uint(100);

        // If the residual/rest, aka reviewersResidual, is not equal to "0", I add one more coin/token to totalReviewersReward, no need to thank me :)
        if (locals.reviewersResidual == 0) {
            locals.totalReviewersReward = data.prize * data.percentageForReviewers / uint(100);
        }
        else {
            locals.totalReviewersReward = (data.prize * data.percentageForReviewers - locals.reviewersResidual) / uint(100) + uint(1);
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
            membersToPay[i].walletAddress = allReviewers[i].walletAddress;
            membersToPay[i].reward = locals.singleReviewerReward;
            // In case of having residual/rest "restRewardReviewers" we add One (1) to a reviewer and withdraw One (1) from "restRewardReviewers"
            // "restRewardReviewers" will certainly become 0 before the end of the loop, as initially it will for sure be less then number of all reviewers
            if (locals.restRewardReviewers != 0) {
                membersToPay[i].reward++;
                locals.restRewardReviewers--;
            }
        }

        // Firstly I put this value the whole reward amount, then I will substract every from it every reward for a single Worker.
        // That way in the end of the loop I will get the residual/rest of the the total reward for all workers
        locals.restRewardWorkers = data.prize;
        for (uint i = 0; i < locals.workers.length; i++) {
            uint residual = data.prize * locals.workers[i].totalGrade % locals.totalReviews;
            uint reward = (data.prize * locals.workers[i].totalGrade - residual) / locals.totalReviews;
            membersToPay[locals.reviewersIndexes.length + i].walletAddress = locals.workers[i].walletAddress;
            membersToPay[locals.reviewersIndexes.length + i].reward = reward;
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
            membersToPay[locals.reviewersIndexes.length + i].reward++;
            locals.restRewardWorkers--;
        }

        return membersToPay;
    }
}

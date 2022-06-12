// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./TaskMemberManager.sol";
import "./ITaskManager.sol";
import "./ITaskMemberManager.sol";

contract TaskManager is OwnableUpgradeable, ITaskManager {

    // !!! MAKE USE OF OPENZEPPELIN OwnableUgradable package !!! //

    // @dev A TaskMemberManager proxy contract that we need to execute a number of functions
    address taskMemberProxy;

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
        SharedTypes.TaskStatus status;
    }

    // @dev This struct will be used to send needed data about a Task to the front-end
    struct TaskToGet {
        address daoContract;
        address taskOwner;
        uint prize;
        uint percentageForReviewers;
        SharedTypes.TaskStatus status;
    }

    // @dev Storing all tasks in a map, where a key is a task id
    mapping(string => Task) private allTasks;

    // @dev This array stores ids of all the tasks, so that I could make use of array functions,
    // but didn't have to store all the Tasks doubled (in a mapping and in an array)
    string[] private tasksIds;

    modifier onlyTaskMemberProxy() {
        require(msg.sender == taskMemberProxy, "You are not allowed to do that");
        _;
    }

    // @dev Checks if the message sender is a task owner
    modifier isTaskOwner(string calldata id) {
        require(allTasks[id].taskOwner == msg.sender, "Only owner of the task can do that");
        _;
    }

    modifier onlyParticularStatus(string calldata id, SharedTypes.TaskStatus status) {
        require(allTasks[id].status == status, "You can't do this action at current Task stage");
        _;
    }

    modifier enoughMembers(string calldata id) {
        uint workersCount = allTasks[id].workersIndexes.length;
        uint reviewersCount = allTasks[id].reviewersIndexes.length;
        require(workersCount >= 1 && reviewersCount >= 1, "In order to begin a task, it should have at least 1 reviewer and 1 worker");
        _;
    }

    function setTaskMemberProxy(address _taskMemberProxy) onlyOwner public {
        taskMemberProxy = _taskMemberProxy;
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    // @dev Creates a task, with provided daoContract and TaskId and message sender becomes a task owner
    function createTask(address daoContract, string calldata id, uint prize, uint percentageForReviewers)
    onlyParticularStatus(id, SharedTypes.TaskStatus.DOES_NOT_EXIST) public {
        allTasks[id].daoContract = daoContract;
        allTasks[id].taskOwner = msg.sender;
        allTasks[id].id = id;
        allTasks[id].prize = prize;
        allTasks[id].percentageForReviewers = percentageForReviewers;
        allTasks[id].status = SharedTypes.TaskStatus.PENDING;
        tasksIds.push(id);
    }

    function removeTask(string calldata id)
    isTaskOwner(id) onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) public {
        uint[] memory reviewersIndexes = allTasks[id].reviewersIndexes;
        uint[] memory workersIndexes = allTasks[id].workersIndexes;
        ITaskMemberManager(taskMemberProxy).removeAllMembers(id, workersIndexes, reviewersIndexes);

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

    function getTask(string calldata id)
    public view returns (TaskToGet memory, address[] memory, address[] memory) {
        require(allTasks[id].status != SharedTypes.TaskStatus.DOES_NOT_EXIST, "A task with this id does not exist");
        TaskToGet memory taskData;
        taskData.daoContract = allTasks[id].daoContract;
        taskData.taskOwner = allTasks[id].taskOwner;
        taskData.percentageForReviewers = allTasks[id].percentageForReviewers;
        taskData.prize = allTasks[id].prize;
        taskData.status = allTasks[id].status;

        address[] memory workers = ITaskMemberManager(taskMemberProxy).getAllWorkers(allTasks[id].workersIndexes);
        address[] memory reviewers = ITaskMemberManager(taskMemberProxy).getAllReviewers(allTasks[id].reviewersIndexes);

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
    isTaskOwner(id) onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) enoughMembers(id) public {
        allTasks[id].status = SharedTypes.TaskStatus.IN_PROCESS;
    }

    // @dev Function that compares incoming strings as Solidity can't do it by default
    function compareStrings(string memory a, string memory b) private pure returns(bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function checkTaskStatus(string calldata id, SharedTypes.TaskStatus status)
    onlyTaskMemberProxy() onlyParticularStatus(id, status) override view external returns(bool) {
        return true;
    }

    function addMemberIndex(string calldata id, SharedTypes.TaskRole role, uint index)
    onlyTaskMemberProxy() onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) override external {
        if (role == SharedTypes.TaskRole.WORKER) {
            allTasks[id].workersIndexes.push(index);
        }
        else if (role == SharedTypes.TaskRole.REVIEWER) {
            allTasks[id].reviewersIndexes.push(index);
        }
    }

    // @dev Returns an array of indexes for either Workers or Reviewers of a particular Task
    function getMemberIndexes(string calldata id, SharedTypes.TaskRole role)
    onlyTaskMemberProxy() override view external returns (uint[] memory) {
        uint[] memory indexes;
        if (role == SharedTypes.TaskRole.WORKER) {
//            indexes = new uint[] (allTasks[id].workersIndexes.length);
            indexes = allTasks[id].workersIndexes;
        }
        else if (role == SharedTypes.TaskRole.REVIEWER) {
//            indexes = new uint[] (allTasks[id].workersIndexes.length);
            indexes = allTasks[id].reviewersIndexes;
        }
        return indexes;
    }

    function removeMember(string calldata id, SharedTypes.TaskRole role, uint index)
    onlyTaskMemberProxy() onlyParticularStatus(id, SharedTypes.TaskStatus.PENDING) override external {
        uint[] storage indexes = allTasks[id].workersIndexes;
        if (role == SharedTypes.TaskRole.REVIEWER) {
            indexes = allTasks[id].reviewersIndexes;
        }
        for (uint i = 0; i < indexes.length; i++) {
            if (indexes[i] == index) {
                indexes[i] = indexes[indexes.length - 1];
                indexes.pop();
            }
        }
    }

    function changeStatus(string calldata id, SharedTypes.TaskStatus status)
    onlyTaskMemberProxy() override external {
        allTasks[id].status = status;
    }

    function getTaskDataForCalculation(string calldata id)
    onlyTaskMemberProxy() override external view returns(SharedTypes.TaskDataForCalculation memory) {
        SharedTypes.TaskDataForCalculation memory data;
        data.reviewersIndexes = allTasks[id].reviewersIndexes;
        data.workersIndexes = allTasks[id].workersIndexes;
        data.prize = allTasks[id].prize;
        data.percentageForReviewers = allTasks[id].percentageForReviewers;
        return data;
    }
}

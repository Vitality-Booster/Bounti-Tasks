//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "./SharedTypes.sol";

interface ITaskManager is SharedTypes {

    function checkTaskStatus(string calldata id, SharedTypes.TaskStatus status) external view returns(bool);

    function addMemberIndex(string calldata id, SharedTypes.TaskRole role, uint index) external;

    function getMemberIndexes(string calldata id, SharedTypes.TaskRole role) view external returns (uint[] memory);

    function removeMember(string calldata id, SharedTypes.TaskRole role, uint index) external;

    function changeStatus(string calldata id, SharedTypes.TaskStatus status) external;

    function getTaskDataForCalculation(string calldata id) external view returns(SharedTypes.TaskDataForCalculation memory);
}

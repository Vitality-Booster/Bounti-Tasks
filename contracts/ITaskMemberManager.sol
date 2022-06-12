//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "./SharedTypes.sol";

interface ITaskMemberManager is SharedTypes {

    function removeAllMembers(string calldata id, uint[] calldata workersIndexes, uint[] calldata reviewersIndexes) external;

    function getAllReviewers(uint[] calldata reviewersIndexes) external view returns(address[] memory);

    function getAllWorkers(uint[] calldata workersIndexes) external view returns(address[] memory);
}

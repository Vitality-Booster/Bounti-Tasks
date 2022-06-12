//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private greeting;
    uint[] array;

    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public returns(string memory) {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
        return greeting;
    }

    function addToArray(uint el) public {
        array.push(el);
    }

    function removeFromArray(uint el) public {
        uint[] storage array2 = array;
        for (uint i = 0; i < array2.length; i++) {
            if (el == array2[i]) {
                array2[i] = array2[array2.length - 1];
                array2.pop();
            }
        }
    }

    function getArray() view public returns(uint[] memory) {
        uint[] memory array2 = new uint[] (array.length);
        for (uint i = 0; i < array2.length; i++) {
            array2[i] = array[i];
        }
        return array2;
    }
}

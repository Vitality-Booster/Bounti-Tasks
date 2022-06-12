const { ethers } = require("hardhat");
const { expect } = require("chai");
const {BigNumber} = require("ethers");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Greeter", function () {
    it("Should return the new greeting once it's changed", async function () {
        const Greeter = await ethers.getContractFactory("Greeter");
        const greeter = await Greeter.deploy("Hello, world!");
        await greeter.deployed();

        expect(await greeter.greet()).to.equal("Hello, world!");

        const setGreetingTx = await greeter.setGreeting("Hola, mundo!");



        // wait until the transaction is mined
        const smttttt = await setGreetingTx.wait();

        console.log("This is something else: ", smttttt);

        expect(await greeter.greet()).to.equal("Hola, mundo!");
    });
});

describe("Checking arrays", async() => {
    it("Should return all values", async() => {
        const Greeter = await ethers.getContractFactory("Greeter");
        const greeter = await Greeter.deploy("Hello, world!");
        await greeter.deployed();

        greeter.addToArray(1);
        greeter.addToArray(6);
        greeter.addToArray(2);
        greeter.addToArray(123);

        const array = await greeter.getArray();
        console.log(array[0].toNumber());
        const array2 = new Array();
        await array.forEach(el => array2.push(el.toNumber()))
        expect([1, 6, 2, 123]).to.eql(array2);
    })
    it("Should delete the value properly", async () => {
        const Greeter = await ethers.getContractFactory("Greeter");
        const greeter = await Greeter.deploy("Hello, world!");
        await greeter.deployed();

        greeter.addToArray(1);
        greeter.addToArray(6);
        greeter.addToArray(2);
        greeter.addToArray(123);

        await greeter.removeFromArray(1);
        const array = await greeter.getArray();
        const array2 = new Array();
        await array.forEach(el => array2.push(el.toNumber()))
        console.log("Array values: ", array2);
        expect([123, 6, 2]).to.eql(array2);
    })
})
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

const setup = async () => {
    const factory = await ethers.getContractFactory("TaskManager");
    const manager = await upgrades.deployProxy(factory);

    const accounts = ethers.getSigners();
    // const accounts = await ethers.getSigners();
    // const reviewers = [];
    // const workers = [];
    // const owner = accounts[0];
    // reviewers[0] = accounts[1];
    // reviewers[1] = accounts[2];
    // reviewers[2] = accounts[3];
    // reviewers[3] = accounts[4];
    // workers[0] = accounts[5];
    // workers[1] = accounts[6];
    // workers[2] = accounts[7];
    // workers[3] = accounts[8];

    return { manager, accounts };
}

const createNewTask = async (manager, taskId, daoContract) => {
    const prize = 200;
    const percentageForReviewers = 25;

    await manager.createTask(daoContract, taskId, prize, percentageForReviewers);
}

describe("TaskManager deployment using deployProxy from OpenZeppelin", async () => {
    it("Should deploy using Proxy", async () => {
        const factory = await ethers.getContractFactory("TaskManager");
        const manager = await upgrades.deployProxy(factory);

        expect(await manager.getTaskMemberProxy()).to.equal("0x0000000000000000000000000000000000000000");
    });
})

describe('Testing TaskManager functions that do not depend on TaskMemberManager', async () => {
    it("Change 'taskMemberProxy' to the new address", async () => {
        const { manager } = await setup();
        const newAddress = "0xaAa491DfD894482832bC44768B31D6DE78C70095";
        await manager.setTaskMemberProxy(newAddress);

        expect(await manager.getTaskMemberProxy()).to.equal(newAddress);
    });
    it("Throw exception when not owner of the contract is trying to change 'taskMemberProxy'", async () => {
        const { manager, accounts } = await setup();
        const newAddress2 = "0xb10da49Aa37C6bF98ed7651491Bf3fEf14C01AcB";
        const account = accounts[3];
        await expect(manager.connect(account).setTaskMemberProxy(newAddress2)).to.be.reverted;
    });

    // The test for creating a single Task is done in TaskIntegrationTest.js
    it('Should get all the Task IDs for Tasks that belong to 1 DAO', async () => {
        const { manager } = await setup();
        const taskId1 = "abcd";
        const taskId2 = "1234";
        const taskId3 = "a1b2c3d4";
        const taskId4 = "1d2c3b4a";
        const daoContract1 = "0xc1bCAA3583b56959E96b01a4aCbD08394aC0A93d";
        const daoContract2 = "0xb10da49Aa37C6bF98ed7651491Bf3fEf14C01AcB";

        await createNewTask(manager, taskId1, daoContract2);
        await createNewTask(manager, taskId2, daoContract2);
        await createNewTask(manager, taskId3, daoContract1);
        await createNewTask(manager, taskId4, daoContract2);

        const tasks1 = await manager.getAllDaoTasks(daoContract1);
        // console.log("Tasks for DAO 1: ", tasks1);
        expect(taskId3).to.equal(tasks1[0]);
        const tasks2 = await manager.getAllDaoTasks(daoContract2);
        // console.log("Tasks for DAO 2: ", tasks2);
        expect(taskId4).to.equal(tasks2[2]);
    });
});
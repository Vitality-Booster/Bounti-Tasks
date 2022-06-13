const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const {wait} = require("@testing-library/user-event/dist/utils");

const setup = async () => {
    const factory1 = await ethers.getContractFactory("TaskManager");
    const factory2 = await ethers.getContractFactory("TaskMemberManager");
    // Deploying contracts using proxies
    const taskManager = await upgrades.deployProxy(factory1);
    const memberManager = await upgrades.deployProxy(factory2);

    // Setting TaskMemberManager proxy address to TaskManager
    await taskManager.setTaskMemberProxy(memberManager.address);
    // Setting TaskManager proxy address to TaskMemberManager
    await memberManager.setTaskProxy(taskManager.address);

    const accounts = await ethers.getSigners();
    const reviewers = [];
    const workers = [];
    const owner = accounts[0];
    reviewers[0] = accounts[1];
    reviewers[1] = accounts[2];
    reviewers[2] = accounts[3];
    reviewers[3] = accounts[4];
    workers[0] = accounts[5];
    workers[1] = accounts[6];
    workers[2] = accounts[7];
    workers[3] = accounts[8];

    return { taskManager, memberManager, owner, reviewers, workers};
}

const createNewTask = async (taskManager, taskId) => {
    const daoContract = "0xc1bCAA3583b56959E96b01a4aCbD08394aC0A93d";
    const prize = 200;
    const percentageForReviewers = 25;

    await taskManager.createTask(daoContract, taskId, prize, percentageForReviewers);
}

const getTaskData = async (taskManager, taskId) => {
    const res = await taskManager.getTask(taskId);
    return res[0];
}

const getTaskReviewers = async (taskManager, taskId) => {
    const res = await taskManager.getTask(taskId);
    return res[2];
}

const beginTask = async (taskManager, memberManager, taskId, reviewers, workers) => {
    // Adding Reviewers and Workers to a Task
    await memberManager.connect(workers[0]).addWorker(taskId);
    await memberManager.connect(workers[1]).addWorker(taskId);
    await memberManager.connect(workers[2]).addWorker(taskId);
    await memberManager.connect(workers[3]).addWorker(taskId);
    await memberManager.connect(reviewers[0]).addReviewer(taskId);
    await memberManager.connect(reviewers[1]).addReviewer(taskId);
    await memberManager.connect(reviewers[2]).addReviewer(taskId);
    await memberManager.connect(reviewers[3]).addReviewer(taskId);

    taskManager.beginTask(taskId);
}

describe("Setting taskProxy and taskMemberProxy in TaskMemberManager and TaskManager contracts", async () => {
    it("Should correctly assign proxies addresses to contracts", async () => {
        const factory1 = await ethers.getContractFactory("TaskManager");
        const factory2 = await ethers.getContractFactory("TaskMemberManager");
        const taskManager = await upgrades.deployProxy(factory1);
        const memberManager = await upgrades.deployProxy(factory2);

        await taskManager.setTaskMemberProxy(memberManager.address);
        await memberManager.setTaskProxy(taskManager.address);

        expect(await taskManager.getTaskMemberProxy()).to.equal(memberManager.address);
        expect(await memberManager.getTaskProxy()).to.equal(taskManager.address);
    });
})

describe("The whole workflow of a single Task", async () => {
    it("Should create a Task with a specified 'taskId' and other data and get it using 'taskId'", async () => {
        const { taskManager } = await setup();

        const daoContract = "0xc1bCAA3583b56959E96b01a4aCbD08394aC0A93d";
        const taskId = "abcd";
        const prize = 200;
        const percentageForReviewers = 25;
        await taskManager.createTask(daoContract, taskId, prize, percentageForReviewers);

        // Should throw exception, as the task with this ID does not exist
        await expect(taskManager.getTask("weirdId")).to.be.reverted;
        // Check if it throws the right message
        await expect(taskManager.getTask("weirdId")).to.be.revertedWith("A task with this ID does not exist");

        // Should throw exception, as the task with this ID already exists
        const diffDaoContract = "0xd1C5A24ae31965b2F147c14e4411AcE1a50A10E0";
        const diffPrize = 300;
        const diffPercentage = 50;
        // All the data is different but taskId
        await expect(taskManager.createTask(diffDaoContract, taskId, diffPrize, diffPercentage)).to.be.reverted;
        // Check if it throws the right message
        await expect(taskManager.createTask(diffDaoContract, taskId, diffPrize, diffPercentage))
            .to.be.revertedWith("The task with this ID already exist");


        const res = await taskManager.getTask(taskId);
        const task = res[0];

        expect(prize).to.equal(task.prize.toNumber());
        expect(daoContract).to.equal(task.daoContract);
    });

    it('Should add Workers and Reviewers to a Task and remove them from the Task, which is only in PENDING stage', async () => {
        const { taskManager, memberManager, reviewers, workers } = await setup();
        const taskId = "abcd";
        await createNewTask(taskManager, taskId);

        // ---------- Checking deleting members (Reviewers and Workers) -----------

        // Should throw an exception, because this person has not been assigned to this task yet
        await expect(memberManager.connect(reviewers[0]).removeMember(taskId))
            .to.be.revertedWith("You have not been assigned to this task");

        await memberManager.connect(reviewers[0]).addReviewer(taskId);

        const gotReviewers = await getTaskReviewers(taskManager, taskId);

        // Checks that there is already 1 assigned Reviewer for this Task
        expect(1).to.equal(gotReviewers.length);

        await memberManager.connect(reviewers[0]).removeMember(taskId);

        const updatedReviewers = await getTaskReviewers(taskManager, taskId);

        // Checks that the existing Reviewer was deleted from the Task
        expect(0).to.equal(updatedReviewers.length);

        // ---------- Checking adding Workers and Reviewers -----------
        await memberManager.connect(reviewers[0]).addReviewer(taskId);

        // Should throw an exception, as this person was already assigned as a Reviewer to this Task
        await expect(memberManager.connect(reviewers[0]).addReviewer(taskId))
            .to.be.revertedWith("You have already been assigned to this task");
        // Should throw an exception, as this user has already been assigned as a Reviewer to this Task, and they can not assign as a Worker either
        await expect(memberManager.connect(reviewers[0]).addWorker(taskId)).to.be.reverted;

        // Should throw an exception, as the Task doesn't have 1 Reviewer and 1 Worker yet
        await expect(taskManager.beginTask(taskId))
            .to.be.revertedWith("In order to begin a task, it should have at least 1 reviewer and 1 worker");

        await memberManager.connect(workers[0]).addWorker(taskId);

        // Should throw an exception, as this person was already assigned as a Worker to this Task
        await expect(memberManager.connect(workers[0]).addReviewer(taskId))
            .to.be.revertedWith("You have already been assigned to this task");
        // Should throw an exception, as this user has already been assigned as a Worker to this Task, and they can not assign as a Reviewer either
        await expect(memberManager.connect(workers[0]).addWorker(taskId)).to.be.reverted;

        await taskManager.beginTask(taskId);

        // Should throw an exception, as users can't apply for any position after a Task has begun
        await expect(memberManager.connect(reviewers[2]).addReviewer(taskId))
            .to.be.revertedWith("You can't do this action at current Task stage");
        // Should throw an exception, as users can't apply for any position after a Task has begun
        await expect(memberManager.connect(workers[2]).addWorker(taskId)).to.be.reverted;
    });

    it('Should let a taskOwner begin a Task if at least 1 Reviewer and 1 Worker were already assigned', async () => {
        const { taskManager, memberManager, reviewers, workers } = await setup();
        const taskId = "abcd";
        await createNewTask(taskManager, taskId);

        // Should throw an exception, as the Task doesn't have 1 Reviewer and 1 Worker yet
        await expect(taskManager.beginTask(taskId)).to.be.reverted;
        // Check if it throws the right message
        await expect(taskManager.beginTask(taskId))
            .to.be.revertedWith("In order to begin a task, it should have at least 1 reviewer and 1 worker");

        await memberManager.connect(workers[0]).addWorker(taskId);

        // Should still throw an exception, as the Task still doesn't have 1 Reviewer, although it already has 1 Worker
        await expect(taskManager.beginTask(taskId)).to.be.reverted;
        // Check if it throws the right message
        await expect(taskManager.beginTask(taskId)).to.be.reverted;

        // Should throw an exception, as this user has already been assigned as a Worker to this Task
        await expect(memberManager.connect(workers[0]).addReviewer(taskId)).to.be.reverted;
        // Check if it throws the right message
        await expect(memberManager.connect(workers[0]).addReviewer(taskId))
            .to.be.revertedWith("You have already been assigned to this task");

        await memberManager.connect(reviewers[0]).addReviewer(taskId);

        // Should throw an exception, as only a taskOwner can begin a Task
        await expect(taskManager.connect(workers[2]).beginTask(taskId)).to.be.reverted;
        // Check if it throws the right message
        await expect(taskManager.connect(workers[2]).beginTask(taskId))
            .to.be.revertedWith("Only owner of the task can do that");

        await taskManager.beginTask(taskId);
        const task = await getTaskData(taskManager, taskId);

        // Status is an 'enum' in the contract, that's why it returns a number instead of a string
        // In the contract '2' is equal to "IN_PROCESS", which is what we want to get after executing 'beginTask()'
        expect(2).to.equal(task.status);

    });

    it('Should allow a taskOwner to delete a Task if it was not started yet', async () => {
        const { taskManager, memberManager, reviewers, workers } = await setup();
        const taskId = "abcd";
        await createNewTask(taskManager, taskId);

        // Only taskOwner can delete a Task
        await expect(taskManager.connect(reviewers[0]).removeTask(taskId)).to.be.reverted;

        // await memberManager.connect(reviewers[0]).addReviewer(taskId);
        // await memberManager.connect(reviewers[1]).addReviewer(taskId);
        // await memberManager.connect(reviewers[2]).addReviewer(taskId);
        // await memberManager.connect(reviewers[3]).addReviewer(taskId);
        //
        // const gotReviewers = await getTaskReviewers(taskManager, taskId);
        // expect(4).to.equal(gotReviewers.length);


        await taskManager.removeTask(taskId);
        await expect(getTaskData(taskManager, taskId)).to.be.reverted;
        await expect(getTaskData(taskManager, taskId))
            .to.be.revertedWith("A task with this ID does not exist");
        // const updatedReviewers = await getTaskReviewers(taskManager, taskId);
        // expect(0).to.equal(updatedReviewers.length);

        // Here we create a new Task to show that if we 'begin' Task, a taskOwner will not be able to delete it
        const taskId2 = "abcd1234";
        await createNewTask(taskManager, taskId2);
        await beginTask(taskManager, memberManager, taskId2, reviewers, workers);

        await expect(taskManager.removeTask(taskId2)).to.be.reverted;
        await expect(taskManager.removeTask(taskId2))
            .to.be.revertedWith("You can't do this action at current Task stage");
    });

    it('should ', function () {

    });
})
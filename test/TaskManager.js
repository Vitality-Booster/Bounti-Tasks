// const {web3, contract} = require("hardhat");
// const TaskManager = artifacts.require("TaskManager");
//
// // contract("TaskManager test", async (accounts) => {
// //     const manager = await TaskManager.new();
// //
// //     const daoContract = "0xd0eac8C5096E6dB3634C8DF34d2F131f35Fee371";
// //     const taskId = "abcd";
// //
// //     const owner = accounts[0];
// //     const reviewer1 = accounts[1];
// //     const reviewer2 = accounts[2];
// //     const reviewer3 = accounts[3];
// //     const reviewer4 = accounts[4];
// //     const worker1 = accounts[5];
// //     const worker2 = accounts[6];
// //     const worker3 = accounts[7];
// //     const worker4 = accounts[8];
// //
// //     it('should create a new Task', async () => {
// //
// //         const prize = 469;
// //         const percentageForReviewers = 17;
// //         await manager.createTask(daoContract, taskId, prize, percentageForReviewers);
// //
// //         const task = await manager.getTask(taskId);
// //         console.log(task);
// //         assert.equal(task, "1");
// //     });
// // });
//
// describe("TaskManager test", async () => {
//
//     let daoContract;
//     let taskId;
//     let manager;
//
//     let owner;
//     let reviewer1;
//     let reviewer2;
//     let reviewer3;
//     let reviewer4;
//     let worker1;
//     let worker2;
//     let worker3;
//     let worker4;
//
//     before(async function () {
//         const accounts = await web3.eth.getAccounts();
//
//         daoContract = "0xd0eac8C5096E6dB3634C8DF34d2F131f35Fee371";
//         taskId = "abcd";
//         manager = await TaskManager.new();
//
//         owner = accounts[0];
//         reviewer1 = accounts[1];
//         reviewer2 = accounts[2];
//         reviewer3 = accounts[3];
//         reviewer4 = accounts[4];
//         worker1 = accounts[5];
//         worker2 = accounts[6];
//         worker3 = accounts[7];
//         worker4 = accounts[8];
//     });
//     //
//
//     //
//
//
//     describe("Creation", function () {
//         it("Should create a new Task", async function () {
//             const greeter = await TaskManager.new("Hello, world!");
//             assert.equal(await greeter.greet(), "Hello, world!");
//
//             const greeter2 = await TaskManager.new("Hola, mundo!");
//             assert.equal(await greeter2.greet(), "Hola, mundo!");
//         });
//     });
// });
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

const setup = async () => {
    const factory = await ethers.getContractFactory("TaskMemberManager");
    const manager = await upgrades.deployProxy(factory);
    const accounts = await ethers.getSigners();
    return { manager, accounts };
}

describe("TaskMemberManager deployment using deployProxy from OpenZeppelin", async () => {
    it("Should deploy using Proxy", async () => {
        const factory = await ethers.getContractFactory("TaskMemberManager");
        const manager = await upgrades.deployProxy(factory);

        expect(await manager.getTaskProxy()).to.equal("0x0000000000000000000000000000000000000000");
    });
})

describe('Testing TaskMemberManager functions that do not depend on TaskManager', async () => {
    it("Change 'taskProxy' to the new address", async () => {
        const { manager } = await setup();
        const newAddress = "0xaAa491DfD894482832bC44768B31D6DE78C70095";
        await manager.setTaskProxy(newAddress);

        expect(await manager.getTaskProxy()).to.equal(newAddress);
    });
    it("Throw exception when not owner of the contract is trying to change 'taskProxy'", async () => {
        const { manager, accounts } = await setup();
        const newAddress2 = "0xb10da49Aa37C6bF98ed7651491Bf3fEf14C01AcB";
        const account = accounts[3];
        await expect(manager.connect(account).setTaskProxy(newAddress2)).to.be.reverted;
    })
});
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MultiChainToken", function () {

    beforeEach(async function () {
        this.accounts = await ethers.getSigners();
        this.owner = this.accounts[0];

        // use this chainId
        this.chainId = 123;

        // create a LayerZero Endpoint mock for testing
        const LayerZeroEndpointMock = await ethers.getContractFactory("LayerZeroEndpointMock");
        this.layerZeroEndpointMock = await LayerZeroEndpointMock.deploy();

        // create two MultiChainCounter instances
        const MultiChainToken = await ethers.getContractFactory("MultiChainToken");
        this.multiChainTokenA = await MultiChainToken.deploy("NAME1", "SYM1", this.layerZeroEndpointMock.address);
        this.multiChainTokenB = await MultiChainToken.deploy("NAME2", "SYM2", this.layerZeroEndpointMock.address);
        this.multiChainTokenC = await MultiChainToken.deploy("NAME3", "SYM3", this.layerZeroEndpointMock.address);

        await this.multiChainTokenA.setExternalMultiChainAddresses(this.multiChainTokenA.address, this.multiChainTokenB.address);
        await this.multiChainTokenB.setExternalMultiChainAddresses(this.multiChainTokenA.address, this.multiChainTokenB.address);
    });

    it("burn local tokens on chain a and mint on chain b", async function () {
        // ensure they're both starting from 100000000000000000000
        let a = await this.multiChainTokenA.balanceOf(this.owner.address);
        let b = await this.multiChainTokenB.balanceOf(this.owner.address);
        let c = await this.multiChainTokenC.balanceOf(this.owner.address);
        expect(a).to.be.equal("100000000000000000000");
        expect(b).to.be.equal("100000000000000000000");
        expect(c).to.be.equal("100000000000000000000");

        //approve and send tokens
        await this.multiChainTokenA.approve(this.multiChainTokenA.address, "69420");
        await this.multiChainTokenA.sendTokens(this.chainId, this.multiChainTokenB.address, "69420")

        //verify tokens burned on chain a and minted on chain b
        a = await this.multiChainTokenA.balanceOf(this.owner.address);
        b = await this.multiChainTokenB.balanceOf(this.owner.address);
        expect(a).to.be.equal("99999999999999930580");
        expect(b).to.be.equal("100000000000000069420");

        //approve and send tokens
        await this.multiChainTokenB.approve(this.multiChainTokenB.address, "69420");
        await this.multiChainTokenB.sendTokens(this.chainId, this.multiChainTokenA.address, "69420")
        a = await this.multiChainTokenA.balanceOf(this.owner.address);
        b = await this.multiChainTokenB.balanceOf(this.owner.address);

        // verify the other way around
        expect(a).to.be.equal("100000000000000000000");
        expect(b).to.be.equal("100000000000000000000");

        // check if token c cannot send.
        await this.multiChainTokenC.approve(this.multiChainTokenC.address, "69420");
        await expect(this.multiChainTokenC.sendTokens(this.chainId, this.multiChainTokenA.address, "69420"))
        .to.be.revertedWith("Only token contract can send");

        // c shound still have original value
        expect(c).to.be.equal("100000000000000000000");
    });
});

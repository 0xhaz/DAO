const { expect } = require("chai");
const { ethers } = require("hardhat");

const tokens = n => {
  return ethers.utils.parseUnits(n.toString(), "ether");
};

const ether = tokens;

const keepPercentage = 10;
const quorumPercentage = 50;

describe("DAO", () => {
  let transaction, result;
  let DAO;
  let token, dao, staking, governance, timelock;
  let owner,
    investor1,
    investor2,
    investor3,
    investor4,
    investor5,
    investors,
    recipient,
    user;

  const delay = 2 * 24 * 60 * 60;

  beforeEach(async () => {
    let accounts = await ethers.getSigners();
    deployer = accounts[0];
    funder = accounts[1];
    investor1 = accounts[2];
    investor2 = accounts[3];
    investor3 = accounts[4];
    investor4 = accounts[5];
    investor5 = accounts[6];
    recipient = accounts[7];
    user = accounts[8];

    // Deploy Token
    const Token = await ethers.getContractFactory("GovToken");
    token = await Token.deploy();
    await token.deployed();

    // Deploy Staking Contract
    const Staking = await ethers.getContractFactory("StakingContract");
    staking = await Staking.deploy(token);
    await staking.deployed();

    // // Deploy Governance
    const Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(token.address, quorumPercentage);
    await governance.deployed();

    DAO = await ethers.getContractFactory("DAO");
    dao = await DAO.deploy(token.address, staking.address, governance.address);
    await dao.deployed();

    transaction = await token.approve(token.address, tokens(1000));
    await transaction.wait();

    // Make a claim
    transaction = await token.connect(investor1).claimTokens();
    await transaction.wait();

    transaction = await token.connect(investor2).claimTokens();
    await transaction.wait();

    transaction = await token.connect(investor3).claimTokens();
    await transaction.wait();

    transaction = await token.connect(investor4).claimTokens();
    await transaction.wait();

    // Stake tokens
  });

  describe("Deployment", () => {
    describe("Success", () => {
      it("Should deploy with tokens for each investors", async () => {
        // expect(token.balanceOf(investor1.address)).to.equal(tokens(1000));
        // expect(token.balanceOf(investor2.address)).to.equal(tokens(1000));
        // expect(token.balanceOf(investor3.address)).to.equal(tokens(1000));
        // expect(token.balanceOf(investor4.address)).to.equal(tokens(1000));
      });
    });
  });

  describe("Create Proposal", () => {
    describe("Success", () => {});

    describe("Failure", () => {});
  });

  describe("Deployment", () => {
    describe("Success", () => {});

    describe("Failure", () => {});
  });

  describe("Deployment", () => {
    describe("Success", () => {});

    describe("Failure", () => {});
  });
});

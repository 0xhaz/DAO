const { ethers } = require("hardhat");

const tokens = (n: number) => ethers.utils.parseEther(n.toString());

const ether = tokens;

const networkConfig = {
  5: {
    name: "goerli",
    entranceFee: tokens(0.01),
    daoPercentage: "10",
  },
  1337: {
    name: "hardhat",
    entranceFee: tokens(0.01),
    daoPercentage: "10",
  },
};

const developmentChains = ["hardhat", "localhost"];
const INITIAL_SUPPLY = tokens(1000000);
const MIN_DELAY = 0;
const VOTING_DELAY = 0;
const VOTING_PERIOD = 50;
const QUORUM_PERCENTAGE = 0;
const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

module.exports = {
  developmentChains,
  networkConfig,
  INITIAL_SUPPLY,
  MIN_DELAY,
  VOTING_DELAY,
  VOTING_PERIOD,
  QUORUM_PERCENTAGE,
  ADDRESS_ZERO,
};

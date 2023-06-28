const { ethers, deployments, getNamedAccounts, network } = require("hardhat");
const { assert, expect } = require("chai");

const {
  developmentChains,
  VOTING_DELAY,
  VOTING_PERIOD,
  MIN_DELAY,
  INITIAL_SUPPLY,
} = require("../hardhat-helper");

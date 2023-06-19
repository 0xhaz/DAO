// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ReentrancyGuard.sol";
import "./Escrow.sol";

contract StakingContract is ReentrancyGuard {
    address public owner;
    IERC20 public token;
    EscrowContract public escrowContract;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastStakeTimestamp;
    uint256 public rewardRate = 10; // 10% annualized

    event TokenStaked(address indexed staker, uint256 amount);
    event TokenUnstaked(address indexed staker, uint256 amount);
    event RewardClaimed(address indexed staker, uint256 amount);

    constructor(address _tokenAddress, address _escrowAddress) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        escrowContract = EscrowContract(_escrowAddress);
    }

    function stakeTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        if (stakedBalances[msg.sender] == 0) {
            lastStakeTimestamp[msg.sender] = block.timestamp;
        } else {
            uint256 rewards = calculateRewards(msg.sender);
            if (rewards > 0) {
                escrowContract.depositTokens(address(token), rewards);
                emit RewardClaimed(msg.sender, rewards);
            }
        }

        token.transferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;

        emit TokenStaked(msg.sender, amount);
    }

    function unstakeTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            stakedBalances[msg.sender] >= amount,
            "Amount must be less than balance"
        );
        uint256 rewards = calculateRewards(msg.sender);
        if (rewards > 0) {
            escrowContract.withdrawTokens(address(token), rewards);
            emit RewardClaimed(msg.sender, rewards);
        }

        stakedBalances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);

        emit TokenUnstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards to claim");

        escrowContract.withdrawTokens(address(token), rewards);

        emit RewardClaimed(msg.sender, rewards);
        lastStakeTimestamp[msg.sender] = block.timestamp;
    }

    function calculateRewards(address staker) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastStakeTimestamp[staker];
        uint256 stakedAmount = stakedBalances[staker];
        uint256 annualRewards = (stakedAmount * rewardRate) / 100;
        uint256 unclaimedRewards = (annualRewards * timeElapsed) / 365 days;
        return unclaimedRewards;
    }
}

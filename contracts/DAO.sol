// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Governance/Governance.sol";
import "./Governance/TimeLock.sol";
import "./Token.sol";

contract DAO is Ownable {
    using SafeMath for uint256;

    uint256 private value;
    uint256 private constant c_MaximumVotingPower = 1000;
    uint256 private constant c_WeightedCoefficient = 2;
    Governance private _governance;
    TimeLock private _timeLock;
    GovToken private _govToken;
    uint256 public votingDelay;
    uint256 public votingPeriod;

    enum Duration {
        OneDay,
        ThreeDays,
        FiveDays,
        SevenDays,
        NineDays,
        TwelveDays
    }

    struct Proposal {
        address proposer;
        string description;
        uint256 tokenWeight;
        uint256 quadraticVotes;
        bool isTokenWeighted;
        bool isQuadraticVoting;
        bool isOpen;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 totalVotes;
        uint256 amount;
        address recipient;
        bool finalized;
    }

    modifier onlyAfterStakeDuration(address _staker) {
        Duration duration = _getDurationFromStakeTimestamp(_staker);

        require(
            block.timestamp >=
                s_stakeTimestamp[_staker] + _getDurationValue(duration),
            "Staking duration not completed"
        );
        _;
    }

    event ValueChanged(uint256 newValue);
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        string description
    );
    event StakedTokens(address staker, uint256 amount);
    event UnstakedTokens(address staker, uint256 amount);
    event TokenRewardsClaimed(address staker, uint256 amount);
    event VoteTokenWeighted(uint256 proposalId, address voter);
    event VoteQuadratic(uint256 proposalId, address voter);
    event VotingPeriodEnded(uint256 proposalId);
    event ProposalFinalized(uint256 proposalId);

    mapping(uint256 => Proposal) public s_proposals;
    mapping(address => uint256) public s_tokenWeight;
    mapping(address => uint256) public s_balanceOf;
    mapping(address => uint256) public s_stakeTimestamp;
    mapping(address => uint256) public s_votingCredits;
    mapping(address => mapping(uint256 => bool)) public s_hasVoted;
    mapping(address => uint256) public s_votes;

    constructor(
        address _govTokenAddress,
        Governance _governanceAddress,
        TimeLock _timeLockAddress,
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod
    ) {
        _govToken = GovToken(_govTokenAddress);
        _governance = _governanceAddress;
        _timeLock = _timeLockAddress;

        votingDelay = _initialVotingDelay;
        votingPeriod = _initialVotingPeriod;
    }

    function store(uint256 newValue) public onlyOwner {
        value = newValue;
        emit ValueChanged(newValue);
    }

    function retrieve() public view returns (uint256) {
        return value;
    }

    function createProposal(
        string memory _description,
        bool _isTokenWeighted,
        bool _isQuadraticVoting,
        uint256 _votingDelay,
        uint256 _votingPeriod
    ) public {
        require(
            _isTokenWeighted || _isQuadraticVoting,
            "Must be token weighted or quadratic voting"
        );

        uint256 proposalId = uint256(
            keccak256(abi.encodePacked(msg.sender, _description))
        );

        uint256 startTimestamp = block.timestamp + _votingDelay;
        uint256 endTimestamp = startTimestamp + _votingPeriod;

        s_proposals[proposalId] = Proposal({
            proposer: msg.sender,
            description: _description,
            tokenWeight: 0,
            quadraticVotes: 0,
            isTokenWeighted: _isTokenWeighted,
            isQuadraticVoting: _isQuadraticVoting,
            isOpen: true,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            totalVotes: 0,
            amount: address(this).balance,
            recipient: address(0),
            finalized: false
        });

        s_votes[msg.sender] = 0;

        emit ProposalCreated(proposalId, msg.sender, _description);
    }

    function voteTokenWeighted(uint256 _proposalId) public {
        require(_proposalId > 0, "Proposal ID must be greater than 0");
        require(
            s_proposals[_proposalId].isTokenWeighted,
            "Token weighted voting not enabled for this proosal"
        );
        require(s_tokenWeight[msg.sender] > 0, "You must have tokens to vote");
        require(s_proposals[_proposalId].isOpen, "Proposal is not open");
        require(!s_hasVoted[msg.sender][_proposalId], "Already voted");

        uint256 tokenBalance = s_tokenWeight[msg.sender];
        uint256 stakingDuration = block.timestamp -
            s_stakeTimestamp[msg.sender];

        // Calculate the time-weighted voting power based on token balance and staking duration
        uint256 timeWeightedVotingPower = _calculateTimeWeightedVotingPower(
            tokenBalance,
            stakingDuration
        );

        s_proposals[_proposalId].totalVotes += timeWeightedVotingPower;
        s_votes[msg.sender] += timeWeightedVotingPower;

        s_proposals[_proposalId].tokenWeight += timeWeightedVotingPower;
        s_hasVoted[msg.sender][_proposalId] = true;

        emit VoteTokenWeighted(_proposalId, msg.sender);
    }

    function voteQuadratic(uint256 _proposalId, uint256 _votingCredits) public {
        require(_proposalId > 0, "Proposal ID must be greater than 0");
        require(
            s_proposals[_proposalId].isQuadraticVoting,
            "Quadratic voting not enabled for this proosal"
        );
        require(s_proposals[_proposalId].isOpen, "Proposal is not open");
        require(!s_hasVoted[msg.sender][_proposalId], "Already voted");
        require(
            s_votingCredits[msg.sender] >= _votingCredits,
            "Insufficient voting credits"
        );

        // Calculate the quadratic voting power based on the staked token weight
        uint256 votingCredits = Math.min(
            _votingCredits,
            s_votingCredits[msg.sender]
        );

        s_proposals[_proposalId].quadraticVotes +=
            votingCredits *
            votingCredits;

        s_proposals[_proposalId].totalVotes += votingCredits;
        s_votes[msg.sender] += votingCredits;

        s_hasVoted[msg.sender][_proposalId] = true;

        emit VoteQuadratic(_proposalId, msg.sender);
    }

    function endVotingPeriod(uint256 _proposalId) public {
        require(_proposalId > 0, "Proposal ID must be greater than 0");
        require(s_proposals[_proposalId].isOpen, "Proposal is not open");
        require(
            block.timestamp >= s_proposals[_proposalId].endTimestamp,
            "Voting period not ended"
        );

        Proposal storage proposal = s_proposals[_proposalId];
        proposal.isOpen = false;

        _finalizeProposal(_proposalId);

        emit VotingPeriodEnded(_proposalId);
    }

    function stakeTokens(uint256 _amount, Duration _duration) public {
        require(_amount > 0, "Staked amount must be greater than 0");
        require(
            s_tokenWeight[msg.sender] == 0,
            "You have already staked tokens"
        );
        require(
            s_balanceOf[msg.sender] >= _amount,
            "Insufficient balance to stake"
        );

        // Transfer the tokens from the staker to the contract
        _govToken.transferFrom(msg.sender, address(this), _amount);

        // Update the staker's balance and stake timestamp
        s_balanceOf[msg.sender] = s_balanceOf[msg.sender].add(_amount);
        s_stakeTimestamp[msg.sender] = block.timestamp;

        // Update the staker's token-weighted voting power
        s_tokenWeight[msg.sender] += _amount;

        // Calculate the voting credits based on the staked amount
        uint256 votingCredits = _calculateVotingCredits(_amount, _duration);

        // Assign the voting credits to the staker
        s_votingCredits[msg.sender] = votingCredits;

        // Get the duration based on the durationIndex
        uint256 duration = _getDurationValue(_duration);

        // Calculate the time weighted voting power
        _calculateTimeWeightedVotingPower(_amount, duration);

        // Store the stake timestamp
        s_stakeTimestamp[msg.sender] = block.timestamp;

        // Calculate additional token rewards based on stake duration
        uint256 additionalRewards = _calculateTokenRewards(_amount, duration);

        // Transfer the additional rewards to the staker
        _govToken.transfer(msg.sender, additionalRewards);

        emit StakedTokens(msg.sender, _amount);
        emit TokenRewardsClaimed(msg.sender, additionalRewards);
    }

    function unstakeTokens() public onlyAfterStakeDuration(msg.sender) {
        require(
            s_tokenWeight[msg.sender] > 0,
            "You have not staked any tokens"
        );

        uint256 stakedAmount = s_tokenWeight[msg.sender];

        // Transfer the tokens from the contract to the staker
        _govToken.transfer(msg.sender, stakedAmount);

        // Reset the staked token balance
        s_tokenWeight[msg.sender] = 0;

        emit UnstakedTokens(msg.sender, stakedAmount);
    }

    function withdrawTokenRewards() public {
        require(
            s_tokenWeight[msg.sender] > 0,
            "You have not staked any tokens"
        );

        uint256 stakedAmount = s_tokenWeight[msg.sender];

        // Calculate additional token rewards based on stake duration
        uint256 additionalRewards = _calculateTokenRewards(
            stakedAmount,
            block.timestamp.sub(block.timestamp)
        );

        // Transfer the additional rewards to the staker
        _govToken.transfer(msg.sender, additionalRewards);

        emit TokenRewardsClaimed(msg.sender, additionalRewards);
    }

    function setQuorum(uint256 _quorumPercentage) public {
        _governance.setQuorum(_quorumPercentage);
    }

    /**
     * @dev Calculates the time-weighted voting power based on the staked token balance and duration.
     *
     * @param _tokenBalance The amount of tokens staked.
     * @param _stakingDuration The duration of the stake.
     * @return The time-weighted voting power.
     */

    function _calculateTimeWeightedVotingPower(
        uint256 _tokenBalance,
        uint256 _stakingDuration
    ) internal pure returns (uint256) {
        // Convert c_WeightedCoefficient to a fixed point number
        uint256 fixedCoefficient = c_WeightedCoefficient * 100;

        // Calculate the weighted factor using fixed-point arithmetic
        uint256 _weightedFactor = (fixedCoefficient + 100) ** _stakingDuration;
        uint256 weightedFactor = _weightedFactor / 100;
        uint256 timeWeightedVotingPower = (c_MaximumVotingPower <=
            weightedFactor)
            ? weightedFactor.mul(_tokenBalance)
            : c_MaximumVotingPower.mul(_tokenBalance);

        return timeWeightedVotingPower;
    }

    function _calculateTokenRewards(
        uint256 _amount,
        uint256 _stakingDuration
    ) internal pure returns (uint256) {
        // Define the reward rate based on the staking duration
        uint256 rewardRate;
        if (_stakingDuration == 1 days) {
            rewardRate = 100;
        } else if (_stakingDuration == 3 days) {
            rewardRate = 150;
        } else if (_stakingDuration == 5 days) {
            rewardRate = 200;
        } else if (_stakingDuration == 7 days) {
            rewardRate = 250;
        } else if (_stakingDuration == 9 days) {
            rewardRate = 500;
        } else if (_stakingDuration == 12 days) {
            rewardRate = 1000;
        } else {
            revert("Invalid staking duration");
        }

        // Calculate the total token rewards based on the stake amount and duration
        uint256 additionalRewards = _amount.mul(rewardRate).div(1000);

        return additionalRewards;
    }

    function _calculateVotingCredits(
        uint256 _amount,
        Duration _duration
    ) internal pure returns (uint256) {
        // Define the voting credits based on the staked amount
        uint256 votingCredits;
        if (_amount >= 1000 && _amount < 5000) {
            votingCredits = 1;
        } else if (_amount >= 5000 && _amount < 10000) {
            votingCredits = 5;
        } else if (_amount >= 10000 && _amount < 50000) {
            votingCredits = 10;
        } else if (_amount >= 50000 && _amount < 100000) {
            votingCredits = 50;
        } else if (_amount >= 100000 && _amount < 500000) {
            votingCredits = 100;
        } else if (_amount >= 500000 && _amount < 1000000) {
            votingCredits = 500;
        } else if (_amount >= 1000000) {
            votingCredits = 1000;
        } else {
            revert("Invalid staked amount");
        }

        // Increase voting credits based on staking duration
        if (_duration == Duration.OneDay) {
            votingCredits *= 2;
        } else if (_duration == Duration.ThreeDays) {
            votingCredits *= 3;
        } else if (_duration == Duration.FiveDays) {
            votingCredits *= 4;
        } else if (_duration == Duration.SevenDays) {
            votingCredits *= 5;
        } else if (_duration == Duration.NineDays) {
            votingCredits *= 6;
        } else if (_duration == Duration.TwelveDays) {
            votingCredits *= 7;
        } else {
            revert("Invalid duration");
        }

        return votingCredits;
    }

    function _getDurationValue(
        Duration _duration
    ) internal pure returns (uint256) {
        if (_duration == Duration.OneDay) {
            return 1 days;
        } else if (_duration == Duration.ThreeDays) {
            return 3 days;
        } else if (_duration == Duration.FiveDays) {
            return 5 days;
        } else if (_duration == Duration.SevenDays) {
            return 7 days;
        } else if (_duration == Duration.NineDays) {
            return 9 days;
        } else if (_duration == Duration.TwelveDays) {
            return 12 days;
        } else {
            revert("Invalid duration");
        }
    }

    function _getDurationFromStakeTimestamp(
        address _staker
    ) internal view returns (Duration) {
        uint256 stakeTimestamp = s_stakeTimestamp[_staker];
        uint256 stakeDuration = block.timestamp.sub(stakeTimestamp);

        if (stakeDuration == 1 days) {
            return Duration.OneDay;
        } else if (stakeDuration == 3 days) {
            return Duration.ThreeDays;
        } else if (stakeDuration == 5 days) {
            return Duration.FiveDays;
        } else if (stakeDuration == 7 days) {
            return Duration.SevenDays;
        } else if (stakeDuration == 9 days) {
            return Duration.NineDays;
        } else if (stakeDuration == 12 days) {
            return Duration.TwelveDays;
        } else {
            revert("Invalid staking duration");
        }
    }

    function _finalizeProposal(uint256 _proposalId) internal {
        Proposal storage proposal = s_proposals[_proposalId];

        require(!proposal.isOpen, "Proposal is still open");
        require(!proposal.finalized, "Proposal is already finalized");

        proposal.finalized = true;

        // Check that the proposal has enough votes
        require(
            proposal.totalVotes >= _governance.quorum(_proposalId),
            "Proposal does not have enough votes"
        );

        // Check that proposal has enough funds
        require(address(this).balance >= proposal.amount, "Not enough funds");

        // Transfer the funds to the recipient
        (bool success, ) = proposal.recipient.call{value: proposal.amount}("");
        require(success, "Transfer failed");

        emit ProposalFinalized(_proposalId);
    }
}

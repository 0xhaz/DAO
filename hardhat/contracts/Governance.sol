// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "./interface/IProjectFund.sol";
import "./interface/IGovernorSettings.sol";
import "./Staking.sol";

error GovernanceContract__NeedEntranceFee();

contract GovernanceContract is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    IProjectFund,
    IGovernorSettings
{
    IProjectFund public projectFund;
    IGovernorSettings public governorSettings;
    Staking public staking;

    uint256 private s_votingDelay;
    uint256 private s_votingPeriod;
    uint256 private s_proposalThreshold;

    mapping(address => bool) public s_isEntranceFeePaid;

    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorumPercentage,
        address _projectFundAddress,
        address _stakingAddress
    )
        Governor("GovernanceContract")
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {
        projectFund = IProjectFund(_projectFundAddress);
        s_votingDelay = _votingDelay;
        s_votingPeriod = _votingPeriod;
        governorSettings = IGovernorSettings(this);
        staking = Staking(_stakingAddress);
    }

    function votingDelay()
        public
        view
        override(IGovernorSettings, IGovernor)
        returns (uint256)
    {
        return s_votingDelay;
    }

    function votingPeriod()
        public
        view
        override(IGovernor, IGovernorSettings)
        returns (uint256)
    {
        return s_votingPeriod;
    }

    function quorum(
        uint256 _blockNumber
    )
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(_blockNumber);
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) public override(Governor, IGovernor) returns (uint256) {
        if (!s_isEntranceFeePaid[msg.sender]) {
            revert GovernanceContract__NeedEntranceFee();
        }

        return super.propose(_targets, _values, _calldatas, _description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, IGovernorSettings)
        returns (uint256)
    {
        return s_proposalThreshold;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _execute(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(
            _proposalId,
            _targets,
            _values,
            _calldatas,
            _descriptionHash
        );
    }

    function _cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function _getVotes(
        address account,
        uint256 /*timepoint */,
        bytes memory
    ) internal view override(GovernorVotes, Governor) returns (uint256) {
        return staking.getMembershipVotingPower(account);
    }
}

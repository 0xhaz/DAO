// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

interface IGovernorSettings {
    function votingDelay() external returns (uint256);

    function votingPeriod() external returns (uint256);

    function proposalThreshold() external returns (uint256);
}

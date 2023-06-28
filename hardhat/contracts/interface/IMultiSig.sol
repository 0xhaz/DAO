// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

interface IMultiSig {
    function contribute(uint256) external payable;

    function withdrawFunds(uint256, address) external;

    function addProRataShare(address, uint256) external;

    function getFunderBalance(address, uint256) external view returns (uint256);
}

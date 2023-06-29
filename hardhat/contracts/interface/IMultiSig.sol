// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

interface IMultiSig {
    function contributeEther(
        uint256 amount,
        uint256 projectId
    ) external payable;

    function contributeTokens(
        address tokenAddress,
        uint256 amount,
        uint256 projectId
    ) external payable;

    function withdrawFunds(uint256 projectId, address account) external;

    function addProRataShare(
        address account,
        uint256 share,
        uint256 projectId
    ) external;

    function getFunderBalance(
        address account,
        uint256 projectId
    ) external view returns (uint256);
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

interface IProjectFund {
    function s_isEntranceFeePaid(address) external view returns (bool);
}

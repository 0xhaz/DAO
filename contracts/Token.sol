// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovToken is ERC20Votes {
    address payable public owner;
    uint256 private _time;
    bool private _minted;
    uint256 constant c_MAX_SUPPLY = 1000000 * 1e18;
    uint256 constant c_TOKENS_PER_USER = 1000;

    mapping(address => bool) public s_claimedTokens;
    address[] public s_tokenHolders;

    event TokenTransferred(
        address indexed from,
        address indexed to,
        uint256 value
    );
    event TokenMinted(address indexed to, uint256 value);
    event TokenBurned(address indexed from, uint256 value);

    constructor(
        uint256 _keepPercentage
    ) ERC20("Gov Token", "GOV") ERC20Permit("Gov Token") {
        uint256 keepAmount = (c_MAX_SUPPLY * _keepPercentage) / 100;
        _mint(msg.sender, c_MAX_SUPPLY);
        _transfer(msg.sender, address(this), c_MAX_SUPPLY - keepAmount);
        s_tokenHolders.push(msg.sender);
    }

    function claimTokens() external {
        require(!s_claimedTokens[msg.sender], "Already claimed tokens");
        s_claimedTokens[msg.sender] = true;
        _transfer(address(this), msg.sender, c_TOKENS_PER_USER * 1e18);
        s_tokenHolders.push(msg.sender);
    }

    function getHodlers() external view returns (uint256) {
        return s_tokenHolders.length;
    }

    // Override functions

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
        emit TokenTransferred(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20Votes) {
        super._mint(to, amount);
        emit TokenMinted(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20Votes) {
        super._burn(account, amount);
        emit TokenBurned(account, amount);
    }
}

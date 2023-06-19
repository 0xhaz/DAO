// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    address public escrowAddress;
    uint256 public constant escrowPercentage = 30;

    constructor(address _escrowAddress) ERC20("MyToken", "MTK") {
        escrowAddress = _escrowAddress;
        uint256 escrowAmount = (totalSupply() * escrowPercentage) / 100;
        _mint(escrowAddress, escrowAmount);
        _mint(msg.sender, totalSupply() - escrowAmount);
    }

    function mint(address recipient, uint256 amount) external returns (bool) {
        _mint(recipient, amount);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function totalSupply() public view override returns (uint256) {
        return super.totalSupply() + 1000000 * 1e18;
    }
}

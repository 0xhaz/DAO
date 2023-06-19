// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface EscrowContract {
    function depositTokens(address tokenAddress, uint256 amount) external;

    function withdrawTokens(address tokenAddress, uint256 amount) external;
}

contract GovernanceToken is ERC20Permit, ERC20Votes {
    address public owner;
    EscrowContract public escrowContract;
    IERC20 public stakedToken;
    address public escrow;
    uint256 private constant MAX_SUPPLY = 1000000 * 1e18;

    event TokenMinted(address indexed recipient, uint256 amount);

    constructor(
        address _escrow,
        address _stakedToken
    ) ERC20("Governance Token", "GOV") ERC20Permit("Governance Token") {
        owner = msg.sender;
        escrow = _escrow;
        stakedToken = IERC20(_stakedToken);
    }

    function stakedTokenAndMint(uint256 _amount) public {
        require(
            stakedToken.balanceOf(msg.sender) >= 1000,
            "Not enough staked tokens"
        );

        stakedToken.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
        escrowContract.depositTokens(
            address(this),
            IERC20(address(this)).balanceOf(msg.sender)
        );

        emit TokenMinted(msg.sender, _amount);
    }

    function withdrawTokenAndBurn(uint256 _amount) public {
        require(
            balanceOf(msg.sender) >= _amount,
            "Not enough governance tokens"
        );

        escrowContract.withdrawTokens(address(this), _amount);
        _burn(msg.sender, _amount);
    }

    function setEscrowContract(address _escrowContract) external {
        require(msg.sender == owner, "Only owner can set escrow contract");
        escrowContract = EscrowContract(_escrowContract);
    }

    function setEscrow(address _escrow) external {
        require(msg.sender == owner, "Only owner can set escrow");
        escrow = _escrow;
    }

    function setStakedToken(address _stakedToken) external {
        require(msg.sender == owner, "Only owner can set staked token");
        stakedToken = IERC20(_stakedToken);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Votes, ERC20) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20Votes, ERC20) {
        require(
            ERC20.totalSupply() + amount <= MAX_SUPPLY,
            "Max supply exceeded"
        );
        super._mint(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20Votes, ERC20) {
        super._burn(account, amount);
    }

    receive() external payable {
        revert("Do not send ETH directly");
    }
}

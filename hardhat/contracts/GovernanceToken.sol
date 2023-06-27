// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20Votes, Ownable {
    uint256 public s_initialSupply = 1000000 * 1e18;

    event TokenTransfer(
        address indexed _from,
        address indexed _to,
        uint256 _amount
    );

    constructor()
        ERC20("GovernanceToken", "GT")
        ERC20Permit("GovernanceToken")
    {
        _mint(msg.sender, s_initialSupply);
    }

    function mintToken(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burnToken(address _account, uint256 _amount) external {
        _burn(_account, _amount);
    }

    function _afterTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override(ERC20Votes) {
        super._afterTokenTransfer(_from, _to, _amount);
        emit TokenTransfer(_from, _to, _amount);
    }

    function _mint(
        address _to,
        uint256 _amount
    ) internal override(ERC20Votes) onlyOwner {
        super._mint(_to, _amount);
    }

    function _burn(
        address _account,
        uint256 _amount
    ) internal override(ERC20Votes) {
        super._burn(_account, _amount);
    }
}

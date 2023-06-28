// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

contract MultiSigWallet {
    address private projectFundAddress;
    Contribution[] private contributions;
    ProRataShare[] private proRataShares;
    uint256 private totalContributions;
    bool private closed;

    struct Contribution {
        address contributor;
        uint256 amount;
    }

    struct ProRataShare {
        address recipient;
        uint256 share;
    }

    modifier onlyProjectFund() {
        require(msg.sender == projectFundAddress, "MultiSig: not project fund");
        _;
    }

    event WithdrawFunds(
        address indexed _funder,
        uint256 indexed _projectId,
        uint256 _amount
    );

    constructor(address _projectFundAddress) {
        projectFundAddress = _projectFundAddress;
        totalContributions = 0;
        closed = false;
    }

    mapping(address => mapping(uint256 => uint256)) private s_funderBalances;

    function contribute(uint256 _amount) external payable {
        require(!closed, "MultiSig: closed");
        require(msg.value > 0, "MultiSig: zero contribution");

        contributions.push(
            Contribution({contributor: msg.sender, amount: _amount})
        );
        totalContributions += msg.value;
    }

    function confirmTransaction() external onlyProjectFund {
        require(closed, "MultiSig: not closed");

        for (uint256 i = 0; i < proRataShares.length; i++) {
            ProRataShare memory share = proRataShares[i];
            payable(share.recipient).transfer(share.share);
        }
    }

    function withdrawFunds(uint256 _projectId, address _funder) external {
        require(!closed, "MultiSig: closed");

        uint256 balance = s_funderBalances[_funder][_projectId];
        require(balance > 0, "MultiSig: zero balance");

        s_funderBalances[_funder][_projectId] = 0;

        (bool success, ) = payable(_funder).call{value: balance}("");
        require(success, "MultiSig: transfer failed");

        emit WithdrawFunds(_funder, _projectId, balance);
    }

    function addProRataShare(
        address _recipient,
        uint256 _share
    ) external onlyProjectFund {
        require(!closed, "MultiSig: closed");

        proRataShares.push(
            ProRataShare({recipient: _recipient, share: _share})
        );
    }

    function getFunderBalance(
        address _funder,
        uint256 _projectId
    ) external view returns (uint256) {
        return s_funderBalances[_funder][_projectId];
    }

    function closeWallet() external onlyProjectFund {
        require(!closed, "MultiSig: closed");
        closed = true;
    }

    function getContributionCount() external view returns (uint256) {
        return contributions.length;
    }

    function getTotalContributions() external view returns (uint256) {
        return totalContributions;
    }
}

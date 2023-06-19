// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Governance.sol";
import "./ReentrancyGuard.sol";

contract EscrowContract is ReentrancyGuard {
    address public owner;
    GovernorContract public governorContract;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public loanAmounts;
    mapping(uint256 => bool) public isProposalClosed;

    event TokenDeposited(address indexed depositor, uint256 amount);
    event TokenWithdrawn(address indexed recipient, uint256 amount);
    event LoanRepaid(address indexed borrower, uint256 amount);
    event FundReleased(address indexed borrower, uint256 amount);

    constructor(address _governorAddress) {
        owner = msg.sender;
        governorContract = GovernorContract(payable(_governorAddress));
    }

    function depositTokens(
        address tokenAddress,
        uint256 amount
    ) external nonReentrant {
        IERC20 token = IERC20(tokenAddress);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Insufficient allowance");
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit TokenDeposited(msg.sender, amount);
    }

    function withdrawTokens(
        address tokenAddress,
        uint256 amount
    ) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        IERC20 token = IERC20(tokenAddress);
        token.transfer(msg.sender, amount);
        balances[msg.sender] -= amount;
        emit TokenWithdrawn(msg.sender, amount);
    }

    function approveProposal(uint256 _proposalId) external {
        require(
            governorContract.state(_proposalId) ==
                IGovernor.ProposalState.Active,
            "Proposal must be active"
        );
        governorContract.castVote(_proposalId, uint8(1));

        address borrower = governorContract.proposalProposer(_proposalId);
        uint256 loanAmount = _calculateLoanAmount(_proposalId);

        require(balances[address(this)] >= loanAmount, "Insufficient funds");
        balances[address(this)] -= loanAmount;
        balances[borrower] += loanAmount;

        loanAmounts[borrower] += loanAmount;

        _releaseFunds(_proposalId);
    }

    function fundRepayment(uint256 _proposalId, uint256 _amount) external {
        require(
            governorContract.state(_proposalId) ==
                IGovernor.ProposalState.Active,
            "Proposal must be active"
        );

        _repayLoan(_proposalId, _amount);
    }

    function _releaseFunds(uint256 _proposalId) internal {
        address recipient = governorContract.proposalProposer(_proposalId);
        uint256 loanAmount = loanAmounts[recipient];
        require(loanAmount > 0, "No loan exists for this proposal");

        loanAmounts[recipient] = 0;
        balances[address(this)] -= loanAmount;
        balances[recipient] += loanAmount;

        emit FundReleased(recipient, loanAmount);
    }

    function _repayLoan(uint256 _proposalId, uint256 _amount) internal {
        uint256 amount = _amount;
        uint256 proposalId = _proposalId;

        require(amount > 0, "No loan exists for this proposal");

        IERC20 token = IERC20(address(this));
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Insufficient allowance");

        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] -= amount;
        balances[address(this)] += amount;
        loanAmounts[msg.sender] -= amount;

        emit LoanRepaid(msg.sender, amount);

        if (loanAmounts[msg.sender] == 0) {
            isProposalClosed[_proposalId] = true;
        }
    }

    // loan amount with 10% interest
    function _calculateLoanAmount(
        uint256 _proposalId
    ) internal view returns (uint256) {
        uint256 fundAmount = governorContract.proposalAmount(_proposalId);

        uint256 loanAmount = fundAmount + (fundAmount / 10) / 100;

        return loanAmount;
    }
}

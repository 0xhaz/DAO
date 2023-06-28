// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "./interface/IMultiSig.sol";
// import "hardhat/console.sol";

error ProjectFund__NotApprovedByDao();
error ProjectFund__UpkeepNeeded();
error ProjectFund__TransferFailed(uint256 _projectId);
error ProjectFund__EntranceFeeNeeded();
error ProjectFund__LowBalance();
error ProjectFund__WithdrawFailed();
error ProjectFund__InvalidStatus();

contract ProjectFund is Ownable, KeeperCompatibleInterface {
    uint256 private projectId = 1;
    uint256 private daoPercentage;
    uint256 private entranceFee;
    address private multiSigWalletAddress;
    IMultiSig private multiSigWallet;

    enum ProjectStatus {
        PENDING,
        SUCCESS,
        FAILED,
        CANCELLED
    }

    struct Project {
        address projectOwnerAddress;
        uint256 projectFunds;
        uint256 goalAmount;
        ProjectStatus projectStatus;
        bool isApprovedByDao;
        bool isProjectFunded;
    }

    mapping(uint256 => Project) private s_projects;
    mapping(bytes32 => uint256) private s_hashToProjectId;
    mapping(uint256 => bytes32) private s_idToHash;
    mapping(address => mapping(uint256 => uint256)) private s_fundersBalance;
    mapping(address => uint256[]) private s_fundedProjects;
    mapping(address => bool) private s_isEntranceFeePaid;
    mapping(uint256 => bool) private s_isApprovedByDao;
    mapping(uint256 => bool) private s_isProjectFunded;
    mapping(uint256 => uint256) private s_projectToTime;
    mapping(uint256 => uint256) private s_time;

    event ProjectFunded(uint256 indexed _projectId);
    event ProjectFailed(uint256 indexed _projectId);
    event EntranceFeePaid(address indexed _projectOwner);
    event ProjectGoesToFunding(uint256 indexed _projectId);
    event WithdrawFund(address indexed _investor, uint256 indexed _projectId);

    modifier isApprovedByDao(uint256 _projectId) {
        if (!s_isApprovedByDao[projectId])
            revert ProjectFund__NotApprovedByDao();
        _;
    }

    modifier onlyOwnerOrProjectOwner(uint256 _projectId) {
        if (
            msg.sender != owner() &&
            msg.sender != s_projects[_projectId].projectOwnerAddress
        ) revert ProjectFund__NotApprovedByDao();
        _;
    }

    constructor(
        uint256 _entranceFee,
        uint256 _daoPercentage,
        address _multiSigWalletAddress
    ) {
        daoPercentage = _daoPercentage;
        entranceFee = _entranceFee;
        multiSigWallet = IMultiSig(_multiSigWalletAddress);
    }

    function fundProject(uint256 _projectId) external payable {
        if (s_projects[_projectId].projectStatus != ProjectStatus.PENDING) {
            revert ProjectFund__InvalidStatus();
        }
        if (s_isApprovedByDao[_projectId] == false) {
            revert ProjectFund__NotApprovedByDao();
        }

        multiSigWallet.contribute{value: msg.value}(_projectId);

        multiSigWallet.addProRataShare(msg.sender, msg.value);

        s_projects[_projectId].projectFunds += msg.value;

        if (
            !_isFunderInProject(
                s_projects[_projectId].projectOwnerAddress,
                _projectId
            )
        ) {
            s_fundedProjects[s_projects[_projectId].projectOwnerAddress].push(
                _projectId
            );
        }

        s_fundedProjects[s_projects[_projectId].projectOwnerAddress] = [
            _projectId
        ];

        emit ProjectFunded(_projectId);
    }

    function createProject(
        bytes32 _ipfsHash,
        uint256 _fundingGoalAmount,
        uint256 _time
    ) external payable {
        if (msg.value <= entranceFee) revert ProjectFund__LowBalance();

        Project storage project = s_projects[projectId];

        project.projectOwnerAddress = msg.sender;
        project.projectFunds = 0;
        project.goalAmount = _fundingGoalAmount;
        project.projectStatus = ProjectStatus.PENDING;
        project.isApprovedByDao = false;
        project.isProjectFunded = false;

        s_hashToProjectId[_ipfsHash] = projectId;
        s_idToHash[projectId] = _ipfsHash;

        s_time[projectId] = _time;
        s_projectToTime[projectId] = block.timestamp + _time;

        emit ProjectGoesToFunding(projectId);
        projectId++;
    }

    function cancelProject(
        uint256 _projectId
    ) external onlyOwnerOrProjectOwner(_projectId) {
        if (s_projects[_projectId].projectStatus != ProjectStatus.PENDING)
            revert ProjectFund__InvalidStatus();

        s_projects[_projectId].isApprovedByDao = false;
        s_projects[_projectId].isProjectFunded = false;
        s_projects[_projectId].projectStatus = ProjectStatus.CANCELLED;
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        override
        returns (bool _upkeepNeeded, bytes memory /*_performData*/)
    {
        uint256 currentProjectId = projectId - 1;
        uint256 currentTimestamp = block.timestamp;

        if (
            currentTimestamp >= s_projectToTime[currentProjectId] &&
            s_projects[currentProjectId].projectStatus == ProjectStatus.PENDING
        ) {
            s_isProjectFunded[currentProjectId] = true;
            return (true, "");
        }
        return (false, "");
    }

    function performUpkeep(bytes calldata /*_performData*/) external override {
        uint256 currentProjectId = projectId - 1;

        require(s_isProjectFunded[currentProjectId]);
        require(
            s_projects[currentProjectId].projectStatus == ProjectStatus.PENDING
        );

        uint256 projectFunds = s_projects[currentProjectId].projectFunds;
        uint256 ownerAmount = (projectFunds * (100 - daoPercentage)) / 100;
        uint256 daoAmount = projectFunds - ownerAmount;

        address projectOwner = s_projects[currentProjectId].projectOwnerAddress;

        _payTo(projectOwner, ownerAmount);
        _payTo(owner(), daoAmount);

        s_projects[currentProjectId].projectStatus = ProjectStatus.SUCCESS;
        s_projects[currentProjectId].isProjectFunded = true;

        emit ProjectFunded(currentProjectId);
    }

    function payEntranceFee() external payable {
        if (msg.value < entranceFee) revert ProjectFund__LowBalance();
        s_isEntranceFeePaid[msg.sender] = true;

        emit EntranceFeePaid(msg.sender);
    }

    function withdrawFunds(uint256 _projectId) external {
        if (s_projects[_projectId].projectStatus != ProjectStatus.SUCCESS)
            revert ProjectFund__InvalidStatus();

        uint256 funderBalance = multiSigWallet.getFunderBalance(
            msg.sender,
            _projectId
        );

        require(funderBalance > 0);

        multiSigWallet.withdrawFunds(_projectId, msg.sender);

        s_projects[_projectId].projectFunds -= funderBalance;

        emit WithdrawFund(msg.sender, _projectId);
    }

    function getProjectDetails(
        uint256 _projectId
    )
        external
        view
        returns (
            Project memory _project,
            uint256 _projectTime,
            uint256 _timeLeft
        )
    {
        _project = s_projects[_projectId];
        _projectTime = s_time[_projectId];
        _timeLeft = s_projectToTime[_projectId] - block.timestamp;
    }

    function getFunderBalance(
        uint256 _projectId,
        address _funder
    ) external view returns (uint256) {
        return multiSigWallet.getFunderBalance(_funder, _projectId);
    }

    function getFundedProjects(
        address _funder
    ) external view returns (uint256[] memory) {
        return s_fundedProjects[_funder];
    }

    function approvedByDao(uint256 _projectId) external onlyOwner {
        if (s_projects[_projectId].projectStatus != ProjectStatus.PENDING)
            revert ProjectFund__InvalidStatus();

        s_isApprovedByDao[_projectId] = true;
        s_projects[_projectId].isApprovedByDao = true;
    }

    function setDaoPercentage(uint256 _daoPercentage) external onlyOwner {
        daoPercentage = _daoPercentage;
    }

    function setEntranceFee(uint256 _entranceFee) external onlyOwner {
        entranceFee = _entranceFee;
    }

    function getEntranceFee() external view returns (uint256) {
        return entranceFee;
    }

    function getDaoPercentage() external view returns (uint256) {
        return daoPercentage;
    }

    function _payTo(address _to, uint256 _amount) internal {
        (bool success, ) = (payable(_to)).call{value: _amount}("");
        if (!success) {
            revert ProjectFund__TransferFailed(_amount);
        }
    }

    function _isFunderInProject(
        address _address,
        uint256 _projectId
    ) internal view returns (bool) {
        uint256[] memory fundedProjects = s_fundedProjects[_address];
        for (uint256 i = 0; i < fundedProjects.length; i++) {
            if (fundedProjects[i] == _projectId) {
                return true;
            }
        }
        return false;
    }
}

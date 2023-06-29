// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interface/IDAOERC721.sol";

contract Staking {
    IDAOERC721 public daoErc721;

    using Address for address;
    using SafeMath for uint256;

    struct Stake {
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
    }

    struct Membership {
        uint256 tokenId;
        uint256 votingPower;
    }

    uint256 private s_votingPowerPerDay;
    uint256 private s_totalVotingPower;
    uint256 private s_membershipCount;

    mapping(uint256 => Stake) private s_stakes;
    mapping(address => Membership) private s_memberships;
    mapping(address => bool) private s_isMembershipToken;

    constructor(IDAOERC721 _daoErc721, uint256 _votingPowerPerDay) {
        daoErc721 = _daoErc721;
        s_votingPowerPerDay = _votingPowerPerDay;
        s_totalVotingPower = 0;
        s_membershipCount = 0;
    }

    function stakeMembership(uint256 _tokenId) external {
        require(
            daoErc721.ownerOf(_tokenId) == msg.sender,
            "Staking: caller is not the owner of the token"
        );
        require(
            !s_isMembershipToken[address(daoErc721)],
            "Staking: membership token already staked"
        );
        require(s_isMembershipToken[msg.sender], "Staking: not a membership");

        daoErc721.transferFrom(msg.sender, address(this), _tokenId);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 30 days;

        s_stakes[_tokenId] = Stake(_tokenId, startTime, endTime);

        uint256 votingPower = _calculateVotingPower(
            _tokenId,
            startTime,
            endTime
        );

        s_totalVotingPower = s_totalVotingPower.add(votingPower);
        s_memberships[msg.sender].votingPower = s_memberships[msg.sender]
            .votingPower
            .add(votingPower);
    }

    function _calculateVotingPower(
        uint256 _tokenId,
        uint256 _startTime,
        uint256 _endTime
    ) private view returns (uint256) {
        Stake memory stake = s_stakes[_tokenId];

        require(stake.tokenId == _tokenId, "Staking: invalid token id");
        require(
            stake.startTime == _startTime,
            "Staking: invalid start time for token id"
        );

        uint256 votingPower = 0;
        uint256 daysStaked = _endTime.sub(_startTime).div(1 days);
        for (uint256 i = 0; i < daysStaked; i++) {
            votingPower = votingPower.add(s_votingPowerPerDay);
        }

        return votingPower;
    }

    function unstakeMembership(uint256 _tokenId) external {
        require(
            daoErc721.ownerOf(_tokenId) == address(this),
            "Staking: token is not staked"
        );

        daoErc721.transferFrom(address(this), msg.sender, _tokenId);

        Stake memory stake = s_stakes[_tokenId];
        uint256 votingPower = _calculateVotingPower(
            _tokenId,
            stake.startTime,
            stake.endTime
        );

        s_totalVotingPower = s_totalVotingPower.sub(votingPower);
        s_memberships[msg.sender].votingPower = s_memberships[msg.sender]
            .votingPower
            .sub(votingPower);
    }

    function getMembership(
        address _owner
    ) external view returns (uint256, uint256) {
        Membership memory membership = s_memberships[_owner];
        require(membership.tokenId != 0, "Staking: not a member");

        return (membership.tokenId, membership.votingPower);
    }

    function getVotingPower() external view returns (uint256) {
        return s_totalVotingPower;
    }

    function getMembershipCount() external view returns (uint256) {
        return s_membershipCount;
    }

    function getMembershipVotingPower(
        address _account
    ) public view returns (uint256) {
        return s_memberships[_account].votingPower;
    }
}

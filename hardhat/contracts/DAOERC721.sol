// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DAOERC721 is
    ERC721,
    ERC721Enumerable,
    Ownable,
    Pausable,
    EIP712,
    ERC721Votes,
    AccessControl
{
    using Address for address;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

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

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _votingPowerPerDay
    ) ERC721(_name, _symbol) EIP712(_name, "1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        s_votingPowerPerDay = _votingPowerPerDay;
        s_totalVotingPower = 0;
        s_membershipCount = 0;
    }

    function mintMembership(address _to) external {
        uint256 _tokenId = _tokenIdCounter.current();
        _safeMint(_to, _tokenId);
        s_isMembershipToken[_to] = true;
        s_membershipCount++;
    }

    function stakeMembership(uint256 _tokenId, uint256 _duration) external {
        require(ownerOf(_tokenId) == msg.sender, "Not owner of token");
        require(s_isMembershipToken[msg.sender], "Not a membership token");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _duration;

        require(endTime > startTime, "Invalid duration");

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

        require(stake.tokenId == _tokenId, "Invalid token id");
        require(_startTime >= stake.startTime && _endTime <= stake.endTime);

        uint256 duration = _endTime.sub(_startTime);
        uint256 votingPower = duration.mul(s_votingPowerPerDay);

        return votingPower;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function getMembership(
        address _owner
    ) external view returns (uint256, uint256) {
        Membership memory membership = s_memberships[_owner];
        require(membership.tokenId > 0, "Not a member");

        return (membership.tokenId, membership.votingPower);
    }

    function getTotalVotingPower() external view returns (uint256) {
        return s_totalVotingPower;
    }

    function getMembershipCount() external view returns (uint256) {
        return s_membershipCount;
    }

    // Override

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Votes) {
        super._afterTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

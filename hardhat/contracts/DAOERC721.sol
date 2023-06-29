// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./factory/MultiSigWalletFactory.sol";

contract DAOERC721 is ERC721, Pausable, EIP712, ERC721Votes, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    address public multiSigWalletFactoryAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        address _multiSigWalletFactoryAddress
    ) ERC721(_name, _symbol) EIP712(_name, "1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        multiSigWalletFactoryAddress = _multiSigWalletFactoryAddress;
    }

    function mintMembership(address _to) external {
        require(
            multiSigWalletFactoryAddress != address(0),
            "DAOERC721: multiSigWalletFactoryAddress is not set"
        );
        require(
            MultiSigWalletFactory(multiSigWalletFactoryAddress).memberToWallet(
                _to
            ) == address(0),
            "DAOERC721: membership already exists"
        );

        uint256 _tokenId = _tokenIdCounter.current();
        _safeMint(_to, _tokenId);
        _tokenIdCounter.increment();

        MultiSigWalletFactory(multiSigWalletFactoryAddress).createWallet(_to);

        MultiSigWalletFactory wallet = MultiSigWalletFactory(
            MultiSigWalletFactory(multiSigWalletFactoryAddress).memberToWallet(
                _to
            )
        );

        IERC721Receiver(_to).onERC721Received(
            msg.sender,
            address(this),
            _tokenId,
            ""
        );

        transferFrom(_to, address(wallet), _tokenId);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Override

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721) whenNotPaused {
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
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

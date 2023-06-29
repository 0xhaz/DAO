// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);

    function onERC721MultiSignWalletCreated(
        address owner,
        address wallet
    ) external;
}

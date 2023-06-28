// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

interface IDAOERC721 {
    function mint(address, uint256) external;

    function burn(uint256) external;

    function transferFrom(address, address, uint256) external;

    function safeTransferFrom(address, address, uint256) external;

    function safeTransferFrom(address, address, uint256, bytes memory) external;

    function approve(address, uint256) external;

    function setApprovalForAll(address, bool) external;

    function getApproved(uint256) external view returns (address);

    function isApprovedForAll(address, address) external view returns (bool);

    function ownerOf(uint256) external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function tokenOfOwnerByIndex(
        address,
        uint256
    ) external view returns (uint256);

    function tokenByIndex(uint256) external view returns (uint256);
}

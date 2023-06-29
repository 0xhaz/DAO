// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "../MultiSig.sol";

contract MultiSigWalletFactory {
    mapping(address => address) public memberToWallet;

    event WalletCreated(address indexed member, address indexed wallet);

    function createWallet(address member) external {
        require(memberToWallet[member] == address(0), "Wallet already exists");

        MultiSigWallet wallet = new MultiSigWallet(member);

        memberToWallet[member] = address(wallet);

        emit WalletCreated(member, address(wallet));
    }
}

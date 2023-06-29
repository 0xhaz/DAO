// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSigWallet {
    address private projectFundAddress;
    Contribution[] private contributions;
    ProRataShare[] private proRataShares;
    uint256 private totalContributions;
    bool private closed;

    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 projectId;
        address tokenAddress;
    }

    struct ProRataShare {
        address recipient;
        uint256 share;
        uint256 projectId;
    }

    modifier onlyProjectFund() {
        require(msg.sender == projectFundAddress, "MultiSig: not project fund");
        _;
    }

    event DepositFunds(address indexed _funder, uint256 _amount);

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
    mapping(address => uint256) private s_funderTotalBalance;

    function depositTokens(
        address _tokenAddress,
        uint256 _amount
    ) external payable {
        require(!closed, "MultiSig: closed");
        require(_amount > 0, "MultiSig: zero contribution");

        if (_tokenAddress == address(0)) {
            require(msg.value == _amount, "MultiSig: incorrect amount");

            (bool success, ) = msg.sender.call{value: msg.value}("");
            require(success, "MultiSig: transfer failed");
        } else {
            IERC20 token = IERC20(_tokenAddress);
            require(
                token.transferFrom(msg.sender, address(this), _amount),
                "MultiSig: transfer failed"
            );

            s_funderTotalBalance[msg.sender] += _amount;

            emit DepositFunds(msg.sender, _amount);
        }
    }

    function contributeEther(
        uint256 _amount,
        uint256 _projectId
    ) external payable {
        require(!closed, "MultiSig: closed");
        require(_amount > 0 || msg.value > 0, "MultiSig: zero contribution");

        contributions.push(
            Contribution({
                contributor: msg.sender,
                amount: msg.value,
                projectId: _projectId,
                tokenAddress: address(0)
            })
        );

        totalContributions += msg.value;
    }

    function contributeTokens(
        address _tokenAddress,
        uint256 _amount,
        uint256 _projectId
    ) external payable {
        require(!closed, "MultiSig: closed");
        require(_amount > 0 || msg.value > 0, "MultiSig: zero contribution");

        IERC20 token = IERC20(_tokenAddress);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "MultiSig: transfer failed"
        );

        contributions.push(
            Contribution({
                contributor: msg.sender,
                amount: _amount,
                projectId: _projectId,
                tokenAddress: _tokenAddress
            })
        );
        totalContributions += _amount;
    }

    function confirmTransaction() external onlyProjectFund {
        require(closed, "MultiSig: not closed");

        for (uint256 i = 0; i < proRataShares.length; i++) {
            ProRataShare memory share = proRataShares[i];
            payable(share.recipient).transfer(share.share);
        }
    }

    function withdrawTokens(
        address _tokenAddress,
        uint256 _amount
    ) external onlyProjectFund {
        require(closed, "MultiSig: not closed");

        if (_tokenAddress == address(0)) {
            (bool success, ) = msg.sender.call{value: _amount}("");
            require(success, "MultiSig: transfer failed");
        } else {
            IERC20 token = IERC20(_tokenAddress);
            require(
                token.transfer(msg.sender, _amount),
                "MultiSig: transfer failed"
            );
        }
    }

    function addProRataShare(
        address _recipient,
        uint256 _share,
        uint256 _projectId
    ) external onlyProjectFund {
        require(!closed, "MultiSig: closed");

        proRataShares.push(
            ProRataShare({
                recipient: _recipient,
                share: _share,
                projectId: _projectId
            })
        );
    }

    /**
     *
     * @dev prepareTransaction: allows the project fund to prepare a transaction
     * by providing the recipient, value, and data. The transaction hash is returned
     *
     * @dev signTransaction: allows the project fund to sign a transaction for a
     * specific transaction hash. The signature is generated offline
     *
     * @dev executeTransaction: allows the project fund to execute a transaction
     * using a signed transaction hash, recipient, value, and data. The transaction
     * is executed if the signature is valid and verified from the project fund address
     *
     */

    function prepareTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external view onlyProjectFund returns (bytes32) {
        require(!closed, "MultiSig: closed");

        bytes32 transactionHash = keccak256(
            abi.encodePacked(address(this), _to, _value, _data)
        );

        return transactionHash;
    }

    function signTransaction(
        bytes32 _transactionHash
    ) external view onlyProjectFund returns (bytes memory) {
        require(closed, "MultiSig: not closed");

        bytes memory signature = _generateSignature(_transactionHash);
        return signature;
    }

    function executeTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data,
        bytes calldata _signature
    ) external onlyProjectFund {
        require(closed, "MultiSig: not closed");

        bytes32 transactionHash = keccak256(
            abi.encodePacked(address(this), _to, _value, _data)
        );

        address signer = _recoverSigner(transactionHash, _signature);
        require(signer == projectFundAddress, "MultiSig: invalid signature");

        (bool success, ) = _to.call{value: _value}(_data);
        require(success, "MultiSig: transaction failed");
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

    /**
     *
     * @dev _generateSignature : takes the transaction hash as input. It converts
     * the transaction hash to an Ethereum signed message hash using the
     * _toEthSignedMessageHash function. It then uses the ecrecover function to recover
     * the address of the signer. Finally, it encodes the address of the
     * signer into bytes and returns it.
     */

    function _generateSignature(
        bytes32 _transactionHash
    ) private pure returns (bytes memory) {
        bytes32 messageHash = _toEthSignedMessageHash(_transactionHash);
        address signer = ecrecover(messageHash, 0, 0, 0);
        require(signer != address(0), "MultiSig: invalid signature");

        bytes memory signature = abi.encodePacked(signer);

        return signature;
    }

    /**
     *
     * @dev _recoverSigner : takes the transaction hash and signature as input. It
     * first checks if the signature length is 65 bytes. It then extracts the
     * r, s and v values from the signature. It then checks if the v value is
     * 27 or 28 and adds 27 if it is 27. It then recovers the address of the
     * signer using the ecrecover function and returns it. Finally, it uses
     * ecrecover to recover the address of the signer and returns it.
     *
     */

    function _recoverSigner(
        bytes32 _hash,
        bytes memory _signature
    ) private pure returns (address) {
        require(_signature.length == 65, "MultiSig: invalid signature length");

        bytes32 messagehash = _toEthSignedMessageHash(_hash);
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        // EIP-155: v should be chaindId * 2 + {35, 36}
        if (v < 37) {
            v += 27;
        }

        require(v == 27 || v == 28, "MultiSig: invalid signature recovery");

        address signer = ecrecover(messagehash, v, r, s);
        require(signer != address(0), "MultiSig: invalid signature");

        return signer;
    }

    /**
     *
     * @dev _toEthSignedMessageHash : prepends the provided hash with the
     * Ethereum signed message prefix ("\x19Ethereum Signed Message:\n32")
     * and hashes the result
     */

    function _toEthSignedMessageHash(
        bytes32 _hash
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
            );
    }
}

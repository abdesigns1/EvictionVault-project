// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./VaultWithdraw.sol";
import "./VaultAdmin.sol";
import "./VaultMerkle.sol";

contract EvictionVault is VaultWithdraw, VaultAdmin, VaultMerkle {


    event Deposit(address indexed depositor, uint256 amount);

    constructor(address[] memory _owners, uint256 _threshold)
        Ownable(msg.sender)
    {
        require(_owners.length > 0, "No owners");
        require(_threshold > 0 && _threshold <= _owners.length, "Invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "Zero address");
            require(!isOwner[o], "Duplicate owner");
            isOwner[o] = true;
            owners.push(o);
        }
        threshold = _threshold;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
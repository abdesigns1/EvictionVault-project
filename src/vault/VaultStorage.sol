// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract VaultStorage {
    bool public paused;
    uint256 public totalVaultValue;
    mapping(address => uint256) public balances;
}
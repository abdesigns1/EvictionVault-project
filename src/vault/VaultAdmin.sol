// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./VaultStorage.sol";

abstract contract VaultAdmin is Ownable, VaultStorage {

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;
    uint256 public txCount;
    uint256 public constant TIMELOCK_DURATION = 1 hours;


function submitTransaction(address to, uint256 value, bytes calldata data) external {
    require(isOwner[msg.sender] || msg.sender == owner(), "Not authorized");
    uint256 id = txCount++;
    transactions[id] = Transaction(to, value, data, false, 1, block.timestamp, 0);
    confirmed[id][msg.sender] = true;
    emit Submission(id);
}

function confirmTransaction(uint256 txId) external {
    require(isOwner[msg.sender] || msg.sender == owner(), "Not authorized");
    Transaction storage txn = transactions[txId];
    require(!txn.executed, "Already executed");
    require(!confirmed[txId][msg.sender], "Already confirmed");
    confirmed[txId][msg.sender] = true;
    txn.confirmations++;
    if (txn.confirmations == threshold) {
        txn.executionTime = block.timestamp + TIMELOCK_DURATION;
    }
    emit Confirmation(txId, msg.sender);
}

    function executeTransaction(uint256 txId) external {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold, "Not enough confirmations");
        require(!txn.executed, "Already executed");
        require(block.timestamp >= txn.executionTime, "Timelock active");

        txn.executed = true;
        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Execution failed");
        emit Execution(txId);
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
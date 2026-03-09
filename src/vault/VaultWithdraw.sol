// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./VaultStorage.sol";

abstract contract VaultWithdraw is Ownable, VaultStorage {

    event Withdrawal(address indexed withdrawer, uint256 amount);

    function withdraw(uint256 amount) external {
        require(!paused, "paused");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        totalVaultValue -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw failed");
        emit Withdrawal(msg.sender, amount);
    }

    function emergencyWithdrawAll() external onlyOwner {
        uint256 vaultBalance = address(this).balance;
        totalVaultValue = 0;
        (bool success,) = payable(owner()).call{value: vaultBalance}("");
        require(success, "Emergency withdraw failed");
    }
}
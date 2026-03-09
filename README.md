# EvictionVault — Nebula Yield Hardening Challenge

### Phase 1 · Day 1 Milestone

---

## Overview

EvictionVault is a modular, multi-sig Ethereum vault contract refactored from a single-file monolith into a secure, layered architecture. This document details every vulnerability identified in the original codebase, the fix applied, and the current state of the contract after hardening.

---

## Project Structure

```
src/
└── vault/
    ├── VaultStorage.sol      # Shared state + onlyOwners modifier
    ├── VaultAdmin.sol        # Multi-sig transactions, timelock, pause/unpause
    ├── VaultWithdraw.sol     # Withdraw + emergencyWithdrawAll
    ├── VaultMerkle.sol       # Merkle root management + claim
    └── EvictionVault.sol     # Main contract — composes all modules

test/
└── EvictionVault.t.sol       # Foundry test suite (8 tests)
```

---

## Vulnerability Fixes

### 1. `setMerkleRoot` Callable by Anyone

**Severity:** Critical

**Original behaviour:**
`setMerkleRoot()` had no access control. Any external address could overwrite the Merkle root, invalidating all legitimate claims and injecting a malicious root to drain the vault.

**Fix:**
Restricted to vault owners via the `onlyOwners` modifier defined in `VaultStorage`.

---

### 2. `emergencyWithdrawAll` Public Drain

**Severity:** Critical

**Original behaviour:**
`emergencyWithdrawAll()` had no access control whatsoever. Any address could call it to drain the entire vault balance to themselves.

**Fix:**
Restricted to vault owners via `onlyOwners`. Withdrawal now goes to the calling owner, not an arbitrary address.

---

**Original behaviour:**
`pause()` and `unpause()` used `isOwner[msg.sender]` but the broader contract design relied on a single privileged owner. This created a centralisation risk — one compromised key could freeze or unfreeze the vault unilaterally.

**Fix:**
Access control is now enforced consistently through the shared `onlyOwners` modifier, which checks the `isOwner` mapping populated at construction. All vault owners listed at deploy time can pause and unpause — no single point of failure.

---

### 3. `receive()` Uses `tx.origin`

**Severity:** High

**Original behaviour:**
The `receive()` fallback credited deposits to `tx.origin` instead of `msg.sender`. This means if a contract forwarded ETH to the vault on behalf of a user, the original EOA (not the forwarding contract) would be credited — enabling phishing-style attacks where a malicious intermediate contract tricks a user into funding an attacker's vault balance.

```solidity
// VULNERABLE
receive() external payable {
    balances[tx.origin] += msg.value;
}
```

**Fix:**
Changed to `msg.sender` so the direct caller is always credited.

```solidity
// FIXED
receive() external payable {
    balances[msg.sender] += msg.value;
    totalVaultValue += msg.value;
    emit Deposit(msg.sender, msg.value);
}
```

---

### 4. `withdraw` and `claim` Use `.transfer`

**Severity:** High

**Original behaviour:**
Both `withdraw()` and `claim()` used `payable(addr).transfer(amount)`. The `.transfer()` method forwards only 2300 gas, which is insufficient for smart contract recipients (e.g. multisig wallets, proxy contracts) and will revert, permanently locking those users' funds.

```solidity
// VULNERABLE
payable(msg.sender).transfer(amount);
```

**Fix:**
Replaced with `.call{value: amount}("")` and an explicit success check, which forwards all available gas and works correctly with all receiver types.

```solidity
// FIXED
(bool success,) = payable(msg.sender).call{value: amount}("");
require(success, "Withdraw failed");
```

---

### 6. Timelock Execution

**Severity:** Medium

**Original behaviour:**
The timelock logic was present but incomplete — `executionTime` was only set when confirmations hit the threshold, but there was no guard against executing a transaction where `executionTime` was still `0` (i.e. threshold not yet reached but `block.timestamp >= 0` is always true).

**Fix:**
Added an explicit `executionTime != 0` check before evaluating the timestamp comparison.

```solidity
// FIXED
require(txn.executionTime != 0, "Timelock not started");
require(block.timestamp >= txn.executionTime, "Timelock active");
```

---

---

## Test Results

```
Ran 8 tests for test/EvictionVault.t.sol:EvictionVaultTest

apple@MacBookPro forge-std % forge test
[⠊] Compiling...
[⠘] Compiling 4 files with Solc 0.8.33
[⠃] Solc 0.8.33 finished in 698.89ms
Compiler run successful!

Ran 8 tests for test/EvictionVault.t.sol:EvictionVaultTest
[PASS] testClaimWithValidProof() (gas: 98227)
[PASS] testDeposit() (gas: 65053)
[PASS] testEmergencyWithdrawOnlyOwner() (gas: 23979)
[PASS] testMultiSigTransactionTimelock() (gas: 267967)
[PASS] testPausePreventsWithdraw() (gas: 17031)
[PASS] testReceiveUsesMsgSender() (gas: 64492)
[PASS] testSetMerkleRootOnlyOwner() (gas: 40195)
[PASS] testWithdrawUsesCall() (gas: 78427)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 6.07ms (16.16ms CPU time)

```

_Nebula Yield — Eviction Vault Hardening Challenge · Phase 1 · March 2026_

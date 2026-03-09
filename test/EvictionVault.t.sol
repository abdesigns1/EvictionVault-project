// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vault/EvictionVault.sol";

contract EvictionVaultTest is Test {
    EvictionVault vault;

    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    bytes32[] emptyProof;

    function setUp() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vault = new EvictionVault(owners, 2);
    }

   
    // Security Tests
   

    function testSetMerkleRootOnlyOwner() public {
       
        bytes32 root = bytes32(uint256(0x123));

        vm.prank(user1);
        vm.expectRevert();
        vault.setMerkleRoot(root);

    
        vault.setMerkleRoot(root);
        assertEq(vault.merkleRoot(), root);
    }

    function testEmergencyWithdrawOnlyOwner() public {
    vm.deal(address(vault), 1 ether);

    vm.prank(user1);
    vm.expectRevert();
    vault.emergencyWithdrawAll();

    
    vm.deal(address(this), 0); 
    vault.emergencyWithdrawAll();
    assertEq(address(vault).balance, 0);
}


receive() external payable {}
    function testReceiveUsesMsgSender() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool sent,) = address(vault).call{value: 1 ether}("");
        require(sent);

        assertEq(vault.balances(user1), 1 ether);
    }

    function testWithdrawUsesCall() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        vm.prank(user1);
        vault.withdraw(1 ether);

        assertEq(vault.balances(user1), 0);
        assertEq(address(vault).balance, 0);
    }

    function testPausePreventsWithdraw() public {
        // deployer is owner
        vault.pause();

        vm.prank(user1);
        vm.expectRevert("paused");
        vault.withdraw(1 ether);
    }

   

    function testDeposit() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balances(user1), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    function testClaimWithValidProof() public {
        
        bytes32 leaf = keccak256(abi.encodePacked(user1, uint256(1 ether)));
        bytes32 root = leaf;

        vault.setMerkleRoot(root);

        vm.deal(address(vault), 1 ether);
        vm.prank(user1);
        vault.claim(emptyProof, 1 ether);

        assertTrue(vault.claimed(user1));
    }

    function testMultiSigTransactionTimelock() public {
    vm.deal(address(vault), 1 ether);

    
    vault.submitTransaction(user1, 1 ether, "");

  
    vm.prank(owner2);
    vault.confirmTransaction(0);

   
    vm.expectRevert();
    vault.executeTransaction(0);

   
    vm.warp(block.timestamp + 1 hours + 1);
    vault.executeTransaction(0);

    (, , , bool executed, , ,) = vault.transactions(0);
    assertTrue(executed);
}
}
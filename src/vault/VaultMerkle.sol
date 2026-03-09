// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract VaultMerkle is Ownable {
    bytes32 public merkleRoot;
    mapping(address => bool) public claimed;

    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);
        require(computed == merkleRoot, "Invalid proof");
        require(!claimed[msg.sender], "Already claimed");
        claimed[msg.sender] = true;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Claim failed");

        emit Claim(msg.sender, amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal stand-in for the SPACE ID Agent ID contract, for local tests.
///         Real Agent ID is ERC-721 on BNB Chain; we only need balanceOf().
contract MockAgentID {
    mapping(address => uint256) public balanceOf;

    function mint(address to) external {
        balanceOf[to] = 1;
    }
}

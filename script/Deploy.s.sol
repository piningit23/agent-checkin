// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentCheckin} from "../src/AgentCheckin.sol";

/// @notice Deploy AgentCheckin. AGENT_ID env var overrides the default.
///         Default = SPACE ID Agent ID on BNB Chain mainnet.
///         Deploy ONLY after Bos gives explicit approval. Never with real funds
///         until then — test on anvil / BSC testnet first.
contract Deploy is Script {
    address public constant MAINNET_AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (AgentCheckin) {
        address agentId = vm.envOr("AGENT_ID", MAINNET_AGENT_ID);
        console.log("Agent ID contract:", agentId);

        vm.startBroadcast();
        AgentCheckin checkin = new AgentCheckin(agentId);
        vm.stopBroadcast();

        console.log("AgentCheckin deployed at:", address(checkin));
        return checkin;
    }
}

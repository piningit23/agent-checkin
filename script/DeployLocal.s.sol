// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentCheckin} from "../src/AgentCheckin.sol";
import {MockAgentID} from "../test/MockAgentID.sol";

/// @notice Local-only deploy + smoke check-in on anvil. Never used on mainnet.
contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();
        MockAgentID mock = new MockAgentID();
        AgentCheckin checkin = new AgentCheckin(address(mock));
        mock.mint(msg.sender);
        checkin.checkIn();
        vm.stopBroadcast();

        console.log("MockAgentID:", address(mock));
        console.log("AgentCheckin:", address(checkin));
        console.log("Badge of deployer:", checkin.badgeOf(msg.sender));
        console.log("Streak of deployer:", checkin.streak(msg.sender));
    }
}

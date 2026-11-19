// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentCheckin} from "../src/AgentCheckin.sol";
import {MockAgentID} from "./MockAgentID.sol";

contract AgentCheckinTest is Test {
    AgentCheckin public checkin;
    MockAgentID public agentID;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public stranger = address(0x5EED);

    event CheckedIn(address indexed user, uint256 indexed day, uint256 streak, uint256 totalCheckins);
    event BadgeMinted(address indexed user, uint256 indexed tokenId);

    function setUp() public {
        // Foundry's default block.timestamp is 1, which makes currentDay() == 0
        // and collides with the zero-initialized lastCheckinDay mapping.
        // Warp to a realistic timestamp (2026-11-19 00:00 UTC).
        vm.warp(1795094400);
        agentID = new MockAgentID();
        checkin = new AgentCheckin(address(agentID));
        agentID.mint(alice);
        agentID.mint(bob);
    }

    function testNonHolderCannotCheckIn() public {
        vm.prank(stranger);
        vm.expectRevert(AgentCheckin.NotAgentIDHolder.selector);
        checkin.checkIn();
    }

    function testFirstCheckInMintsBadgeAndStreakOne() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(checkin));
        emit BadgeMinted(alice, 1);
        checkin.checkIn();

        assertEq(checkin.badgeOf(alice), 1);
        assertEq(checkin.ownerOf(1), alice);
        assertEq(checkin.streak(alice), 1);
        assertEq(checkin.totalCheckinsByUser(alice), 1);
        assertEq(checkin.totalCheckins(), 1);
        assertEq(checkin.balanceOf(alice), 1);
    }

    function testSecondCheckInSameDayReverts() public {
        vm.prank(alice);
        checkin.checkIn();

        vm.prank(alice);
        vm.expectRevert(AgentCheckin.AlreadyCheckedInToday.selector);
        checkin.checkIn();
    }

    function testNextDayCheckInGrowsStreak() public {
        vm.prank(alice);
        checkin.checkIn();

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        checkin.checkIn();

        assertEq(checkin.streak(alice), 2);
        assertEq(checkin.totalCheckinsByUser(alice), 2);
        // Still exactly one badge per user.
        assertEq(checkin.badgeOf(alice), 1);
        assertEq(checkin.balanceOf(alice), 1);
    }

    function testMissedDayResetsStreak() public {
        vm.prank(alice);
        checkin.checkIn();
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        checkin.checkIn();
        assertEq(checkin.streak(alice), 2);

        // Skip a full day, then check in: streak restarts at 1.
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        checkin.checkIn();
        assertEq(checkin.streak(alice), 1);
        assertEq(checkin.totalCheckinsByUser(alice), 3);
    }

    function testBadgeIsSoulbound() public {
        vm.prank(alice);
        checkin.checkIn();

        vm.prank(alice);
        vm.expectRevert("AgentCheckin: badge is soulbound, non-transferable");
        checkin.transferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert("AgentCheckin: badge is soulbound, non-transferable");
        checkin.safeTransferFrom(alice, bob, 1);
    }

    function testTwoUsersGetDifferentBadges() public {
        vm.prank(alice);
        checkin.checkIn();
        vm.prank(bob);
        checkin.checkIn();

        assertEq(checkin.badgeOf(alice), 1);
        assertEq(checkin.badgeOf(bob), 2);
        assertEq(checkin.nextTokenId(), 3);
        assertEq(checkin.totalCheckins(), 2);
    }

    function testCanCheckInTodayView() public {
        assertTrue(checkin.canCheckInToday(alice));
        vm.prank(alice);
        checkin.checkIn();
        assertFalse(checkin.canCheckInToday(alice));
        vm.warp(block.timestamp + 1 days);
        assertTrue(checkin.canCheckInToday(alice));
    }

    function testTokenURIReturnsDataURI() public {
        vm.prank(alice);
        checkin.checkIn();
        string memory uri = checkin.tokenURI(1);
        assertTrue(bytes(uri).length > 100);
        // Must start with data:application/json;base64,
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(bytes(uri)[i], prefix[i]);
        }
    }

    function testCheckedInEvent() public {
        uint256 day = vm.getBlockTimestamp() / 1 days;
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(checkin));
        emit CheckedIn(alice, day, 1, 1);
        checkin.checkIn();
    }
}

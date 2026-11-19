// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Minimal read-only interface of the SPACE ID Agent ID contract.
/// @dev Agent ID is an ERC-721 (name.ai) on BNB Chain. We only ever read
///      balanceOf() — the contract never moves, approves, or escrows any asset.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title Agent Check-in — daily check-in dApp for Binance Agent ID holders
/// @notice Agent ID holders (name.ai) check in once per day. The first
///         check-in mints a soulbound (non-transferable) badge NFT. Consecutive
///         daily check-ins grow the streak; a missed day resets it to 1.
///         Use case: access control, exactly as listed in the Binance Agent ID
///         Hackathon announcement (60,000 USDC, submission until 2026-12-09).
/// @dev No payments, no token approvals, no admin functions, no owner.
///      The Agent ID contract address is immutable and set at deploy time.
contract AgentCheckin is ERC721 {
    using Strings for uint256;

    /// @notice SPACE ID Agent ID contract on BNB Chain mainnet:
    ///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
    IAgentID public immutable agentID;

    uint256 public nextTokenId = 1;
    uint256 public totalCheckins;

    /// @notice Current consecutive-day streak per user.
    mapping(address => uint256) public streak;
    /// @notice Day number (block.timestamp / 1 days) of the last check-in.
    mapping(address => uint256) public lastCheckinDay;
    mapping(address => uint256) public totalCheckinsByUser;
    /// @notice Badge token id per user (0 = no badge minted yet).
    mapping(address => uint256) public badgeOf;

    event CheckedIn(address indexed user, uint256 indexed day, uint256 streak, uint256 totalCheckins);
    event BadgeMinted(address indexed user, uint256 indexed tokenId);

    error NotAgentIDHolder();
    error AlreadyCheckedInToday();

    constructor(address _agentID) ERC721("Agent Check-in Badge", "ACB") {
        require(_agentID != address(0), "AgentCheckin: zero Agent ID address");
        agentID = IAgentID(_agentID);
    }

    /// @notice Day number used for the once-per-day rule (UTC days).
    function currentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function canCheckInToday(address user) public view returns (bool) {
        return lastCheckinDay[user] != currentDay();
    }

    /// @notice Check in for today. Requires holding at least one Agent ID.
    ///         First call mints the soulbound badge; later calls only update
    ///         the streak. Reverts if already checked in today.
    function checkIn() external {
        if (agentID.balanceOf(msg.sender) == 0) revert NotAgentIDHolder();

        uint256 day = currentDay();
        if (lastCheckinDay[msg.sender] == day) revert AlreadyCheckedInToday();

        if (lastCheckinDay[msg.sender] != 0 && lastCheckinDay[msg.sender] == day - 1) {
            streak[msg.sender] += 1;
        } else {
            streak[msg.sender] = 1;
        }
        lastCheckinDay[msg.sender] = day;
        totalCheckinsByUser[msg.sender] += 1;
        totalCheckins += 1;

        if (badgeOf[msg.sender] == 0) {
            uint256 tokenId = nextTokenId++;
            badgeOf[msg.sender] = tokenId;
            _safeMint(msg.sender, tokenId);
            emit BadgeMinted(msg.sender, tokenId);
        }

        emit CheckedIn(msg.sender, day, streak[msg.sender], totalCheckinsByUser[msg.sender]);
    }

    /// @notice Soulbound: minting (from == address(0)) is the only allowed
    ///         movement. Every transfer / burn reverts.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (from != address(0)) {
            revert("AgentCheckin: badge is soulbound, non-transferable");
        }
        return super._update(to, tokenId, auth);
    }

    /// @notice On-chain metadata: name, description, live streak attribute
    ///         and a minimal SVG image, so wallets show the badge properly.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "AgentCheckin: nonexistent token");
        address owner = ownerOf(tokenId);

        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                '<rect width="400" height="400" fill="#0B0E14"/>',
                '<rect x="30" y="30" width="340" height="340" fill="none" stroke="#F0B90B" stroke-width="6" rx="24"/>',
                '<text x="200" y="180" font-family="monospace" font-size="34" fill="#F0B90B" text-anchor="middle">AGENT CHECK-IN</text>',
                '<text x="200" y="250" font-family="monospace" font-size="64" fill="#FFFFFF" text-anchor="middle">',
                streak[owner].toString(),
                '</text>',
                '<text x="200" y="290" font-family="monospace" font-size="22" fill="#AAAAAA" text-anchor="middle">day streak</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Agent Check-in Badge #',
                tokenId.toString(),
                '","description":"Soulbound badge for daily check-ins by a Binance Agent ID (name.ai) holder.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '","attributes":[{"trait_type":"Streak","value":',
                streak[owner].toString(),
                '},{"trait_type":"Total Check-ins","value":',
                totalCheckinsByUser[owner].toString(),
                "}]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
}

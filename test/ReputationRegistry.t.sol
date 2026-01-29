// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {Errors} from "../src/libraries/Errors.sol";

contract ReputationRegistryTest is Test {
    ReputationRegistry reputation;
    IdentityRegistry identity;

    address owner;
    address alice;
    address bob;

    uint256 agentId1;
    uint256 agentId2;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy contracts
        identity = new IdentityRegistry("TestRegistry", "TR");
        reputation = new ReputationRegistry();
        reputation.initialize(address(identity));

        // Register agents
        agentId1 = identity.register("ipfs://agent1");
        agentId2 = identity.register("ipfs://agent2");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // Test: Give feedback
    function test_GiveFeedback() public {
        vm.startPrank(alice);

        vm.expectEmit(true, true, false, false);
        emit ReputationRegistry.GiveFeedback(agentId1, alice, 0, "", "", bytes32(0));

        reputation.giveFeedback(
            agentId1,
            int128(5),
            uint8(0),
            "quality",
            "speed",
            "https://endpoint.com",
            "ipfs://feedback",
            keccak256("feedback")
        );

        // Verify feedback stored
        (address client, int128 value, uint8 decimals, string memory tag1, string memory tag2, bool revoked) =
            reputation.readFeedback(agentId1, 0);

        assertEq(client, alice);
        assertEq(value, 5);
        assertEq(decimals, 0);
        assertEq(tag1, "quality");
        assertEq(tag2, "speed");
        assertFalse(revoked);

        vm.stopPrank();
    }

    // Test: Multiple feedbacks increment index correctly
    function test_MultipleFeedbacks() public {
        vm.startPrank(alice);

        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));
        reputation.giveFeedback(agentId1, int128(3), 0, "tag3", "tag4", "", "", bytes32(0));

        vm.stopPrank();

        vm.prank(bob);
        reputation.giveFeedback(agentId1, int128(4), 0, "tag5", "tag6", "", "", bytes32(0));

        // Verify feedback count
        assertEq(reputation.getFeedbackCount(agentId1), 3);

        // Verify client feedback count
        assertEq(reputation.getClientFeedbackCount(alice, agentId1), 2);
        assertEq(reputation.getClientFeedbackCount(bob, agentId1), 1);
    }

    // Test: Revoke feedback
    function test_RevokeFeedback() public {
        vm.startPrank(alice);

        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));

        vm.expectEmit(true, true, false, false);
        emit ReputationRegistry.FeedbackRevoked(agentId1, alice, 0);

        reputation.revokeFeedback(agentId1, 0);

        (, , , , , bool revoked) = reputation.readFeedback(agentId1, 0);
        assertTrue(revoked);

        vm.stopPrank();
    }

    // Test: Cannot revoke someone else's feedback
    function test_RevertWhen_RevokingOthersFeedback() public {
        vm.prank(alice);
        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));

        vm.prank(bob);
        vm.expectRevert(Errors.InvalidInput.selector);
        reputation.revokeFeedback(agentId1, 0);
    }

    // Test: Agent owner cannot give feedback to themselves
    function test_RevertWhen_OwnerGivesFeedback() public {
        vm.expectRevert(Errors.InvalidInput.selector);
        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));
    }

    // Test: Append response (agent owner only)
    function test_AppendResponse() public {
        vm.prank(alice);
        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));

        vm.expectEmit(true, false, true, false);
        emit ReputationRegistry.ResponseAppended(agentId1, 0, alice);

        reputation.appendResponse(agentId1, 0, "ipfs://response", keccak256("response"));

        (address client, , string memory responseURI, bytes32 responseHash) = reputation.readResponse(agentId1, 0);

        assertEq(client, alice);
        assertEq(responseURI, "ipfs://response");
        assertEq(responseHash, keccak256("response"));
    }

    // Test: Non-owner cannot append response
    function test_RevertWhen_NonOwnerAppendsResponse() public {
        vm.prank(alice);
        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));

        vm.prank(bob);
        vm.expectRevert(Errors.InvalidInput.selector);
        reputation.appendResponse(agentId1, 0, "ipfs://response", keccak256("response"));
    }

    // Test: Get client feedback indices
    function test_GetClientFeedbackIndices() public {
        vm.startPrank(alice);

        reputation.giveFeedback(agentId1, int128(5), 0, "tag1", "tag2", "", "", bytes32(0));
        reputation.giveFeedback(agentId1, int128(3), 0, "tag3", "tag4", "", "", bytes32(0));

        vm.stopPrank();

        uint256[] memory indices = reputation.getClientFeedbackIndices(alice, agentId1);

        assertEq(indices.length, 2);
        assertEq(indices[0], 0);
        assertEq(indices[1], 1);
    }

    // Test: EIP-8004 compliance - only core fields stored, URI/hash emitted
    function test_EIP8004_Compliance() public {
        vm.prank(alice);

        // Events should include endpoint, feedbackURI, feedbackHash
        vm.expectEmit(true, true, false, true);
        emit ReputationRegistry.GiveFeedback(
            agentId1, alice, 0, "https://endpoint.com", "ipfs://feedback", keccak256("feedback")
        );

        reputation.giveFeedback(
            agentId1,
            int128(5),
            0,
            "quality",
            "speed",
            "https://endpoint.com",
            "ipfs://feedback",
            keccak256("feedback")
        );

        // Verify only core fields stored (not URI/hash)
        (address client, int128 value, uint8 decimals, string memory tag1, string memory tag2, bool revoked) =
            reputation.readFeedback(agentId1, 0);

        assertEq(client, alice);
        assertEq(value, 5);
        assertEq(decimals, 0);
        assertEq(tag1, "quality");
        assertEq(tag2, "speed");
        assertFalse(revoked);
        // URI/hash not in storage, only in events
    }

    // Test: Prevent double initialization
    function test_RevertWhen_DoubleInitialize() public {
        vm.expectRevert(ReputationRegistry.AlreadyInitialized.selector);
        reputation.initialize(address(identity));
    }

    // Test: Value decimals validation
    function test_RevertWhen_InvalidDecimals() public {
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidInput.selector);
        reputation.giveFeedback(agentId1, int128(5), 19, "tag1", "tag2", "", "", bytes32(0)); // > 18
    }
}

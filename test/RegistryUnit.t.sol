// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";

contract RegistryUnit is Test {
    IdentityRegistry registry;
    address alice;
    uint256 pK;

    function setUp() public {
        registry = new IdentityRegistry("TestRegistry", "TR");
        (alice, pK) = makeAddrAndKey("2131");
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function test_tokenIdInc() public {
        uint256 before_agentId = registry.getAgentId(); // 0

        registry.register("0x1231");
        uint256 after_agentId = registry.getAgentId(); // 1

        uint256 before_agentId_2 = registry.getAgentId(); // 1

        registry.register("0x1221");
        uint256 after_agentId_2 = registry.getAgentId(); // 2
    }

    // setAgentWallet

    function test_setAgentWallet() public {
        registry.register("0x1231");
        // need to sign with prefix
        bytes32 messageHash;
        uint256 agentId = 1;
        address newWallet = alice;
        uint256 deadline = block.timestamp + 10000;

        assembly {
            // = keccak256(abi.encode(agentId, newWallet, deadline));
            let ptr := mload(0x40)
            mstore(ptr, agentId)
            mstore(add(ptr, 0x20), newWallet)
            mstore(add(ptr, 0x40), deadline)
            messageHash := keccak256(ptr, 0x60)
        }

        (, uint256 key) = makeAddrAndKey("bro");

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(IdentityRegistry.InvalidSignature.selector);
        registry.setAgentWallet(agentId, newWallet, signature);
    }
}

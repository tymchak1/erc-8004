// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {Structs} from "./libraries/Structs.sol";
import {Errors} from "./libraries/Errors.sol";

contract ReputationRegistry is IReputationRegistry, Ownable {
    mapping(uint256 agentId => mapping(address client => mapping(uint256 feedbackIndex => Structs.Feedback))) private
        feedbacks;

    IIdentityRegistry private s_identityRegistry;

    constructor() Ownable(msg.sender) {}

    function initialize(address identityRegistry) external onlyOwner {
        s_identityRegistry = IIdentityRegistry(identityRegistry);
    }

    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        if (valueDecimals > 18) revert Errors.InvalidInput();
        if (agentId == 0 || s_identityRegistry.getAgentId() < agentId) {
            revert Errors.InvalidInput();
        }
        if (_isAgentOwner(agentId, msg.sender)) revert Errors.InvalidInput();

        _storeFeedback(value, valueDecimals, tag1, tag2, false);
    }

    function _isAgentOwner(uint256 agentId, address sender) internal view returns (bool) {
        address owner = IERC721(address(s_identityRegistry)).ownerOf(agentId);
        if (sender == owner) {
            revert Errors.InvalidInput();
        }
    }

    function _storeFeedback(
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        bool isRevoked
    ) internal {
        // update mapping with newly created struct
    }
}

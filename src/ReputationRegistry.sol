// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {Structs} from "./libraries/Structs.sol";
import {Errors} from "./libraries/Errors.sol";

contract ReputationRegistry is IReputationRegistry, Ownable {
    error NotInitialized();
    error AlreadyInitialized();
    error FeedbackDoesNotExist();
    error ResponseDoesNotExist();

    mapping(uint256 agentId => mapping(uint256 feedbackIndex => Structs.Feedback)) private s_feedbacks;
    mapping(uint256 agentId => mapping(uint256 feedbackIndex => Structs.Response)) private s_responses;
    mapping(uint256 agentId => uint256 feedbackCount) private s_feedbackCount;
    mapping(address client => mapping(uint256 agentId => uint256 clientFeedbackCount)) private s_clientFeedbackCount;
    mapping(address client => mapping(uint256 agentId => mapping(uint256 localIndex => uint256 globalFeedbackIndex))) private s_clientFeedbackIndices;

    IIdentityRegistry private s_identityRegistry;

    event GiveFeedback(
        uint256 indexed agentId,
        address indexed client,
        uint256 feedbackIndex,
        string endpoint,
        string feedbackURI,
        bytes32 feedbackHash
    );
    event FeedbackRevoked(uint256 indexed agentId, address indexed client, uint256 feedbackIndex);
    event ResponseAppended(uint256 indexed agentId, uint256 feedbackIndex, address indexed client);

    constructor() Ownable(msg.sender) {}

    modifier isInitialized() {
        if (address(s_identityRegistry) == address(0)) revert NotInitialized();
        _;
    }

    function initialize(address identityRegistry) external onlyOwner {
        if (address(s_identityRegistry) != address(0)) revert AlreadyInitialized();
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
    ) external isInitialized {
        if (valueDecimals > 18) revert Errors.InvalidInput();
        if (agentId == 0 || s_identityRegistry.getAgentId() < agentId) {
            revert Errors.InvalidInput();
        }
        if (_isAgentOwner(agentId, msg.sender)) revert Errors.InvalidInput();

        uint256 feedbackIndex = _storeFeedback(agentId, value, valueDecimals, tag1, tag2, false);
        emit GiveFeedback(agentId, msg.sender, feedbackIndex, endpoint, feedbackURI, feedbackHash);
    }

    function revokeFeedback(uint256 agentId, uint256 feedbackIndex) external isInitialized {
        if (agentId == 0 || s_identityRegistry.getAgentId() < agentId) {
            revert Errors.InvalidInput();
        }

        Structs.Feedback storage feedback = s_feedbacks[agentId][feedbackIndex];

        if (feedback.clientAddress != msg.sender) {
            revert Errors.InvalidInput();
        }
        if (feedback.isRevoked) {
            revert FeedbackDoesNotExist();
        }

        feedback.isRevoked = true;
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }

    function appendResponse(
        uint256 agentId,
        uint256 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external {
        if (agentId == 0 || s_identityRegistry.getAgentId() < agentId) {
            revert Errors.InvalidInput();
        }
        if (feedbackIndex >= s_feedbackCount[agentId]) {
            revert FeedbackDoesNotExist();
        }
        if (!_isAgentOwner(agentId, msg.sender)) {
            revert Errors.InvalidInput();
        }

        Structs.Feedback memory feedback = s_feedbacks[agentId][feedbackIndex];

        s_responses[agentId][feedbackIndex] = Structs.Response({
            agentId: agentId,
            clientAddress: feedback.clientAddress,
            feedbackIndex: uint64(feedbackIndex),
            responseURI: responseURI,
            responseHash: responseHash
        });

        emit ResponseAppended(agentId, feedbackIndex, feedback.clientAddress);
    }

    function _isAgentOwner(uint256 agentId, address sender) internal view returns (bool) {
        address owner = IERC721(address(s_identityRegistry)).ownerOf(agentId);
        return sender == owner;
    }

    function _storeFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        bool isRevoked
    ) internal returns (uint256 feedbackIndex) {
        feedbackIndex = s_feedbackCount[agentId]++;

        s_feedbacks[agentId][feedbackIndex] = Structs.Feedback({
            agentId: agentId,
            clientAddress: msg.sender,
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            isRevoked: isRevoked
        });

        uint256 localIndex = s_clientFeedbackCount[msg.sender][agentId]++;
        s_clientFeedbackIndices[msg.sender][agentId][localIndex] = feedbackIndex;
    }

    function readFeedback(uint256 agentId, uint256 feedbackIndex)
        external
        view
        returns (
            address clientAddress,
            int128 value,
            uint8 valueDecimals,
            string memory tag1,
            string memory tag2,
            bool isRevoked
        )
    {
        if (agentId == 0) revert Errors.InvalidInput();
        if (feedbackIndex >= s_feedbackCount[agentId]) revert FeedbackDoesNotExist();

        Structs.Feedback memory f = s_feedbacks[agentId][feedbackIndex];
        if (f.clientAddress == address(0)) revert FeedbackDoesNotExist();

        clientAddress = f.clientAddress;
        value = f.value;
        valueDecimals = f.valueDecimals;
        tag1 = f.tag1;
        tag2 = f.tag2;
        isRevoked = f.isRevoked;
    }

    function getClientFeedbackIndices(address client, uint256 agentId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = s_clientFeedbackCount[client][agentId];
        uint256[] memory indices = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            indices[i] = s_clientFeedbackIndices[client][agentId][i];
        }

        return indices;
    }

    function getClientFeedbackCount(address client, uint256 agentId) external view returns (uint256) {
        return s_clientFeedbackCount[client][agentId];
    }

    function getFeedbackCount(uint256 agentId) external view returns (uint256) {
        return s_feedbackCount[agentId];
    }

    function readResponse(uint256 agentId, uint256 feedbackIndex)
        external
        view
        returns (
            address clientAddress,
            uint64 storedFeedbackIndex,
            string memory responseURI,
            bytes32 responseHash
        )
    {
        Structs.Response memory r = s_responses[agentId][feedbackIndex];
        if (r.clientAddress == address(0)) revert ResponseDoesNotExist();

        clientAddress = r.clientAddress;
        storedFeedbackIndex = r.feedbackIndex;
        responseURI = r.responseURI;
        responseHash = r.responseHash;
    }

    function getIdentityRegistry() external view returns (address) {
        return address(s_identityRegistry);
    }
    
}

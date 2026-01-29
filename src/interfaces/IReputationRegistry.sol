// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IReputationRegistry {
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external;

    function revokeFeedback(uint256 agentId, uint256 feedbackIndex) external;

    function appendResponse(
        uint256 agentId,
        uint256 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external;

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
        );

    function getClientFeedbackIndices(address client, uint256 agentId)
        external
        view
        returns (uint256[] memory);

    function getClientFeedbackCount(address client, uint256 agentId) external view returns (uint256);

    function getFeedbackCount(uint256 agentId) external view returns (uint256);

    function readResponse(uint256 agentId, uint256 feedbackIndex)
        external
        view
        returns (
            address clientAddress,
            uint64 storedFeedbackIndex,
            string memory responseURI,
            bytes32 responseHash
        );

    function getIdentityRegistry() external view returns (address);
}


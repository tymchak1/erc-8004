// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IIdentityRegistry {
    function register(string calldata agentURI) external returns (uint256 agentId);
    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external;
    function setAgentWallet(uint256 agentId, address newWallet, bytes calldata signature) external;

    function getMetadata(uint256 agentId, string memory metadataKey) external view returns (bytes memory);
    function getAgentId() external view returns (uint256);
}

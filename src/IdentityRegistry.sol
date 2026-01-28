// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {Errors} from "./libraries/Errors.sol";

contract IdentityRegistry is IIdentityRegistry, ERC721URIStorage, Ownable {
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    uint256 private s_agentId = 0;
    address private s_agentWallet;

    event Registered(uint256 indexed agentId, string tokenURI_, address indexed registrant);
    event MetadataSet(uint256 indexed agentId, string metadataKey, bytes metadataValue);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

    function register(string calldata tokenURI) external onlyOwner returns (uint256 agentId) {
        // metadata not empty
        if (bytes(tokenURI).length <= 0) revert Errors.InvalidInput();

        agentId = s_agentId++; // 0

        _safeMint(owner(), agentId); // 1
        _setTokenURI(agentId, tokenURI);
        emit Registered(agentId, tokenURI, msg.sender);
    }

    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external onlyOwner {
        if (agentId == 0 || bytes(metadataKey).length <= 0 || bytes(metadataValue).length <= 0) {
            revert Errors.InvalidInput();
        }
        _metadata[agentId][metadataKey] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataValue);
    }

    function setAgentWallet(uint256 agentId, address newWallet, bytes calldata signature) external onlyOwner {
        if (agentId == 0 || newWallet == address(0)) revert Errors.InvalidInput();

        bytes32 messageHash = getMessageHash(agentId, newWallet);
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        if (signer != owner()) revert Errors.InvalidSignature();

        s_agentWallet = newWallet;
    }

    function getMessageHash(uint256 agentId, address newWallet) internal pure returns (bytes32 messageHash) {
        assembly {
            // = keccak256(abi.encode(agentId, newWallet, deadline));
            let ptr := mload(0x40)
            mstore(ptr, agentId)
            mstore(add(ptr, 0x20), newWallet)
            messageHash := keccak256(ptr, 0x40)
        }
    }

    function getMetadata(uint256 agentId, string memory metadataKey) external view returns (bytes memory) {
        if (agentId == 0 || agentId > s_agentId) revert Errors.InvalidInput();
        return _metadata[agentId][metadataKey];
    }

    function getAgentId() external view returns (uint256) {
        return s_agentId;
    }
}

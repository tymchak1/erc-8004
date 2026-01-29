// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Structs {
    struct Feedback {
        uint256 agentId;
        address clientAddress;
        int128 value;
        uint8 valueDecimals;
        string tag1;
        string tag2;
        bool isRevoked;
    }

    struct Response {
        uint256 agentId;
        address clientAddress;
        uint64 feedbackIndex;
        string responseURI;
        bytes32 responseHash;
    }
}

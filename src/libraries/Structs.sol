// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Structs {
    struct Feedback {
        int128 value;
        uint8 valueDecimals;
        string tag1;
        string tag2;
        bool isRevoked;
    }
}

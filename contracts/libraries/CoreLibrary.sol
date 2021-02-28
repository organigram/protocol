// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;

library CoreLibrary {
    struct Metadata {
        bytes32 ipfsHash;
        uint8 hashFunction;
        uint8 hashSize;
    }
    struct Entry {
        address addr;   // Address of account or contract.
        Metadata doc;   // Doc stored on IPFS.
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library CoreLibrary {
    struct Entry {
        address addr; // Address of account or contract.
        string cid; // Metadata stored on IPFS.
    }
}

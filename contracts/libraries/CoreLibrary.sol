// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;

library CoreLibrary {
    struct Entry {
        address addr;   // Address of account or contract.
        string cid;   // Metadata stored on IPFS.
    }
}
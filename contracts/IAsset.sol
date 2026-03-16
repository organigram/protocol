// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma experimental ABIEncoderV2;

interface IAsset {
    function initialize(
        string memory,
        string memory,
        address,
        uint256
    ) external;
}

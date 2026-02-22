// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

interface IAsset {
    function initialize(
        string memory,
        string memory,
        address,
        uint256
    ) external;
}

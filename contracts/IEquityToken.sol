// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface used by procedures that settle equity transfers.
interface IEquityToken {
    function settleTransfer(
        address recipient,
        uint256 amount,
        string calldata movementCid
    ) external;

    function validateTransfer(
        address seller,
        address recipient,
        uint256 amount,
        string calldata movementCid
    ) external view;

    function isTransferProcedure(address procedure) external view returns (bool);
}

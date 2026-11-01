// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Optional hook for operation targets that bind a proposal to its creator.
interface IProposalOperationValidator {
    function isOwnerBoundProposalOperation(bytes calldata operationData) external view returns (bool);

    function validateProposalCreator(address creator, bytes calldata operationData) external view;
}

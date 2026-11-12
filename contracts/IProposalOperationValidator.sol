// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Optional hook for operation targets that bind a proposal to its creator.
interface IProposalOperationValidator {
    /// @notice Tell whether an operation may only be proposed by the account it concerns.
    function isOwnerBoundProposalOperation(bytes calldata operationData) external view returns (bool);

    /// @notice Revert unless the creator of a proposal may propose this operation.
    function validateProposalCreator(address creator, bytes calldata operationData) external view;
}

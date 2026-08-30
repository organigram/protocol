// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Read-only execution context exposed by a procedure while it applies a proposal.
interface IProcedureExecutionContext {
    function getExecutionContext()
        external
        view
        returns (bool isApplying, uint256 proposalKey, address proposalCreator);

    /// @notice Whether the procedure is in the atomic equity-transfer settlement path.
    function isSettlingEquityTransfer() external view returns (bool);
}

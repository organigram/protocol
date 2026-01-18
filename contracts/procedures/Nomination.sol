// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;
import "../Procedure.sol";

/// @title Nomination Procedure
/// @notice A nomination executes an operation if the nominator is in the nominaters organ.
contract NominationProcedure is Procedure {
    /// @notice function signature for nominate().
    bytes4 private constant _INTERFACE_NOMINATION = 0xc5f28e49;

    /// @notice Register EIP165 interfaces for introspection.
    /// @param interfaceId The interface identifier.
    /// @return isSupported True if the interface is supported, false otherwise.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == _INTERFACE_NOMINATION || super.supportsInterface(interfaceId);
    }

    /// @notice Apply the nomination.
    /// @param proposalKey The key used to identify the proposal.
    function nominate(uint256 proposalKey)
        public onlyInOrgan(procedureData.deciders)
    {
        super.adoptProposal(proposalKey);
    }
}
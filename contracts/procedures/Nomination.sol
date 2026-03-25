// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import '../Procedure.sol';

/// @title Nomination Procedure
/// @notice A nomination executes an operation if the nominator is in the nominaters organ.
contract NominationProcedure is Procedure {
    /// @notice function signature for nominate().
    bytes4 private constant _INTERFACE_NOMINATION = 0xc5f28e49;
    bytes32 private constant NOMINATION_TYPEHASH =
        keccak256(
            'Nomination(uint256 proposalKey,uint256 nonce,uint256 deadline)'
        );

    /// @notice Register EIP165 interfaces for introspection.
    /// @param interfaceId The interface identifier.
    /// @return isSupported True if the interface is supported, false otherwise.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == _INTERFACE_NOMINATION ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Apply the nomination.
    /// @param proposalKey The key used to identify the proposal.
    function nominate(
        uint256 proposalKey
    ) public onlyInOrgan(procedureData.deciders) {
        super._adoptProposal(proposalKey);
    }

    function nominateBySig(
        uint256 proposalKey,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public {
        address signer = _recoverTypedSigner(
            keccak256(
                abi.encode(NOMINATION_TYPEHASH, proposalKey, nonce, deadline)
            ),
            nonce,
            deadline,
            signature
        );
        require(
            ProcedureLibrary.isInOrgan(procedureData.deciders, signer),
            'Not authorized'
        );
        super._adoptProposal(proposalKey);
    }
}

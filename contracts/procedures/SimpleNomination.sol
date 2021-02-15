// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

/**
    Nomination procedure.
    A nomination applies an effect if nominator is in the nominaters organ.
*/

import "../libraries/MetadataLibrary.sol";
import "../Procedure.sol";

contract SimpleNominationProcedure is Procedure {
    using MetadataLibrary for MetadataLibrary.Metadata;
    bytes4 private constant _INTERFACE_NOMINATION = 0xc5f28e49; // nominate().

    constructor ()
        public
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_NOMINATION);
    }

    function initialize(
        MetadataLibrary.Metadata memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration
    )
        public
        override
    {
        super.initialize(_metadata, _proposers, _moderators, _deciders, _withModeration);
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_NOMINATION);
    }

    function nominate(uint256 proposalKey)
        public onlyDeciders
    {
        super.applyProposal(proposalKey);
    }
}
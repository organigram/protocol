// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

/**
    Nomination procedure.
    A nomination applies an effect if nominator is in the nominaters organ.
*/

import "../libraries/CoreLibrary.sol";
import "../Procedure.sol";

contract NominationProcedure is Procedure {
    using CoreLibrary for CoreLibrary.Metadata;
    bytes4 private constant _INTERFACE_NOMINATION = 0xc5f28e49; // nominate().

    constructor ()
        public
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_NOMINATION);
    }

    function initialize(
        CoreLibrary.Metadata memory _metadata,
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
        public onlyInOrgan(procedureData.deciders)
    {
        super.adoptProposal(proposalKey);
    }
}
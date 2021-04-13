// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;
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

    // Register EIP165 interfaces for introspection.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == _INTERFACE_NOMINATION || super.supportsInterface(interfaceId);
    }

    function nominate(uint256 proposalKey)
        public onlyInOrgan(procedureData.deciders)
    {
        super.adoptProposal(proposalKey);
    }
}
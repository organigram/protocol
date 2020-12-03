// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

/**
    Nomination procedure.
    A nomination applies an effect if nominator is in the nominaters organ.
*/

import "../Procedure.sol";

contract SimpleNominationProcedure is Procedure {
    address payable public nominatersOrgan;
    bytes4 private constant _INTERFACE_NOMINATION = 0xc5f28e49; // nominate().

    constructor (
        bytes32 _metadataIpfsHash, uint8 _metadataHashFunction, uint8 _metadataHashSize,
        address payable _nominatersOrgan
    ) Procedure (_metadataIpfsHash, _metadataHashFunction, _metadataHashSize)
        public
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_NOMINATION);
        nominatersOrgan = _nominatersOrgan;
    }

    function nominate(uint256 moveKey)
        public onlyInOrgan(nominatersOrgan)
    {
        Procedure.applyMove(moveKey);
    }
}
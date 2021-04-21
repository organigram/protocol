// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Organ.sol";
import "./libraries/CoreLibrary.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract Organigram {
    using CoreLibrary for CoreLibrary.Entry;
    using CoreLibrary for CoreLibrary.Metadata;
    address payable public organ;
    address payable public procedures; // Organ with procedures addresses.

    event organCreated(address payable organ);
    event procedureCreated(address payable procedureType, address payable procedure);

    constructor(CoreLibrary.Metadata memory metadata)
    {
        organ = payable(address(new Organ()));
        procedures = createOrgan(payable(msg.sender), metadata);
    }

    function createOrgan(
        address payable admin,
        CoreLibrary.Metadata memory metadata
    )
        public
        returns (address payable clone)
    {
        // Clone organ and initialize it.
        clone = payable(Clones.clone(organ));
        Organ(clone).initialize(admin, metadata);
        emit organCreated(clone);
        return clone;
    }

    // @todo : Implement Diamond in Organigram.sol ? https://eips.ethereum.org/EIPS/eip-2535
    function createProcedure(address payable procedureId)
        public
        returns (address payable procedure)
    {
        // Check if procedure.
        require(ERC165Checker.supportsInterface(procedureId, 0x71dbd330), "Not a procedure.");
        // Check if procedure is in registry.
        require(Organ(procedures).getEntryIndexForAddress(procedureId) > 0, "Procedure not found.");
        procedure = payable(Clones.clone(procedureId));
        emit procedureCreated(procedureId, procedure);
        // NB: The initialize method will need to be called directly.
        return procedure;
    }

    function registerProcedures(CoreLibrary.Entry[] memory entries)
        external
    {
        // Only valid procedures
        for (uint256 i; i < entries.length; ++i) {
            require(
                ERC165Checker.supportsInterface(entries[i].addr, 0x71dbd330),
                "An entry in parameters is not a valid procedure."
            );
        }
        Organ(organ).addEntries(entries);
    }
}
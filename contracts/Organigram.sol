// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "./Organ.sol";
import "./libraries/CoreLibrary.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@opengsn/contracts/src/ERC2771Recipient.sol";

contract Organigram is ERC2771Recipient {
    using CoreLibrary for CoreLibrary.Entry;
    address payable public organ;
    address payable public procedures; // Organ with procedures addresses.

    event organCreated(address payable organ);
    event procedureCreated(address payable procedureType, address payable procedure);

    constructor(string memory cid, address trustedForwarder)
    {
        _setTrustedForwarder(trustedForwarder);
        organ = payable(address(new Organ()));
        procedures = createOrgan(payable(_msgSender()), cid);
    }

    function createOrgan(
        address payable admin,
        string memory cid
    )
        public
        returns (address payable clone)
    {
        // Clone organ and initialize it.
        clone = payable(Clones.clone(organ));
        Organ(clone).initialize(admin, cid, getTrustedForwarder());
        emit organCreated(clone);
        return clone;
    }

    // @todo : Implement Diamond in Organigram.sol ? https://eips.ethereum.org/EIPS/eip-2535
    /**
     *  Create a procedure from a procedure type.
     *  Because we are cloning the procedure, we will need to call initialize immediately.
     *  We can put the initialize() populated transaction data in the data parameter.
     */
    function createProcedure(address payable procedureType, bytes memory data)
        public
        returns (address payable procedure)
    {
        // Check if procedure.
        require(ERC165Checker.supportsInterface(procedureType, 0x71dbd330), "Not a procedure.");
        // Check if procedure is in registry.
        require(Organ(procedures).getEntryIndexForAddress(procedureType) > 0, "Procedure not found.");
        // Creates a minimal clone.
        procedure = payable(Clones.clone(procedureType));
        emit procedureCreated(procedureType, procedure);
        // NB: The initialize method will need to be called immediately
        // if not through the data parameter.
        if (data.length > 0) {
            Address.functionCall(procedure, data);
        }
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
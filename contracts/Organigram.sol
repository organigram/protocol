// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./Organ.sol";
import "./libraries/MetadataLibrary.sol";
import "@openzeppelin/contracts/introspection/ERC165Checker.sol";

contract Organigram {
    using OrganLibrary for OrganLibrary.Entry;
    using MetadataLibrary for MetadataLibrary.Metadata;
    address payable public organ;
    address payable public procedures; // Organ with procedures addresses.

    event organCreated(address payable organ);
    event procedureCreated(address payable procedureType, address payable procedure);

    constructor(MetadataLibrary.Metadata memory metadata)
        public
    {
        organ = payable(address(new Organ()));
        procedures = createOrgan(msg.sender, metadata);
    }

    function createOrgan(
        address payable admin,
        MetadataLibrary.Metadata memory metadata
    )
        public
        returns (address payable clone)
    {
        // Clone organ and initialize it.
        clone = _createClone(organ);
        Organ(clone).initialize(admin, metadata);
        organCreated(clone);
        return clone;
    }

    // @todo : Implement Diamond in Organigram.sol - https://eips.ethereum.org/EIPS/eip-2535
    function createProcedure(address payable procedureId)
        public
        returns (address payable procedure)
    {
        // Check if procedure.
        require(ERC165Checker.supportsInterface(procedureId, 0x71dbd330), "Not a procedure.");
        // Check if procedure is in registry.
        require(Organ(procedures).getEntryIndexForAddress(procedureId) > 0, "Procedure not found.");
        procedure = _createClone(procedureId);
        // The initialize method needs to be called directly.
        procedureCreated(procedureId, procedure);
        return procedure;
    }

    function registerProcedures(OrganLibrary.Entry[] memory entries)
        external
    {
        // Only valid procedures
        for (uint256 i; i < entries.length; ++i) {
            require(ERC165Checker.supportsInterface(entries[i].addr, 0x71dbd330), "An entry in parameters is not a valid procedure.");
        }
        Organ(organ).addEntries(entries);
    }

    // From https://github.com/optionality/clone-factory.
    function _createClone(address payable target)
        internal
        returns (address payable result)
    {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }
}
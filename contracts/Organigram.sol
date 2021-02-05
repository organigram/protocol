// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

import "./Organ.sol";

contract Organigram {
    address payable public _organ;
    address payable public _proceduresRegistry; // Organ with procedures addresses.

    event organCreated(address payable organ);
    event procedureCreated(address payable procedureType, address payable deployedProcedure);

    constructor(
        bytes32 prIpfsHash, uint8 prHashFunction, uint8 prHashSize
    ) public {
        _organ = address(new Organ());
        _proceduresRegistry = createOrgan(msg.sender, prIpfsHash, prHashFunction, prHashSize);
    }

    function createOrgan(
        address payable admin,
        bytes32 metadataIpfsHash,
        uint8 metadataHashFunction,
        uint8 metadataHashSize
    ) public returns (address payable clone) {
        // Clone organ and initialize it.
        clone = _createClone(_organ);
        Organ(clone).initialize(admin, metadataIpfsHash, metadataHashFunction, metadataHashSize);
        organCreated(clone);
    }

    function createProcedure(address payable procedureId, bytes calldata args) public returns (address payable procedure) {
        // Procedure 
        require(Organ(_proceduresRegistry).getEntryIndexForAddress(procedureId) > 0, "Procedure not found.");
        procedure = _createClone(procedureId);
        procedure.call('') // 0xec is function signature of initialize(bytes calldata)
        procedureCreated(procedureId, procedure);
    }

    // From https://github.com/optionality/clone-factory.
    function _createClone(address payable target) internal returns (address payable result) {
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
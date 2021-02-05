// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./libraries/ProcedureLibrary.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";

/*
    A procedure defines a set of operations compiled in a move.
    The procedure dictates the way the move can be applied.

    @TODO : Add moves getters.
*/

contract Procedure is ERC165 {
    using ProcedureLibrary for ProcedureLibrary.ProcedureData;
    using ProcedureLibrary for ProcedureLibrary.Move;
    using OrganLibrary for OrganLibrary.Entry;
    ProcedureLibrary.ProcedureData private procedureData;
    bytes4 private constant _INTERFACE_ID_PROCEDURE = 0x71dbd330;

    /**
        Modifiers.
    */

    modifier onlyInOrgan(address payable organAddress) {
        require(ProcedureLibrary.isInOrgan(organAddress, msg.sender), "Not authorized");
        _;
    }

    /**
        Procedure constructor.
    */

    constructor (bytes32 metadataIpfsHash, uint8 metadataHashFunction, uint8 metadataHashSize)
        public
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_ID_PROCEDURE);
        procedureData.init(metadataIpfsHash, metadataHashFunction, metadataHashSize);
    }

    /**
        Internal API.
        A procedure must call this method itself.
    */

    function applyMove(uint256 moveKey)
        internal
    {
        procedureData.applyMove(moveKey);
    }

    /**
        Public API : Procedure Metadata and Admin.
    */

    function updateMetadata(bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize)
        public
    {
        procedureData.updateMetadata(ipfsHash, hashFunction, hashSize);
    }

    function updateAdmin(address payable admin)
        public
    {
        procedureData.updateAdmin(admin);
    }

    /**
        Public API : Moves creation and update.
    */

    function propose()

    function createMove(bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize)
        public returns (uint256)
    {
        return procedureData.createMove(ipfsHash, hashFunction, hashSize);
    }

    function moveAddEntries(
        uint256 moveKey, address payable organ, OrganLibrary.Entry[] memory entries, bool lock
    )
        public
    {
        procedureData.moveAddEntries(moveKey, organ, entries, lock);
    }

    function moveRemoveEntries(
        uint256 moveKey, address payable organ, uint256[] memory indexes, bool lock
    )
        public
    {
        procedureData.moveRemoveEntries(moveKey, organ, indexes, lock);
    }

    function moveReplaceEntry(
        uint256 moveKey, address payable organ, uint index, address payable addr,
        bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize, bool lock
    )
        public
    {
        procedureData.moveReplaceEntry(moveKey, organ, index, addr, ipfsHash, hashFunction, hashSize, lock);
    }

    function moveAddProcedure(
        uint256 moveKey, address payable organ, address procedure, bytes2 permissions, bool lock
    )
        public
    {
        procedureData.moveAddProcedure(moveKey, organ, procedure, permissions, lock);
    }

    function moveRemoveProcedure(
        uint256 moveKey, address payable organ, address procedure, bool lock
    )
        public
    {
        procedureData.moveRemoveProcedure(moveKey, organ, procedure, lock);
    }

    function moveReplaceProcedure(
        uint256 moveKey, address payable organ,
        address oldProcedure, address newProcedure, bytes2 permissions, bool lock
    )
        public
    {
        procedureData.moveReplaceProcedure(moveKey, organ, oldProcedure, newProcedure, permissions, lock);
    }

    function moveCall(
        uint256 moveKey, bytes memory call,  bool lock
    )
        public
    {
        procedureData.moveCall(moveKey, call, lock);
    }

    function moveReceiveCollectible(
        uint256 moveKey, address payable organ, address operator, address target, uint256 token_id, bool lock
    )
        public
    {
        procedureData.moveReceiveCollectible(moveKey, organ, operator, target, token_id, lock);
    }

    function moveTransferCollectible(
        uint256 moveKey, address payable organ, address operator, address target, uint256 token_id, bool lock
    )
        public
    {
        procedureData.moveTransferCollectible(moveKey, organ, operator, target, token_id, lock);
    }

    function moveReceiveCoins(
        uint256 moveKey, address payable organ, address operator, address target, uint256 value, bool lock
    )
        public
    {
        procedureData.moveReceiveCoins(moveKey, organ, operator, target, value, lock);
    }

    function moveTransferCoins(
        uint256 moveKey, address payable organ, address operator, address target, uint256 value, bool lock
    )
        public
    {
        procedureData.moveTransferCoins(moveKey, organ, operator, target, value, lock);
    }

    function moveReceiveEther(
        uint256 moveKey, address payable organ, address target, uint256 value, bool lock
    )
        public
    {
        procedureData.moveReceiveEther(moveKey, organ, target, value, lock);
    }

    function moveTransferEther(
        uint256 moveKey, address payable organ, address target, uint256 value, bool lock
    )
        public
    {
        procedureData.moveTransferEther(moveKey, organ, target, value, lock);
    }

    function lockMove(uint256 moveKey)
        public
    {
        procedureData.lockMove(moveKey);
    }

    /*
        Accessors.
    */

    function getMovesLength() public view returns (uint256 length) {
        return procedureData.movesLength;
    }

    function getMove(uint256 moveKey) public view returns (ProcedureLibrary.Move memory move) {
        return procedureData.moves[moveKey];
    }

    function getMetadata()
        public
        view
        returns (
            bytes32 ipfsHash,
            uint8 hashFunction,
            uint8 hashSize
        )
    {
        return procedureData.getMetadata();
    }
}
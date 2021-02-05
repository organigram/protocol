// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../Organ.sol";

/*
    Organigr.am Contracts Framework - Procedure library.
    This library holds the logic common to all procedures.

    A procedure can affect an organ by :
    - Adding, removing, replacing entries.
    - Adding, removing, replacing procedures.
    - Withdrawing funds and transferring them to another organ.
    The procedure can process several operations inside one move.
*/

library ProcedureLibrary {
    struct ProcedureData {
        Metadata metadata;
        address payable admin;
        mapping (uint256 => Proposal) proposals;
        uint256 movesLength;
    }

    struct Metadata {
        bytes32 ipfsHash;
        uint8 hashFunction;
        uint8 hashSize;
    }

    struct Proposal {
        address payable creator;
        Metadata metadata;
        bool locked;
        bool applied;
        bool processing;
        Operation[] operations;
    }

    struct Operation {
        uint256 index;          // index will stay after reordering.
        address payable organ;  // target organ address.
        uint256 value;          // value transferred with the call.
        uint8 operationType;   // avoid reading function signature.
        // Possible masks:
        // 0: operation on procedure.
        // 1/2/3: addEntry/removeEntry/replaceEntry.
        // 4/5/6: addProcedure/removeProcedure/replaceProcedure.
        // 7: withdraw funds.
        // 8: withdraw tokens.
        bytes callData;
        bool processed;
    }

    /**
        Modifiers.
    */
    modifier onlyAdmin(ProcedureData storage self) {
        require(isInOrgan(self.admin, msg.sender), "Not authorized.");
        _;
    }
    modifier onlyMoveCreator(ProcedureData storage self, uint256 moveKey) {
        require(self.moves[moveKey].creator == msg.sender, "Not authorized.");
        _;
    }
    modifier onlyNewMove(ProcedureData storage self, uint256 moveKey) {
        require(
            !self.moves[moveKey].locked &&
            !self.moves[moveKey].applied &&
            !self.moves[moveKey].processing,
            "Not authorized."
        );
        _;
    }
    modifier onlyLockedMove(ProcedureData storage self, uint256 moveKey) {
        require(
            self.moves[moveKey].locked &&
            !self.moves[moveKey].applied &&
            !self.moves[moveKey].processing,
            "Not authorized."
        );
        _;
    }

    /**
        Events.
    */

    event metadataUpdated(address from, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize);
    event adminUpdated(address from, address payable admin);
    event moveCreated(address payable creator, uint256 moveKey);
    event moveApplied(uint256 moveKey);

    /*
        Procedure management.
    */

    function init(
        ProcedureData storage self, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize
    )
        public
    {
        self.metadata = Metadata({
            ipfsHash: ipfsHash,
            hashFunction: hashFunction,
            hashSize: hashSize
        });
        self.admin = msg.sender;
    }

    function updateAdmin(ProcedureData storage self, address payable admin)
        public onlyAdmin(self)
    {
        self.admin = admin;
        emit adminUpdated(msg.sender, admin);
    }

    function updateMetadata(
        ProcedureData storage self, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize
    )
        public onlyAdmin(self)
    {
        self.metadata = Metadata({
            ipfsHash: ipfsHash,
            hashFunction: hashFunction,
            hashSize: hashSize
        });
        emit metadataUpdated(msg.sender, ipfsHash, hashFunction, hashSize);
    }

    /**
        Utils.
    */
    function isInOrgan(address payable organ, address payable caller)
        public view returns (bool)
    {
        return organ == caller || Organ(organ).getEntryIndexForAddress(caller) != 0;
    }

    /**
        External API.
    */

    function applyMove(ProcedureData storage self, uint256 moveKey)
        internal onlyLockedMove(self, moveKey)
    {
        // Start processing.
        self.moves[moveKey].processing = true;
        // Process operations.
        for (uint256 i = 0; i < self.moves[moveKey].operations.length; ++i) {
            if (self.moves[moveKey].operations[i].organ != address(0)) {
                self.moves[moveKey].operations[i].organ.call(self.moves[moveKey].operations[i].callData);
            }
            self.moves[moveKey].operations[i].processed = true;
        }
        self.moves[moveKey].applied = true;
        emit moveApplied(moveKey);
    }

    function createMove(
        ProcedureData storage self,
        bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize
    )
        internal returns (uint256)
    {
        // Moves is a mapping, its key starts at 1.
        uint256 moveKey = self.movesLength++;
        self.moves[moveKey].creator = msg.sender;
        self.moves[moveKey].metadata = Metadata({
            ipfsHash: ipfsHash,
            hashFunction: hashFunction,
            hashSize: hashSize
        });
        return moveKey;
    }

    /**
        Move API.
    */

    function moveAddEntries(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, OrganLibrary.Entry[] memory entries,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // 0x981d5e7b is Organ.addEntries function selector.
            callData: abi.encodeWithSelector(0x981d5e7b, entries),
            operationType: 1,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveRemoveEntries(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, uint256[] memory indexes,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // 0x7615eb81 is Organ.removeEntries function selector.
            callData: abi.encodeWithSelector(0x7615eb81, indexes),
            operationType: 2,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveReplaceEntry(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, uint index,
        address payable addr, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        Move storage move = self.moves[moveKey];
        move.operations.push(Operation({
            index: move.operations.length,
            organ: organ,
            value: 0,
            // 0x91bdfe63 is Organ.replaceEntry function signature.
            callData: abi.encodeWithSelector(0x91bdfe63, index, addr, ipfsHash, hashFunction, hashSize),
            operationType: 3,
            processed: false
        }));
        if (lock) {
            move.locked = true;
            emit moveCreated(move.creator, moveKey);
        }
    }

    function moveCall(
        ProcedureData storage self, uint256 moveKey,
        bytes memory call,  bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: address(0),
            value: 0,
            callData: call,
            operationType: 0,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveAddProcedure(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address procedure, bytes2 permissions,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // 0x7f0a4e27 is Organ.addProcedure function signature.
            callData: abi.encodeWithSelector(0x7f0a4e27, procedure, permissions),
            operationType: 4,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveRemoveProcedure(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address procedure,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // 0x19b9404c is Organ.removeProcedure function signature.
            callData: abi.encodeWithSelector(0x19b9404c, procedure),
            operationType: 5,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveReplaceProcedure(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address oldProcedure, address newProcedure, bytes2 permissions,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // 0xd0922d4a is Organ.replaceProcedure function signature.
            callData: abi.encodeWithSelector(0xd0922d4a, oldProcedure, newProcedure, permissions),
            operationType: 6,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveReceiveCollectible(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address operator, address /*target*/,
        uint256 tokenId, bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // @todo Call data for this operation.
            callData: abi.encodeWithSelector(0xc1075329, operator, tokenId),
            operationType: 7,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveTransferCollectible(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address operator, address target,
        uint256 tokenId, bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // @todo Call data for this operation.
            callData: abi.encodeWithSelector(0x5e35359e, operator, target, tokenId),
            operationType: 8,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveReceiveCoins(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address operator, address target, uint256 value,
        bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // @todo Call data for this operation.
            callData: abi.encodeWithSelector(0xc1075329, operator, target, value),
            operationType: 7,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveTransferCoins(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address operator, address target,
        uint256 value, bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // @todo Call data for this operation.
            callData: abi.encodeWithSelector(0x5e35359e, operator, target, value),
            operationType: 8,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveReceiveEther(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address target, uint256 value, bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // @todo Call data for this operation.
            callData: abi.encodeWithSelector(0xc1075329, target, value),
            operationType: 7,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function moveTransferEther(
        ProcedureData storage self, uint256 moveKey,
        address payable organ, address target, uint256 value, bool lock
    )
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].operations.push(Operation({
            index: self.moves[moveKey].operations.length,
            organ: organ,
            value: 0,
            // @todo Call data for this operation.
            callData: abi.encodeWithSelector(0x5e35359e, target, value),
            operationType: 8,
            processed: false
        }));
        if (lock) {
            self.moves[moveKey].locked = true;
            emit moveCreated(self.moves[moveKey].creator, moveKey);
        }
    }

    function lockMove(ProcedureData storage self, uint256 moveKey)
        internal onlyMoveCreator(self, moveKey) onlyNewMove(self, moveKey)
    {
        self.moves[moveKey].locked = true;
        emit moveCreated(msg.sender, moveKey);
    }

    /**
        Private API.
    */

    function getMetadata(ProcedureData storage self)
        public view returns (bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize)
    {
        return (
            self.metadata.ipfsHash,
            self.metadata.hashFunction,
            self.metadata.hashSize
        );
    }
}
// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/*
    Organigr.am Contracts Framework - Organ library.
    This library holds the logic to manage a simple organ.
*/

import "./CoreLibrary.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";

library OrganLibrary {
    using EnumerableSet for EnumerableSet.AddressSet;
    using CoreLibrary for CoreLibrary.Metadata;
    using CoreLibrary for CoreLibrary.Entry;
    bytes2 public constant PERMISSION_ADD_PROCEDURES = 0x0001;
    bytes2 public constant PERMISSION_REMOVE_PROCEDURES = 0x0002;
    bytes2 public constant PERMISSION_ADD_ENTRIES = 0x0004;
    bytes2 public constant PERMISSION_REMOVE_ENTRIES = 0x0008;
    bytes2 public constant PERMISSION_UPDATE_METADATA = 0x0010;
    bytes2 public constant PERMISSION_DEPOSIT_ETHER = 0x0020;
    bytes2 public constant PERMISSION_WITHDRAW_ETHER = 0x0040;
    bytes2 public constant PERMISSION_DEPOSIT_COINS = 0x0080;
    bytes2 public constant PERMISSION_WITHDRAW_COINS = 0x0100;
    bytes2 public constant PERMISSION_DEPOSIT_COLLECTIBLES = 0x0200;
    bytes2 public constant PERMISSION_WITHDRAW_COLLECTIBLES = 0x0400;

    /*
        Entries are sets of addresses, contracts or documents.
    */

    struct OrganData {
        CoreLibrary.Metadata metadata;
        CoreLibrary.Entry[] entries;
        uint256 entriesCount;
        EnumerableSet.AddressSet procedures;
        mapping(address => bytes2) permissions;
        mapping(address => uint256) addressIndexInEntries;
    }

    /*
        Events.
    */

    event metadataUpdated(address from, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize);
    event adminUpdated(address from, address admin);
    event procedureAdded(address from, address procedure, bytes2 permissions);
    event procedureRemoved(address from, address procedure);
    event collectibleTransferred(address operator, address to, uint256 tokenId);
    event collectibleReceived(address operator, address from, uint256 tokenId);
    event coinsTransferred(address operator, address from, address to, uint256 amount);
    event coinsReceived(address operator, address from, address to, uint256 amount);
    event etherTransferred(address from, address to, uint256 amount);
    event etherReceived(address from, uint256 amount);
    event entryAdded(address from, uint256 index, address addr, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize);
    event entryRemoved(address from, uint256 index);

    /*
        Modifier.
    */

    modifier onlyPerm(OrganData storage self, bytes2 permission) {
        require(
            self.permissions[msg.sender] & permission == permission ||
            self.permissions[address(0)] & permission == permission,
            "Not authorized."
        );
        _;
    }

    /*
        Constructor.
    */

    function init(
        OrganData storage self, address defaultAdmin,
        CoreLibrary.Metadata memory metadata
    )
        public
    {
        // Initializing with deployer as admin.
        address payable _admin = payable(defaultAdmin != address(0) ? defaultAdmin : msg.sender);

        // Add _admin in procedures set.
        self.permissions[_admin] = 0xffff;
        self.procedures.add(_admin);

        // Initializing metadata.
        self.metadata = metadata;

        // Reserve index O for empty Entry.
        self.entries.push(
            CoreLibrary.Entry(
                address(0),
                CoreLibrary.Metadata(0, 0, 0)
            )
        );
    }

    function updateMetadata(
        OrganData storage self, CoreLibrary.Metadata memory metadata
    )
        public
        onlyPerm(self, PERMISSION_UPDATE_METADATA)
    {
        self.metadata = metadata;
        emit metadataUpdated(msg.sender, metadata.ipfsHash, metadata.hashSize, metadata.hashFunction);
    }

    /*
        Assets management.
    */

    function transferCollectible(
        OrganData storage self, address operator, address from,
        address to, uint256 tokenId
    )
        public
        onlyPerm(self, PERMISSION_WITHDRAW_COLLECTIBLES)
    {
        // @note Organ must be the owner, approved, or operator of ERC-721.
        IERC721(operator).safeTransferFrom(from, to, tokenId);
        emit collectibleTransferred(operator, to, tokenId);
    }

    function receiveCollectible(
        OrganData storage self, address operator,
        address from, uint256 tokenId
    )
        public
        onlyPerm(self, PERMISSION_DEPOSIT_COLLECTIBLES)
    {
        emit collectibleReceived(operator, from, tokenId);
    }

    function transferCoins(
        OrganData storage self, address operator,
        address from, address to, uint256 amount
    )
        public
        onlyPerm(self, PERMISSION_WITHDRAW_COINS)
    {
        bytes memory data;
        IERC777(operator).send(to, amount, data);
        emit coinsTransferred(operator, from, to, amount);
    }

    function receiveCoins(
        OrganData storage self, address operator,
        address from, address to, uint256 amount
    )
        public
        onlyPerm(self, PERMISSION_DEPOSIT_COINS)
    {
        emit coinsReceived(operator, from, to, amount);
    }

    function transferEther(OrganData storage self, address payable to, uint256 value)
        public
        onlyPerm(self, PERMISSION_WITHDRAW_ETHER)
    {
        to.transfer(value);
        emit etherTransferred(msg.sender, to, value);
    }

    function receiveEther(OrganData storage self, uint256 value)
        public
        onlyPerm(self, PERMISSION_DEPOSIT_ETHER)
    {
        emit etherReceived(msg.sender, value);
    }

    /*
        Procedures management.
    */

    function removeProcedure(OrganData storage self, address procedure)
        public
        onlyPerm(self, PERMISSION_REMOVE_PROCEDURES)
    {
        // Check procedure is already there.
        require(self.procedures.contains(procedure), "Record not found.");
        // Remove from Procedures set.
        self.procedures.remove(procedure);
        self.permissions[procedure] = bytes2(0);
        emit procedureRemoved(msg.sender, procedure);
    }

    function addProcedure(OrganData storage self, address procedure, bytes2 permissions)
        public
        onlyPerm(self, PERMISSION_ADD_PROCEDURES)
        returns (uint256 index)
    {
        // Check new procedure is not already there.
        require(!self.procedures.contains(procedure), "Duplicate record.");
        // Check new procedure has permissions.
        require(permissions != 0x0000, "Wrong permissions set.");

        // Store procedures.
        self.procedures.add(procedure);
        self.permissions[procedure] = permissions;
        emit procedureAdded(msg.sender, procedure, permissions);
        return index;
    }

    function replaceProcedure (
        OrganData storage self, address oldProcedure, address newProcedure,
        bytes2 permissions
    )
        public
        onlyPerm(self, PERMISSION_REMOVE_PROCEDURES)
        onlyPerm(self, PERMISSION_ADD_PROCEDURES)
    {
        // Check old procedure will be removable before adding.
        require(self.procedures.contains(oldProcedure), "Record not found.");
        // Check new procedure has permissions.
        require(permissions > 0, "Wrong permissions set.");

        // Check if we are replacing a master with another, or updating permissions.
        if (oldProcedure != newProcedure) {
            addProcedure(self, newProcedure, permissions);
            removeProcedure(self, oldProcedure);
        }
        else {
            // Update permissions.
            self.permissions[newProcedure] = permissions;
        }
        // Trigger events.
        emit procedureRemoved(msg.sender, oldProcedure);
        emit procedureAdded(msg.sender, newProcedure, permissions);
    }

    /**
        Entries management.
    */

    function addEntries(
        OrganData storage self, CoreLibrary.Entry[] memory entries
    )
        public
        onlyPerm(self, PERMISSION_ADD_ENTRIES)
        returns (uint256[] memory indexes)
    {
        require(entries.length > 0, "No entries specified.");
        // uint256 memory initialGas = gasleft();
        indexes = new uint256[](entries.length);

        for (uint256 i = 0 ; i < entries.length ; i++) {
            // If the entry has an address, we check that the address has not been used before.
            if (entries[i].addr != address(0)) {
                require(self.addressIndexInEntries[entries[i].addr] == 0, "Duplicate record.");
            }
            // Adding the entry.
            self.entries.push(entries[i]);
            // Registering entry position relative to its address.
            indexes[i] = self.entries.length - 1;
            self.addressIndexInEntries[entries[i].addr] = indexes[i];
            // Incrementing entries counter.
            self.entriesCount++;
            emit entryAdded(
                msg.sender,
                indexes[i],
                entries[i].addr,
                entries[i].doc.ipfsHash,
                entries[i].doc.hashFunction,
                entries[i].doc.hashSize
            );
        }

        // Registering the address as active
        return indexes;
    }

    function removeEntries(OrganData storage self, uint256[] memory indexes)
        public
        onlyPerm(self, PERMISSION_REMOVE_ENTRIES)
    {
        for (uint256 i = 0 ; i < indexes.length ; i++) {
            address addr = self.entries[indexes[i]].addr;
            delete self.entries[indexes[i]];
            self.entriesCount--;
            // Deleting entry index.
            if (addr != address(0))
                self.addressIndexInEntries[addr] = 0;
            // Logging event.
            emit entryRemoved(msg.sender, indexes[i]);
        }
    }

    function replaceEntry(
        OrganData storage self, uint256 index, CoreLibrary.Entry memory entry
    )
        public
        onlyPerm(self, PERMISSION_REMOVE_ENTRIES)
        onlyPerm(self, PERMISSION_ADD_ENTRIES)
    {
        // Check that the replacing address is not registered.
        if (entry.addr != address(0)) {
            require(self.addressIndexInEntries[entry.addr] > 0, "Record not found.");
        }
        self.addressIndexInEntries[self.entries[index].addr] = 0;
        emit entryRemoved(msg.sender, index);

        self.entries[index] = entry;

        self.addressIndexInEntries[entry.addr] = index;
        emit entryAdded(msg.sender, index,  entry.addr, entry.doc.ipfsHash,  entry.doc.hashFunction,  entry.doc.hashSize);
    }

    function getProceduresLength(OrganData storage self)
        public
        view
        returns (uint256 length)
    {
        return self.procedures.length();
    }

    function getProcedure(OrganData storage self, uint256 index)
        public
        view
        returns (address addr, bytes2 perms)
    {
        addr = self.procedures.at(index);
        perms = self.permissions[addr];
        return (addr, perms);
    }

    function getEntry(OrganData storage self, uint256 index)
        public
        view
        returns (CoreLibrary.Entry storage)
    {
        return self.entries[index];
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

/*
    Organigram Protocol - Organ library.
    This library holds the logic to manage a simple organ.
*/

import './CoreLibrary.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC777.sol';
import '@openzeppelin/contracts/interfaces/IERC1155.sol';

library OrganLibrary {
    using EnumerableSet for EnumerableSet.AddressSet;
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
        string cid;
        CoreLibrary.Entry[] entries;
        uint256 entriesCount;
        EnumerableSet.AddressSet procedures;
        mapping(address => bytes2) permissions;
        mapping(address => uint256) addressIndexInEntries;
    }

    /*
        Events.
    */
    event cidUpdated(address from, string cid);
    event adminUpdated(address from, address admin);
    event procedureAdded(address from, address procedure, bytes2 permissions);
    event procedureRemoved(address from, address procedure);
    event collectibleTransferred(address operator, address to, uint256 tokenId);
    event collectibleReceived(address operator, address from, uint256 tokenId);
    event coinsTransferred(
        address operator,
        address from,
        address to,
        uint256 amount
    );
    event coinsReceived(
        address operator,
        address from,
        address to,
        uint256 amount
    );
    event etherTransferred(address from, address to, uint256 amount);
    event etherReceived(address from, uint256 amount);
    event entryAdded(address from, uint256 index, address addr, string cid);
    event entryRemoved(address from, uint256 index);

    error LengthMismatch();
    error ZeroAddress();
    error DuplicateProcedure(address proc);

    /*
        Modifier.
    */
    modifier onlyPerm(
        OrganData storage self,
        bytes2 permission,
        address caller
    ) {
        require(
            self.permissions[caller] & permission == permission ||
                self.permissions[address(0)] & permission == permission,
            'Not authorized.'
        );
        _;
    }

    /*
        Constructor. Takes an optional array of { procedure, permissions } and sets the permissions in the organ:
    */
    function init(
        OrganData storage self,
        address[] memory _procedures,
        bytes2[] memory _permissions,
        string memory cid
        // address caller
    ) public {
        // Initializing with deployer as admin.
        // address payable _admin = payable(
        // defaultAdmin != address(0) ? defaultAdmin : caller
        // );

        // self.permissions[_admin] = 0xffff;
        // self.procedures.add(_admin);
        // For each procedure in procedures, set the permissions for that procedure.
        if (_procedures.length != _permissions.length) revert LengthMismatch();

        for (uint256 i = 0; i < _procedures.length; i++) {
            address p = _procedures[i];
            if (p == address(0)) revert ZeroAddress();

            // add() retourne false si déjà présent
            if (!self.procedures.add(p)) revert DuplicateProcedure(p);

            self.permissions[p] = _permissions[i];
        }

        // Initializing cid.
        self.cid = cid;

        // Reserve index O for empty Entry.
        self.entries.push(CoreLibrary.Entry(address(0), string('')));
    }

    function updateCid(
        OrganData storage self,
        string memory cid,
        address caller
    ) public onlyPerm(self, PERMISSION_UPDATE_METADATA, caller) {
        self.cid = cid;
        emit cidUpdated(caller, cid);
    }

    /*
        Assets management.
    */
    function transferCollectible(
        OrganData storage self,
        address token,
        address from,
        address to,
        uint256 tokenId
    ) public onlyPerm(self, PERMISSION_WITHDRAW_COLLECTIBLES, from) {
        // @note Organ must be the owner, approved, or operator of ERC-721.
        IERC721(token).safeTransferFrom(from, to, tokenId);
        emit collectibleTransferred(token, to, tokenId);
    }

    function receiveCollectible(
        OrganData storage self,
        address operator,
        address from,
        uint256 tokenId
    ) public onlyPerm(self, PERMISSION_DEPOSIT_COLLECTIBLES, from) {
        emit collectibleReceived(operator, from, tokenId);
    }

    function transferCoins(
        OrganData storage self,
        address token,
        address from,
        address to,
        uint256 amount
    ) public onlyPerm(self, PERMISSION_WITHDRAW_COINS, from) {
        bytes memory data;
        IERC777(token).send(to, amount, data);
        emit coinsTransferred(token, from, to, amount);
    }

    function receiveCoins(
        OrganData storage self,
        address operator,
        address from,
        address to,
        uint256 amount
    ) public onlyPerm(self, PERMISSION_DEPOSIT_COINS, from) {
        emit coinsReceived(operator, from, to, amount);
    }

    function transferEther(
        OrganData storage self,
        address payable to,
        uint256 value,
        address from
    ) public onlyPerm(self, PERMISSION_WITHDRAW_ETHER, from) {
        to.transfer(value);
        emit etherTransferred(from, to, value);
    }

    function receiveEther(
        OrganData storage self,
        uint256 value,
        address from
    ) public onlyPerm(self, PERMISSION_DEPOSIT_ETHER, from) {
        emit etherReceived(from, value);
    }

    /*
        Procedures management.
    */
    function removeProcedure(
        OrganData storage self,
        address procedure,
        address caller
    ) public onlyPerm(self, PERMISSION_REMOVE_PROCEDURES, caller) {
        // Check procedure is already there.
        require(self.procedures.contains(procedure), 'Record not found.');
        // Remove from Procedures set.
        self.procedures.remove(procedure);
        self.permissions[procedure] = bytes2(0);
        emit procedureRemoved(caller, procedure);
    }

    function addProcedure(
        OrganData storage self,
        address procedure,
        bytes2 permissions,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_ADD_PROCEDURES, caller)
        returns (uint256 index)
    {
        // Check new procedure is not already there.
        require(!self.procedures.contains(procedure), 'Duplicate record.');
        // Check new procedure has permissions.
        require(permissions != 0x0000, 'Wrong permissions set.');

        // Store procedures.
        self.procedures.add(procedure);
        self.permissions[procedure] = permissions;
        emit procedureAdded(caller, procedure, permissions);
        return index;
    }

    function replaceProcedure(
        OrganData storage self,
        address oldProcedure,
        address newProcedure,
        bytes2 permissions,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_REMOVE_PROCEDURES, caller)
        onlyPerm(self, PERMISSION_ADD_PROCEDURES, caller)
    {
        // Check old procedure will be removable before adding.
        require(self.procedures.contains(oldProcedure), 'Record not found.');
        // Check new procedure has permissions.
        require(permissions > 0, 'Wrong permissions set.');

        // Check if we are replacing a master with another, or updating permissions.
        if (oldProcedure != newProcedure) {
            addProcedure(self, newProcedure, permissions, caller);
            removeProcedure(self, oldProcedure, caller);
        } else {
            // Update permissions.
            self.permissions[newProcedure] = permissions;
        }
        // Trigger events.
        emit procedureRemoved(caller, oldProcedure);
        emit procedureAdded(caller, newProcedure, permissions);
    }

    /**
        Entries management.
    */
    function addEntries(
        OrganData storage self,
        CoreLibrary.Entry[] memory entries,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_ADD_ENTRIES, caller)
        returns (uint256[] memory indexes)
    {
        require(entries.length > 0, 'No entries specified.');
        // uint256 memory initialGas = gasleft();
        indexes = new uint256[](entries.length);

        for (uint256 i = 0; i < entries.length; i++) {
            // If the entry has an address, we check that the address has not been used before.
            if (entries[i].addr != address(0)) {
                require(
                    self.addressIndexInEntries[entries[i].addr] == 0,
                    'Duplicate record.'
                );
            }
            // Adding the entry.
            self.entries.push(entries[i]);
            // Registering entry position relative to its address.
            indexes[i] = self.entries.length - 1;
            self.addressIndexInEntries[entries[i].addr] = indexes[i];
            // Incrementing entries counter.
            self.entriesCount++;
            emit entryAdded(
                caller,
                indexes[i],
                entries[i].addr,
                entries[i].cid
            );
        }

        // Registering the address as active
        return indexes;
    }

    function removeEntries(
        OrganData storage self,
        uint256[] memory indexes,
        address caller
    ) public onlyPerm(self, PERMISSION_REMOVE_ENTRIES, caller) {
        for (uint256 i = 0; i < indexes.length; i++) {
            address addr = self.entries[indexes[i]].addr;
            delete self.entries[indexes[i]];
            self.entriesCount--;
            // Deleting entry index.
            if (addr != address(0)) self.addressIndexInEntries[addr] = 0;
            // Logging event.
            emit entryRemoved(caller, indexes[i]);
        }
    }

    function replaceEntry(
        OrganData storage self,
        uint256 index,
        CoreLibrary.Entry memory entry,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_REMOVE_ENTRIES, caller)
        onlyPerm(self, PERMISSION_ADD_ENTRIES, caller)
    {
        // Check that the replacing address is not registered.
        if (entry.addr != address(0)) {
            require(
                self.addressIndexInEntries[entry.addr] > 0,
                'Record not found.'
            );
        }
        self.addressIndexInEntries[self.entries[index].addr] = 0;
        emit entryRemoved(caller, index);

        self.entries[index] = entry;

        self.addressIndexInEntries[entry.addr] = index;
        emit entryAdded(caller, index, entry.addr, entry.cid);
    }

    function getProceduresLength(
        OrganData storage self
    ) public view returns (uint256 length) {
        return self.procedures.length();
    }

    function getProcedure(
        OrganData storage self,
        uint256 index
    ) public view returns (address addr, bytes2 perms) {
        addr = self.procedures.at(index);
        perms = self.permissions[addr];
        return (addr, perms);
    }

    function getEntry(
        OrganData storage self,
        uint256 index
    ) public view returns (CoreLibrary.Entry storage) {
        return self.entries[index];
    }
}

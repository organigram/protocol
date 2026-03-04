// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

/*
    Organigram Protocol - Organ library.
    This library holds the logic to manage a simple organ.
*/

import './CoreLibrary.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC777.sol';
import '@openzeppelin/contracts/interfaces/IERC1155.sol';

library OrganLibrary {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using CoreLibrary for CoreLibrary.Entry;
    bytes2 public constant PERMISSION_ADD_PERMISSIONS = 0x0001;
    bytes2 public constant PERMISSION_REMOVE_PERMISSIONS = 0x0002;
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
        EnumerableSet.AddressSet permissionAddresses;
        mapping(address => bytes2) permissions;
        mapping(address => uint256) addressIndexInEntries;
    }

    /*
        Events.
    */
    event cidUpdated(address from, string cid);
    event adminUpdated(address from, address admin);
    event permissionAdded(
        address from,
        address permissionAddress,
        bytes2 permissionValue
    );
    event permissionRemoved(address from, address permissionAddress);
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
    error DuplicatePermission(address perm);

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
        Constructor.
    */
    function init(
        OrganData storage self,
        address[] memory _permissionAddresses,
        bytes2[] memory _permissionValues,
        string memory cid,
        CoreLibrary.Entry[] memory entries
    ) public {
        // Initializing cid.
        self.cid = cid;

        // Reserve index O for empty Entry.
        self.entries.push(CoreLibrary.Entry(address(0), string('')));

        // Setting the permissions.
        if (_permissionAddresses.length != _permissionValues.length)
            revert LengthMismatch();

        for (uint256 i = 0; i < _permissionAddresses.length; i++) {
            address p = _permissionAddresses[i];
            if (p == address(0)) revert ZeroAddress();
            if (!self.permissionAddresses.add(p)) revert DuplicatePermission(p);

            self.permissions[p] = _permissionValues[i];
        }

        // Adding entries.
        for (uint256 i = 0; i < entries.length; i++) {
            // If the entry has an address, we check that the address has not been used before.
            if (entries[i].addr != address(0)) {
                require(
                    self.addressIndexInEntries[entries[i].addr] == 0,
                    'Duplicate record.'
                );
            }
            self.entries.push(entries[i]);
            if (entries[i].addr != address(0)) {
                self.addressIndexInEntries[entries[i].addr] = self.entries.length - 1;
            }
        }
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
        address caller,
        address to,
        uint256 tokenId
    ) public onlyPerm(self, PERMISSION_WITHDRAW_COLLECTIBLES, caller) {
        // @note Organ must be the owner, approved, or operator of ERC-721.
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
        emit collectibleTransferred(caller, to, tokenId);
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
        address caller,
        address to,
        uint256 amount
    ) public onlyPerm(self, PERMISSION_WITHDRAW_COINS, caller) {
        IERC20(token).safeTransfer(to, amount);
        emit coinsTransferred(caller, address(this), to, amount);
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
        uint256 amount,
        address from
    ) internal onlyPerm(self, PERMISSION_WITHDRAW_ETHER, from) {
        (bool success, ) = to.call{value: amount}('');
        require(success, 'Transfer failed.');
        emit etherTransferred(from, to, amount);
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
    function removePermission(
        OrganData storage self,
        address permissionAddress,
        address caller
    ) public onlyPerm(self, PERMISSION_REMOVE_PERMISSIONS, caller) {
        // Check address is already there.
        require(
            self.permissionAddresses.contains(permissionAddress),
            'Record not found.'
        );
        // Remove from Procedures set.
        self.permissionAddresses.remove(permissionAddress);
        self.permissions[permissionAddress] = bytes2(0);
        emit permissionRemoved(caller, permissionAddress);
    }

    function addPermission(
        OrganData storage self,
        address permissionAddress,
        bytes2 permissionValue,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_ADD_PERMISSIONS, caller)
        returns (uint256 index)
    {
        // Check new address is not already there.
        require(
            !self.permissionAddresses.contains(permissionAddress),
            'Duplicate record.'
        );
        // Check new address has permissions.
        require(permissionValue != 0x0000, 'Wrong permissions set.');

        // Store permissions.
        self.permissionAddresses.add(permissionAddress);
        self.permissions[permissionAddress] = permissionValue;
        emit permissionAdded(caller, permissionAddress, permissionValue);
        return index;
    }

    function replacePermission(
        OrganData storage self,
        address oldPermissionAddress,
        address newPermissionAddress,
        bytes2 newPermissionValue,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_REMOVE_PERMISSIONS, caller)
        onlyPerm(self, PERMISSION_ADD_PERMISSIONS, caller)
    {
        // Check old address will be removable before adding.
        require(
            self.permissionAddresses.contains(oldPermissionAddress),
            'Record not found.'
        );
        // Check new address has permissions.
        require(newPermissionValue > 0, 'Wrong permissions set.');

        // Check if we are replacing a master with another, or updating permissions.
        if (oldPermissionAddress != newPermissionAddress) {
            addPermission(
                self,
                newPermissionAddress,
                newPermissionValue,
                caller
            );
            removePermission(self, oldPermissionAddress, caller);
        } else {
            // Update permissions.
            self.permissions[newPermissionAddress] = newPermissionValue;
        }
        // Trigger events.
        emit permissionRemoved(caller, oldPermissionAddress);
        emit permissionAdded(caller, newPermissionAddress, newPermissionValue);
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

    function getPermissionsLength(
        OrganData storage self
    ) public view returns (uint256 length) {
        return self.permissionAddresses.length();
    }

    function getPermission(
        OrganData storage self,
        uint256 index
    ) public view returns (address addr, bytes2 perms) {
        addr = self.permissionAddresses.at(index);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

/*
    Organigram Protocol - Organ library.
    This library holds the logic to manage a simple organ.
*/

import {CoreLibrary} from './CoreLibrary.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

/// @title Organ library
/// @notice Storage layout and rules of organs, linked into the `Organ` contract.
library OrganLibrary {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using CoreLibrary for CoreLibrary.Entry;
    /// @notice Permission to grant permissions.
    bytes2 public constant PERMISSION_ADD_PERMISSIONS = 0x0001;
    /// @notice Permission to revoke permissions.
    bytes2 public constant PERMISSION_REMOVE_PERMISSIONS = 0x0002;
    /// @notice Permission to add entries.
    bytes2 public constant PERMISSION_ADD_ENTRIES = 0x0004;
    /// @notice Permission to remove entries.
    bytes2 public constant PERMISSION_REMOVE_ENTRIES = 0x0008;
    /// @notice Permission to replace the metadata reference.
    bytes2 public constant PERMISSION_UPDATE_METADATA = 0x0010;
    /// @notice Permission to send ether held by the organ.
    bytes2 public constant PERMISSION_WITHDRAW_ETHER = 0x0040;
    /// @notice Permission to send tokens held by the organ.
    bytes2 public constant PERMISSION_WITHDRAW_COINS = 0x0100;
    /// @notice Permission to send ERC-721 tokens held by the organ.
    bytes2 public constant PERMISSION_WITHDRAW_COLLECTIBLES = 0x0400;
    /// @notice Permission to make the organ call a whitelisted outside contract.
    bytes2 public constant PERMISSION_EXECUTE_WHITELISTED = 0x0800;
    /// @notice Permission to change the calls the organ may make to outside contracts.
    bytes2 public constant PERMISSION_MANAGE_EXECUTION_WHITELIST = 0x1000;

    /*
        Entries are sets of addresses, contracts or documents.
    */
    enum ParamConstraintType {
        NONE,
        EXACT,
        RANGE,
        SELF,
        WHITELISTED_ADDRESS
    }

    struct ParamConstraint {
        uint8 index;
        ParamConstraintType constraintType;
        bytes32 minValue;
        bytes32 maxValue;
        bytes32 exactValue;
    }

    struct CallPolicy {
        address target;
        bytes4 selector;
        bool enabled;
        ParamConstraint[] constraints;
    }

    struct OrganData {
        string cid;
        CoreLibrary.Entry[] entries;
        uint256 entriesCount;
        EnumerableSet.AddressSet permissionAddresses;
        mapping(address => bytes2) permissions;
        mapping(address => uint256) addressIndexInEntries;
        EnumerableSet.Bytes32Set callPolicyKeys;
        mapping(bytes32 => CallPolicy) callPolicies;
        mapping(bytes32 => EnumerableSet.AddressSet) callPolicyWhitelistedAddresses;
    }

    /*
        Events.
    */
    /// @notice The metadata reference of the organ changed.
    event cidUpdated(address from, string cid);
    /// @notice An address received permissions on the organ.
    event permissionAdded(
        address from,
        address permissionAddress,
        bytes2 permissionValue
    );
    /// @notice An address lost its permissions on the organ.
    event permissionRemoved(address from, address permissionAddress);
    /// @notice The organ sent an ERC-721 token.
    event collectibleTransferred(address operator, address to, uint256 tokenId);
    /// @notice The organ received an ERC-721 token.
    event collectibleReceived(address operator, address from, uint256 tokenId);
    /// @notice The organ sent tokens.
    event coinsTransferred(
        address operator,
        address from,
        address to,
        uint256 amount
    );
    /// @notice The organ received tokens.
    event coinsReceived(
        address operator,
        address from,
        address to,
        uint256 amount
    );
    /// @notice The organ sent ether.
    event etherTransferred(address from, address to, uint256 amount);
    /// @notice The organ received ether.
    event etherReceived(address from, uint256 amount);
    /// @notice An entry was added to the organ.
    event entryAdded(address from, uint256 index, address addr, string cid);
    /// @notice An entry was removed from the organ.
    event entryRemoved(address from, uint256 index);
    /// @notice The organ may now call a function of an outside contract.
    event callPolicySet(
        address indexed caller,
        address indexed target,
        bytes4 indexed selector
    );
    /// @notice The organ may no longer call a function of an outside contract.
    event callPolicyRemoved(
        address indexed caller,
        address indexed target,
        bytes4 indexed selector
    );
    /// @notice An address was allowed as an argument of a whitelisted call.
    event callPolicyWhitelistedAddressAdded(
        bytes32 indexed policyKey,
        address indexed candidate
    );
    /// @notice An address is no longer allowed as an argument of a whitelisted call.
    event callPolicyWhitelistedAddressRemoved(
        bytes32 indexed policyKey,
        address indexed candidate
    );
    /// @notice The organ made a whitelisted call to an outside contract.
    event whitelistedExecution(
        address indexed caller,
        address indexed target,
        bytes4 indexed selector,
        uint256 value
    );

    error LengthMismatch();
    error ZeroAddress();
    error DuplicatePermission(address perm);
    error InvalidTarget();
    error InvalidSelector();
    error CallPolicyNotFound(bytes32 policyKey);
    error InvalidConstraintIndex(uint256 index);
    error UnsupportedCallDataLength();
    error ConstraintViolation(uint256 index);
    error InvalidEntryIndex(uint256 index);
    error InvalidEntry();

    /*
        Modifier.
    */
    modifier onlyPerm(
        OrganData storage self,
        bytes2 permission,
        address caller
    ) {
        _requirePermission(self, permission, caller);
        _;
    }

    function _requirePermission(
        OrganData storage self,
        bytes2 permission,
        address caller
    ) private view {
        require(
            self.permissions[caller] & permission == permission,
            'Not authorized.'
        );
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
            _validateEntry(entries[i]);
            // If the entry has an address, we check that the address has not been used before.
            if (entries[i].addr != address(0)) {
                require(
                    self.addressIndexInEntries[entries[i].addr] == 0,
                    'Duplicate record.'
                );
            }
            self.entries.push(entries[i]);
            if (entries[i].addr != address(0)) {
                self.addressIndexInEntries[entries[i].addr] =
                    self.entries.length -
                    1;
            }
            self.entriesCount++;
        }
    }

    function _callPolicyKey(
        address target,
        bytes4 selector
    ) internal pure returns (bytes32) {
        bytes32 policyKey;
        assembly ('memory-safe') {
            mstore(0x00, shl(96, target))
            mstore(0x14, selector)
            policyKey := keccak256(0x00, 0x18)
        }
        return policyKey;
    }

    function _clearCallPolicyStorage(
        OrganData storage self,
        bytes32 policyKey
    ) internal {
        delete self.callPolicies[policyKey].constraints;
        uint256 length = self
            .callPolicyWhitelistedAddresses[policyKey]
            .length();
        for (uint256 i = length; i > 0; i--) {
            address candidate = self
                .callPolicyWhitelistedAddresses[policyKey]
                .at(i - 1);
            bool removed = self
                .callPolicyWhitelistedAddresses[policyKey]
                .remove(candidate);
            assert(removed);
            // No external call precedes: set operations are internal.
            // forge-lint: disable-next-line(reentrancy-events)
            emit callPolicyWhitelistedAddressRemoved(policyKey, candidate);
        }
    }

    function _readWord(
        bytes calldata data,
        uint256 index
    ) internal pure returns (bytes32 word) {
        uint256 start = 4 + index * 32;
        if (data.length < start + 32) revert InvalidConstraintIndex(index);
        assembly {
            word := calldataload(add(data.offset, start))
        }
    }

    function _asAddress(bytes32 word) internal pure returns (address) {
        return address(uint160(uint256(word)));
    }

    function _selector(
        bytes calldata data
    ) internal pure returns (bytes4 selector) {
        if (data.length < 4) revert UnsupportedCallDataLength();
        selector = bytes4(data[:4]);
    }

    function _entryExists(
        OrganData storage self,
        uint256 index
    ) internal view returns (bool) {
        if (index == 0 || index >= self.entries.length) return false;
        CoreLibrary.Entry storage entry = self.entries[index];
        return entry.addr != address(0) || bytes(entry.cid).length != 0;
    }

    function _validateEntry(CoreLibrary.Entry memory entry) internal pure {
        if (entry.addr == address(0) && bytes(entry.cid).length == 0)
            revert InvalidEntry();
    }

    function _performCall(
        address target,
        uint256 value,
        bytes calldata data
    ) internal returns (bytes memory result) {
        // slither-disable-next-line arbitrary-send-eth
        (bool success, bytes memory callResult) = target.call{value: value}(
            data
        );
        if (!success) {
            assembly {
                revert(add(callResult, 32), mload(callResult))
            }
        }
        return callResult;
    }

    function _validateConstraint(
        OrganData storage self,
        bytes32 policyKey,
        ParamConstraint storage constraint,
        bytes calldata data
    ) internal view {
        if (constraint.constraintType == ParamConstraintType.NONE) {
            return;
        }

        bytes32 word = _readWord(data, constraint.index);
        if (constraint.constraintType == ParamConstraintType.EXACT) {
            if (word != constraint.exactValue)
                revert ConstraintViolation(constraint.index);
            return;
        }
        if (constraint.constraintType == ParamConstraintType.RANGE) {
            uint256 value = uint256(word);
            if (
                value < uint256(constraint.minValue) ||
                value > uint256(constraint.maxValue)
            ) revert ConstraintViolation(constraint.index);
            return;
        }
        if (constraint.constraintType == ParamConstraintType.SELF) {
            if (_asAddress(word) != address(this))
                revert ConstraintViolation(constraint.index);
            return;
        }
        if (
            constraint.constraintType == ParamConstraintType.WHITELISTED_ADDRESS
        ) {
            if (
                !self.callPolicyWhitelistedAddresses[policyKey].contains(
                    _asAddress(word)
                )
            ) {
                revert ConstraintViolation(constraint.index);
            }
            return;
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

    function setCallPolicy(
        OrganData storage self,
        address target,
        bytes4 selector,
        ParamConstraint[] memory constraints,
        address[] memory whitelistedAddresses,
        address caller
    ) public onlyPerm(self, PERMISSION_MANAGE_EXECUTION_WHITELIST, caller) {
        if (target == address(0)) revert InvalidTarget();
        if (selector == bytes4(0)) revert InvalidSelector();
        bytes32 policyKey = _callPolicyKey(target, selector);
        if (!self.callPolicyKeys.contains(policyKey)) {
            bool added = self.callPolicyKeys.add(policyKey);
            assert(added);
        } else {
            _clearCallPolicyStorage(self, policyKey);
        }
        CallPolicy storage policy = self.callPolicies[policyKey];
        policy.target = target;
        policy.selector = selector;
        policy.enabled = true;
        for (uint256 i = 0; i < constraints.length; i++) {
            policy.constraints.push(constraints[i]);
        }
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (
                self.callPolicyWhitelistedAddresses[policyKey].add(
                    whitelistedAddresses[i]
                )
            ) {
                // No external call precedes: set operations are internal.
                // forge-lint: disable-next-item(reentrancy-events)
                emit callPolicyWhitelistedAddressAdded(
                    policyKey,
                    whitelistedAddresses[i]
                );
            }
        }
        // No external call precedes: set operations are internal.
        // forge-lint: disable-next-line(reentrancy-events)
        emit callPolicySet(caller, target, selector);
    }

    function removeCallPolicy(
        OrganData storage self,
        address target,
        bytes4 selector,
        address caller
    ) public onlyPerm(self, PERMISSION_MANAGE_EXECUTION_WHITELIST, caller) {
        bytes32 policyKey = _callPolicyKey(target, selector);
        if (!self.callPolicyKeys.contains(policyKey))
            revert CallPolicyNotFound(policyKey);
        _clearCallPolicyStorage(self, policyKey);
        delete self.callPolicies[policyKey];
        bool removed = self.callPolicyKeys.remove(policyKey);
        assert(removed);
        // No external call precedes: set operations are internal.
        // forge-lint: disable-next-line(reentrancy-events)
        emit callPolicyRemoved(caller, target, selector);
    }

    function executeWhitelisted(
        OrganData storage self,
        address target,
        uint256 value,
        bytes calldata data,
        address caller
    )
        public
        onlyPerm(self, PERMISSION_EXECUTE_WHITELISTED, caller)
        returns (bytes memory result)
    {
        // A call policy does not bound the ether sent along with the call.
        if (value != 0)
            _requirePermission(self, PERMISSION_WITHDRAW_ETHER, caller);
        bytes4 selector = _selector(data);
        bytes32 policyKey = _callPolicyKey(target, selector);
        CallPolicy storage policy = self.callPolicies[policyKey];
        if (!policy.enabled) revert CallPolicyNotFound(policyKey);
        for (uint256 i = 0; i < policy.constraints.length; i++) {
            _validateConstraint(self, policyKey, policy.constraints[i], data);
        }
        result = _performCall(target, value, data);
        // Logged once the call succeeded; the organ entry point is nonReentrant.
        // forge-lint: disable-next-line(reentrancy-events)
        emit whitelistedExecution(caller, target, selector, value);
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
        emit collectibleTransferred(caller, to, tokenId);
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
    }

    function receiveCollectible(
        OrganData storage self,
        address operator,
        address from,
        uint256 tokenId
    ) public {
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
    ) public {
        emit coinsReceived(operator, from, to, amount);
    }

    function transferEther(
        OrganData storage self,
        address payable to,
        uint256 amount,
        address from
    ) internal onlyPerm(self, PERMISSION_WITHDRAW_ETHER, from) {
        emit etherTransferred(from, to, amount);
        (bool success, ) = to.call{value: amount}('');
        require(success, 'Transfer failed.');
    }

    function receiveEther(
        OrganData storage self,
        uint256 value,
        address from
    ) public {
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
        bool removed = self.permissionAddresses.remove(permissionAddress);
        assert(removed);
        self.permissions[permissionAddress] = bytes2(0);
        emit permissionRemoved(caller, permissionAddress);
    }

    function addPermission(
        OrganData storage self,
        address permissionAddress,
        bytes2 permissionValue,
        address caller
    ) public onlyPerm(self, PERMISSION_ADD_PERMISSIONS, caller) {
        if (permissionAddress == address(0)) revert ZeroAddress();
        // Check new address is not already there.
        require(
            !self.permissionAddresses.contains(permissionAddress),
            'Duplicate record.'
        );
        // Check new address has permissions.
        require(permissionValue != 0x0000, 'Wrong permissions set.');

        // Store permissions.
        bool added = self.permissionAddresses.add(permissionAddress);
        assert(added);
        self.permissions[permissionAddress] = permissionValue;
        emit permissionAdded(caller, permissionAddress, permissionValue);
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
        if (newPermissionAddress == address(0)) revert ZeroAddress();

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
            _validateEntry(entries[i]);
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
            if (entries[i].addr != address(0)) {
                self.addressIndexInEntries[entries[i].addr] = indexes[i];
            }
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
            if (!_entryExists(self, indexes[i]))
                revert InvalidEntryIndex(indexes[i]);
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
        if (!_entryExists(self, index)) revert InvalidEntryIndex(index);
        _validateEntry(entry);

        address previousAddress = self.entries[index].addr;

        // Check that the replacing address is not already registered elsewhere.
        if (entry.addr != address(0)) {
            require(
                self.addressIndexInEntries[entry.addr] == 0 ||
                    self.addressIndexInEntries[entry.addr] == index,
                'Duplicate record.'
            );
        }
        if (previousAddress != address(0)) {
            self.addressIndexInEntries[previousAddress] = 0;
        }
        emit entryRemoved(caller, index);

        self.entries[index] = entry;

        if (entry.addr != address(0)) {
            self.addressIndexInEntries[entry.addr] = index;
        }
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

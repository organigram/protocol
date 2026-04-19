// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import './libraries/CoreLibrary.sol';

interface IOrgan {
    enum ParamConstraintType {
        NONE,
        EXACT,
        RANGE,
        SELF,
        WHITELISTED_ADDRESS
    }

    struct ParamConstraintInput {
        uint8 index;
        ParamConstraintType constraintType;
        bytes32 minValue;
        bytes32 maxValue;
        bytes32 exactValue;
    }

    /// @notice Initialize a freshly cloned organ.
    /// @param procedures Addresses that receive permissions on the organ.
    /// @param permissions Permission bitmasks aligned with `procedures`.
    /// @param cid Content identifier describing the organ metadata.
    /// @param entries Initial entries stored on the organ.
    /// @param trustedForwarder ERC-2771 forwarder trusted by the organ.
    function initialize(
        address[] memory procedures,
        bytes2[] memory permissions,
        string memory cid,
        CoreLibrary.Entry[] memory entries,
        address trustedForwarder
    ) external;

    /// @notice Update the metadata CID of the organ.
    /// @param cid New content identifier describing the organ.
    function updateCid(string calldata cid) external;

    /// @notice Append entries to the organ directory.
    /// @param entries Entries to append.
    /// @return indexes Indexes assigned to the newly inserted entries.
    function addEntries(
        CoreLibrary.Entry[] memory entries
    ) external returns (uint256[] memory indexes);

    /// @notice Remove entries from the organ directory.
    /// @param indexes Indexes to remove.
    function removeEntries(uint256[] memory indexes) external;

    /// @notice Replace one entry at a fixed index.
    /// @param index Index of the entry to replace.
    /// @param entry New entry payload stored at `index`.
    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    ) external;

    /// @notice Grant permissions to one address or procedure.
    /// @param permissionAddress Address receiving the permission bitmask.
    /// @param permissionValue Permission bitmask to grant.
    function addPermission(
        address permissionAddress,
        bytes2 permissionValue
    ) external;

    /// @notice Remove every permission bit from one address or procedure.
    /// @param permissionAddress Address whose permissions should be removed.
    function removePermission(address permissionAddress) external;

    /// @notice Replace one permission holder with another.
    /// @param oldPermission Address currently holding the permission.
    /// @param newPermission Address that should receive the permission instead.
    /// @param newPermissionValue Permission bitmask assigned to `newPermission`.
    function replacePermission(
        address oldPermission,
        address newPermission,
        bytes2 newPermissionValue
    ) external;

    /// @notice Configure a whitelist policy for an external call path.
    /// @dev Policies are keyed by `target + selector`. Each policy can constrain calldata
    /// arguments with `NONE`, `EXACT`, `RANGE`, `SELF`, or `WHITELISTED_ADDRESS`.
    /// The whitelist is only consulted by constraints that use `WHITELISTED_ADDRESS`.
    /// @param target The external contract the organ may call.
    /// @param selector The function selector allowed on `target`.
    /// @param constraints The calldata constraints that must be satisfied to execute the call.
    /// @param whitelistedAddresses The addresses accepted by whitelist-based constraints.
    function setCallPolicy(
        address target,
        bytes4 selector,
        ParamConstraintInput[] calldata constraints,
        address[] calldata whitelistedAddresses
    ) external;

    /// @notice Remove a previously configured external call policy.
    /// @param target The external contract whose policy should be removed.
    /// @param selector The function selector whose policy should be removed.
    function removeCallPolicy(address target, bytes4 selector) external;

    /// @notice Execute an external call that has been approved by a whitelist policy.
    /// @dev The organ validates the call against the policy configured for `target + selector`
    /// before forwarding the call. Every configured constraint must pass.
    /// @param target The external contract to call.
    /// @param value The amount of native token to forward with the call.
    /// @param data The encoded calldata forwarded to `target`.
    /// @return result The raw return data produced by the external call.
    function executeWhitelisted(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory result);

    /// @notice Return the core summary of the organ.
    /// @return cid Metadata CID currently attached to the organ.
    /// @return permissionsLength Number of permission entries configured on the organ.
    /// @return entriesLength Number of allocated entry slots.
    /// @return entriesCount Number of active entries.
    /// @return interfaceId ERC-165 interface id implemented by the organ.
    function getOrgan()
        external
        view
        returns (
            string memory cid,
            uint256 permissionsLength,
            uint256 entriesLength,
            uint256 entriesCount,
            bytes4 interfaceId
        );

    /// @notice Find the index of one entry address.
    /// @param addr Address stored in the entry.
    /// @return index Index of the entry associated with `addr`.
    function getEntryIndexForAddress(
        address addr
    ) external view returns (uint256 index);

    /// @notice Return one stored entry.
    /// @param index Index of the entry to read.
    /// @return entry Entry payload stored at `index`.
    function getEntry(
        uint256 index
    ) external view returns (CoreLibrary.Entry memory entry);

    /// @notice Return one permission entry by index.
    /// @param index Index of the permission entry to read.
    /// @return addr Address holding the permission.
    /// @return perms Permission bitmask held by `addr`.
    function getPermission(
        uint256 index
    ) external view returns (address addr, bytes2 perms);

    /// @notice Return the permission bitmask assigned to one address.
    /// @param addr Address to inspect.
    /// @return perms Permission bitmask currently assigned to `addr`.
    function getPermissions(address addr) external view returns (bytes2 perms);

    /// @notice Return summary information about a call policy.
    /// @param target The external contract keyed by the policy.
    /// @param selector The function selector keyed by the policy.
    /// @return enabled Whether the policy exists and is active.
    /// @return constraintsLength The number of parameter constraints configured on the policy.
    /// @return whitelistedAddressesLength The number of addresses stored in the policy whitelist.
    function getCallPolicy(
        address target,
        bytes4 selector
    )
        external
        view
        returns (
            bool enabled,
            uint256 constraintsLength,
            uint256 whitelistedAddressesLength
        );

    /// @notice Return one parameter constraint of a call policy.
    /// @param target The external contract keyed by the policy.
    /// @param selector The function selector keyed by the policy.
    /// @param index The position of the constraint inside the policy.
    /// @return paramIndex The zero-based calldata argument index constrained by this rule.
    /// @return constraintType The type of validation applied to that argument.
    /// @return minValue The lower bound used by range constraints.
    /// @return maxValue The upper bound used by range constraints.
    /// @return exactValue The exact value used by exact-match constraints.
    function getCallPolicyConstraint(
        address target,
        bytes4 selector,
        uint256 index
    )
        external
        view
        returns (
            uint8 paramIndex,
            ParamConstraintType constraintType,
            bytes32 minValue,
            bytes32 maxValue,
            bytes32 exactValue
        );

    /// @notice Check whether an address is present in a call policy whitelist.
    /// @param target The external contract keyed by the policy.
    /// @param selector The function selector keyed by the policy.
    /// @param candidate The address to test against the whitelist.
    /// @return True if `candidate` belongs to the whitelist associated with the policy.
    function isCallPolicyWhitelistedAddress(
        address target,
        bytes4 selector,
        address candidate
    ) external view returns (bool);
}

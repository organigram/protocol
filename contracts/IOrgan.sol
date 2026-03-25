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
    function initialize(
        address[] memory procedures,
        bytes2[] memory permissions,
        string memory cid,
        CoreLibrary.Entry[] memory entries,
        address trustedForwarder
    ) external;

    function updateCid(string calldata cid) external;

    function addEntries(
        CoreLibrary.Entry[] memory entries
    ) external returns (uint256[] memory indexes);

    function removeEntries(uint256[] memory indexes) external;

    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    ) external;

    function addPermission(
        address permissionAddress,
        bytes2 permissionValue
    ) external;

    function removePermission(address permissionAddress) external;

    function replacePermission(
        address oldPermission,
        address newPermission,
        bytes2 newPermissionValue
    ) external;

    function setCallPolicy(
        address target,
        bytes4 selector,
        ParamConstraintInput[] calldata constraints,
        address[] calldata whitelistedAddresses
    ) external;

    function removeCallPolicy(address target, bytes4 selector) external;

    function executeWhitelisted(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory result);

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

    function getEntryIndexForAddress(
        address addr
    ) external view returns (uint256 index);

    function getEntry(
        uint256 index
    ) external view returns (CoreLibrary.Entry memory entry);

    function getPermission(
        uint256 index
    ) external view returns (address addr, bytes2 perms);

    function getPermissions(address addr) external view returns (bytes2 perms);

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

    function isCallPolicyWhitelistedAddress(
        address target,
        bytes4 selector,
        address candidate
    ) external view returns (bool);
}

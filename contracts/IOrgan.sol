// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

import './libraries/CoreLibrary.sol';

interface IOrgan {
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
}

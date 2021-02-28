// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libraries/CoreLibrary.sol";

interface IOrgan {
    function initialize(
        address payable admin,
        CoreLibrary.Metadata memory metadata
    ) external;
    function updateMetadata(CoreLibrary.Metadata calldata metadata) external;
    function addEntries(CoreLibrary.Entry[] memory entries) external returns (uint256[] memory indexes);
    function removeEntries(uint256[] memory indexes) external;
    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    ) external;
    function addProcedure(address procedure, bytes2 permissions) external;
    function removeProcedure(address procedure) external;
    function replaceProcedure(
        address oldProcedure,
        address newProcedure,
        bytes2 permissions
    ) external;
    function getOrgan()
        external view
        returns (
            CoreLibrary.Metadata memory metadata,
            uint256 proceduresLength,
            uint256 entriesLength,
            uint256 entriesCount
        );
    function getEntryIndexForAddress(address addr)
        external view
        returns (uint256 index);
    function getEntry(uint256 index)
        external
        view
        returns (CoreLibrary.Entry memory entry);
    function getProcedure(uint256 index)
        external
        view
        returns (address addr, bytes2 perms);
    function getPermissions(address addr)
        external
        view
        returns (bytes2 perms);
} 
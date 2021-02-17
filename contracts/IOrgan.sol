// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libraries/MetadataLibrary.sol";
import "./libraries/OrganLibrary.sol";

interface IOrgan {
    function initialize(
        address payable admin,
        MetadataLibrary.Metadata memory metadata
    ) external;
    function updateMetadata(MetadataLibrary.Metadata calldata metadata) external;
    function addEntries(OrganLibrary.Entry[] memory entries) external returns (uint256[] memory indexes);
    function removeEntries(uint256[] memory indexes) external;
    function replaceEntry(
        uint256 index,
        OrganLibrary.Entry memory entry
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
            MetadataLibrary.Metadata memory metadata,
            uint256 proceduresLength,
            uint256 entriesLength
        );
    function getEntryIndexForAddress(address addr)
        external view
        returns (uint256 index);
    function getEntry(uint256 index)
        external
        view
        returns (OrganLibrary.Entry memory entry);
    function getProcedure(uint256 index)
        external
        view
        returns (address addr, bytes2 perms);
    function getPermissions(address addr)
        external
        view
        returns (bytes2 perms);
} 
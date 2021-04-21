// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./libraries/CoreLibrary.sol";
import "./libraries/OrganLibrary.sol";
import "./IOrgan.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
    An organ contains a list of entries and a set of procedures.
    A procedure is a contract that can effect changes on organs.
    An entry can be a document and/or an address (a wallet or a contract).
*/

contract Organ is
    IOrgan,
    ERC165,
    Initializable,
    IERC777Recipient,
    IERC777Sender,
    IERC721Receiver
{
    using CoreLibrary for CoreLibrary.Metadata;
    using CoreLibrary for CoreLibrary.Entry;
    using OrganLibrary for OrganLibrary.OrganData;

    // Organ data storage.
    OrganLibrary.OrganData internal organData;
    bytes4 constant INTERFACE_ID = type(IOrgan).interfaceId;

    /**
        Organ API.
    */

    constructor()
    {
        organData.init(msg.sender, CoreLibrary.Metadata(0, 0, 0));
    }

    // Register EIP165 interfaces for introspection.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    function initialize(
        address payable admin,
        CoreLibrary.Metadata memory metadata
    )
        external
        initializer
        override
    {
        organData.init(admin, metadata);
    }

    // Assets.

    receive()
        external
        payable
    {
        organData.receiveEther(msg.value);
    }

    // @todo : Protect ether transfers against re-entrancy attacks.
    function transfer(address payable to, uint256 value)
        public
    {
        organData.transferEther(to, value);
    }

    // Implementing ERC-777 receiver interface.
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata, /*data*/
        bytes calldata /*operatorData*/
    )
        external
        override
    {
        organData.receiveCoins(operator, from, to, amount);
    }

    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata, /*userData*/
        bytes calldata /*operatorData*/
    )
        external
        override
    {
        organData.transferCoins(operator, from, to, amount);
    }

    function transferCoins(
        address operator,
        address from,
        address to,
        uint256 amount
    )
        external
    {
        organData.transferCoins(operator, from, to, amount);
    }

    // Implementing ERC-721 receiver interface.
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory /*data*/
    )
        public
        override
        returns (bytes4)
    {
        organData.receiveCollectible(operator, from, tokenId);
        return this.onERC721Received.selector;
    }

    function updateMetadata(CoreLibrary.Metadata calldata metadata)
        external
        override
    {
        organData.updateMetadata(metadata);
    }

    /*
        API for Procedure contract.
    */

    function addEntries(CoreLibrary.Entry[] memory entries)
        external
        override
        returns (uint256[] memory indexes)
    {
        return organData.addEntries(entries);
    }

    function removeEntries(uint256[] memory indexes)
        external
        override
    {
        organData.removeEntries(indexes);
    }

    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    )
        external
        override
    {
        organData.replaceEntry(index, entry);
    }

    // @TODO : Should be plural.
    function addProcedure(address procedure, bytes2 permissions)
        external
        override
    {
        organData.addProcedure(procedure, permissions);
    }

    // @TODO : Should be plural.
    function removeProcedure(address procedure)
        external
        override
    {
        organData.removeProcedure(procedure);
    }

    function replaceProcedure(
        address oldProcedure,
        address newProcedure,
        bytes2 permissions
    )
        external
        override
    {
        organData.replaceProcedure(oldProcedure, newProcedure, permissions);
    }

    /*
        Accessors.
    */

    function getOrgan()
        external
        view
        override
        returns (
            CoreLibrary.Metadata memory metadata,
            uint256 proceduresLength,
            uint256 entriesLength,
            uint256 entriesCount
        )
    {
        return (
            organData.metadata,
            organData.getProceduresLength(),
            organData.entries.length,
            organData.entriesCount
        );
    }

    function getEntryIndexForAddress(address addr)
        external
        view
        override
        returns (uint256 index)
    {
        return organData.addressIndexInEntries[addr];
    }

    function getEntry(uint256 index)
        external
        view
        override
        returns (CoreLibrary.Entry memory entry)
    {
        return organData.getEntry(index);
    }

    function getProcedure(uint256 index)
        external
        view
        override
        returns (address addr, bytes2 perms)
    {
        return organData.getProcedure(index);
    }

    function getPermissions(address addr)
        external
        view
        override
        returns (bytes2 perms)
    {
        return organData.permissions[addr];
    }
}

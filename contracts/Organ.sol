// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libraries/MetadataLibrary.sol";
import "./libraries/OrganLibrary.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
    An organ contains a list of entries and a set of procedures.
    A procedure is a contract that can effect changes on organs.
    An entry can be a document and/or an address (a wallet or a contract).
*/

contract Organ is
    ERC165,
    Initializable,
    IERC777Recipient,
    IERC777Sender,
    IERC721Receiver
{
    using MetadataLibrary for MetadataLibrary.Metadata;
    using OrganLibrary for OrganLibrary.OrganData;
    using OrganLibrary for OrganLibrary.Entry;
    // Organ contract interface.
    bytes4 private constant _INTERFACE_ID_ORGAN = 0xbae78d7b;
    // Organ data storage.
    OrganLibrary.OrganData internal organData;

    /**
        Organ API.
    */

    constructor()
        public
    {
        _registerInterface(_INTERFACE_ID_ORGAN);
        organData.init(msg.sender, MetadataLibrary.Metadata(0, 0, 0));
    }

    function initialize(
        address payable admin,
        MetadataLibrary.Metadata memory metadata
    )
        external
        initializer
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_ID_ORGAN);
        organData.init(admin, metadata);
    }

    // Assets.

    receive()
        external
        payable
    {
        organData.receiveEther(msg.value);
    }

    // @TODO : Protect ether transfers against re-entrancy attacks.
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

    function updateMetadata(MetadataLibrary.Metadata calldata metadata)
        public
    {
        organData.updateMetadata(metadata);
    }

    /*
        API for Procedure contract.
    */

    function addEntries(OrganLibrary.Entry[] memory entries)
        public
        returns (uint256[] memory indexes)
    {
        return organData.addEntries(entries);
    }

    function removeEntries(uint256[] memory indexes)
        public
    {
        organData.removeEntries(indexes);
    }

    function replaceEntry(
        uint256 index,
        OrganLibrary.Entry memory entry
    )
        public
    {
        organData.replaceEntry(index, entry);
    }

    // @TODO : Should be plural.
    function addProcedure(address procedure, bytes2 permissions)
        public
    {
        organData.addProcedure(procedure, permissions);
    }

    // @TODO : Should be plural.
    function removeProcedure(address procedure)
        public
    {
        organData.removeProcedure(procedure);
    }

    function replaceProcedure(
        address oldProcedure,
        address newProcedure,
        bytes2 permissions
    )
        public
    {
        organData.replaceProcedure(oldProcedure, newProcedure, permissions);
    }

    /*
        Accessors.
    */

    function getEntriesLength()
        public
        view
        returns (uint256 length)
    {
        return organData.entries.length;
    }

    function getEntryIndexForAddress(address addr)
        public
        view
        returns (uint256 index)
    {
        return organData.addressIndexInEntries[addr];
    }

    function getEntry(uint256 index)
        public
        view
        returns (OrganLibrary.Entry memory entry)
    {
        return organData.getEntry(index);
    }

    function getProceduresLength()
        public
        view
        returns (uint256 length)
    {
        return organData.getProceduresLength();
    }

    function getProcedure(uint256 index)
        public
        view
        returns (address procedure, bytes2 permissions)
    {
        return organData.getProcedure(index);
    }

    function getPermissions(address procedure)
        public
        view
        returns (bytes2 permissions)
    {
        return organData.getPermissions(procedure);
    }

    function getMetadata()
        public
        view
        returns (MetadataLibrary.Metadata memory metadata)
    {
        return organData.getMetadata();
    }
}

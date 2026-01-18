// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;
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
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@opengsn/contracts/src/ERC2771Recipient.sol";

/// @title Organ contract
/// @author Organigram.ai
/// @notice An organ contains a list of entries, a list of assets (tokens) and a set of procedures. A procedure is a contract that can effect changes on organs. An entry can be a document and/or an address (a wallet or a contract).

contract Organ is
    IOrgan,
    ERC165,
    Initializable,
    IERC777Recipient,
    IERC777Sender,
    IERC721Receiver,
    IERC1155Receiver,
    ERC2771Recipient
{
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
        _disableInitializers();
    }

    // Register EIP165 interfaces for introspection.
    function supportsInterface(bytes4 interfaceId)
        public view
        virtual override(ERC165, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC777Recipient).interfaceId
            || interfaceId == type(IERC777Sender).interfaceId
            || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId
            || interfaceId == INTERFACE_ID
            || super.supportsInterface(interfaceId);
    }

    function initialize(
        address payable admin,
        string memory cid,
        address forwarder
    )
        external
        initializer
        override
    {
        organData.init(admin, cid, _msgSender());
        _setTrustedForwarder(forwarder);
    }

    // Assets.

    receive()
        external
        payable
    {
        organData.receiveEther(msg.value, _msgSender());
    }

    // @todo : Protect ether transfers against re-entrancy attacks.
    function transfer(address payable to, uint256 value)
        public
    {
        organData.transferEther(to, value, _msgSender());
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
        address token,
        address from,
        address to,
        uint256 amount
    )
        external
    {
        organData.transferCoins(token, from, to, amount);
    }

    function transferCollectible(
        address token,
        address from,
        address to,
        uint256 tokenId
    )
        external
    {
        organData.transferCollectible(token, from, to, tokenId);
    }

    // ERC-721 receiver hook.
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

    // ERC-1155 receiver hooks.
    function onERC1155Received(address, address, uint256, uint256, bytes memory)
        public virtual override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public virtual override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function updateCid(string calldata cid)
        external
        override
    {
        organData.updateCid(cid, _msgSender());
    }

    /*
        API for Procedure contract.
    */

    function addEntries(CoreLibrary.Entry[] memory entries)
        external
        override
        returns (uint256[] memory indexes)
    {
        return organData.addEntries(entries, _msgSender());
    }

    function removeEntries(uint256[] memory indexes)
        external
        override
    {
        organData.removeEntries(indexes, _msgSender());
    }

    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    )
        external
        override
    {
        organData.replaceEntry(index, entry, _msgSender());
    }

    // @TODO : Should be plural.
    function addProcedure(address procedure, bytes2 permissions)
        external
        override
    {
        organData.addProcedure(procedure, permissions, _msgSender());
    }

    // @TODO : Should be plural.
    function removeProcedure(address procedure)
        external
        override
    {
        organData.removeProcedure(procedure, _msgSender());
    }

    function replaceProcedure(
        address oldProcedure,
        address newProcedure,
        bytes2 permissions
    )
        external
        override
    {
        organData.replaceProcedure(oldProcedure, newProcedure, permissions, _msgSender());
    }

    /*
        Accessors.
    */

    function getOrgan()
        external
        view
        override
        returns (
            string memory cid,
            uint256 proceduresLength,
            uint256 entriesLength,
            uint256 entriesCount,
            bytes4 interfaceId
        )
    {
        return (
            organData.cid,
            organData.getProceduresLength(),
            organData.entries.length,
            organData.entriesCount,
            INTERFACE_ID
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

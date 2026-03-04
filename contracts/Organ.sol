// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

import './libraries/CoreLibrary.sol';
import './libraries/OrganLibrary.sol';
import './MetaGasStation.sol';
import './IOrgan.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC777.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import {Initializable as InitializableStatic} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/interfaces/IERC777Recipient.sol';
import '@openzeppelin/contracts/interfaces/IERC777Sender.sol';
import '@openzeppelin/contracts/interfaces/IERC721Receiver.sol';
import '@openzeppelin/contracts/interfaces/IERC1155Receiver.sol';

/// @title Organ contract
/// @author Organigram.ai
/// @notice An organ contains a list of entries, a list of assets (tokens) and a set of procedures. A procedure is a contract that can effect changes on organs. An entry can be a document and/or an address (a wallet or a contract).

contract Organ is
    IOrgan,
    ERC165,
    InitializableStatic,
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

    constructor() {
        _disableInitializers();
    }

    // Register EIP165 interfaces for introspection.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC777Recipient).interfaceId ||
            interfaceId == type(IERC777Sender).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == INTERFACE_ID ||
            super.supportsInterface(interfaceId);
    }

    function initialize(
        address[] memory permissionAddresses,
        bytes2[] memory permissionValues,
        string memory cid,
        CoreLibrary.Entry[] memory entries,
        address forwarder
    ) external override initializer {
        organData.init(permissionAddresses, permissionValues, cid, entries);
        _setTrustedForwarder(forwarder);
    }

    // Assets.

    receive() external payable {
        organData.receiveEther(msg.value, _msgSender());
    }

    // @todo : Protect ether transfers against re-entrancy attacks.
    function transfer(address payable to, uint256 value) public {
        organData.transferEther(to, value, _msgSender());
    }

    // Implementing ERC-777 receiver interface.
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata /*data*/,
        bytes calldata /*operatorData*/
    ) external override {
        organData.receiveCoins(operator, from, to, amount);
    }

    function tokensToSend(
        address operator,
        address,
        address to,
        uint256 amount,
        bytes calldata /*userData*/,
        bytes calldata /*operatorData*/
    ) external override {
        organData.transferCoins(_msgSender(), operator, to, amount);
    }

    function transferCoins(
        address token,
        address,
        address to,
        uint256 amount
    ) external {
        organData.transferCoins(token, _msgSender(), to, amount);
    }

    function transferCollectible(
        address token,
        address,
        address to,
        uint256 tokenId
    ) external {
        organData.transferCollectible(token, _msgSender(), to, tokenId);
    }

    // ERC-721 receiver hook.
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory /*data*/
    ) public override returns (bytes4) {
        organData.receiveCollectible(operator, from, tokenId);
        return this.onERC721Received.selector;
    }

    // ERC-1155 receiver hooks.
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function updateCid(string calldata cid) external override {
        organData.updateCid(cid, _msgSender());
    }

    /*
        API for Procedure contract.
    */

    function addEntries(
        CoreLibrary.Entry[] memory entries
    ) external override returns (uint256[] memory indexes) {
        return organData.addEntries(entries, _msgSender());
    }

    function removeEntries(uint256[] memory indexes) external override {
        organData.removeEntries(indexes, _msgSender());
    }

    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    ) external override {
        organData.replaceEntry(index, entry, _msgSender());
    }

    // @TODO : Should be plural.
    function addPermission(
        address permissionAddress,
        bytes2 permissionValue
    ) external override {
        organData.addPermission(
            permissionAddress,
            permissionValue,
            _msgSender()
        );
    }

    // @TODO : Should be plural.
    function removePermission(address permissionAddress) external override {
        organData.removePermission(permissionAddress, _msgSender());
    }

    function replacePermission(
        address oldPermissionAddress,
        address newPermissionAddress,
        bytes2 newPermissionValue
    ) external override {
        organData.replacePermission(
            oldPermissionAddress,
            newPermissionAddress,
            newPermissionValue,
            _msgSender()
        );
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
            uint256 permissionsLength,
            uint256 entriesLength,
            uint256 entriesCount,
            bytes4 interfaceId
        )
    {
        return (
            organData.cid,
            organData.getPermissionsLength(),
            organData.entries.length,
            organData.entriesCount,
            INTERFACE_ID
        );
    }

    function getEntryIndexForAddress(
        address addr
    ) external view override returns (uint256 index) {
        return organData.addressIndexInEntries[addr];
    }

    function getEntry(
        uint256 index
    ) external view override returns (CoreLibrary.Entry memory entry) {
        return organData.getEntry(index);
    }

    function getPermission(
        uint256 index
    ) external view override returns (address addr, bytes2 perms) {
        return organData.getPermission(index);
    }

    function getPermissions(
        address addr
    ) external view override returns (bytes2 perms) {
        return organData.permissions[addr];
    }
}

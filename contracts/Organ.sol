// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import './libraries/CoreLibrary.sol';
import './libraries/OrganLibrary.sol';
import './MetaGasStation.sol';
import './IOrgan.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
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
    ReentrancyGuard,
    ERC2771Recipient
{
    using CoreLibrary for CoreLibrary.Entry;
    using OrganLibrary for OrganLibrary.OrganData;
    using EnumerableSet for EnumerableSet.AddressSet;

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

    /// @inheritdoc IOrgan
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

    function transferEther(address payable to, uint256 value) public nonReentrant {
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
    ) external nonReentrant {
        organData.transferCoins(token, _msgSender(), to, amount);
    }

    function transferCollectible(
        address token,
        address,
        address to,
        uint256 tokenId
    ) external nonReentrant {
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

    /// @inheritdoc IOrgan
    function updateCid(string calldata cid) external override {
        organData.updateCid(cid, _msgSender());
    }

    /*
        API for Procedure contract.
    */

    /// @inheritdoc IOrgan
    function addEntries(
        CoreLibrary.Entry[] memory entries
    ) external override returns (uint256[] memory indexes) {
        return organData.addEntries(entries, _msgSender());
    }

    /// @inheritdoc IOrgan
    function removeEntries(uint256[] memory indexes) external override {
        organData.removeEntries(indexes, _msgSender());
    }

    /// @inheritdoc IOrgan
    function replaceEntry(
        uint256 index,
        CoreLibrary.Entry memory entry
    ) external override {
        organData.replaceEntry(index, entry, _msgSender());
    }

    // @TODO : Should be plural.
    /// @inheritdoc IOrgan
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
    /// @inheritdoc IOrgan
    function removePermission(address permissionAddress) external override {
        organData.removePermission(permissionAddress, _msgSender());
    }

    /// @inheritdoc IOrgan
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

    /// @inheritdoc IOrgan
    function setCallPolicy(
        address target,
        bytes4 selector,
        IOrgan.ParamConstraintInput[] calldata constraints,
        address[] calldata whitelistedAddresses
    ) external override {
        uint256 constraintsLength = constraints.length;
        OrganLibrary.ParamConstraint[] memory converted = new OrganLibrary.ParamConstraint[](constraintsLength);
        for (uint256 i = 0; i < constraintsLength; i++) {
            converted[i] = OrganLibrary.ParamConstraint({
                index: constraints[i].index,
                constraintType: OrganLibrary.ParamConstraintType(uint8(constraints[i].constraintType)),
                minValue: constraints[i].minValue,
                maxValue: constraints[i].maxValue,
                exactValue: constraints[i].exactValue
            });
        }
        organData.setCallPolicy(
            target,
            selector,
            converted,
            whitelistedAddresses,
            _msgSender()
        );
    }

    /// @inheritdoc IOrgan
    function removeCallPolicy(address target, bytes4 selector) external override {
        organData.removeCallPolicy(target, selector, _msgSender());
    }

    /// @inheritdoc IOrgan
    function executeWhitelisted(
        address target,
        uint256 value,
        bytes calldata data
    ) external override nonReentrant returns (bytes memory result) {
        return organData.executeWhitelisted(target, value, data, _msgSender());
    }

    /*
        Accessors.
    */

    /// @inheritdoc IOrgan
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

    /// @inheritdoc IOrgan
    function getEntryIndexForAddress(
        address addr
    ) external view override returns (uint256 index) {
        return organData.addressIndexInEntries[addr];
    }

    /// @inheritdoc IOrgan
    function getEntry(
        uint256 index
    ) external view override returns (CoreLibrary.Entry memory entry) {
        return organData.getEntry(index);
    }

    /// @inheritdoc IOrgan
    function getPermission(
        uint256 index
    ) external view override returns (address addr, bytes2 perms) {
        (addr, perms) = organData.getPermission(index);
        return (addr, perms);
    }

    /// @inheritdoc IOrgan
    function getPermissions(
        address addr
    ) external view override returns (bytes2 perms) {
        return organData.permissions[addr];
    }

    /// @inheritdoc IOrgan
    function getCallPolicy(
        address target,
        bytes4 selector
    )
        external
        view
        override
        returns (
            bool enabled,
            uint256 constraintsLength,
            uint256 whitelistedAddressesLength
        )
    {
        bytes32 policyKey = OrganLibrary._callPolicyKey(target, selector);
        OrganLibrary.CallPolicy storage policy = organData.callPolicies[policyKey];
        return (
            policy.enabled,
            policy.constraints.length,
            organData.callPolicyWhitelistedAddresses[policyKey].length()
        );
    }

    /// @inheritdoc IOrgan
    function getCallPolicyConstraint(
        address target,
        bytes4 selector,
        uint256 index
    )
        external
        view
        override
        returns (
            uint8 paramIndex,
            IOrgan.ParamConstraintType constraintType,
            bytes32 minValue,
            bytes32 maxValue,
            bytes32 exactValue
        )
    {
        bytes32 policyKey = OrganLibrary._callPolicyKey(target, selector);
        OrganLibrary.ParamConstraint storage constraint = organData.callPolicies[policyKey].constraints[index];
        return (
            constraint.index,
            IOrgan.ParamConstraintType(uint8(constraint.constraintType)),
            constraint.minValue,
            constraint.maxValue,
            constraint.exactValue
        );
    }

    /// @inheritdoc IOrgan
    function isCallPolicyWhitelistedAddress(
        address target,
        bytes4 selector,
        address candidate
    ) external view override returns (bool) {
        bytes32 policyKey = OrganLibrary._callPolicyKey(target, selector);
        return organData.callPolicyWhitelistedAddresses[policyKey].contains(candidate);
    }
}

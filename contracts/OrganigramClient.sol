// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import {Organ} from './Organ.sol';
import {Asset} from './Asset.sol';
import {IAsset} from './IAsset.sol';
import {EquityToken} from './EquityToken.sol';
import {ERC2771Recipient} from './MetaGasStation.sol';
import {CoreLibrary} from './libraries/CoreLibrary.sol';
import {ERC165Checker} from '@openzeppelin/contracts/utils/introspection/ERC165Checker.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';

/// @title Organigram client
/// @notice Entry point of the protocol on a chain: the registry of procedure types, and the factory of organs,
/// assets and procedures, deployed as clones of their implementations.
contract OrganigramClient is ERC2771Recipient {
    using CoreLibrary for CoreLibrary.Entry;
    address payable private immutable ORGAN; // Cloneable organ implementation.
    address payable private immutable ASSET; // Cloneable asset implementation.
    address payable private immutable EQUITY_TOKEN; // Cloneable equity implementation.
    address payable private immutable PROCEDURES_REGISTRY; // Organ with the addresses of supported procedures implementations.
    address private immutable OWNER;

    /// @notice An organ was deployed.
    event organDeployed(address payable organ);
    /// @notice An asset was deployed.
    event assetDeployed(address payable asset);
    /// @notice A procedure was deployed from a registered procedure type.
    event procedureDeployed(
        address payable procedureType,
        address payable procedure
    );

    /// @notice Implementation that organs are cloned from.
    function organ() external view returns (address payable) {
        return ORGAN;
    }

    /// @notice Implementation that assets are cloned from.
    function asset() external view returns (address payable) {
        return ASSET;
    }

    /// @notice Implementation that equity tokens are cloned from.
    function equityToken() external view returns (address payable) {
        return EQUITY_TOKEN;
    }

    /// @notice Organ listing the registered procedure types.
    function proceduresRegistry() external view returns (address payable) {
        return PROCEDURES_REGISTRY;
    }

    /// @notice Account allowed to register procedure types.
    function owner() external view returns (address) {
        return OWNER;
    }

    struct DeployOrganArgs {
        address[] permissionAddresses;
        bytes2[] permissionValues;
        string cid;
        CoreLibrary.Entry[] entries;
        bytes32 salt;
    }
    struct DeployProcedureArgs {
        address payable procedureType;
        bytes data;
        bytes32 salt;
    }
    struct DeployAssetArgs {
        string name;
        string symbol;
        uint256 initialSupply;
        bytes32 salt;
        bool isEquity;
        address transferProcedure;
    }

    /// @dev Clone addresses depend on the caller, so that nobody can deploy
    /// first at an address another account predicted with the same salt.
    function _callerSalt(bytes32 salt) internal view returns (bytes32) {
        return keccak256(abi.encode(_msgSender(), salt));
    }

    /// @notice Deploy the client contract together with default organ and asset implementations.
    /// @param cid Metadata CID assigned to the internal procedures registry organ.
    /// @param trustedForwarder ERC-2771 forwarder trusted by freshly deployed clones.
    /// @param salt Deterministic salt used to deploy the procedures registry organ.
    constructor(string memory cid, address trustedForwarder, bytes32 salt) {
        _setTrustedForwarder(trustedForwarder);
        OWNER = _msgSender();
        ORGAN = payable(address(new Organ()));
        ASSET = payable(address(new Asset()));
        EQUITY_TOKEN = payable(address(new EquityToken()));

        // Create permissions arguments for the procedures registry organ.
        address[] memory permissionAddresses = new address[](2);
        bytes2[] memory permissionValues = new bytes2[](2);

        permissionAddresses[0] = OWNER; // Set the sender as default admin...
        permissionValues[0] = bytes2(0xffff); // ...with all permissions.
        permissionAddresses[1] = address(this); // Allow controlled registry updates via registerProcedures().
        permissionValues[1] = bytes2(0x0004); // PERMISSION_ADD_ENTRIES.

        CoreLibrary.Entry[] memory emptyEntries = new CoreLibrary.Entry[](0);

        PROCEDURES_REGISTRY = deployOrgan(
            permissionAddresses,
            permissionValues,
            cid,
            emptyEntries,
            salt
        );
    }

    /// @notice Deploy a single organ clone and initialize it.
    /// @param _permissionAddresses Addresses receiving permissions on the organ.
    /// @param _permissionValues Permission bitmasks aligned with `_permissionAddresses`.
    /// @param cid Metadata CID assigned to the deployed organ.
    /// @param entries Initial entries stored on the organ.
    /// @param salt Deterministic clone salt.
    /// @return clone Address of the deployed organ clone.
    function deployOrgan(
        address[] memory _permissionAddresses,
        bytes2[] memory _permissionValues,
        string memory cid,
        CoreLibrary.Entry[] memory entries,
        bytes32 salt
    ) public returns (address payable clone) {
        require(
            _permissionAddresses.length == _permissionValues.length,
            'LengthMismatch'
        );

        // If no permissions are provided, set the sender as admin with all permissions.
        if (_permissionAddresses.length == 0) {
            _permissionAddresses = new address[](1);
            _permissionValues = new bytes2[](1);
            _permissionAddresses[0] = _msgSender();
            _permissionValues[0] = bytes2(0xffff);
        }

        // Clone organ and initialize it.
        clone = payable(Clones.cloneDeterministic(ORGAN, _callerSalt(salt)));
        Organ(clone).initialize(
            _permissionAddresses,
            _permissionValues,
            cid,
            entries,
            trustedForwarder()
        );
        // Emitted after initializing a clone of a trusted implementation.
        // forge-lint: disable-next-line(reentrancy-events)
        emit organDeployed(clone);
        return clone;
    }

    /// @notice Deploy several organ clones in one call.
    /// @param batch Organ deployment payloads.
    /// @return clones Addresses of the deployed organ clones.
    function deployOrgans(
        DeployOrganArgs[] memory batch
    ) public returns (address payable[] memory clones) {
        clones = new address payable[](batch.length);

        for (uint256 i = 0; i < batch.length; i++) {
            clones[i] = deployOrgan(
                batch[i].permissionAddresses,
                batch[i].permissionValues,
                batch[i].cid,
                batch[i].entries,
                batch[i].salt
            );
        }
        return clones;
    }

    /// @notice Deploy a single asset clone and initialize it as an ERC-20 token.
    /// @param name Token name.
    /// @param symbol Token symbol.
    /// @param initialSupply Initial token supply minted to the caller.
    /// @param salt Deterministic clone salt.
    /// @return clone Address of the deployed asset clone.
    function deployAsset(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        bytes32 salt
    ) public returns (address payable clone) {
        clone = payable(
            Clones.cloneDeterministic(address(ASSET), _callerSalt(salt))
        );
        IAsset(clone).initialize(name, symbol, _msgSender(), initialSupply);

        // Emitted after initializing a clone of a trusted implementation.
        // forge-lint: disable-next-line(reentrancy-events)
        emit assetDeployed(clone);
        return clone;
    }

    /// @notice Deploy several asset clones in one call.
    /// @param batch Asset deployment payloads.
    /// @return clones Addresses of the deployed asset clones.
    function deployAssets(
        DeployAssetArgs[] memory batch
    ) public returns (address payable[] memory clones) {
        clones = new address payable[](batch.length);

        for (uint256 i = 0; i < batch.length; i++) {
            if (batch[i].isEquity) {
                require(
                    batch[i].transferProcedure != address(0),
                    'Transfer procedure required.'
                );
                clones[i] = payable(
                    Clones.cloneDeterministic(
                        address(EQUITY_TOKEN),
                        _callerSalt(batch[i].salt)
                    )
                );
                EquityToken(clones[i]).initialize(
                    batch[i].name,
                    batch[i].symbol,
                    _msgSender(),
                    batch[i].initialSupply,
                    batch[i].transferProcedure
                );
                // Emitted after initializing a clone of a trusted implementation.
                // forge-lint: disable-next-line(reentrancy-events)
                emit assetDeployed(clones[i]);
            } else {
                clones[i] = deployAsset(
                    batch[i].name,
                    batch[i].symbol,
                    batch[i].initialSupply,
                    batch[i].salt
                );
            }
        }
        return clones;
    }

    /// @notice Deploy one procedure clone from a registered procedure implementation.
    /// @param procedureType Registered procedure implementation to clone.
    /// @param data Optional initialization calldata executed immediately after deployment.
    /// @param salt Deterministic clone salt.
    /// @return procedure Address of the deployed procedure clone.
    function deployProcedure(
        address payable procedureType,
        bytes memory data,
        bytes32 salt
    ) public returns (address payable procedure) {
        require(data.length > 0, 'Missing initialization data.');
        require(
            ERC165Checker.supportsInterface(procedureType, 0x71dbd330),
            'Not a procedure.'
        );
        require(
            Organ(PROCEDURES_REGISTRY).getEntryIndexForAddress(procedureType) >
                0,
            'Procedure not found.'
        );
        procedure = payable(
            Clones.cloneDeterministic(procedureType, _callerSalt(salt))
        );
        // Only the registry and ERC-165 view calls precede the event.
        // forge-lint: disable-next-line(reentrancy-events)
        emit procedureDeployed(procedureType, procedure);
        bytes memory initReturnData = Address.functionCall(procedure, data);
        require(
            initReturnData.length == 0,
            'Unexpected initialization result.'
        );
        return procedure;
    }

    /// @notice Deploy several procedure clones in one call.
    /// @param batch Procedure deployment payloads.
    /// @return created Addresses of the deployed procedure clones.
    function deployProcedures(
        DeployProcedureArgs[] memory batch
    ) public returns (address payable[] memory created) {
        created = new address payable[](batch.length);

        for (uint256 i = 0; i < batch.length; i++) {
            created[i] = deployProcedure(
                batch[i].procedureType,
                batch[i].data,
                batch[i].salt
            );
        }
        return created;
    }

    /// @notice Deploy a complete organigram in one transaction.
    /// @param organBatch Organ deployment payloads.
    /// @param assetBatch Asset deployment payloads.
    /// @param procedureBatch Procedure deployment payloads.
    /// @return organsDeployed Addresses of the deployed organs.
    /// @return assetsDeployed Addresses of the deployed assets.
    /// @return proceduresDeployed Addresses of the deployed procedures.
    function deployOrganigram(
        DeployOrganArgs[] memory organBatch,
        DeployAssetArgs[] memory assetBatch,
        DeployProcedureArgs[] memory procedureBatch
    )
        public
        returns (
            address payable[] memory organsDeployed,
            address payable[] memory assetsDeployed,
            address payable[] memory proceduresDeployed
        )
    {
        organsDeployed = deployOrgans(organBatch);
        assetsDeployed = deployAssets(assetBatch);
        proceduresDeployed = deployProcedures(procedureBatch);
        return (organsDeployed, assetsDeployed, proceduresDeployed);
    }

    /// @notice Register supported procedure implementations in the procedures registry.
    /// @param entries Registry entries that point to valid procedure implementations.
    function registerProcedures(CoreLibrary.Entry[] memory entries) external {
        require(_msgSender() == OWNER, 'Not authorized.');
        // Only valid procedures
        for (uint256 i; i < entries.length; ++i) {
            require(
                ERC165Checker.supportsInterface(entries[i].addr, 0x71dbd330),
                'An entry in parameters is not a valid procedure.'
            );
        }
        uint256[] memory indexes = Organ(PROCEDURES_REGISTRY).addEntries(
            entries
        );
        require(indexes.length == entries.length, 'Registry update failed.');
    }
}

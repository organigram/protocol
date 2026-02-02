// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

import './Organ.sol';
import './Asset.sol';
import './MetaGasStation.sol';
import './libraries/CoreLibrary.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165Checker.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract OrganigramClient is ERC2771Recipient {
    using CoreLibrary for CoreLibrary.Entry;
    address payable public organ; // Cloneable organ implementation.
    address payable public proceduresRegistry; // Organ with the addresses of supported procedures implementations.

    event organCreated(address payable organ);
    event assetCreated(address payable asset);
    event procedureCreated(
        address payable procedureType,
        address payable procedure
    );

    struct CreateOrganArgs {
        address[] permissionAddresses;
        bytes2[] permissionValues;
        string cid;
        bytes32 salt;
    }
    struct CreateProcedureArgs {
        address payable procedureType;
        bytes data;
        bytes32 salt;
    }

    struct CreateAssetArgs {
        string name;
        string symbol;
        uint256 initialSupply;
        bytes32 salt;
    }

    constructor(string memory cid, address trustedForwarder, bytes32 salt) {
        _setTrustedForwarder(trustedForwarder);
        organ = payable(address(new Organ()));

        // Create permissions arguments for the procedures registry organ.
        address[] memory permissionAddresses = new address[](1);
        bytes2[] memory permissionValues = new bytes2[](1);
        permissionAddresses[0] = _msgSender(); // Set the sender as default admin...
        permissionValues[0] = bytes2(0xffff); // ...with all permissions.

        proceduresRegistry = createOrgan(
            permissionAddresses,
            permissionValues,
            cid,
            salt
        );
    }

    function createOrgan(
        address[] memory _permissionAddresses,
        bytes2[] memory _permissionValues,
        string memory cid,
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
        clone = payable(Clones.cloneDeterministic(organ, salt));
        Organ(clone).initialize(
            _permissionAddresses,
            _permissionValues,
            cid,
            trustedForwarder()
        );
        emit organCreated(clone);
        return clone;
    }

    function createOrgans(
        CreateOrganArgs[] memory batch
    ) public returns (address payable[] memory clones) {
        clones = new address payable[](batch.length);

        for (uint256 i = 0; i < batch.length; i++) {
            clones[i] = createOrgan(
                batch[i].permissionAddresses,
                batch[i].permissionValues,
                batch[i].cid,
                batch[i].salt
            );
        }
        return clones;
    }

    function createAsset(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        bytes32 salt
    ) public returns (address payable clone) {
        Asset asset = new Asset(name, symbol, initialSupply);
        clone = payable(Clones.cloneDeterministic(address(asset), salt));

        emit assetCreated(clone);
        return clone;
    }

    function createAssets(
        CreateAssetArgs[] memory batch
    ) public returns (address payable[] memory clones) {
        clones = new address payable[](batch.length);

        for (uint256 i = 0; i < batch.length; i++) {
            clones[i] = createAsset(
                batch[i].name,
                batch[i].symbol,
                batch[i].initialSupply,
                batch[i].salt
            );
        }
        return clones;
    }

    function createProcedure(
        address payable procedureType,
        bytes memory data,
        bytes32 salt
    ) public returns (address payable procedure) {
        require(
            ERC165Checker.supportsInterface(procedureType, 0x71dbd330),
            'Not a procedure.'
        );
        require(
            Organ(proceduresRegistry).getEntryIndexForAddress(procedureType) >
                0,
            'Procedure not found.'
        );
        procedure = payable(Clones.cloneDeterministic(procedureType, salt));
        emit procedureCreated(procedureType, procedure);
        // NB: The initialize method will need to be called immediately
        // if not through the data parameter.
        if (data.length > 0) {
            Address.functionCall(procedure, data);
        }
        return procedure;
    }

    function createProcedures(
        CreateProcedureArgs[] memory batch
    ) public returns (address payable[] memory created) {
        created = new address payable[](batch.length);

        for (uint256 i = 0; i < batch.length; i++) {
            created[i] = createProcedure(
                batch[i].procedureType,
                batch[i].data,
                batch[i].salt
            );
        }
        return created;
    }

    function deployOrganigram(
        CreateOrganArgs[] memory organBatch,
        CreateAssetArgs[] memory assetBatch,
        CreateProcedureArgs[] memory procedureBatch
    )
        public
        returns (
            address payable[] memory organsCreated,
            address payable[] memory assetsCreated,
            address payable[] memory proceduresCreated
        )
    {
        organsCreated = createOrgans(organBatch);
        assetsCreated = createAssets(assetBatch);
        proceduresCreated = createProcedures(procedureBatch);
        return (organsCreated, assetsCreated, proceduresCreated);
    }

    function registerProcedures(CoreLibrary.Entry[] memory entries) external {
        // Only valid procedures
        for (uint256 i; i < entries.length; ++i) {
            require(
                ERC165Checker.supportsInterface(entries[i].addr, 0x71dbd330),
                'An entry in parameters is not a valid procedure.'
            );
        }
        Organ(proceduresRegistry).addEntries(entries);
    }
}

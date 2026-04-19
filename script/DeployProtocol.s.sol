// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CoreLibrary} from "../contracts/libraries/CoreLibrary.sol";
import {Organ} from "../contracts/Organ.sol";
import {Asset} from "../contracts/Asset.sol";
import {NominationProcedure} from "../contracts/procedures/Nomination.sol";
import {VoteProcedure} from "../contracts/procedures/Vote.sol";
import {ERC20VoteProcedure} from "../contracts/procedures/ERC20Vote.sol";
import {OrganigramClient} from "../contracts/OrganigramClient.sol";
import {MetaGasStation} from "../contracts/MetaGasStation.sol";

interface Vm {
    function envOr(string calldata name, bytes32 defaultValue) external view returns (bytes32 value);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployProtocolScript {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Deployment {
        Asset asset;
        Organ organ;
        NominationProcedure nominationProcedure;
        VoteProcedure voteProcedure;
        ERC20VoteProcedure erc20VoteProcedure;
        OrganigramClient organigramClient;
        Organ proceduresRegistry;
        MetaGasStation metaGasStation;
    }

    function run() external returns (Deployment memory deployment) {
        bytes32 proceduresRegistrySalt = vm.envOr("PROCEDURES_REGISTRY_SALT", bytes32(0));

        vm.startBroadcast();

        deployment.metaGasStation = new MetaGasStation("Organigram MetaGasStation");
        deployment.asset = new Asset();
        deployment.organ = new Organ();
        deployment.nominationProcedure = new NominationProcedure();
        deployment.voteProcedure = new VoteProcedure();
        deployment.erc20VoteProcedure = new ERC20VoteProcedure();
        deployment.organigramClient =
            new OrganigramClient("procedures-registry", address(deployment.metaGasStation), proceduresRegistrySalt);
        deployment.proceduresRegistry = Organ(deployment.organigramClient.proceduresRegistry());

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](3);
        entries[0] = CoreLibrary.Entry(address(deployment.nominationProcedure), "nomination");
        entries[1] = CoreLibrary.Entry(address(deployment.voteProcedure), "vote");
        entries[2] = CoreLibrary.Entry(address(deployment.erc20VoteProcedure), "erc20Vote");
        deployment.proceduresRegistry.addEntries(entries);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import '../contracts/Asset.sol';
import '../contracts/Organ.sol';
import '../contracts/OrganigramClient.sol';
import '../contracts/Procedure.sol';
import '../contracts/libraries/CoreLibrary.sol';
import '../contracts/libraries/ProcedureLibrary.sol';
import '../contracts/procedures/ERC20Vote.sol';
import '../contracts/procedures/Nomination.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';

interface Vm {
    function deal(address account, uint256 newBalance) external;
    function expectRevert() external;
    function expectRevert(bytes calldata revertData) external;
    function prank(address account) external;
    function roll(uint256 newHeight) external;
    function warp(uint256 newTimestamp) external;
}

contract ReentrantEtherReceiver {
    Organ private immutable organ;
    address payable private immutable target;
    bool private entered;
    bool public blocked;
    bool public reentered;

    constructor(Organ organ_, address payable target_) {
        organ = organ_;
        target = target_;
    }

    receive() external payable {
        if (entered) return;
        entered = true;

        try organ.transferEther(target, 1 wei) {
            reentered = true;
        } catch {
            blocked = true;
        }
    }
}

contract SelfTargetProcedure is Procedure {
    bool public marked;

    function markExecuted() external {
        require(msg.sender == address(this), 'Not self.');
        marked = true;
    }

    function adopt(uint256 proposalKey) external {
        _adoptProposal(proposalKey);
    }
}

contract ProtocolSecurityTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA201);
    address private constant RELAYER = address(0xDEC0DE);
    bytes32 private constant SALT = keccak256('security-test-salt');

    receive() external payable {}

    function testOrganBlocksReentrantEtherWithdrawal() public {
        Organ organ = _deployOrgan();
        vm.deal(address(this), 3 ether);

        (bool deposited, ) = payable(address(organ)).call{value: 2 ether}('');
        require(deposited, 'Deposit failed.');

        ReentrantEtherReceiver receiver = new ReentrantEtherReceiver(organ, payable(CAROL));
        organ.addPermission(address(receiver), bytes2(0x0040));

        organ.transferEther(payable(address(receiver)), 1 ether);

        require(receiver.blocked(), 'Reentrant withdrawal was not blocked.');
        require(!receiver.reentered(), 'Reentrant withdrawal succeeded.');
        require(address(organ).balance == 1 ether, 'Unexpected organ balance.');
    }

    function testEntryReplacementAndRemovalInvariants() public {
        Organ organ = _deployOrgan();

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](2);
        entries[0] = CoreLibrary.Entry(ALICE, 'alice');
        entries[1] = CoreLibrary.Entry(BOB, 'bob');
        uint256[] memory indexes = organ.addEntries(entries);

        organ.replaceEntry(indexes[0], CoreLibrary.Entry(CAROL, 'carol'));
        require(organ.getEntryIndexForAddress(ALICE) == 0, 'Old address still indexed.');
        require(organ.getEntryIndexForAddress(CAROL) == indexes[0], 'New address not indexed.');

        vm.expectRevert();
        organ.replaceEntry(indexes[0], CoreLibrary.Entry(BOB, 'duplicate'));

        vm.expectRevert();
        organ.replaceEntry(indexes[0], CoreLibrary.Entry(address(0), ''));

        uint256[] memory removeIndexes = new uint256[](1);
        removeIndexes[0] = indexes[0];
        organ.removeEntries(removeIndexes);

        (, , , uint256 entriesCount, ) = organ.getOrgan();
        require(entriesCount == 1, 'Active entry count mismatch.');

        vm.expectRevert();
        organ.removeEntries(removeIndexes);

        CoreLibrary.Entry[] memory emptyEntries = new CoreLibrary.Entry[](1);
        emptyEntries[0] = CoreLibrary.Entry(address(0), '');

        vm.expectRevert();
        organ.addEntries(emptyEntries);
    }

    function testInitialEntriesAreCounted() public {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](2);
        entries[0] = CoreLibrary.Entry(ALICE, 'alice');
        entries[1] = CoreLibrary.Entry(BOB, 'bob');

        Organ organ = _deployOrganWithEntries(entries);

        (, , uint256 entriesLength, uint256 entriesCount, ) = organ.getOrgan();
        require(entriesLength == 3, 'Unexpected entries length.');
        require(entriesCount == 2, 'Initial entries were not counted.');
    }

    function testZeroTargetProposalExecutesOnProcedureItself() public {
        SelfTargetProcedure procedure = _deploySelfTargetProcedure();
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(0)),
            data: abi.encodeCall(SelfTargetProcedure.markExecuted, ()),
            value: 0,
            processed: false
        });

        uint256 proposalKey = procedure.propose('self-call', operations);
        procedure.adopt(proposalKey);

        require(procedure.marked(), 'Self-target operation was not executed.');
    }

    function testClientRequiresInitializedProcedureClone() public {
        OrganigramClient client = new OrganigramClient('registry', address(0), SALT);
        NominationProcedure implementation = new NominationProcedure();

        vm.expectRevert(bytes('Missing initialization data.'));
        client.deployProcedure(payable(address(implementation)), '', keccak256('missing-init'));
    }

    function testOnlyClientOwnerCanRegisterProcedures() public {
        OrganigramClient client = new OrganigramClient('registry', address(0), SALT);
        NominationProcedure implementation = new NominationProcedure();
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(address(implementation), 'nomination');

        vm.prank(RELAYER);
        vm.expectRevert(bytes('Not authorized.'));
        client.registerProcedures(entries);

        client.registerProcedures(entries);
        require(
            Organ(client.proceduresRegistry()).getEntryIndexForAddress(address(implementation)) > 0,
            'Procedure was not registered.'
        );
    }

    function testERC20VoteUsesSnapshotInsteadOfCurrentBalance() public {
        Asset token = _deployAsset(100 ether);
        vm.roll(10);
        token.delegate(address(this));
        vm.roll(11);

        ERC20VoteProcedure procedure = _deployERC20VoteProcedure(token);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);

        vm.warp(1000);
        uint256 proposalKey = procedure.propose('snapshot-vote', operations);
        require(token.transfer(BOB, 100 ether), 'Token transfer failed.');

        vm.warp(1001);
        vm.prank(BOB);
        procedure.vote(proposalKey, true);
        procedure.vote(proposalKey, false);

        vm.warp(1011);
        require(!procedure.count(proposalKey), 'Current token balances influenced the vote.');
    }

    function _deployOrgan() private returns (Organ organ) {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](0);
        return _deployOrganWithEntries(entries);
    }

    function _deployOrganWithEntries(
        CoreLibrary.Entry[] memory entries
    ) private returns (Organ organ) {
        Organ implementation = new Organ();
        organ = Organ(payable(Clones.clone(address(implementation))));

        address[] memory permissionAddresses = new address[](1);
        permissionAddresses[0] = address(this);
        bytes2[] memory permissionValues = new bytes2[](1);
        permissionValues[0] = bytes2(0xffff);

        organ.initialize(permissionAddresses, permissionValues, 'organ', entries, address(0));
    }

    function _deployAsset(uint256 supply) private returns (Asset token) {
        Asset implementation = new Asset();
        token = Asset(Clones.clone(address(implementation)));
        token.initialize('Vote Token', 'VOTE', address(this), supply);
    }

    function _deployERC20VoteProcedure(
        Asset token
    ) private returns (ERC20VoteProcedure procedure) {
        ERC20VoteProcedure implementation = new ERC20VoteProcedure();
        procedure = ERC20VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            'erc20-vote',
            payable(address(0)),
            payable(address(0)),
            payable(address(0)),
            false,
            address(0),
            0,
            10,
            50000,
            address(token)
        );
    }

    function _deploySelfTargetProcedure() private returns (SelfTargetProcedure procedure) {
        SelfTargetProcedure implementation = new SelfTargetProcedure();
        procedure = SelfTargetProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            'self-target',
            payable(address(0)),
            payable(address(0)),
            payable(address(0)),
            false,
            address(0)
        );
    }
}

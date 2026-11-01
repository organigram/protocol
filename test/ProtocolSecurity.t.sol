// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/Asset.sol";
import "../contracts/Organ.sol";
import "../contracts/OrganigramClient.sol";
import "../contracts/Procedure.sol";
import "../contracts/libraries/CoreLibrary.sol";
import "../contracts/libraries/ProcedureLibrary.sol";
import "../contracts/procedures/ERC20Vote.sol";
import "../contracts/procedures/Nomination.sol";
import "../contracts/procedures/Vote.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

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
        require(msg.sender == address(this), "Not self.");
        marked = true;
    }

    function adopt(uint256 proposalKey) external {
        _adoptProposal(proposalKey);
    }
}

contract ProtocolSecurityTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA201);
    address private constant RELAYER = address(0xDEC0DE);
    bytes32 private constant SALT = keccak256("security-test-salt");

    receive() external payable {}

    function testOrganBlocksReentrantEtherWithdrawal() public {
        Organ organ = _deployOrgan();
        vm.deal(address(this), 3 ether);

        (bool deposited,) = payable(address(organ)).call{value: 2 ether}("");
        require(deposited, "Deposit failed.");

        ReentrantEtherReceiver receiver = new ReentrantEtherReceiver(organ, payable(CAROL));
        organ.addPermission(address(receiver), bytes2(0x0040));

        organ.transferEther(payable(address(receiver)), 1 ether);

        require(receiver.blocked(), "Reentrant withdrawal was not blocked.");
        require(!receiver.reentered(), "Reentrant withdrawal succeeded.");
        require(address(organ).balance == 1 ether, "Unexpected organ balance.");
    }

    function testEntryReplacementAndRemovalInvariants() public {
        Organ organ = _deployOrgan();

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](2);
        entries[0] = CoreLibrary.Entry(ALICE, "alice");
        entries[1] = CoreLibrary.Entry(BOB, "bob");
        uint256[] memory indexes = organ.addEntries(entries);

        organ.replaceEntry(indexes[0], CoreLibrary.Entry(CAROL, "carol"));
        require(organ.getEntryIndexForAddress(ALICE) == 0, "Old address still indexed.");
        require(organ.getEntryIndexForAddress(CAROL) == indexes[0], "New address not indexed.");

        vm.expectRevert();
        organ.replaceEntry(indexes[0], CoreLibrary.Entry(BOB, "duplicate"));

        vm.expectRevert();
        organ.replaceEntry(indexes[0], CoreLibrary.Entry(address(0), ""));

        uint256[] memory removeIndexes = new uint256[](1);
        removeIndexes[0] = indexes[0];
        organ.removeEntries(removeIndexes);

        (,,, uint256 entriesCount,) = organ.getOrgan();
        require(entriesCount == 1, "Active entry count mismatch.");

        vm.expectRevert();
        organ.removeEntries(removeIndexes);

        CoreLibrary.Entry[] memory emptyEntries = new CoreLibrary.Entry[](1);
        emptyEntries[0] = CoreLibrary.Entry(address(0), "");

        vm.expectRevert();
        organ.addEntries(emptyEntries);
    }

    function testInitialEntriesAreCounted() public {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](2);
        entries[0] = CoreLibrary.Entry(ALICE, "alice");
        entries[1] = CoreLibrary.Entry(BOB, "bob");

        Organ organ = _deployOrganWithEntries(entries);

        (,, uint256 entriesLength, uint256 entriesCount,) = organ.getOrgan();
        require(entriesLength == 3, "Unexpected entries length.");
        require(entriesCount == 2, "Initial entries were not counted.");
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

        uint256 proposalKey = procedure.propose("self-call", operations);
        procedure.adopt(proposalKey);

        require(procedure.marked(), "Self-target operation was not executed.");
    }

    function testClientRequiresInitializedProcedureClone() public {
        OrganigramClient client = new OrganigramClient("registry", address(0), SALT);
        NominationProcedure implementation = new NominationProcedure();

        vm.expectRevert(bytes("Missing initialization data."));
        client.deployProcedure(payable(address(implementation)), "", keccak256("missing-init"));
    }

    function testOnlyClientOwnerCanRegisterProcedures() public {
        OrganigramClient client = new OrganigramClient("registry", address(0), SALT);
        NominationProcedure implementation = new NominationProcedure();
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(address(implementation), "nomination");

        vm.prank(RELAYER);
        vm.expectRevert(bytes("Not authorized."));
        client.registerProcedures(entries);

        client.registerProcedures(entries);
        require(
            Organ(client.proceduresRegistry()).getEntryIndexForAddress(address(implementation)) > 0,
            "Procedure was not registered."
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
        uint256 proposalKey = procedure.propose("snapshot-vote", operations);
        require(token.transfer(BOB, 100 ether), "Token transfer failed.");

        vm.warp(1001);
        vm.prank(BOB);
        procedure.vote(proposalKey, true);
        procedure.vote(proposalKey, false);

        vm.warp(1011);
        require(!procedure.count(proposalKey), "Current token balances influenced the vote.");
    }

    function testERC20VoteAppliesAnApprovedProposal() public {
        Asset token = _deployAsset(100 ether);
        vm.roll(10);
        token.delegate(address(this));
        vm.roll(11);

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(address(this), "voter");
        Organ sourceOrgan = _deployOrganWithEntries(entries);
        uint8[3] memory roleModes = [uint8(1), uint8(2), uint8(1)];
        ERC20VoteProcedure procedure =
            _deployERC20VoteProcedureWithRoleModes(token, sourceOrgan, false, roleModes);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);

        vm.warp(1000);
        uint256 proposalKey = procedure.propose("approved-proposal", operations);
        vm.warp(1001);
        procedure.vote(proposalKey, true);
        vm.warp(1011);
        procedure.applyProposal(proposalKey);

        ProcedureLibrary.Proposal memory proposal = procedure.getProposal(proposalKey);
        require(proposal.adopted && proposal.applied, "Approved vote was not applied.");
    }

    function testERC20VoteCanRequireUnanimousApproval() public {
        Asset token = _deployAsset(100 ether);
        vm.roll(10);
        token.delegate(address(this));
        vm.roll(11);

        uint8[3] memory roleModes = [uint8(1), uint8(2), uint8(1)];
        ERC20VoteProcedure implementation = new ERC20VoteProcedure();
        ERC20VoteProcedure procedure = ERC20VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "unanimous-token-vote",
            payable(address(0)),
            payable(address(0)),
            payable(address(0)),
            false,
            address(0),
            0,
            10,
            100000,
            address(token),
            roleModes
        );

        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);
        vm.warp(1000);
        uint256 proposalKey = procedure.propose("unanimous-token-proposal", operations);
        vm.warp(1001);
        procedure.vote(proposalKey, true);
        vm.warp(1011);

        require(procedure.count(proposalKey), "Unanimous token vote was not approved.");
    }

    function testVoteCanRequireUnanimousApproval() public {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(address(this), "voter");
        Organ sourceOrgan = _deployOrganWithEntries(entries);
        VoteProcedure implementation = new VoteProcedure();
        VoteProcedure procedure = VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "unanimous-vote",
            payable(address(sourceOrgan)),
            payable(address(0)),
            payable(address(sourceOrgan)),
            false,
            address(0),
            0,
            10,
            100000
        );

        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);
        vm.warp(1000);
        uint256 proposalKey = procedure.propose("unanimous-proposal", operations);
        vm.warp(1001);
        procedure.vote(proposalKey, true);
        vm.warp(1011);

        require(procedure.count(proposalKey), "Unanimous member vote was not approved.");
    }

    function testVoteElectionResultsExposeTheVoteSplit() public {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](2);
        entries[0] = CoreLibrary.Entry(address(this), "voter");
        entries[1] = CoreLibrary.Entry(BOB, "voter");
        Organ sourceOrgan = _deployOrganWithEntries(entries);
        VoteProcedure implementation = new VoteProcedure();
        VoteProcedure procedure = VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "vote-results",
            payable(address(sourceOrgan)),
            payable(address(0)),
            payable(address(sourceOrgan)),
            false,
            address(0),
            0,
            10,
            50000
        );

        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);
        vm.warp(1000);
        uint256 proposalKey = procedure.propose("vote-results-proposal", operations);
        vm.warp(1001);
        procedure.vote(proposalKey, true);
        vm.prank(BOB);
        procedure.vote(proposalKey, false);

        (
            uint256 approvals,
            uint256 objections,
            uint256 eligibleVotes
        ) = procedure.getElectionResults(proposalKey);
        require(approvals == 1, "Approving vote was not exposed.");
        require(objections == 1, "Rejecting vote was not exposed.");
        require(eligibleVotes == 2, "Eligible voter count was not exposed.");
    }

    function testERC20VoteElectionResultsUseSnapshotVotingPower() public {
        Asset token = _deployAsset(100 ether);
        require(token.transfer(BOB, 40 ether), "Bob funding failed.");
        vm.roll(10);
        token.delegate(address(this));
        vm.prank(BOB);
        token.delegate(BOB);
        vm.roll(11);

        ERC20VoteProcedure procedure = _deployERC20VoteProcedure(token);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);
        vm.warp(1000);
        uint256 proposalKey = procedure.propose("token-vote-results", operations);
        vm.warp(1001);
        procedure.vote(proposalKey, true);
        vm.prank(BOB);
        procedure.vote(proposalKey, false);

        (
            uint256 approvals,
            uint256 objections,
            uint256 eligibleVotes
        ) = procedure.getElectionResults(proposalKey);
        require(approvals == 60 ether, "Approving voting power was not exposed.");
        require(objections == 40 ether, "Rejecting voting power was not exposed.");
        require(eligibleVotes == 100 ether, "Snapshot supply was not exposed.");
    }

    function testAssetSelfDelegatesVotingRightsToNewHolders() public {
        Asset token = _deployAsset(100 ether);

        require(token.delegates(address(this)) == address(this), "Initial holder was not delegated.");
        require(token.getVotes(address(this)) == 100 ether, "Initial holder has no voting rights.");

        require(token.transfer(BOB, 10 ether), "Token transfer failed.");

        require(token.delegates(BOB) == BOB, "Recipient was not delegated.");
        require(token.getVotes(BOB) == 10 ether, "Recipient has no voting rights.");
    }

    function testERC20VoteTokenRolesAllowTokenHolderWithoutSourceOrgan() public {
        Asset token = _deployAsset(100 ether);
        require(token.transfer(BOB, 10 ether), "Token transfer failed.");

        vm.roll(10);
        vm.prank(BOB);
        token.delegate(BOB);
        vm.roll(11);

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(ALICE, "alice");
        Organ sourceOrgan = _deployOrganWithEntries(entries);
        uint8[3] memory roleModes = [uint8(1), uint8(1), uint8(1)];
        ERC20VoteProcedure procedure =
            _deployERC20VoteProcedureWithRoleModes(token, sourceOrgan, true, roleModes);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);

        vm.warp(1000);
        vm.prank(BOB);
        uint256 proposalKey = procedure.propose("token-holder-proposal", operations);

        vm.warp(1001);
        vm.prank(BOB);
        procedure.presentProposal(proposalKey);

        vm.warp(1002);
        vm.prank(BOB);
        procedure.vote(proposalKey, true);

        vm.warp(1012);
        require(procedure.count(proposalKey), "Token holder vote was not counted.");
    }

    function testERC20VoteRoleModesCanMixTokenAndOrganSources() public {
        Asset token = _deployAsset(100 ether);
        require(token.transfer(BOB, 10 ether), "Token transfer failed.");

        vm.roll(10);
        vm.prank(BOB);
        token.delegate(BOB);
        vm.roll(11);

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(ALICE, "alice");
        Organ sourceOrgan = _deployOrganWithEntries(entries);
        uint8[3] memory roleModes = [uint8(1), uint8(0), uint8(1)];
        ERC20VoteProcedure procedure =
            _deployERC20VoteProcedureWithRoleModes(token, sourceOrgan, true, roleModes);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);

        vm.warp(1000);
        vm.prank(BOB);
        uint256 proposalKey = procedure.propose("mixed-role-proposal", operations);

        vm.prank(BOB);
        vm.expectRevert(bytes("Not authorized"));
        procedure.presentProposal(proposalKey);

        vm.warp(1001);
        vm.prank(ALICE);
        procedure.presentProposal(proposalKey);

        vm.warp(1002);
        vm.prank(BOB);
        procedure.vote(proposalKey, true);

        vm.warp(1012);
        require(procedure.count(proposalKey), "Mixed token and organ roles were not honored.");
    }

    function testERC20VoteRoleModesCanDisableModeration() public {
        Asset token = _deployAsset(100 ether);
        require(token.transfer(BOB, 10 ether), "Token transfer failed.");

        vm.roll(10);
        vm.prank(BOB);
        token.delegate(BOB);
        vm.roll(11);

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(ALICE, "alice");
        Organ sourceOrgan = _deployOrganWithEntries(entries);
        uint8[3] memory roleModes = [uint8(1), uint8(2), uint8(1)];
        ERC20VoteProcedure procedure =
            _deployERC20VoteProcedureWithRoleModes(token, sourceOrgan, false, roleModes);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);

        vm.warp(1000);
        vm.prank(BOB);
        uint256 proposalKey = procedure.propose("unmoderated-token-proposal", operations);

        vm.warp(1001);
        vm.prank(BOB);
        procedure.vote(proposalKey, true);

        vm.warp(1011);
        require(procedure.count(proposalKey), "Disabled moderation mode did not start voting.");
    }

    function testERC20VoteCanRequireASeparateMajorityOfOrganMembers() public {
        Asset token = _deployAsset(100 ether);
        require(token.transfer(ALICE, 70 ether), "Alice funding failed.");
        require(token.transfer(BOB, 20 ether), "Bob funding failed.");
        require(token.transfer(CAROL, 10 ether), "Carol funding failed.");

        vm.roll(10);
        vm.prank(ALICE);
        token.delegate(ALICE);
        vm.prank(BOB);
        token.delegate(BOB);
        vm.prank(CAROL);
        token.delegate(CAROL);
        vm.roll(11);

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](3);
        entries[0] = CoreLibrary.Entry(ALICE, "alice");
        entries[1] = CoreLibrary.Entry(BOB, "bob");
        entries[2] = CoreLibrary.Entry(CAROL, "carol");
        Organ shareholders = _deployOrganWithEntries(entries);
        uint8[3] memory roleModes = [uint8(1), uint8(2), uint8(0)];

        ERC20VoteProcedure implementation = new ERC20VoteProcedure();
        ERC20VoteProcedure procedure = ERC20VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "double-majority",
            payable(address(0)),
            payable(address(0)),
            payable(address(shareholders)),
            false,
            address(0),
            0,
            10,
            50000,
            address(token),
            roleModes,
            true
        );

        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](0);
        vm.warp(1000);
        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("double-majority-proposal", operations);

        vm.warp(1001);
        vm.prank(ALICE);
        procedure.vote(proposalKey, true);

        vm.warp(1011);
        vm.expectRevert(bytes("Member majority has not been reached"));
        procedure.count(proposalKey);

        vm.warp(1012);
        vm.prank(ALICE);
        uint256 secondProposalKey = procedure.propose("double-majority-proposal-2", operations);

        vm.warp(1013);
        vm.prank(ALICE);
        procedure.vote(secondProposalKey, true);
        vm.prank(BOB);
        procedure.vote(secondProposalKey, true);

        vm.warp(1022);
        require(procedure.count(secondProposalKey), "Two shareholders should satisfy double majority.");
    }

    function _deployOrgan() private returns (Organ organ) {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](0);
        return _deployOrganWithEntries(entries);
    }

    function _deployOrganWithEntries(CoreLibrary.Entry[] memory entries)
        private
        returns (Organ organ)
    {
        Organ implementation = new Organ();
        organ = Organ(payable(Clones.clone(address(implementation))));

        address[] memory permissionAddresses = new address[](1);
        permissionAddresses[0] = address(this);
        bytes2[] memory permissionValues = new bytes2[](1);
        permissionValues[0] = bytes2(0xffff);

        organ.initialize(permissionAddresses, permissionValues, "organ", entries, address(0));
    }

    function _deployAsset(uint256 supply) private returns (Asset token) {
        Asset implementation = new Asset();
        token = Asset(Clones.clone(address(implementation)));
        token.initialize("Vote Token", "VOTE", address(this), supply);
    }

    function _deployERC20VoteProcedure(Asset token) private returns (ERC20VoteProcedure procedure) {
        ERC20VoteProcedure implementation = new ERC20VoteProcedure();
        procedure = ERC20VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "erc20-vote",
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

    function _deployERC20VoteProcedureWithRoleModes(
        Asset token,
        Organ sourceOrgan,
        bool withModeration,
        uint8[3] memory roleModes
    ) private returns (ERC20VoteProcedure procedure) {
        ERC20VoteProcedure implementation = new ERC20VoteProcedure();
        procedure = ERC20VoteProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "erc20-vote-role-modes",
            payable(address(sourceOrgan)),
            payable(address(sourceOrgan)),
            payable(address(sourceOrgan)),
            withModeration,
            address(0),
            0,
            10,
            50000,
            address(token),
            roleModes
        );
    }

    function _deploySelfTargetProcedure() private returns (SelfTargetProcedure procedure) {
        SelfTargetProcedure implementation = new SelfTargetProcedure();
        procedure = SelfTargetProcedure(payable(Clones.clone(address(implementation))));
        procedure.initialize(
            "self-target",
            payable(address(0)),
            payable(address(0)),
            payable(address(0)),
            false,
            address(0)
        );
    }
}

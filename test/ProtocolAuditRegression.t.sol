// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/Organ.sol";
import "../contracts/IOrgan.sol";
import "../contracts/OrganigramClient.sol";
import "../contracts/Procedure.sol";
import "../contracts/libraries/CoreLibrary.sol";
import "../contracts/libraries/ProcedureLibrary.sol";
import "../contracts/procedures/Vote.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface RegressionVm {
    function deal(address account, uint256 newBalance) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert() external;
    function prank(address account) external;
    function warp(uint256 newTimestamp) external;
    function sign(uint256 pk, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function addr(uint256 pk) external returns (address);
}

contract RegressionPayableSink {
    function pay() external payable {}
}

contract RegressionOpenProcedure is Procedure {}

contract ProtocolAuditRegressionTest {
    RegressionVm private constant vm = RegressionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant PK = 0xA11CE;

    receive() external payable {}

    function _digest(address verifying, bytes32 structHash) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Organigram Procedure"),
                keccak256("1"),
                block.chainid,
                verifying
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function _sig(bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _opHash(ProcedureLibrary.Operation memory op) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("Operation(uint256 index,address target,bytes data,uint256 value)"),
                op.index, op.target, keccak256(op.data), op.value
            )
        );
    }

    // proposeBySig hashes a non-empty operation list correctly.
    function testProposeBySigWithOperation() public {
        RegressionOpenProcedure p = RegressionOpenProcedure(payable(Clones.clone(address(new RegressionOpenProcedure()))));
        p.initialize("p", payable(address(0)), payable(address(0)), payable(address(0)), false, address(0));

        ProcedureLibrary.Operation[] memory ops = new ProcedureLibrary.Operation[](1);
        ops[0] = ProcedureLibrary.Operation({
            index: 0, target: payable(address(0xBEEF)), data: hex"12345678", value: 0, processed: false
        });
        bytes32[] memory hs = new bytes32[](1);
        hs[0] = _opHash(ops[0]);
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Proposal(string cid,bytes32 operationsHash,uint256 nonce,uint256 deadline)"),
                keccak256(bytes("cid")), keccak256(abi.encodePacked(hs)), uint256(0), block.timestamp + 1
            )
        );
        uint256 key = p.proposeBySig("cid", ops, 0, block.timestamp + 1, _sig(_digest(address(p), structHash)));
        ProcedureLibrary.Proposal memory prop = p.getProposal(key);
        require(prop.creator == vm.addr(PK), "creator mismatch");
        require(prop.operations.length == 1 && prop.operations[0].target == address(0xBEEF), "ops mismatch");
    }

    function _vote(bool withModeration) private returns (VoteProcedure v) {
        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(address(this), "voter");
        Organ organ = Organ(payable(Clones.clone(address(new Organ()))));
        address[] memory pa = new address[](1);
        pa[0] = address(this);
        bytes2[] memory pv = new bytes2[](1);
        pv[0] = bytes2(0xffff);
        organ.initialize(pa, pv, "o", entries, address(0));
        v = VoteProcedure(payable(Clones.clone(address(new VoteProcedure()))));
        v.initialize("v", payable(address(0)), payable(address(0)), payable(address(organ)), withModeration,
            address(0), 0, 100, 50000);
    }

    // Signed and direct vetoes share the "Election already started" guard.
    function testBlockBySigRespectsElectionGuard() public {
        VoteProcedure v = _vote(true);
        vm.warp(1000);
        uint256 key = v.propose("x", new ProcedureLibrary.Operation[](0));
        v.presentProposal(key);
        vm.warp(1001);
        v.vote(key, true);

        vm.expectRevert(bytes("Election already started."));
        v.blockProposal(key, "late veto");

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("BlockProposal(uint256 proposalKey,string reason,uint256 nonce,uint256 deadline)"),
                key, keccak256(bytes("late veto")), uint256(0), uint256(2000)
            )
        );
        bytes memory signature = _sig(_digest(address(v), structHash));
        vm.expectRevert(bytes("Election already started."));
        v.blockProposalBySig(key, "late veto", 0, 2000, signature);
    }

    // A signed proposal starts its election like a direct one.
    function testVoteProposeBySigStartsElection() public {
        VoteProcedure v = _vote(false);
        vm.warp(1000);
        ProcedureLibrary.Operation[] memory ops = new ProcedureLibrary.Operation[](0);
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Proposal(string cid,bytes32 operationsHash,uint256 nonce,uint256 deadline)"),
                keccak256(bytes("x")), keccak256(""), uint256(0), uint256(2000)
            )
        );
        uint256 key = v.proposeBySig("x", ops, 0, 2000, _sig(_digest(address(v), structHash)));
        (uint256 start,,) = v.getElection(key);
        require(start == 1000, "election not started");
        vm.warp(1001);
        v.vote(key, true);
        vm.warp(1101);
        v.applyProposal(key);
        require(v.getProposal(key).adopted, "signed proposal not adopted");
    }

    function _applySig(VoteProcedure v, uint256 key) private returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("ApplyProposal(uint256 proposalKey,uint256 nonce,uint256 deadline)"),
                key, uint256(0), uint256(2000)
            )
        );
        return _sig(_digest(address(v), structHash));
    }

    // A signed application counts the votes like a direct one.
    function testVoteApplyProposalBySigSettlesAnApprovedVote() public {
        VoteProcedure v = _vote(false);
        vm.warp(1000);
        uint256 key = v.propose("x", new ProcedureLibrary.Operation[](0));
        vm.warp(1001);
        v.vote(key, true);
        vm.warp(1101);
        v.applyProposalBySig(key, 0, 2000, _applySig(v, key));
        ProcedureLibrary.Proposal memory proposal = v.getProposal(key);
        require(proposal.adopted && proposal.applied, "signed application skipped the count");
    }

    // A signed application rejects a lost vote like a direct one.
    function testVoteApplyProposalBySigRejectsALostVote() public {
        VoteProcedure v = _vote(false);
        vm.warp(1000);
        uint256 key = v.propose("x", new ProcedureLibrary.Operation[](0));
        vm.warp(1101);
        v.applyProposalBySig(key, 0, 2000, _applySig(v, key));
        ProcedureLibrary.Proposal memory proposal = v.getProposal(key);
        require(proposal.applied && !proposal.adopted, "signed application adopted a lost vote");
    }

    // Sending ether through a whitelisted call requires PERMISSION_WITHDRAW_ETHER.
    function testWhitelistedExecutionValueRequiresWithdrawPermission() public {
        Organ organ = Organ(payable(Clones.clone(address(new Organ()))));
        address[] memory pa = new address[](2);
        pa[0] = address(this);
        pa[1] = address(0xB0B);
        bytes2[] memory pv = new bytes2[](2);
        pv[0] = bytes2(0xffff);
        pv[1] = bytes2(0x0800); // EXECUTE_WHITELISTED only.
        organ.initialize(pa, pv, "o", new CoreLibrary.Entry[](0), address(0));
        RegressionPayableSink sink = new RegressionPayableSink();
        organ.setCallPolicy(address(sink), RegressionPayableSink.pay.selector, new IOrgan.ParamConstraintInput[](0), new address[](0));
        vm.deal(address(organ), 5 ether);

        vm.prank(address(0xB0B));
        vm.expectRevert(bytes("Not authorized."));
        organ.executeWhitelisted(address(sink), 5 ether, abi.encodeCall(RegressionPayableSink.pay, ()));

        vm.prank(address(0xB0B));
        organ.executeWhitelisted(address(sink), 0, abi.encodeCall(RegressionPayableSink.pay, ()));

        organ.executeWhitelisted(address(sink), 5 ether, abi.encodeCall(RegressionPayableSink.pay, ()));
        require(address(sink).balance == 5 ether, "value not moved by withdrawer");
    }

    // A vote without any ballot is rejected instead of staying open forever.
    function testVoteWithoutBallotsCanBeRejected() public {
        VoteProcedure v = _vote(false);
        vm.warp(1000);
        uint256 key = v.propose("x", new ProcedureLibrary.Operation[](0));
        vm.warp(1101);
        require(!v.count(key), "empty vote approved");
        v.applyProposal(key);
        ProcedureLibrary.Proposal memory proposal = v.getProposal(key);
        require(proposal.applied && !proposal.adopted, "empty vote not rejected");
    }

    // Reusing someone else's salt yields another address instead of taking theirs.
    function testCloneSaltIsBoundToTheCaller() public {
        OrganigramClient client = new OrganigramClient("registry", address(0), keccak256("r"));
        bytes32 salt = keccak256("victim-salt");
        vm.prank(address(0xBAD));
        address squatted =
            client.deployOrgan(new address[](0), new bytes2[](0), "squat", new CoreLibrary.Entry[](0), salt);
        address victim =
            client.deployOrgan(new address[](0), new bytes2[](0), "victim", new CoreLibrary.Entry[](0), salt);
        require(squatted != victim, "same address for two callers");
        require(
            victim
                == Clones.predictDeterministicAddress(
                    client.organ(), keccak256(abi.encode(address(this), salt)), address(client)
                ),
            "unexpected victim address"
        );
    }
}

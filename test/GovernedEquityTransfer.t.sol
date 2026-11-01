// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/Organ.sol";
import "../contracts/EquityToken.sol";
import "../contracts/libraries/CoreLibrary.sol";
import "../contracts/libraries/ProcedureLibrary.sol";
import "../contracts/procedures/Nomination.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface Vm {
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData, address emitter) external;
    function prank(address account) external;
}

/// @notice Regression tests for an equity transfer governed by an existing procedure.
contract GovernedEquityTransferTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA201);

    function testHolderProposesAndChairmanTransfersWithAMovementRecord() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, BOB, 5, "encrypted-cid")
        );

        require(token.balanceOf(ALICE) == 100, "A proposal moved units.");

        vm.expectEmit(true, true, true, true, address(token));
        emit EquityToken.MovementSettled(address(procedure), proposalKey, ALICE, BOB, 5, "encrypted-cid");
        vm.prank(CAROL);
        procedure.nominate(proposalKey);

        require(token.balanceOf(ALICE) == 95, "Seller was not debited.");
        require(token.balanceOf(BOB) == 5, "Buyer was not credited.");
    }

    function testChairmanCanRejectTransferWithoutModeration() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, BOB, 5, "encrypted-cid")
        );

        vm.prank(CAROL);
        procedure.reject(proposalKey);

        require(token.balanceOf(ALICE) == 100, "Rejected transfer debited the seller.");
        require(token.balanceOf(BOB) == 0, "Rejected transfer credited the buyer.");
    }

    function testTransferRequiresAnEncryptedMovementRecord() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        ProcedureLibrary.Operation[] memory operations = _transferOperations(
            procedure, token, BOB, 5, ""
        );
        vm.expectRevert(bytes("Movement record required."));
        vm.prank(ALICE);
        procedure.propose("transfer-without-record", operations);

        require(token.balanceOf(ALICE) == 100, "Transfer without record debited the seller.");
        require(token.balanceOf(BOB) == 0, "Transfer without record credited the buyer.");
    }

    function testTransferOperationMayTargetTheProcedureAddress() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        ProcedureLibrary.Operation[] memory operations = _transferOperations(
            procedure, token, BOB, 5, "encrypted-cid"
        );
        operations[0].target = payable(address(procedure));

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("transfer-proposal", operations);
        vm.prank(CAROL);
        procedure.nominate(proposalKey);

        require(token.balanceOf(ALICE) == 95, "Seller was not debited.");
        require(token.balanceOf(BOB) == 5, "Buyer was not credited.");
    }

    function testOnlyTheHolderCanCreateAnExecutableTransferProposal() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();

        vm.prank(BOB);
        vm.expectRevert(bytes("Insufficient equity units."));
        procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, ALICE, 5, "encrypted-cid")
        );

        require(token.balanceOf(ALICE) == 100, "Unauthorised proposal moved units.");
        require(token.balanceOf(BOB) == 0, "Unauthorised proposal credited units.");
    }

    function testDirectTokenTransfersAreRejected() public {
        (EquityToken token,) = _deploySystem();

        vm.prank(ALICE);
        vm.expectRevert(bytes("Transfers must be settled by an authorized procedure."));
        token.transfer(BOB, 1);
    }

    function testSharesSelfDelegateVotingRightsToHolderAndRecipient() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        require(token.delegates(ALICE) == ALICE, "Initial holder was not delegated.");
        require(token.getVotes(ALICE) == 100, "Initial holder has no voting rights.");

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, BOB, 5, "encrypted-cid")
        );
        vm.prank(CAROL);
        procedure.nominate(proposalKey);

        require(token.delegates(BOB) == BOB, "Recipient was not delegated.");
        require(token.getVotes(BOB) == 5, "Recipient has no voting rights.");
    }

    function testDirectSettlementOperationCannotSkipTheMovementRecord() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(token)),
            data: abi.encodeWithSelector(token.settleTransfer.selector, BOB, 5, ""),
            value: 0,
            processed: false
        });

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("direct-settlement", operations);

        vm.prank(CAROL);
        vm.expectRevert(bytes("Movement record required."));
        procedure.nominate(proposalKey);

        require(token.balanceOf(ALICE) == 100, "Direct settlement moved units.");
        require(token.balanceOf(BOB) == 0, "Direct settlement credited units.");
    }

    function testDirectSettlementOperationStillEmitsTheMovementRecord() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(token)),
            data: abi.encodeWithSelector(token.settleTransfer.selector, BOB, 5, "encrypted-cid"),
            value: 0,
            processed: false
        });

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("direct-settlement", operations);

        vm.expectEmit(true, true, true, true, address(token));
        emit EquityToken.MovementSettled(address(procedure), proposalKey, ALICE, BOB, 5, "encrypted-cid");
        vm.prank(CAROL);
        procedure.nominate(proposalKey);
    }

    function testTransferProcedureCanGovernItsAuthorizations() public {
        (EquityToken token, NominationProcedure procedure) = _deploySystem();
        NominationProcedure implementation = new NominationProcedure();
        NominationProcedure additionalAdmin = NominationProcedure(
            payable(Clones.clone(address(implementation)))
        );
        additionalAdmin.initialize(
            "additional-asset-admin",
            payable(address(0)),
            payable(address(0)),
            payable(address(0)),
            false,
            address(0)
        );
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(token)),
            data: abi.encodeWithSelector(
                token.setProcedureAuthorization.selector,
                token.ADMIN_PROCEDURE_ROLE(),
                address(additionalAdmin),
                true
            ),
            value: 0,
            processed: false
        });

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("add-asset-admin", operations);
        vm.prank(CAROL);
        procedure.nominate(proposalKey);

        require(
            token.isProcedureAuthorized(
                token.ADMIN_PROCEDURE_ROLE(),
                address(additionalAdmin)
            ),
            "Asset admin procedure was not authorized."
        );
    }

    function _transferOperations(
        NominationProcedure procedure,
        EquityToken token,
        address recipient,
        uint256 amount,
        string memory movementCid
    ) private pure returns (ProcedureLibrary.Operation[] memory operations) {
        operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(0)),
            data: abi.encodeWithSelector(
                procedure.transferEquity.selector,
                address(token),
                recipient,
                amount,
                movementCid
            ),
            value: 0,
            processed: false
        });
    }

    function _deploySystem()
        private
        returns (EquityToken token, NominationProcedure procedure)
    {
        NominationProcedure procedureImplementation = new NominationProcedure();
        procedure = NominationProcedure(payable(Clones.clone(address(procedureImplementation))));

        Organ chairman = _deployOrganWithEntry(CAROL);
        EquityToken tokenImplementation = new EquityToken();
        token = EquityToken(Clones.clone(address(tokenImplementation)));

        procedure.initialize(
            "governed-equity",
            payable(address(0)),
            payable(address(0)),
            payable(address(chairman)),
            false,
            address(0)
        );
        token.initialize(
            "Equity", "EQT", ALICE, 100, address(procedure)
        );
    }

    function _deployOrganWithEntry(address entry) private returns (Organ organ) {
        Organ implementation = new Organ();
        organ = Organ(payable(Clones.clone(address(implementation))));

        CoreLibrary.Entry[] memory entries = new CoreLibrary.Entry[](1);
        entries[0] = CoreLibrary.Entry(entry, "entry");

        organ.initialize(new address[](0), new bytes2[](0), "organ", entries, address(0));
    }
}

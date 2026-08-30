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
    function prank(address account) external;
}

/// @notice Regression tests for a registered equity transfer governed by an existing procedure.
contract GovernedEquityTransferTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA201);

    function testHolderProposesAndChairmanSettlesAndRegistersAtomically() public {
        (EquityToken token, Organ registry, NominationProcedure procedure) = _deploySystem(true);

        ProcedureLibrary.Operation[] memory operations = _transferOperations(
            procedure, token, registry, BOB, 5, "encrypted-cid"
        );
        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("transfer-proposal", operations);

        require(token.balanceOf(ALICE) == 100, "A proposal moved units.");

        vm.prank(CAROL);
        procedure.nominate(proposalKey);

        require(token.balanceOf(ALICE) == 95, "Seller was not debited.");
        require(token.balanceOf(BOB) == 5, "Buyer was not credited.");
        (,, uint256 entriesLength, uint256 entriesCount,) = registry.getOrgan();
        require(entriesLength == 2 && entriesCount == 1, "Movement was not registered.");
    }

    function testOnlyTheHolderCanCreateAnExecutableTransferProposal() public {
        (EquityToken token, Organ registry, NominationProcedure procedure) = _deploySystem(true);

        vm.prank(BOB);
        vm.expectRevert(bytes("Insufficient equity units."));
        procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, registry, ALICE, 5, "encrypted-cid")
        );

        require(token.balanceOf(ALICE) == 100, "Unauthorised proposal moved units.");
        require(token.balanceOf(BOB) == 0, "Unauthorised proposal credited units.");
    }

    function testDirectTokenTransfersAreRejected() public {
        (EquityToken token,,) = _deploySystem(true);

        vm.prank(ALICE);
        vm.expectRevert(bytes("Transfers must be settled by an authorized procedure."));
        token.transfer(BOB, 1);
    }

    function testSharesSelfDelegateVotingRightsToHolderAndRecipient() public {
        (EquityToken token, Organ registry, NominationProcedure procedure) = _deploySystem(true);
        require(token.delegates(ALICE) == ALICE, "Initial holder was not delegated.");
        require(token.getVotes(ALICE) == 100, "Initial holder has no voting rights.");

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, registry, BOB, 5, "encrypted-cid")
        );
        vm.prank(CAROL);
        procedure.nominate(proposalKey);

        require(token.delegates(BOB) == BOB, "Recipient was not delegated.");
        require(token.getVotes(BOB) == 5, "Recipient has no voting rights.");
    }

    function testRegistryFailureRevertsTheWholeSettlement() public {
        (EquityToken token, Organ registry, NominationProcedure procedure) = _deploySystem(false);

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose(
            "transfer-proposal",
            _transferOperations(procedure, token, registry, BOB, 5, "encrypted-cid")
        );

        vm.prank(CAROL);
        vm.expectRevert(bytes("Failed to apply proposal: the underlying transaction reverted."));
        procedure.nominate(proposalKey);

        require(token.balanceOf(ALICE) == 100, "Failed registry write moved units.");
        require(token.balanceOf(BOB) == 0, "Failed registry write credited units.");
    }

    function testDirectSettlementOperationCannotBypassTheRegister() public {
        (EquityToken token,, NominationProcedure procedure) = _deploySystem(true);
        ProcedureLibrary.Operation[] memory operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(token)),
            data: abi.encodeWithSelector(token.settleTransfer.selector, BOB, 5),
            value: 0,
            processed: false
        });

        vm.prank(ALICE);
        uint256 proposalKey = procedure.propose("direct-settlement", operations);

        vm.prank(CAROL);
        vm.expectRevert(bytes("Failed to apply proposal: the underlying transaction reverted."));
        procedure.nominate(proposalKey);

        require(token.balanceOf(ALICE) == 100, "Direct settlement moved units.");
        require(token.balanceOf(BOB) == 0, "Direct settlement credited units.");
    }

    function testTransferProcedureCanGovernItsAuthorizations() public {
        (EquityToken token,, NominationProcedure procedure) = _deploySystem(true);
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
        Organ registry,
        address recipient,
        uint256 amount,
        string memory movementCid
    ) private pure returns (ProcedureLibrary.Operation[] memory operations) {
        operations = new ProcedureLibrary.Operation[](1);
        operations[0] = ProcedureLibrary.Operation({
            index: 0,
            target: payable(address(0)),
            data: abi.encodeWithSelector(
                procedure.settleEquityTransfer.selector,
                address(token),
                payable(address(registry)),
                recipient,
                amount,
                movementCid
            ),
            value: 0,
            processed: false
        });
    }

    function _deploySystem(bool grantRegistryWrite)
        private
        returns (EquityToken token, Organ registry, NominationProcedure procedure)
    {
        NominationProcedure procedureImplementation = new NominationProcedure();
        procedure = NominationProcedure(payable(Clones.clone(address(procedureImplementation))));

        Organ chairman = _deployOrganWithEntry(CAROL, address(0), bytes2(0));
        EquityToken tokenImplementation = new EquityToken();
        token = EquityToken(Clones.clone(address(tokenImplementation)));
        registry = _deployOrganWithEntry(
            address(0), grantRegistryWrite ? address(procedure) : address(0), bytes2(0x0004)
        );

        procedure.initialize(
            "governed-equity",
            payable(address(0)),
            payable(address(0)),
            payable(address(chairman)),
            false,
            address(0)
        );
        token.initialize(
            "Registered shares", "SHR", ALICE, 100, address(procedure)
        );
    }

    function _deployOrganWithEntry(address entry, address permission, bytes2 permissionValue)
        private
        returns (Organ organ)
    {
        Organ implementation = new Organ();
        organ = Organ(payable(Clones.clone(address(implementation))));

        address[] memory permissions = permission == address(0) ? new address[](0) : new address[](1);
        bytes2[] memory values = permission == address(0) ? new bytes2[](0) : new bytes2[](1);
        if (permission != address(0)) {
            permissions[0] = permission;
            values[0] = permissionValue;
        }

        CoreLibrary.Entry[] memory entries = entry == address(0)
            ? new CoreLibrary.Entry[](0)
            : new CoreLibrary.Entry[](1);
        if (entry != address(0)) entries[0] = CoreLibrary.Entry(entry, "entry");

        organ.initialize(permissions, values, "organ", entries, address(0));
    }
}

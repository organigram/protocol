// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import {ProcedureLibrary} from './libraries/ProcedureLibrary.sol';
import {ERC2771Recipient} from './MetaGasStation.sol';
import {IProposalOperationValidator} from './IProposalOperationValidator.sol';
import {IEquityToken} from './IEquityToken.sol';
import {ERC165} from '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {Initializable as InitializableStatic} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

/// @title Procedure
/// @notice Lets the members of some organs change other organs through proposals: lists of operations that
/// proposers submit, moderators may present or block, and deciders adopt or reject.
/// @dev Adoption runs the operations. Every action has a `…BySig` variant verifying an EIP-712 signature,
/// so that a relayer can submit it on behalf of the signer.
contract Procedure is
    ERC165,
    InitializableStatic,
    ReentrancyGuard,
    ERC2771Recipient,
    EIP712,
    IProposalOperationValidator
{
    using ProcedureLibrary for ProcedureLibrary.ProcedureData;
    using ProcedureLibrary for ProcedureLibrary.Operation;
    ProcedureLibrary.ProcedureData internal procedureData;
    /// @notice ERC-165 interface identifier of procedures.
    bytes4 public constant INTERFACE_ID = 0x71dbd330;
    bytes32 internal constant OPERATION_TYPEHASH =
        keccak256(
            'Operation(uint256 index,address target,bytes data,uint256 value)'
        );
    bytes32 internal constant PROPOSAL_TYPEHASH =
        keccak256(
            'Proposal(string cid,bytes32 operationsHash,uint256 nonce,uint256 deadline)'
        );
    bytes32 internal constant PRESENT_PROPOSAL_TYPEHASH =
        keccak256(
            'PresentProposal(uint256 proposalKey,uint256 nonce,uint256 deadline)'
        );
    bytes32 internal constant BLOCK_PROPOSAL_TYPEHASH =
        keccak256(
            'BlockProposal(uint256 proposalKey,string reason,uint256 nonce,uint256 deadline)'
        );
    bytes32 internal constant APPLY_PROPOSAL_TYPEHASH =
        keccak256(
            'ApplyProposal(uint256 proposalKey,uint256 nonce,uint256 deadline)'
        );

    /**
        Modifiers.
    */
    modifier onlyInOrgan(address payable organAddress) {
        _requireInOrgan(organAddress);
        _;
    }

    modifier onlyDeciders() {
        _requireDecider();
        _;
    }

    function _requireInOrgan(address payable organAddress) private view {
        require(
            ProcedureLibrary.isInOrgan(organAddress, _msgSender()),
            'Not authorized'
        );
    }

    function _requireDecider() private view {
        _requireInOrgan(procedureData.deciders);
    }

    /**
        Procedure constructor.
    */
    constructor() EIP712('Organigram Procedure', '1') {
        _disableInitializers();
    }

    // Register EIP165 interfaces for introspection.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        // @todo : Use type(IProcedure).interfaceId
        return
            interfaceId == INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /// @notice Initialize a procedure clone with its roles.
    /// @param _cid Reference to the procedure metadata.
    /// @param _proposers Organ whose members may submit proposals, or a single address.
    /// @param _moderators Organ whose members may present or block proposals.
    /// @param _deciders Organ whose members adopt or reject proposals, or a single address.
    /// @param _withModeration Whether proposals must be presented by a moderator before the decision.
    /// @param _trustedForwarder Forwarder relaying gasless transactions.
    function initialize(
        string memory _cid,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        address _trustedForwarder
    ) public virtual initializer {
        procedureData.init(
            _cid,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder
        );
        _setTrustedForwarder(_trustedForwarder);
    }

    /**
        Public API : Proposals creation and update.
    */
    function propose(
        string memory cid,
        ProcedureLibrary.Operation[] memory operations
    ) public returns (uint256 proposalKey) {
        return _propose(cid, operations, _msgSender());
    }

    /// @notice Submit a proposal signed by a proposer, relayed by any account.
    function proposeBySig(
        string calldata cid,
        ProcedureLibrary.Operation[] calldata operations,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public returns (uint256 proposalKey) {
        bytes32 operationsHash = _hashOperations(operations);
        address signer = _recoverTypedSigner(
            keccak256(
                abi.encode(
                    PROPOSAL_TYPEHASH,
                    keccak256(bytes(cid)),
                    operationsHash,
                    nonce,
                    deadline
                )
            ),
            nonce,
            deadline,
            signature
        );
        return _propose(cid, operations, signer);
    }

    /// @notice Block a proposal as a moderator, with a reason.
    function blockProposal(
        uint256 proposalKey,
        string calldata reason
    ) public {
        _blockProposal(proposalKey, reason, _msgSender());
    }

    /// @notice Block a proposal with a block signed by a moderator, relayed by any account.
    function blockProposalBySig(
        uint256 proposalKey,
        string calldata reason,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public {
        address signer = _recoverTypedSigner(
            keccak256(
                abi.encode(
                    BLOCK_PROPOSAL_TYPEHASH,
                    proposalKey,
                    keccak256(bytes(reason)),
                    nonce,
                    deadline
                )
            ),
            nonce,
            deadline,
            signature
        );
        _blockProposal(proposalKey, reason, signer);
    }

    /// @notice When moderation is enabled, moderators must accept the proposal.
    function presentProposal(uint256 proposalKey) public {
        _presentProposal(proposalKey, _msgSender());
    }

    /// @notice Present a proposal with a presentation signed by a moderator, relayed by any account.
    function presentProposalBySig(
        uint256 proposalKey,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public {
        address signer = _recoverTypedSigner(
            keccak256(
                abi.encode(
                    PRESENT_PROPOSAL_TYPEHASH,
                    proposalKey,
                    nonce,
                    deadline
                )
            ),
            nonce,
            deadline,
            signature
        );
        _presentProposal(proposalKey, signer);
    }

    /// @dev Direct and signed calls share these hooks, so that a procedure
    /// overriding them applies its rules to both.
    function _propose(
        string memory cid,
        ProcedureLibrary.Operation[] memory operations,
        address creator
    ) internal virtual returns (uint256 proposalKey) {
        _validateOwnerBoundOperations(operations, creator);
        return procedureData.propose(cid, operations, creator);
    }

    function _blockProposal(
        uint256 proposalKey,
        string memory reason,
        address moderator
    ) internal virtual {
        procedureData.blockProposal(proposalKey, reason, moderator);
    }

    function _presentProposal(
        uint256 proposalKey,
        address moderator
    ) internal virtual {
        procedureData.presentProposal(proposalKey, moderator);
    }

    /// @notice The procedure calls this method directly to adopt and apply a proposal.
    function _adoptProposal(uint256 proposalKey) internal virtual nonReentrant {
        procedureData._adoptProposal(proposalKey);
    }

    /// @dev Settlement helper for derived procedures that already hold the
    /// reentrancy lock in their public entry point.
    function _applyAdoptedProposal(uint256 proposalKey) internal {
        procedureData._adoptProposal(proposalKey);
    }

    /// @notice The procedure calls this method directly to reject a proposal.
    function _rejectProposal(
        uint256 proposalKey
    ) internal virtual nonReentrant {
        procedureData._rejectProposal(proposalKey);
    }

    /// @dev Rejection counterpart for a derived procedure holding the lock.
    function _applyRejectedProposal(uint256 proposalKey) internal {
        procedureData._rejectProposal(proposalKey);
    }

    /// @notice Apply proposal.
    function applyProposal(uint256 proposalKey) public nonReentrant {
        _applyProposal(proposalKey);
    }

    /// @notice Settle a proposal with an application signed by any account, relayed by another.
    function applyProposalBySig(
        uint256 proposalKey,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public nonReentrant {
        _recoverTypedSigner(
            keccak256(
                abi.encode(
                    APPLY_PROPOSAL_TYPEHASH,
                    proposalKey,
                    nonce,
                    deadline
                )
            ),
            nonce,
            deadline,
            signature
        );
        _applyProposal(proposalKey);
    }

    /// @dev Direct and signed applications share this hook, so that a
    /// procedure settling its own decisions applies them to both. Callers
    /// hold the reentrancy lock.
    function _applyProposal(uint256 proposalKey) internal virtual {
        procedureData.applyProposal(proposalKey);
    }

    /*
        Accessors.
    */
    /// @notice Read the metadata reference, the roles and the proposal count of the procedure.
    function getProcedure()
        public
        view
        returns (
            string memory cid,
            address payable proposers,
            address payable moderators,
            address payable deciders,
            bool withModeration,
            uint256 proposalsLength,
            bytes4 interfaceId
        )
    {
        return (
            procedureData.cid,
            procedureData.proposers,
            procedureData.moderators,
            procedureData.deciders,
            procedureData.withModeration,
            procedureData.proposalsLength,
            INTERFACE_ID
        );
    }

    /// @notice Read one proposal.
    function getProposal(
        uint256 proposalKey
    ) public view returns (ProcedureLibrary.Proposal memory) {
        return procedureData.proposals[proposalKey];
    }

    /// @notice Read the next signature nonce of an account.
    function getNonce(address account) public view returns (uint256) {
        return procedureData.nonces[account];
    }

    /// @notice Lets an operation target safely identify the proposal currently being applied.
    function getExecutionContext()
        external
        view
        returns (bool isApplying, uint256 proposalKey, address proposalCreator)
    {
        return (
            procedureData.isApplyingProposal,
            procedureData.applyingProposalKey,
            procedureData.applyingProposalCreator
        );
    }

    /// @notice Transfers the proposal creator's equity; the token emits the movement record.
    function transferEquity(
        address asset,
        address recipient,
        uint256 amount,
        string calldata movementCid
    ) external {
        require(msg.sender == address(this), 'Only executable proposal.');
        IEquityToken(asset).settleTransfer(recipient, amount, movementCid);
    }

    /// @inheritdoc IProposalOperationValidator
    function isOwnerBoundProposalOperation(
        bytes calldata operationData
    ) external pure override returns (bool) {
        return
            operationData.length >= 4 &&
            bytes4(operationData[:4]) == this.transferEquity.selector;
    }

    /// @inheritdoc IProposalOperationValidator
    function validateProposalCreator(
        address creator,
        bytes calldata operationData
    ) external view override {
        require(operationData.length >= 4, 'Unsupported owner-bound operation.');
        bytes4 selector = bytes4(operationData[:4]);
        require(
            selector == this.transferEquity.selector,
            'Unsupported owner-bound operation.'
        );
        (
            address asset,
            address recipient,
            uint256 amount,
            string memory movementCid
        ) = abi.decode(operationData[4:], (address, address, uint256, string));
        require(
            IEquityToken(asset).isTransferProcedure(address(this)),
            'Not transfer procedure.'
        );
        IEquityToken(asset).validateTransfer(
            creator,
            recipient,
            amount,
            movementCid
        );
    }

    function _validateOwnerBoundOperations(
        ProcedureLibrary.Operation[] memory operations,
        address creator
    ) internal view {
        for (uint256 i = 0; i < operations.length; ++i) {
            address target = operations[i].target == address(0)
                ? address(this)
                : operations[i].target;
            if (target.code.length == 0) continue;

            (bool supportsValidation, bytes memory supportResult) = target
                .staticcall(
                    abi.encodeWithSelector(
                        IProposalOperationValidator
                            .isOwnerBoundProposalOperation
                            .selector,
                        operations[i].data
                    )
                );
            if (
                !supportsValidation ||
                supportResult.length != 32 ||
                !abi.decode(supportResult, (bool))
            ) continue;

            (bool isValid, bytes memory validationResult) = target.staticcall(
                abi.encodeWithSelector(
                    IProposalOperationValidator
                        .validateProposalCreator
                        .selector,
                    creator,
                    operations[i].data
                )
            );
            if (!isValid) {
                assembly {
                    revert(add(validationResult, 0x20), mload(validationResult))
                }
            }
        }
    }

    function _recoverTypedSigner(
        bytes32 structHash,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) internal returns (address signer) {
        require(deadline >= block.timestamp, 'Signature expired');
        signer = ECDSA.recover(_hashTypedDataV4(structHash), signature);
        require(procedureData.nonces[signer] == nonce, 'Invalid nonce');
        procedureData.nonces[signer] = nonce + 1;
    }

    function _hashOperation(
        ProcedureLibrary.Operation memory operation
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    OPERATION_TYPEHASH,
                    operation.index,
                    operation.target,
                    keccak256(operation.data),
                    operation.value
                )
            );
    }

    function _hashOperations(
        ProcedureLibrary.Operation[] calldata operations
    ) internal pure returns (bytes32) {
        bytes32[] memory operationHashes = new bytes32[](operations.length);
        for (uint256 i = 0; i < operations.length; i++) {
            operationHashes[i] = _hashOperation(operations[i]);
        }
        bytes32 operationsHash;
        assembly ('memory-safe') {
            operationsHash := keccak256(
                add(operationHashes, 0x20),
                mul(mload(operationHashes), 0x20)
            )
        }
        return operationsHash;
    }
}

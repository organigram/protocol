// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma experimental ABIEncoderV2;

import './libraries/ProcedureLibrary.sol';
import './MetaGasStation.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {Initializable as InitializableStatic} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

/*
    A procedure defines a set of operations compiled in a proposal.
    The procedure dictates the way the proposal can be applied.
*/
contract Procedure is
    ERC165,
    InitializableStatic,
    ReentrancyGuard,
    ERC2771Recipient,
    EIP712
{
    using ProcedureLibrary for ProcedureLibrary.ProcedureData;
    using ProcedureLibrary for ProcedureLibrary.Operation;
    ProcedureLibrary.ProcedureData internal procedureData;
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
        require(
            ProcedureLibrary.isInOrgan(organAddress, _msgSender()),
            'Not authorized'
        );
        _;
    }

    modifier onlyDeciders() {
        require(
            ProcedureLibrary.isInOrgan(procedureData.deciders, _msgSender()),
            'Not authorized'
        );
        _;
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
            _trustedForwarder,
            _msgSender()
        );
        _setTrustedForwarder(_trustedForwarder);
    }

    /**
        Public API : Procedure Cid and Admin.
    */
    function updateCid(string memory cid) public {
        procedureData.updateCid(cid, _msgSender());
    }

    function updateAdmin(address payable admin) public {
        procedureData.updateAdmin(admin, _msgSender());
    }

    /**
        Public API : Proposals creation and update.
    */
    function propose(
        string memory cid,
        ProcedureLibrary.Operation[] memory operations
    ) public virtual returns (uint256 proposalKey) {
        return procedureData.propose(cid, operations, _msgSender());
    }

    function proposeBySig(
        string calldata cid,
        ProcedureLibrary.Operation[] calldata operations,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public virtual returns (uint256 proposalKey) {
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
        return procedureData.propose(cid, operations, signer);
    }

    /// @notice The procedure can override this method.
    function blockProposal(
        uint256 proposalKey,
        string calldata reason
    ) public virtual {
        procedureData.blockProposal(proposalKey, reason, _msgSender());
    }

    function blockProposalBySig(
        uint256 proposalKey,
        string calldata reason,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public virtual {
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
        procedureData.blockProposal(proposalKey, reason, signer);
    }

    /// @notice When moderation is enabled, moderators must accept the proposal.
    function presentProposal(uint256 proposalKey) public virtual {
        procedureData.presentProposal(proposalKey, _msgSender());
    }

    function presentProposalBySig(
        uint256 proposalKey,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public virtual {
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
        procedureData.presentProposal(proposalKey, signer);
    }

    /// @notice The procedure calls this method directly to adopt and apply a proposal.
    function _adoptProposal(uint256 proposalKey) internal virtual nonReentrant {
        procedureData._adoptProposal(proposalKey);
    }

    /// @notice The procedure calls this method directly to reject a proposal.
    function _rejectProposal(uint256 proposalKey) internal virtual nonReentrant {
        procedureData._rejectProposal(proposalKey);
    }

    /// @notice Apply proposal.
    function applyProposal(uint256 proposalKey) public virtual nonReentrant {
        procedureData.applyProposal(proposalKey);
    }

    function applyProposalBySig(
        uint256 proposalKey,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public virtual nonReentrant {
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
        procedureData.applyProposal(proposalKey);
    }

    /*
        Accessors.
    */
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

    function getProposal(
        uint256 proposalKey
    ) public view returns (ProcedureLibrary.Proposal memory) {
        return procedureData.proposals[proposalKey];
    }

    function getNonce(address account) public view returns (uint256) {
        return procedureData.nonces[account];
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
        return keccak256(abi.encodePacked(operationHashes));
    }
}

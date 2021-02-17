// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libraries/MetadataLibrary.sol";
import "./libraries/ProcedureLibrary.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

/*
    A procedure defines a set of operations compiled in a proposal.
    The procedure dictates the way the proposal can be applied.

    @TODO : Add proposals getters.
*/

contract Procedure is ERC165, Initializable {
    using MetadataLibrary for MetadataLibrary.Metadata;
    using ProcedureLibrary for ProcedureLibrary.ProcedureData;
    using ProcedureLibrary for ProcedureLibrary.Operation;
    using OrganLibrary for OrganLibrary.Entry;
    ProcedureLibrary.ProcedureData internal procedureData;
    bytes4 constant public _INTERFACE_ID_PROCEDURE = 0x71dbd330;

    /**
        Modifiers.
    */

    modifier onlyInOrgan(address payable organAddress) {
        require(ProcedureLibrary.isInOrgan(organAddress, msg.sender), "Not authorized");
        _;
    }

    modifier onlyDeciders() {
        require(ProcedureLibrary.isInOrgan(procedureData.deciders, msg.sender), "Not authorized");
        _;
    }

    /**
        Procedure constructor.
    */

    constructor ()
        public
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_ID_PROCEDURE);
        procedureData.init(
            MetadataLibrary.Metadata(0, 0, 0),
            address(0), // Proposers.
            address(0), // Moderators.
            address(0), // Deciders.
            false       // With Moderation.
        );
    }

    function initialize(
        MetadataLibrary.Metadata memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration
    )
        public
        virtual
        initializer
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_ID_PROCEDURE);
        procedureData.init(_metadata, _proposers, _moderators, _deciders, _withModeration);
    }

    /**
        Public API : Procedure Metadata and Admin.
    */

    function updateMetadata(MetadataLibrary.Metadata memory metadata)
        public
    {
        procedureData.updateMetadata(metadata);
    }

    function updateAdmin(address payable admin)
        public
    {
        procedureData.updateAdmin(admin);
    }

    /**
        Public API : Proposals creation and update.
    */

    function propose(
        MetadataLibrary.Metadata memory metadata,
        ProcedureLibrary.Operation[] memory operations
    )
        public
        virtual
        returns (uint256 proposalKey)
    {
        return procedureData.propose(metadata, operations);
    }

    /// @notice The procedure calls this method directly to adopt and apply proposal.
    function blockProposal(uint256 proposalKey, MetadataLibrary.Metadata calldata reason)
        public
        virtual
    {
        procedureData.blockProposal(proposalKey, reason);
    }

    /// @notice The procedure calls this method directly to adopt and apply proposal.
    function adoptProposal(uint256 proposalKey)
        public
        virtual
    {
        procedureData.adoptProposal(proposalKey);
    }

    /// @notice Apply proposal.
    function applyProposal(uint256 proposalKey)
        public
        virtual
    {
        procedureData.applyProposal(proposalKey);
    }

    /*
        Accessors.
    */

    function getProcedure()
        public
        view
        returns (
            MetadataLibrary.Metadata memory metadata,
            address payable proposers,
            address payable moderators,
            address payable deciders,
            uint256 proposalsLength
        )
    {
        return (
            procedureData.metadata,
            procedureData.proposers,
            procedureData.moderators,
            procedureData.deciders,
            procedureData.proposalsLength
        );
    }

    function getProposal(uint256 proposalKey)
        public view
        returns (ProcedureLibrary.Proposal memory)
    {
        return procedureData.proposals[proposalKey];
    }
}
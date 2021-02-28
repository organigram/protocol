// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libraries/CoreLibrary.sol";
import "./libraries/ProcedureLibrary.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

/*
    A procedure defines a set of operations compiled in a proposal.
    The procedure dictates the way the proposal can be applied.

    @TODO : Add proposals getters.
*/

contract Procedure is ERC165, Initializable {
    using CoreLibrary for CoreLibrary.Metadata;
    using ProcedureLibrary for ProcedureLibrary.ProcedureData;
    using ProcedureLibrary for ProcedureLibrary.Operation;
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
            CoreLibrary.Metadata(0, 0, 0),
            address(0), // Proposers.
            address(0), // Moderators.
            address(0), // Deciders.
            false       // With Moderation.
        );
    }

    function initialize(
        CoreLibrary.Metadata memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration
    )
        public
        virtual
        initializer
    {
        // Register ERC165 interfaces for introspection.
        _registerInterface(0x01ffc9a7); // ERC-165
        _registerInterface(_INTERFACE_ID_PROCEDURE);
        procedureData.init(_metadata, _proposers, _moderators, _deciders, _withModeration);
    }

    /**
        Public API : Procedure Metadata and Admin.
    */

    function updateMetadata(CoreLibrary.Metadata memory metadata)
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
        CoreLibrary.Metadata memory metadata,
        ProcedureLibrary.Operation[] memory operations
    )
        public
        virtual
        returns (uint256 proposalKey)
    {
        return procedureData.propose(metadata, operations);
    }

    /// @notice The procedure can override this method.
    function blockProposal(uint256 proposalKey, CoreLibrary.Metadata calldata reason)
        public
        virtual
    {
        procedureData.blockProposal(proposalKey, reason);
    }

    /// @notice When moderation is enabled, moderators must accept the proposal. 
    function presentProposal(uint256 proposalKey)
        public
    {
        procedureData.presentProposal(proposalKey);
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
            CoreLibrary.Metadata memory metadata,
            address payable proposers,
            address payable moderators,
            address payable deciders,
            bool withModeration,
            uint256 proposalsLength
        )
    {
        return (
            procedureData.metadata,
            procedureData.proposers,
            procedureData.moderators,
            procedureData.deciders,
            procedureData.withModeration,
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
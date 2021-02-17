// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../IOrgan.sol";
import "./MetadataLibrary.sol";

/*
    Organigr.am Contracts Framework - Procedure library.
    This library holds the logic common to all procedures.

    A procedure can affect an organ by :
    - Adding, removing, replacing entries.
    - Adding, removing, replacing procedures.
    - Withdrawing funds and transferring them to another organ.
    The procedure can process several operations inside one proposal.
*/

library ProcedureLibrary {
    using MetadataLibrary for MetadataLibrary.Metadata;

    struct ProcedureData {
        MetadataLibrary.Metadata metadata;
        address payable proposers;
        address payable moderators;
        address payable deciders;
        address payable admin;
        mapping (uint256 => Proposal) proposals;
        uint256 proposalsLength;
        bool withModeration;
    }

    struct Proposal {
        address payable creator;
        MetadataLibrary.Metadata metadata;
        MetadataLibrary.Metadata blockReason;
        bool presented;
        bool blocked;
        bool adopted;
        bool applied;
        Operation[] operations;
        // @todo : Reference other proposals from a proposal?
        // uint256[] proposals;
    }

    struct Operation {
        uint256 index;
        address payable organ;
        bytes data;
        uint256 value;
        bool processed;
    }

    /**
        Modifiers.
    */
    modifier onlyInOrgan(address payable organAddress) {
        require(isInOrgan(organAddress, msg.sender), "Not authorized.");
        _;
    }

    modifier onlyNewProposal(ProcedureData storage self, uint256 proposalKey) {
        require(
            !self.proposals[proposalKey].presented
            && !self.proposals[proposalKey].adopted
            && !self.proposals[proposalKey].applied
            && !self.proposals[proposalKey].blocked,
            "Not authorized"
        );
        _;
    }

    modifier onlyAdoptedProposal(ProcedureData storage self, uint256 proposalKey) {
        require(
            self.proposals[proposalKey].adopted
            && !self.proposals[proposalKey].applied
            && !self.proposals[proposalKey].blocked,
            "Not authorized"
        );
        _;
    }

    modifier onlyPresentedProposal(ProcedureData storage self, uint256 proposalKey) {
        require(
            self.proposals[proposalKey].presented
            && !self.proposals[proposalKey].adopted
            && !self.proposals[proposalKey].applied
            && !self.proposals[proposalKey].blocked,
            "Not authorized"
        );
        _;
    }

    /**
        Events.
    */

    event MetadataUpdated(address from, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize);
    event AdminUpdated(address from, address payable admin);
    event ProposalCreated(address payable indexed creator, uint256 indexed proposalKey);
    event ProposalBlocked(
        address payable indexed moderator,
        uint256 indexed proposalKey,
        bytes32 ipfsHash,
        uint8 hashFunction,
        uint8 hashSize
    );
    event ProposalApplied(uint256 indexed proposalKey);

    /*
        Procedure management.
    */

    function init(
        ProcedureData storage self,
        MetadataLibrary.Metadata memory metadata,
        address payable proposers,
        address payable moderators,
        address payable deciders,
        bool withModeration // Adds an extra step where moderators can block a proposal before deciders.
    )
        public
    {
        self.metadata = metadata;
        self.proposers = proposers;
        self.moderators = moderators;
        self.deciders = deciders;
        self.withModeration = withModeration;
        self.admin = msg.sender;
    }

    /**
        Admin API.
    */

    function updateAdmin(ProcedureData storage self, address payable admin)
        public onlyInOrgan(self.admin)
    {
        self.admin = admin;
        emit AdminUpdated(msg.sender, admin);
    }

    function updateMetadata(
        ProcedureData storage self, MetadataLibrary.Metadata memory metadata
    )
        public onlyInOrgan(self.admin)
    {
        self.metadata = metadata;
        emit MetadataUpdated(msg.sender, metadata.ipfsHash, metadata.hashFunction, metadata.hashSize);
    }

    /**
        Utils.
    */
    function isInOrgan(address payable organ, address payable caller)
        public view returns (bool)
    {
        return organ == address(0) || organ == caller || IOrgan(organ).getEntryIndexForAddress(caller) != 0;
    }

    /**
        External API.
    */

    /// @notice Proposers can create a proposal with a set of operations.
    /// @dev Merge with proposalCall.
    /// @param metadata Metadata describing the proposal, stored on IPFS.
    /// @param operations Set of solidity calls on the procedure or given organ.
    /// @return proposalKey of proposal created.
    function propose(
        ProcedureData storage self,
        MetadataLibrary.Metadata memory metadata,
        Operation[] memory operations
    )
        public
        onlyInOrgan(self.proposers)
        returns (uint256 proposalKey)
    {
        proposalKey = self.proposalsLength++;
        self.proposals[proposalKey].creator = msg.sender;
        self.proposals[proposalKey].metadata = metadata;
        for (uint256 i = 0 ; i < operations.length ; ++i) {
            self.proposals[proposalKey].operations.push(Operation({
                index: self.proposals[proposalKey].operations.length,
                organ: operations[i].organ,
                data: operations[i].data,
                value: operations[i].value,
                processed: false
            }));
        }

        if (!self.withModeration) {
            self.proposals[proposalKey].presented = true;
        }
        emit ProposalCreated(msg.sender, proposalKey);
        return proposalKey;
    }

    /// @notice Block proposal (veto).
    /// @param proposalKey of proposal.
    /// @param reason for blocking the proposal.
    function blockProposal(
        ProcedureData storage self,
        uint256 proposalKey,
        MetadataLibrary.Metadata memory reason
    )
        public
        onlyInOrgan(self.moderators)
    {
        require(!self.proposals[proposalKey].blocked, "Already blocked.");
        require(!self.proposals[proposalKey].applied, "Already applied.");
        self.proposals[proposalKey].blocked = true;
        self.proposals[proposalKey].blockReason = reason;
        emit ProposalBlocked(msg.sender, proposalKey, reason.ipfsHash, reason.hashFunction, reason.hashSize);
    }

    /// @notice Adopt proposal and attempt to apply it.
    /// @dev Should only be called once by parent contract.
    /// @param proposalKey of proposal.
    function adoptProposal(ProcedureData storage self, uint256 proposalKey)
        internal
        onlyPresentedProposal(self, proposalKey)
    {
        self.proposals[proposalKey].adopted = true;
        applyProposal(self, proposalKey);
    }

    /// @notice Apply an adopted proposal.
    /// @param proposalKey of proposal.
    function applyProposal(ProcedureData storage self, uint256 proposalKey)
        public
        onlyAdoptedProposal(self, proposalKey)
    {
        // Process operations.
        for (uint256 i = 0; i < self.proposals[proposalKey].operations.length; ++i) {
            if (!self.proposals[proposalKey].operations[i].processed) {
                if (self.proposals[proposalKey].operations[i].organ != address(0)) {
                    self.proposals[proposalKey].operations[i].organ.call(self.proposals[proposalKey].operations[i].data);
                } else {
                    // @todo Fix arbitrary call.
                    address(msg.sender).call(self.proposals[proposalKey].operations[i].data);
                }
                self.proposals[proposalKey].operations[i].processed = true;
            }
        }
        self.proposals[proposalKey].applied = true;
        emit ProposalApplied(proposalKey);
    }
}
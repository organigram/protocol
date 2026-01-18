// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "../IOrgan.sol";

/*
    Organigr.am Contracts Framework - Procedure library.
    This library holds the logic common to all procedures.

    A procedure can affect an organ by :
    - Adding, removing, replacing entries.
    - Adding, removing, replacing procedures.
    - Withdrawing funds and transferring them to another organ.
    The procedure can process a batch of operations in a proposal.
*/

library ProcedureLibrary {
    struct ProcedureData {
        string cid;
        address payable proposers;
        address payable moderators;
        address payable deciders;
        address payable admin;
        mapping (uint256 => Proposal) proposals;
        uint256 proposalsLength;
        bool withModeration;
        address forwarder;
        address caller;
    }

    struct Proposal {
        address payable creator;
        string cid;
        string blockReason;
        bool presented;
        bool blocked;
        bool adopted;
        bool applied;
        Operation[] operations;
    }

    struct Operation {
        uint256 index;
        address payable target;
        bytes data;
        uint256 value;
        bool processed;
    }

    /**
        Modifiers.
    */
    modifier onlyInOrgan(address payable organAddress, address sender) {
        require(isInOrgan(organAddress, sender), "Not authorized.");
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

    event CidUpdated(address from, string cid);
    event AdminUpdated(address from, address admin);
    event ProposalCreated(address indexed creator, uint256 indexed proposalKey);
    event ProposalBlocked(
        address indexed moderator,
        uint256 indexed proposalKey,
        string reason
    );
    event ProposalPresented(address indexed presenter, uint256 indexed proposalKey);
    event ProposalApplied(uint256 indexed proposalKey);

    /*
        Procedure management.
    */

    function init(
        ProcedureData storage self,
        string memory cid,
        address payable proposers,
        address payable moderators,
        address payable deciders,
        bool withModeration, // Adds an extra step where moderators can block a proposal before deciders.
        address forwarder,
        address caller
    )
        public
    {
        self.cid = cid;
        self.proposers = proposers;
        self.moderators = moderators;
        self.deciders = deciders;
        self.withModeration = withModeration;
        self.forwarder = forwarder;
        self.admin = payable(caller);
    }

    /**
        Admin API.
    */

    function updateAdmin(ProcedureData storage self, address payable admin, address caller)
        public onlyInOrgan(self.admin, caller)
    {
        self.admin = admin;
        emit AdminUpdated(msg.sender, admin);
    }

    function updateCid(
        ProcedureData storage self, string memory cid, address caller
    )
        public onlyInOrgan(self.admin, caller)
    {
        self.cid = cid;
        emit CidUpdated(msg.sender, cid);
    }

    /**
        Utils.
    */
    function isInOrgan(address payable organ, address caller)
        public view returns (bool)
    {
        return organ == address(0) || organ == caller || IOrgan(organ).getEntryIndexForAddress(caller) != 0;
    }

    /**
        External API.
    */

    /// @notice Proposers can create a proposal with a set of operations.
    /// @dev Merge with proposalCall.
    /// @param cid Metadata describing the proposal, stored on IPFS.
    /// @param operations Set of solidity calls on the procedure or given organ.
    /// @return proposalKey of proposal created.
    function propose(
        ProcedureData storage self,
        string memory cid,
        Operation[] memory operations,
        address caller
    )
        public
        onlyInOrgan(self.proposers, caller)
        returns (uint256 proposalKey)
    {
        proposalKey = self.proposalsLength++;
        self.proposals[proposalKey].creator = payable(caller);
        self.proposals[proposalKey].cid = cid;
        for (uint256 i = 0 ; i < operations.length ; ++i) {
            self.proposals[proposalKey].operations.push(Operation({
                index: self.proposals[proposalKey].operations.length,
                target: operations[i].target,
                data: operations[i].data,
                value: operations[i].value,
                processed: false
            }));
        }

        if (!self.withModeration) {
            self.proposals[proposalKey].presented = true;
        }
        emit ProposalCreated(caller, proposalKey);
        return proposalKey;
    }

    /// @notice Block proposal (veto).
    /// @param proposalKey of proposal.
    /// @param reason for blocking the proposal.
    function blockProposal(
        ProcedureData storage self,
        uint256 proposalKey,
        string memory reason,
        address caller
    )
        public
        onlyInOrgan(self.moderators, caller)
    {
        require(!self.proposals[proposalKey].blocked, "Already blocked.");
        require(!self.proposals[proposalKey].applied, "Already applied.");
        self.proposals[proposalKey].blocked = true;
        self.proposals[proposalKey].blockReason = reason;
        emit ProposalBlocked(caller, proposalKey, reason);
    }

    /// @notice Present proposal, in Moderation mode.
    /// @param proposalKey of proposal.
    function presentProposal(
        ProcedureData storage self,
        uint256 proposalKey,
        address caller
    )
        public
        onlyInOrgan(self.moderators, caller)
        onlyNewProposal(self, proposalKey)
    {
        require(self.withModeration, "Moderation not enabled.");
        self.proposals[proposalKey].presented = true;
        emit ProposalPresented(msg.sender, proposalKey);
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

    /// @notice Adopt proposal and attempt to apply it.
    /// @dev Should only be called once by parent contract.
    /// @param proposalKey of proposal.
    function rejectProposal(ProcedureData storage self, uint256 proposalKey)
        internal
        onlyPresentedProposal(self, proposalKey)
    {
        self.proposals[proposalKey].adopted = false;
        self.proposals[proposalKey].applied = true;
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
                if (self.proposals[proposalKey].operations[i].target != address(0)) {
                    // solhint-disable-next-line avoid-low-level-calls
                    (bool success,) = self.proposals[proposalKey].operations[i].target.call{value: self.proposals[proposalKey].operations[i].value}(self.proposals[proposalKey].operations[i].data);
                    require(success, "Proposal not applied, underlying transaction reverted.");
                } else {
                    // solhint-disable-next-line avoid-low-level-calls
                    (bool success,) = address(msg.sender).call{value: self.proposals[proposalKey].operations[i].value}(self.proposals[proposalKey].operations[i].data);
                    require(success, "Proposal not applied, underlying transaction reverted.");
                }
                self.proposals[proposalKey].operations[i].processed = true;
            }
        }
        self.proposals[proposalKey].applied = true;
        emit ProposalApplied(proposalKey);
    }
}
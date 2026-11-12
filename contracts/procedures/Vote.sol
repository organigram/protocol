// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import {Procedure} from '../Procedure.sol';
import {ProcedureLibrary} from '../libraries/ProcedureLibrary.sol';
import {IOrgan} from '../IOrgan.sol';

struct Vote {
    bool voted;
    bool approved;
}

struct Election {
    // Map voters' addresses to votes.
    uint256 start;
    uint48 snapshot;
    mapping(address => Vote) votes;
    address[] voters;
    uint256 votesCount;
}

/// @title Vote procedure
/// @notice A procedure in which the members of the deciders organ vote on each proposal.
/// @dev The vote opens when a proposal is presented. Once it is over, anyone calls `applyProposal` to count
/// the ballots and settle the proposal.
contract VoteProcedure is Procedure {
    using ProcedureLibrary for ProcedureLibrary.Operation;
    /// @notice vote().
    bytes4 private constant _INTERFACE_VOTE = 0xc9d27afe;
    bytes32 private constant VOTE_TYPEHASH =
        keccak256(
            'Vote(uint256 proposalKey,bool approval,uint256 nonce,uint256 deadline)'
        );
    mapping(uint256 => Election) internal elections;
    /// @notice Share of the voters who must vote, in thousandths of a percent.
    uint32 public quorumSize; // Minimum number of votes.
    /// @notice Duration of a vote, in seconds.
    uint32 public voteDuration; // Duration of vote in seconds.
    /// @notice Share of the ballots that must approve, in thousandths of a percent.
    uint32 public majoritySize; // majoritySize.div((2^32)-1) is the minimum ratio for adoption.

    /// @dev Register EIP165 interfaces for introspection.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == _INTERFACE_VOTE ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Check that initialize parameters are correct.
    function initialize(
        string memory,
        address payable,
        address payable,
        address payable,
        bool,
        address
    ) public pure override {
        revert('Missing parameters');
    }

    /// @notice Initialize the procedure.
    function initialize(
        string memory _cid,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        address _trustedForwarder,
        uint32 _quorumSize,
        uint32 _voteDuration,
        uint32 _majoritySize
    ) public virtual {
        super.initialize(
            _cid,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder
        );
        require(_voteDuration > 0, 'Invalid vote duration.');
        require(_quorumSize <= 100000, 'Invalid quorum size.');
        require(
            _majoritySize > 0 && _majoritySize <= 100000,
            'Invalid majority size.'
        );
        // Register EIP165 interface for introspection.
        quorumSize = _quorumSize;
        voteDuration = _voteDuration;
        majoritySize = _majoritySize;
    }

    /// @notice Create a election.
    function vote(uint256 proposalKey, bool approval) public {
        require(_canVote(_msgSender(), proposalKey), 'Not authorized');
        _vote(_msgSender(), proposalKey, approval);
    }

    /// @notice Cast a vote signed by a decider, relayed by any account.
    function voteBySig(
        uint256 proposalKey,
        bool approval,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) public {
        address signer = _recoverTypedSigner(
            keccak256(
                abi.encode(
                    VOTE_TYPEHASH,
                    proposalKey,
                    approval,
                    nonce,
                    deadline
                )
            ),
            nonce,
            deadline,
            signature
        );
        require(_canVote(signer, proposalKey), 'Not authorized');
        _vote(signer, proposalKey, approval);
    }

    function _vote(address voter, uint256 proposalKey, bool approval) internal {
        require(
            block.timestamp > elections[proposalKey].start,
            'Election not started.'
        );
        require(
            block.timestamp < (elections[proposalKey].start + voteDuration),
            'Election ended.'
        );
        require(
            !elections[proposalKey].votes[voter].voted,
            'Duplicate record.'
        );
        elections[proposalKey].votes[voter] = Vote({
            voted: true,
            approved: approval
        });
        elections[proposalKey].voters.push(voter);
        elections[proposalKey].votesCount++;
    }

    function _startElection(uint256 proposalKey) internal virtual {
        elections[proposalKey].start = block.timestamp;
    }

    function _canPropose(address account) internal view virtual returns (bool) {
        return ProcedureLibrary.isInOrgan(procedureData.proposers, account);
    }

    function _canModerate(
        address account
    ) internal view virtual returns (bool) {
        return ProcedureLibrary.isInOrgan(procedureData.moderators, account);
    }

    function _canVote(
        address account,
        uint256
    ) internal view virtual returns (bool) {
        return ProcedureLibrary.isInOrgan(procedureData.deciders, account);
    }

    /// @notice Count votes when election is ended.
    /// @dev @todo Handle delegation of Votes.
    /// @return approved True if the proposal is adopted.
    function count(
        uint256 proposalKey
    ) public view virtual returns (bool approved) {
        require(elections[proposalKey].start > 0, 'No election.');
        require(
            block.timestamp >= (elections[proposalKey].start + voteDuration),
            'Election not ended.'
        );
        (
            uint256 approvals,
            uint256 objections,
            uint256 eligibleVotes
        ) = getElectionResults(proposalKey);
        uint256 votesCast = approvals + objections;
        if (
            votesCast <
            ((quorumSize * eligibleVotes) / 100000)
        ) {
            return false;
        }
        if (votesCast == 0) return false;
        return
            approvals * 100000 >=
            votesCast * majoritySize;
    }

    /// @notice Get the current vote split and the eligible voting base.
    /// @dev ERC20VoteProcedure overrides this to use snapshot voting power.
    /// @return approvals The number of approving votes.
    /// @return objections The number of rejecting votes.
    /// @return eligibleVotes The number of votes eligible to participate.
    function getElectionResults(
        uint256 proposalKey
    ) public view virtual returns (
        uint256 approvals,
        uint256 objections,
        uint256 eligibleVotes
    ) {
        Election storage election = elections[proposalKey];
        for (uint256 i = 0; i < election.voters.length; i++) {
            Vote storage voterVote = election.votes[election.voters[i]];
            if (!voterVote.voted) continue;
            if (voterVote.approved) {
                approvals++;
            } else {
                objections++;
            }
        }
        eligibleVotes = _getOrganEntriesCount(procedureData.deciders);
    }

    function _getOrganEntriesCount(
        address payable organAddress
    ) internal view returns (uint256 entriesCount) {
        (
            string memory cid,
            uint256 permissionsLength,
            uint256 entriesLength,
            uint256 activeEntriesCount,
            bytes4 interfaceId
        ) = IOrgan(organAddress).getOrgan();
        cid;
        permissionsLength;
        entriesLength;
        interfaceId;
        return activeEntriesCount;
    }

    /**
      Procedure methods overrides.
  */

    /// @dev Applies to `propose` and `proposeBySig`.
    function _propose(
        string memory _cid,
        ProcedureLibrary.Operation[] memory _operations,
        address creator
    ) internal override returns (uint256 proposalKey) {
        require(_canPropose(creator), 'Not authorized');
        _validateOwnerBoundOperations(_operations, creator);
        proposalKey = ProcedureLibrary.proposeUnchecked(
            procedureData,
            _cid,
            _operations,
            creator
        );
        if (procedureData.proposals[proposalKey].presented) {
            _startElection(proposalKey);
        }
        return proposalKey;
    }

    /// @dev Applies to `presentProposal` and `presentProposalBySig`.
    function _presentProposal(
        uint256 proposalKey,
        address moderator
    ) internal override {
        require(_canModerate(moderator), 'Not authorized');
        ProcedureLibrary.presentProposalUnchecked(
            procedureData,
            proposalKey,
            moderator
        );
        _startElection(proposalKey);
    }

    /// @notice A veto accepts arguments which defines a motivation as a IPFS multihash.
    /// @dev Applies to `blockProposal` and `blockProposalBySig`.
    function _blockProposal(
        uint256 proposalKey,
        string memory reason,
        address moderator
    ) internal override {
        require(_canModerate(moderator), 'Not authorized');
        require(elections[proposalKey].start == 0, 'Election already started.');
        ProcedureLibrary.blockProposalUnchecked(
            procedureData,
            proposalKey,
            reason,
            moderator
        );
    }

    /// @notice Finalize a vote once the election has ended.
    /// @dev Anyone can trigger the settlement transaction once voting is over.
    function _applyProposal(uint256 proposalKey) internal override {
        if (count(proposalKey)) {
            // The caller already holds the reentrancy lock. Calling the
            // guarded helper on Procedure would attempt to acquire it a
            // second time and always revert before the proposal operation.
            super._applyAdoptedProposal(proposalKey);
        } else {
            super._applyRejectedProposal(proposalKey);
        }
    }

    /// @notice Get information about a current election
    /// @return start The UNIX time when the election started.
    /// @return hasVoted True if the voter has voted.
    /// @return votesCount The number of votes cast so far.
    function getElection(
        uint256 _proposalKey
    ) public view returns (uint256 start, bool hasVoted, uint256 votesCount) {
        return (
            elections[_proposalKey].start,
            elections[_proposalKey].votes[_msgSender()].voted,
            elections[_proposalKey].votesCount
        );
    }
}

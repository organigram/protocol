// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../libraries/CoreLibrary.sol";
import "../Procedure.sol";

/*
  Vote Procedure.
  A Vote Procedure will apply an effect based on the decision of a vote.
  Votes can be vetoed, and enacted.
*/

struct Vote {
  bool voted;
  bool approved;
}

struct Ballot {
  // Vote.
  // Map voters' addresses to votes.
  uint256 start;
  mapping(address => Vote) votes;
  address[] voters;
  uint256 votesCount;
}

contract VoteProcedure is Procedure {
  using CoreLibrary for CoreLibrary.Metadata;
  using ProcedureLibrary for ProcedureLibrary.Operation;
  bytes4 private constant _INTERFACE_VOTE = 0xc9d27afe; // vote().
  mapping(uint256 => Ballot) internal ballots;
  uint32 public quorumSize; // Minimum number of votes.
  uint32 public voteDuration; // Duration of vote in blocks.
  uint32 public majoritySize; // majoritySize.div((2^32)-1) is the minimum ratio for adoption.

  // Register EIP165 interfaces for introspection.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override
    returns (bool)
  {
    return interfaceId == _INTERFACE_VOTE ||
      super.supportsInterface(interfaceId);
  }

  function initialize(
    CoreLibrary.Metadata memory,
    address payable,
    address payable,
    address payable,
    bool
  )
    public
    pure
    override
  {
    revert("Missing parameters");
  }

  function initialize(
    CoreLibrary.Metadata memory _metadata,
    address payable _proposers,
    address payable _moderators,
    address payable _deciders,
    bool _withModeration,
    uint32 _quorumSize,
    uint32 _voteDuration,
    uint32 _majoritySize
  )
    public
  {
    super.initialize(
      _metadata,
      _proposers,
      _moderators,
      _deciders,
      _withModeration
    );
    // Register EIP165 interface for introspection.
    quorumSize = _quorumSize;
    voteDuration = _voteDuration;
    majoritySize = _majoritySize;
  }

  function vote(uint256 proposalKey, bool approval)
    public
    onlyInOrgan(procedureData.deciders)
  {
    require(
      block.number > ballots[proposalKey].start,
      "Ballot not started."
    );
    require(
      block.number < (ballots[proposalKey].start + voteDuration),
      "Ballot ended."
    );
    require(
      !ballots[proposalKey].votes[msg.sender].voted,
      "Duplicate record."
    );
    ballots[proposalKey].votes[msg.sender] = Vote({
      voted: true,
      approved: approval
    });
    ballots[proposalKey].voters.push(msg.sender);
    ballots[proposalKey].votesCount++;
  }

  /// @notice Count votes when ballot is ended.
  /// @dev @todo Handle delegation of Votes.
  function count(uint256 proposalKey)
    public
    view
    returns (bool approved)
  {
    require(ballots[proposalKey].start > 0, "No ballot.");
    require(
      block.number >= (ballots[proposalKey].start + voteDuration),
      "Ballot not ended."
    );
    if (ballots[proposalKey].votesCount < quorumSize) {
      return false;
    }
    uint256 approvals;
    for (uint256 i = 0; i < ballots[proposalKey].voters.length; i++) {
      if (
        ballots[proposalKey]
          .votes[ballots[proposalKey].voters[i]]
          .voted &&
        ballots[proposalKey]
          .votes[ballots[proposalKey].voters[i]]
          .approved
      ) {
        approvals++;
      }
    }
    return (
      (approvals / ballots[proposalKey].votesCount) >
      (majoritySize / (uint32((2**32) - 1)))
    );
  }

  /**
      Procedure methods overrides.
  */

  function propose(
    CoreLibrary.Metadata memory _metadata,
    ProcedureLibrary.Operation[] memory _operations
  )
    public
    override
    onlyInOrgan(procedureData.proposers)
    returns (uint256 proposalKey)
  {
    proposalKey = super.propose(_metadata, _operations);
    if (procedureData.proposals[proposalKey].presented) {
      ballots[proposalKey].start = block.number;
    }
    return proposalKey;
  }

  function presentProposal(uint256 proposalKey)
    public override
    onlyInOrgan(procedureData.moderators)
  {
    super.presentProposal(proposalKey);
    ballots[proposalKey].start = block.number;
  }

  /// @notice A veto accepts arguments which defines a motivation as a IPFS multihash.
  /// @dev Overrides Procedure.blockProposal.
  function blockProposal(
    uint256 proposalKey,
    CoreLibrary.Metadata calldata reason
  )
    public
    override
    onlyInOrgan(procedureData.moderators)
  {
    require(ballots[proposalKey].start != 0, "Ballot started.");
    super.blockProposal(proposalKey, reason);
  }

  function adoptProposal(uint256 proposalKey)
    public
    override
    onlyInOrgan(procedureData.moderators)
  {
    // count() returns true if enactment is possible.
    require(count(proposalKey), "Not authorized");
    super.adoptProposal(proposalKey);
  }

  function getBallot(uint256 _proposalKey)
    public
    view
    returns (
      uint256 start,
      bool hasVoted,
      uint256 votesCount
    )
  {
    return (
      ballots[_proposalKey].start,
      ballots[_proposalKey].votes[msg.sender].voted,
      ballots[_proposalKey].votesCount
    );
  }
}

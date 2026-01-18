// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "../Procedure.sol";

struct Vote {
  bool voted;
  bool approved;
}

struct Election {
  // Map voters' addresses to votes.
  uint256 start;
  mapping(address => Vote) votes;
  address[] voters;
  uint256 votesCount;
}


/// @title Vote Procedure
/// @notice  A Vote Procedure will execute operation(s) based on the decision of a vote.
/// @dev Votes can be vetoed, and enacted.
contract VoteProcedure is Procedure {
  using ProcedureLibrary for ProcedureLibrary.Operation;
  /// @notice vote().
  bytes4 private constant _INTERFACE_VOTE = 0xc9d27afe;
  mapping(uint256 => Election) internal elections;
  uint32 public quorumSize; // Minimum number of votes.
  uint32 public voteDuration; // Duration of vote in seconds.
  uint32 public majoritySize; // majoritySize.div((2^32)-1) is the minimum ratio for adoption.

  /// @dev Register EIP165 interfaces for introspection.
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

  /// @notice Check that initialize parameters are correct.
  function initialize(
    string memory,
    address payable,
    address payable,
    address payable,
    bool,
    address
  )
    public
    pure
    override
  {
    revert("Missing parameters");
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
  )
    public
    virtual
  {
    super.initialize(
      _cid,
      _proposers,
      _moderators,
      _deciders,
      _withModeration,
      _trustedForwarder
    );
    // Register EIP165 interface for introspection.
    quorumSize = _quorumSize;
    voteDuration = _voteDuration;
    majoritySize = _majoritySize;
  }

  /// @notice Create a election.
  function vote(uint256 proposalKey, bool approval)
    public
    onlyInOrgan(procedureData.deciders)
  {
    require(
      block.timestamp > elections[proposalKey].start,
      "Election not started."
    );
    require(
      block.timestamp < (elections[proposalKey].start + voteDuration),
      "Election ended."
    );
    require(
      !elections[proposalKey].votes[_msgSender()].voted,
      "Duplicate record."
    );
    elections[proposalKey].votes[_msgSender()] = Vote({
      voted: true,
      approved: approval
    });
    elections[proposalKey].voters.push(_msgSender());
    elections[proposalKey].votesCount++;
  }

  /// @notice Count votes when election is ended.
  /// @dev @todo Handle delegation of Votes.
  /// @return approved True if the proposal is adopted.
  function count(uint256 proposalKey)
    public
    view
    returns (bool approved)
  {
    require(elections[proposalKey].start > 0, "No election.");
    require(
      block.timestamp >= (elections[proposalKey].start + voteDuration),
      "Election not ended."
    );
    (,,,uint256 decidersCount,) = IOrgan(procedureData.deciders).getOrgan();
    if (elections[proposalKey].votesCount < ((quorumSize * decidersCount) / 100000)) {
      return false;
    }
    uint256 approvals;
    for (uint256 i = 0; i < elections[proposalKey].voters.length; i++) {
      if (
        elections[proposalKey]
          .votes[elections[proposalKey].voters[i]]
          .voted &&
        elections[proposalKey]
          .votes[elections[proposalKey].voters[i]]
          .approved
      ) {
        approvals++;
      }
    }

    require(elections[proposalKey].votesCount > 0, "No vote");
    return (
      approvals >
      ((elections[proposalKey].votesCount * majoritySize) / 100000)
    );
  }

  /**
      Procedure methods overrides.
  */

  /// @notice Propose a new proposal.
  /// @dev Overrides Procedure.propose.
  /// @return proposalKey The key of the proposal.
  function propose(
    string memory _cid,
    ProcedureLibrary.Operation[] memory _operations
  )
    public
    override
    onlyInOrgan(procedureData.proposers)
    returns (uint256 proposalKey)
  {
    proposalKey = super.propose(_cid, _operations);
    if (procedureData.proposals[proposalKey].presented) {
      elections[proposalKey].start = block.timestamp;
    }
    return proposalKey;
  }

  /// @notice Present a proposal.
  /// @dev Overrides Procedure.
  function presentProposal(uint256 proposalKey)
    public override
    onlyInOrgan(procedureData.moderators)
  {
    super.presentProposal(proposalKey);
    elections[proposalKey].start = block.timestamp;
  }

  /// @notice A veto accepts arguments which defines a motivation as a IPFS multihash.
  /// @dev Overrides Procedure.blockProposal.
  function blockProposal(
    uint256 proposalKey,
    string calldata reason
  )
    public
    override
    onlyInOrgan(procedureData.moderators)
  {
    require(elections[proposalKey].start != 0, "Election started.");
    super.blockProposal(proposalKey, reason);
  }

  /// @notice A veto accepts arguments which defines a motivation as a IPFS multihash.
  /// @dev Overrides Procedure.adoptProposal.
  function adoptProposal(uint256 proposalKey)
    public
    override
    onlyInOrgan(procedureData.moderators)
  {
    if (count(proposalKey)) {
      super.adoptProposal(proposalKey);
    } else {
      super.rejectProposal(proposalKey);
    }
  }

  /// @notice Get information about a current election
  /// @return start The UNIX time when the election started.
  /// @return hasVoted True if the voter has voted.
  /// @return votesCount The number of votes cast so far.
  function getElection(uint256 _proposalKey)
    public
    view
    returns (
      uint256 start,
      bool hasVoted,
      uint256 votesCount
    )
  {
    return (
      elections[_proposalKey].start,
      elections[_proposalKey].votes[_msgSender()].voted,
      elections[_proposalKey].votesCount
    );
  }
}

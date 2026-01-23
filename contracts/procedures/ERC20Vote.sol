// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

import '../Procedure.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

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

/// @title ERC20 Vote Procedure.
/// @notice An ERC20 Vote Procedure will execute operations based on the decision of a vote. The voter's relative weight in the vote depends on the amount of tokens they own of a certain asset.
contract ERC20VoteProcedure is Procedure {
    using ProcedureLibrary for ProcedureLibrary.Operation;
    /// @notice Function signature for vote().
    bytes4 private constant _INTERFACE_VOTE = 0xc9d27afe;
    mapping(uint256 => Election) internal elections;
    /// @notice tokenContract is an ERC20 token contract representing the rights to vote.
    IERC20 public tokenContract;
    /// @notice quorumSize is the minimum percentage of votes required to validate a election.
    /// @dev Minimum value (1) is 0.0001% (1/1000000) of all the votes cast.
    uint32 public quorumSize;
    /// @notice Duration of vote in seconds.
    uint32 public voteDuration;
    /// @notice majoritySize is the minimum percentage of votes required to validate a election.
    /// @dev Minimum value (1) is 0.0001% (1/1000000) of all addresses allowed to vote.
    uint32 public majoritySize; //

    ///@notice Register EIP165 interfaces for introspection.
    /// @param interfaceId The interface identifier.
    /// @return isSupported True if the interface is supported, false otherwise.
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
    /// @param _metadata The procedure metadata.
    /// @param _proposers The organ whose entries will be allowed to propose proposals.
    /// @param _moderators The organ whose entries will be allowed to moderate proposals.
    /// @param _deciders The organ whose entries will be allowed to adopt or refect proposals.
    /// @param _withModeration Whether or not the procedure requires moderation.
    /// @param _trustedForwarder The trusted forwarder contract.
    /// @param _tokenContract The ERC20 token contract representing the rights to vote.
    /// @param _quorumSize The minimum percentage of votes required to validate a election.
    /// @param _voteDuration Duration of vote in seconds.
    /// @param _majoritySize The minimum percentage of votes required to validate a election.
    function initialize(
        string memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        address _trustedForwarder,
        address _tokenContract,
        uint32 _quorumSize,
        uint32 _voteDuration,
        uint32 _majoritySize
    ) public virtual {
        super.initialize(
            _metadata,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder
        );
        // @todo : Check if tokenContract implements ERC20.
        tokenContract = IERC20(_tokenContract);
        quorumSize = _quorumSize;
        voteDuration = _voteDuration;
        majoritySize = _majoritySize;
    }

    /// @notice Vote for a proposal.
    /// @param proposalKey The key used to identify the proposal.
    /// @param approval True if the voter approves the proposal, false otherwise.
    function vote(
        uint256 proposalKey,
        bool approval
    ) public onlyInOrgan(procedureData.deciders) {
        require(
            block.timestamp > elections[proposalKey].start,
            'Election not started'
        );
        require(
            block.timestamp < (elections[proposalKey].start + voteDuration),
            'Election ended'
        );
        require(
            !elections[proposalKey].votes[_msgSender()].voted,
            'Duplicate record'
        );
        elections[proposalKey].votes[_msgSender()] = Vote({
            voted: true,
            approved: approval
        });
        elections[proposalKey].voters.push(_msgSender());
        elections[proposalKey].votesCount++;
    }

    /// @notice Count votes after election has ended.
    /// @param proposalKey The key used to identify the proposal.
    /// @return approved True if the election has been approved.
    function count(uint256 proposalKey) public view returns (bool approved) {
        require(elections[proposalKey].start > 0, 'No election');
        require(
            block.timestamp >= (elections[proposalKey].start + voteDuration),
            'Election not ended'
        );
        if (procedureData.deciders != address(0)) {
            (, , , uint256 decidersCount, ) = IOrgan(procedureData.deciders)
                .getOrgan();
            require(
                elections[proposalKey].votesCount >
                    ((quorumSize * decidersCount) / 100000),
                'Quorum has not been reached'
            );
        }
        uint256 approvals;
        uint256 objections;
        for (uint256 i = 0; i < elections[proposalKey].voters.length; i++) {
            if (
                elections[proposalKey]
                    .votes[elections[proposalKey].voters[i]]
                    .voted
            ) {
                if (
                    elections[proposalKey]
                        .votes[elections[proposalKey].voters[i]]
                        .approved
                ) {
                    approvals += tokenContract.balanceOf(
                        elections[proposalKey].voters[i]
                    );
                } else {
                    objections += tokenContract.balanceOf(
                        elections[proposalKey].voters[i]
                    );
                }
            }
        }
        require((approvals + objections) > 0, 'No vote');
        return (approvals >
            (((approvals + objections) * majoritySize) / 100000));
    }

    /**
      Procedure methods overrides.
  */

    /// @notice Propose a new election.
    /// @dev Overrides ProcedureLibrary.propose.
    /// @param _metadata IPFS multihash of the proposal metadata.
    /// @param _operations Array of operations to execute if the proposal is approved.
    /// @return proposalKey The key of the proposal.
    function propose(
        string memory _metadata,
        ProcedureLibrary.Operation[] memory _operations
    )
        public
        override
        onlyInOrgan(procedureData.proposers)
        returns (uint256 proposalKey)
    {
        proposalKey = super.propose(_metadata, _operations);
        if (procedureData.proposals[proposalKey].presented) {
            elections[proposalKey].start = block.timestamp;
        }
        return proposalKey;
    }

    /// @notice Present a election.
    /// @dev Overrides ProcedureLibrary.presentProposal.
    /// @param proposalKey The key of the proposal to present.
    function presentProposal(
        uint256 proposalKey
    ) public override onlyInOrgan(procedureData.moderators) {
        super.presentProposal(proposalKey);
        elections[proposalKey].start = block.timestamp;
    }

    /// @notice A veto accepts arguments which defines a motivation as a IPFS multihash.
    /// @dev Overrides Procedure.blockProposal.
    /// @param proposalKey The key of the proposal to block.
    /// @param reason The IPFS multihash of the document explaining why the proposal has been blocked.
    function blockProposal(
        uint256 proposalKey,
        string calldata reason
    ) public override onlyInOrgan(procedureData.moderators) {
        require(elections[proposalKey].start != 0, 'Election started');
        super.blockProposal(proposalKey, reason);
    }

    /// @notice Enact the proposal.
    /// @dev Overrides ProcedureLibrary.adoptProposal.
    /// Having count here snapshots the votes.
    /// If a high gas price transaction transfers a lot of tokens,
    /// and then calls adoptProposal, the result of the vote could
    /// be determined by the highest bidder.
    /// @param proposalKey The key of the proposal to adopt.
    function adoptProposal(
        uint256 proposalKey
    ) public override onlyInOrgan(procedureData.moderators) {
        if (count(proposalKey)) {
            super.adoptProposal(proposalKey);
        } else {
            super.rejectProposal(proposalKey);
        }
    }

    /// @notice Get election information.
    /// @param _proposalKey The key used to identify the proposal.
    /// @return start Election start UNIX time.
    /// @return hasVoted True if the sender has voted.
    /// @return votesCount Number of votes cast so far.
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

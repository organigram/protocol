// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import './Vote.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title ERC20 Vote Procedure.
/// @notice An ERC20 Vote Procedure will execute operations based on the decision of a vote. The voter's relative weight in the vote depends on the amount of tokens they own of a certain asset.
contract ERC20VoteProcedure is VoteProcedure {
    /// @notice tokenContract is an ERC20 token contract representing the rights to vote.
    IERC20 public tokenContract;

    /// @notice Prevent using the non-ERC20 initializer inherited from VoteProcedure.
    function initialize(
        string memory,
        address payable,
        address payable,
        address payable,
        bool,
        address,
        uint32,
        uint32,
        uint32
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
    /// @param _quorumSize The minimum percentage of votes required to validate a election.
    /// @param _voteDuration Duration of vote in seconds.
    /// @param _majoritySize The minimum percentage of votes required to validate a election.
    /// @param _tokenContract The ERC20 token contract representing the rights to vote.
    function initialize(
        string memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        address _trustedForwarder,
        uint32 _quorumSize,
        uint32 _voteDuration,
        uint32 _majoritySize,
        address _tokenContract
    ) public virtual {
        super.initialize(
            _metadata,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder,
            _quorumSize,
            _voteDuration,
            _majoritySize
        );
        // @todo : Check if tokenContract implements ERC20.
        tokenContract = IERC20(_tokenContract);
    }

    /// @notice Count votes after election has ended.
    /// @param proposalKey The key used to identify the proposal.
    /// @return approved True if the election has been approved.
    function count(
        uint256 proposalKey
    ) public view override returns (bool approved) {
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
}

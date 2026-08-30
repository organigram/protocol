// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
pragma experimental ABIEncoderV2;

import {VoteProcedure} from './Vote.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC5805} from '@openzeppelin/contracts/interfaces/IERC5805.sol';

/// @title ERC20 Vote Procedure.
/// @notice An ERC20 Vote Procedure will execute operations based on the decision of a vote. The voter's relative weight in the vote depends on the amount of tokens they own of a certain asset.
contract ERC20VoteProcedure is VoteProcedure {
    enum RoleMode {
        ORGAN,
        TOKEN,
        DISABLED
    }

    /// @notice tokenContract is an ERC20Votes-compatible token representing the rights to vote.
    IERC5805 public tokenContract;
    RoleMode public proposerMode;
    RoleMode public moderatorMode;
    RoleMode public voterMode;
    /// @notice When voters come from an organ, require a majority of its members in addition
    /// to the usual token-weighted quorum and majority.
    bool public requireMemberMajority;

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
        _initializeErc20VoteProcedure(
            _metadata,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder,
            _quorumSize,
            _voteDuration,
            _majoritySize,
            _tokenContract,
            [RoleMode.ORGAN, RoleMode.ORGAN, RoleMode.ORGAN],
            false
        );
    }

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
        address _tokenContract,
        uint8[3] memory _roleModes
    ) public virtual {
        _initializeErc20VoteProcedure(
            _metadata,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder,
            _quorumSize,
            _voteDuration,
            _majoritySize,
            _tokenContract,
            [
                _roleModeFromUint8(_roleModes[0]),
                _roleModeFromUint8(_roleModes[1]),
                _roleModeFromUint8(_roleModes[2])
            ],
            false
        );
    }

    /// @notice Initialize an ERC-20 vote with optional member-majority validation.
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
        address _tokenContract,
        uint8[3] memory _roleModes,
        bool _requireMemberMajority
    ) public virtual {
        _initializeErc20VoteProcedure(
            _metadata,
            _proposers,
            _moderators,
            _deciders,
            _withModeration,
            _trustedForwarder,
            _quorumSize,
            _voteDuration,
            _majoritySize,
            _tokenContract,
            [
                _roleModeFromUint8(_roleModes[0]),
                _roleModeFromUint8(_roleModes[1]),
                _roleModeFromUint8(_roleModes[2])
            ],
            _requireMemberMajority
        );
    }

    function _initializeErc20VoteProcedure(
        string memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        address _trustedForwarder,
        uint32 _quorumSize,
        uint32 _voteDuration,
        uint32 _majoritySize,
        address _tokenContract,
        RoleMode[3] memory _roleModes,
        bool _requireMemberMajority
    ) internal {
        require(_tokenContract.code.length > 0, 'Invalid token contract.');
        require(_roleModes[0] != RoleMode.DISABLED, 'Invalid proposer mode.');
        require(_roleModes[2] != RoleMode.DISABLED, 'Invalid voter mode.');
        require(
            !_withModeration || _roleModes[1] != RoleMode.DISABLED,
            'Invalid moderator mode.'
        );
        require(
            !_requireMemberMajority || _roleModes[2] == RoleMode.ORGAN,
            'Member majority requires organ voters.'
        );
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
        tokenContract = IERC5805(_tokenContract);
        uint48 currentClock = tokenContract.clock();
        currentClock;
        proposerMode = _roleModes[0];
        moderatorMode = _roleModes[1];
        voterMode = _roleModes[2];
        requireMemberMajority = _requireMemberMajority;
    }

    function _startElection(uint256 proposalKey) internal override {
        super._startElection(proposalKey);
        uint48 currentClock = tokenContract.clock();
        require(currentClock > 0, 'Invalid token clock.');
        elections[proposalKey].snapshot = currentClock - 1;
    }

    function _canPropose(
        address account
    ) internal view override returns (bool) {
        if (proposerMode == RoleMode.ORGAN) {
            return super._canPropose(account);
        }
        if (proposerMode == RoleMode.TOKEN) {
            return _hasCurrentTokenBalance(account);
        }
        return false;
    }

    function _canModerate(
        address account
    ) internal view override returns (bool) {
        if (moderatorMode == RoleMode.ORGAN) {
            return super._canModerate(account);
        }
        if (moderatorMode == RoleMode.TOKEN) {
            return _hasCurrentTokenBalance(account);
        }
        return false;
    }

    function _canVote(
        address account,
        uint256 proposalKey
    ) internal view override returns (bool) {
        if (voterMode == RoleMode.ORGAN) {
            return super._canVote(account, proposalKey);
        }
        if (voterMode == RoleMode.TOKEN) {
            uint48 snapshot = elections[proposalKey].snapshot;
            return
                snapshot > 0 &&
                tokenContract.getPastVotes(account, snapshot) > 0;
        }
        return false;
    }

    function _hasCurrentTokenBalance(
        address account
    ) internal view returns (bool) {
        return IERC20(address(tokenContract)).balanceOf(account) > 0;
    }

    function _roleModeFromUint8(uint8 mode) internal pure returns (RoleMode) {
        require(mode <= uint8(RoleMode.DISABLED), 'Invalid role mode.');
        return RoleMode(mode);
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
        uint48 snapshot = elections[proposalKey].snapshot;
        uint256 approvals = 0;
        uint256 objections = 0;
        for (uint256 i = 0; i < elections[proposalKey].voters.length; i++) {
            address voter = elections[proposalKey].voters[i];
            if (elections[proposalKey].votes[voter].voted) {
                uint256 weight = tokenContract.getPastVotes(voter, snapshot);
                if (elections[proposalKey].votes[voter].approved) {
                    approvals += weight;
                } else {
                    objections += weight;
                }
            }
        }
        uint256 votesCast = approvals + objections;
        require(votesCast > 0, 'No vote');
        require(
            votesCast >=
                ((quorumSize * tokenContract.getPastTotalSupply(snapshot)) /
                    100000),
            'Quorum has not been reached'
        );
        if (requireMemberMajority) {
            uint256 approvingMembers = 0;
            for (uint256 i = 0; i < elections[proposalKey].voters.length; i++) {
                address voter = elections[proposalKey].voters[i];
                if (elections[proposalKey].votes[voter].approved)
                    approvingMembers++;
            }
            require(
                approvingMembers * 2 >
                    _getOrganEntriesCount(procedureData.deciders),
                'Member majority has not been reached'
            );
        }
        return (approvals > ((votesCast * majoritySize) / 100000));
    }
}

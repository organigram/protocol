// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../libraries/MetadataLibrary.sol";
import "../Procedure.sol";
import "../libraries/VotePropositionLibrary.sol";
import "../libraries/MetadataLibrary.sol";

/*
    Vote Procedure.
    A Vote Procedure will apply an effect based on the decision of a vote.
    Votes can be vetoed, and enacted.

    @TODO : Add propositions getter.
*/

contract VoteProcedure is Procedure {
    using MetadataLibrary for MetadataLibrary.Metadata;
    using VotePropositionLibrary for VotePropositionLibrary.Proposition;
    using MetadataLibrary for MetadataLibrary.Metadata;
    bytes4 private constant _INTERFACE_VOTE = 0xc9d27afe; // vote().
    // A Proposition is mapped to a locked proposal.
    mapping (uint256 => VotePropositionLibrary.Proposition) internal propositions;
    uint32 public quorumSize;   // Minimum number of voters.
    uint32 public voteDuration; // Duration of vote in blocks.
    uint32 public majoritySize; // majoritySize.div((2^32)-1) is the minimum ratio for adoption.

    constructor ()
        public
    {
        quorumSize = 0;
        voteDuration = 0;
        enactors = address(0);
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_VOTE);
    }

    function initialize(
        MetadataLibrary.Metadata memory _metadata,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        uint32 _quorumSize,
        uint32 _voteDuration,
        uint32 _majoritySize
    ) 
        external
    {
        super.initialize(_metadata, _proposers, _moderators, _deciders, _withModeration);
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_VOTE);
        quorumSize = _quorumSize;
        voteDuration = _voteDuration;
        enactmentDuration = _enactmentDuration;
        majoritySize = _majoritySize;
    }

    function vote(uint256 proposalKey, bool approval)
        public onlyInOrgan(deciders())
    {
        propositions[proposalKey].vote(approval);
    }

    // A veto accepts arguments which defines a motivation as a IPFS multihash.
    function veto(uint256 proposalKey, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize)
        public onlyInOrgan(moderators())
    {
        propositions[proposalKey].veto(ipfsHash, hashFunction, hashSize);
    }

    function count(uint256 proposalKey)
        public view returns (bool)
    {
        return propositions[proposalKey].count();
    }

    function enact(uint256 proposalKey)
        public onlyInOrgan(moderators())
    {
        // proposition.count() returns true if enactment is possible.
        require (propositions[proposalKey].count(), "Not authorized");
        Procedure.adoptProposal(proposalKey);
        propositions[proposalKey].enact();
    }


    function getProposition(uint256 proposalKey)
        public
        view
        returns (
            address payable,
            uint256,
            uint256,
            uint256,
            uint256,
            address payable,
            address payable
        )
    {
        return (
            propositions[proposalKey].creator,
            propositions[proposalKey].quorumSize,
            propositions[proposalKey].voteDuration,
            propositions[proposalKey].enactmentDuration,
            propositions[proposalKey].majoritySize,
            propositions[proposalKey].vetoer,
            propositions[proposalKey].enactor
        );
    }

    function getPropositionMetadata(uint256 proposalKey)
        public view
        returns (MetadataLibrary.Metadata memory)
    {
        return propositions[proposalKey].metadata;
    }

    function getPropositionVetoMetadata(uint256 proposalKey)
        public view
        returns (MetadataLibrary.Metadata memory)
    {
        return propositions[proposalKey].vetoMetadata;
    }
}
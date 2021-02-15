// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./MetadataLibrary.sol";

/*
    Library for a vote.
    Stores how votes, vetoes and enactment operates.
*/

library VotePropositionLibrary {
    using MetadataLibrary for MetadataLibrary.Metadata;

    struct Ballot {
        address payable creator;
        // MetadataLibrary.Metadata can describe a proposition.
        // Cannot be updated after creation.
        MetadataLibrary.Metadata metadata;
        uint256 quorumSize;
        uint256 voteDuration;
        uint256 enactmentDuration;
        uint256 majoritySize;
        // Vote.
        // Map voters' addresses to votes.
        mapping(address => Vote) votes;
        address[] voters;
        uint256 votesCount;
        // Veto.
        address payable vetoer;
        MetadataLibrary.Metadata vetoMetadata;
        // Enactment.
        address payable enactor;
    }

    struct Vote {
        bool voted;
        bool approved;
    }

    /*
        Proposition management.
    */

    function init(
        Proposition storage self,
        bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize,
        uint256 quorumSize, uint256 voteDuration, uint256 enactmentDuration, uint256 majoritySize
    )
        external
    {
        self.creator = msg.sender;
        self.metadata = MetadataLibrary.Metadata({
            ipfsHash: ipfsHash,
            hashFunction: hashFunction,
            hashSize: hashSize
        });
        self.quorumSize = quorumSize;
        self.voteDuration = voteDuration;
        self.enactmentDuration = enactmentDuration;
        self.majoritySize = majoritySize;
    }

    function vote(
        Proposition storage self,
        bool approval
    )
        external
    {
        self.votes[msg.sender] = Vote({
            voted: true,
            approved: approval
        });
        self.voters.push(msg.sender);
        self.votesCount++;
    }

    function veto(
        Proposition storage self,
        bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize
    )
        external
    {
        self.vetoer = msg.sender;
        self.vetoMetadata = MetadataLibrary.Metadata({
            ipfsHash: ipfsHash,
            hashFunction: hashFunction,
            hashSize: hashSize
        });
    }

    function count(Proposition storage self)
        external view
        returns (bool)
    {
        // @TODO : returns boolean.
        uint256 approval;
        for (uint256 i = 0; i < self.voters.length; i++) {
            if (self.votes[self.voters[i]].voted && self.votes[self.voters[i]].approved) {
                approval++;
            }
        }
        return true;
    }

    function enact(Proposition storage self)
        external
    {
        self.enactor = msg.sender;
    }
}
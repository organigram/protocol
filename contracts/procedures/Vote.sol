// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../Procedure.sol";
import "../libraries/VotePropositionLibrary.sol";

/*
    Vote Procedure.
    A Vote Procedure will apply an effect based on the decision of a vote.
    Votes can be vetoed, and enacted.

    @TODO : Add propositions getter.
*/

contract VoteProcedure is Procedure {
    using VotePropositionLibrary for VotePropositionLibrary.Proposition;
    bytes4 private constant _INTERFACE_VOTE = 0xc9d27afe; // vote().
    // A Proposition is mapped to a locked moved.
    mapping (uint256 => VotePropositionLibrary.Proposition) internal propositions;
    address payable public votersOrgan;
    address payable public vetoersOrgan;
    address payable public enactorsOrgan;

    constructor (
        bytes32 _metadataIpfsHash, uint8 _metadataHashFunction, uint8 _metadataHashSize,
        address payable _votersOrgan, address payable _vetoersOrgan, address payable _enactorsOrgan
    ) Procedure (_metadataIpfsHash, _metadataHashFunction, _metadataHashSize)
        public
    {
        // Register EIP165 interface for introspection.
        _registerInterface(_INTERFACE_VOTE);
        votersOrgan = _votersOrgan;
        vetoersOrgan = _vetoersOrgan;
        enactorsOrgan = _enactorsOrgan;
    }

    function vote(uint256 moveKey, bool approval)
        public onlyInOrgan(votersOrgan)
    {
        propositions[moveKey].vote(approval);
    }

    // A veto accepts arguments which defines a motivation as a IPFS multihash.
    function veto(uint256 moveKey, bytes32 ipfsHash, uint8 hashFunction, uint8 hashSize)
        public onlyInOrgan(vetoersOrgan)
    {
        propositions[moveKey].veto(ipfsHash, hashFunction, hashSize);
    }

    function count(uint256 moveKey)
        public view returns (bool)
    {
        return propositions[moveKey].count();
    }

    function enact(uint256 moveKey)
        public onlyInOrgan(enactorsOrgan)
    {
        // proposition.count() returns true if enactment is possible.
        require (propositions[moveKey].count(), "Not authorized");
        Procedure.applyMove(moveKey);
        propositions[moveKey].enact();
    }
}
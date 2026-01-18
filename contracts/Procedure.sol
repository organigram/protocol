// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "./libraries/ProcedureLibrary.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@opengsn/contracts/src/ERC2771Recipient.sol";

/*
    A procedure defines a set of operations compiled in a proposal.
    The procedure dictates the way the proposal can be applied.
*/

contract Procedure is ERC165, Initializable, ReentrancyGuard, ERC2771Recipient {
    using ProcedureLibrary for ProcedureLibrary.ProcedureData;
    using ProcedureLibrary for ProcedureLibrary.Operation;
    ProcedureLibrary.ProcedureData internal procedureData;
    bytes4 constant public INTERFACE_ID = 0x71dbd330;

    /**
        Modifiers.
    */

    modifier onlyInOrgan(address payable organAddress) {
        require(ProcedureLibrary.isInOrgan(organAddress, _msgSender()), "Not authorized");
        _;
    }

    modifier onlyDeciders() {
        require(ProcedureLibrary.isInOrgan(procedureData.deciders, _msgSender()), "Not authorized");
        _;
    }

    /**
        Procedure constructor.
    */

    constructor () {
        _disableInitializers();
    }

    // Register EIP165 interfaces for introspection.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // @todo : Use type(IProcedure).interfaceId
        return interfaceId == INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    function initialize(
        string memory _cid,
        address payable _proposers,
        address payable _moderators,
        address payable _deciders,
        bool _withModeration,
        address _trustedForwarder
    )
        public
        virtual
        initializer
    {
        procedureData.init(_cid, _proposers, _moderators, _deciders, _withModeration, _trustedForwarder, _msgSender());
        _setTrustedForwarder(_trustedForwarder);
    }

    /**
        Public API : Procedure Cid and Admin.
    */

    function updateCid(string memory cid)
        public
    {
        procedureData.updateCid(cid, _msgSender());
    }

    function updateAdmin(address payable admin)
        public
    {
        procedureData.updateAdmin(admin, _msgSender());
    }

    /**
        Public API : Proposals creation and update.
    */

    function propose(
        string memory cid,
        ProcedureLibrary.Operation[] memory operations
    )
        public
        virtual
        returns (uint256 proposalKey)
    {
        return procedureData.propose(cid, operations, _msgSender());
    }

    /// @notice The procedure can override this method.
    function blockProposal(uint256 proposalKey, string calldata reason)
        public
        virtual
    {
        procedureData.blockProposal(proposalKey, reason, _msgSender());
    }

    /// @notice When moderation is enabled, moderators must accept the proposal. 
    function presentProposal(uint256 proposalKey)
        public
        virtual
    {
        procedureData.presentProposal(proposalKey, _msgSender());
    }

    /// @notice The procedure calls this method directly to adopt and apply proposal.
    function adoptProposal(uint256 proposalKey)
        public nonReentrant
        virtual
    {
        procedureData.adoptProposal(proposalKey);
    }

    /// @notice The procedure calls this method directly to adopt and apply proposal.
    function rejectProposal(uint256 proposalKey)
        public nonReentrant
        virtual
    {
        procedureData.rejectProposal(proposalKey);
    }

    /// @notice Apply proposal.
    function applyProposal(uint256 proposalKey)
        public nonReentrant
        virtual
    {
        procedureData.applyProposal(proposalKey);
    }

    /*
        Accessors.
    */

    function getProcedure()
        public
        view
        returns (
            string memory cid,
            address payable proposers,
            address payable moderators,
            address payable deciders,
            bool withModeration,
            uint256 proposalsLength,
            bytes4 interfaceId
        )
    {
        return (
            procedureData.cid,
            procedureData.proposers,
            procedureData.moderators,
            procedureData.deciders,
            procedureData.withModeration,
            procedureData.proposalsLength,
            INTERFACE_ID
        );
    }

    function getProposal(uint256 proposalKey)
        public view
        returns (ProcedureLibrary.Proposal memory)
    {
        return procedureData.proposals[proposalKey];
    }
}
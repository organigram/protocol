//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "./Organ.sol";
import "@opengsn/contracts/src/BasePaymaster.sol";

contract MetaGasStation is BasePaymaster {
    function versionPaymaster()
        external
        view
        virtual
        override
        returns (string memory)
    {
        return "3.0.0-beta.10";
    }

    address payable public whitelistsOrgan;

    constructor(address payable _whitelistsOrgan) {
        whitelistsOrgan = _whitelistsOrgan;
    }

    function _verifyApprovalData(bytes calldata approvalData)
        internal
        view
        virtual
        override
    {
        require(approvalData.length != 0, "approvalData should not be empty");
    }

    function _preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
        internal
        virtual
        override
        returns (bytes memory context, bool revertOnRecipientRevert)
    {
        (relayRequest, signature, approvalData, maxPossibleGas);
        (address whitelist) = abi.decode(approvalData, (address));
        address sender = relayRequest.request.from; 
        require(
            Organ(whitelistsOrgan).getEntryIndexForAddress(whitelist) != 0,
            "Whitelist is not whitelisted."
        );
        require(
            Organ(payable(whitelist)).getEntryIndexForAddress(sender) != 0,
            "User is not whitelisted."
        );
        return (abi.encode(sender, whitelist), false);
    }

    function _postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    ) internal virtual override {
        (context, success, gasUseWithoutPost, relayData);
        (address sender, address whitelist) = abi.decode(context, (address, address));
        emit PostRelayed(sender, whitelist, gasUseWithoutPost);
    }

    event PostRelayed(address indexed payer, address indexed whitelist, uint256 indexed gasUseWithoutPost);
}

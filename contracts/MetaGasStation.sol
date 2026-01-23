// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/metatx/ERC2771Forwarder.sol';

contract MetaGasStation is ERC2771Forwarder {
    constructor(string memory name) ERC2771Forwarder(name) {}
}

abstract contract ERC2771Recipient is Context {
    address private _trustedForwarder;

    function _setTrustedForwarder(address forwarder) internal virtual {
        _trustedForwarder = forwarder;
    }

    function isTrustedForwarder(
        address forwarder
    ) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    /**
     * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (
            calldataLength >= contextSuffixLength &&
            isTrustedForwarder(msg.sender)
        ) {
            unchecked {
                return
                    address(
                        bytes20(msg.data[calldataLength - contextSuffixLength:])
                    );
            }
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Override for `msg.data`. Defaults to the original `msg.data` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (
            calldataLength >= contextSuffixLength &&
            isTrustedForwarder(msg.sender)
        ) {
            unchecked {
                return msg.data[:calldataLength - contextSuffixLength];
            }
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev ERC-2771 specifies the context as being a single address (20 bytes).
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return 20;
    }
}

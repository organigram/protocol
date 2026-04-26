// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol';
import {Initializable as InitializableUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import './IAsset.sol';

contract Asset is IAsset, InitializableUpgradeable, ERC20Upgradeable, ERC20VotesUpgradeable {
    function initialize(
        string memory name_,
        string memory symbol_,
        address initialReceiver_,
        uint256 initialSupply_
    ) external override initializer {
        __ERC20_init(name_, symbol_);
        __EIP712_init(name_, '1');
        __ERC20Votes_init();
        _mint(initialReceiver_, initialSupply_);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }

    // Prevent anyone from initializing the implementation itself.
    constructor() {
        _disableInitializers();
    }
}

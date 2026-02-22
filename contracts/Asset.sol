// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {Initializable as InitializableUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

contract Asset is InitializableUpgradeable, ERC20Upgradeable {
    function initialize(
        string memory name_,
        string memory symbol_,
        address initialReceiver_,
        uint256 initialSupply_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        _mint(initialReceiver_, initialSupply_);
    }

    // Prevent anyone from initializing the implementation itself.
    constructor() {
        _disableInitializers();
    }
}

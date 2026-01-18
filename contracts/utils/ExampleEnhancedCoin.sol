// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract ExampleEnhancedCoin is ERC777 {
  constructor(uint256 initialSupply, address[] memory defaultOperators, string memory _name, string memory _symbol)
    ERC777(_name, _symbol, defaultOperators)
  {
    _mint(_msgSender(), initialSupply, "", "");
  }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ExampleMultitoken is ERC1155 {
  uint256 public constant GOLD = 0;
  uint256 public constant SILVER = 1;
  uint256 public constant THORS_HAMMER = 2;
  uint256 public constant SWORD = 3;
  uint256 public constant SHIELD = 4;

  constructor() ERC1155("https://game.example/api/item/{id}.json") {
    _mint(_msgSender(), GOLD, 10**18, "");
    _mint(_msgSender(), SILVER, 10**27, "");
    _mint(_msgSender(), THORS_HAMMER, 1, "");
    _mint(_msgSender(), SWORD, 10**9, "");
    _mint(_msgSender(), SHIELD, 10**9, "");
  }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

contract ExampleCollectible is ERC721URIStorage {
    uint256 private _tokenIds = 0;

    constructor() ERC721('ExampleCollectible', 'ECL') {}

    function awardItem(
        address player,
        string memory _tokenURI
    ) public returns (uint256) {
        _tokenIds += 1;

        uint256 newItemId = _tokenIds;
        _mint(player, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        return newItemId;
    }
}

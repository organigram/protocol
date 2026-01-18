# Organigram

Organigram is a Solidity framework for building governance systems on Ethereum.

- [Organs](docs/01_standardOrgan.md)  
  Organs store the governance data like users, roles, documents...
* [Procedures](docs/02_00_standardProcedure.md)  
  Procedures set rules for modifying this data and the system itself (eg. publication, nomination, election, or any process writable in a smart contract).

  For comprehensive documentation, please visit https://organigram.ai

## Usage

- Install package from NPM registry with
  ```bash
  npm install --save @organigram/protocol
  # or
  yarn add @organigram/protocol
  # or
  pnpm add @organigram/protocol
  ```
- Import contracts in your solidity contracts like so
  ```javascript
  import "@organigram/protocol/Organ.sol";
  ```
- Import contracts artifacts in your JS code with
  ```javascript
  var contract = require("truffle-contract");
  var data = require("@organigram/protocol/build/contracts/Organ.json");
  var Organ = contract(data);
  ```

## Contributing

We are looking for Solidity developers and testers to keep our contracts secure and up-to-date. Please create issues in our Github page, fork and create Pull-Requests.

https://github.com/organigram/contracts
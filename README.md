# Organigram Protocol

The Organigram Protocol is a Solidity framework for building modular incorruptible governance systems on Ethereum.

By assembling three simple concepts, it allows for the automated execution of any business rules in a decentralized and auditable manner:

- [Assets](https://organigram.ai/en/docs/protocol/assets) are what is being governed: they represent value in cryptocurrency - either native assets (such as ETH), stablecoins (such as USDC or EurE), or any other types of ERC-20-compatible tokens.
- [Organs](https://organigram.ai/en/docs/protocol/organs) are cryptographic vaults: they store the permissions defining who can access what assets. They can only be modified by procedures stored in the organ's internal memory.
- [Procedures](https://organigram.ai/en/docs/protocol/organs) are automated, pre-approved workflows that allow permitted users to perform actions in a compliant and safe way (for example transfer assets or edit permissions after a vote).

For comprehensive documentation, please visit our [official website](https://organigram.ai/en/docs).

## Installation

Install the NPM package with:

```bash
# npm:
npm install @organigram/protocol
# pnpm: 
pnpm add @organigram/protocol
```

## Usage

With this package, you can directly interact with the Organigram Protocol smart contracts in your Solidity and JavaScript code, or use our official clients to build your own applications on top of the protocol.

- Import contract sources in your solidity code:

  ```javascript
  import "@organigram/protocol/Organ.sol";
  ```

- Import contracts artifacts in your JS code:

  ```javascript
  import OrganContractABI from '@organigram/protocol/abi/Organ.sol/Organ.json' with { type: 'json' }
  import { getContract, type Abi } from 'viem'

  const contract = getContract({
    address: getAddress(address as Address),
    abi: OrganContractABI.abi as Abi,
    client: {
      // ... viem client configuration 
    }
  })
  ```

- Use the official [JavaScript/TypeScript client](https://github.com/organigram/js):

  ```bash
  pnpm add @organigram/js
  ```
  ```javascript
  import { OrganigramClient, Organigram, Organ } from '@organigram/js'

  const organigramClient = await OrganigramClient.load({
      publicClient: {
        // ... viem public client configuration
      }
      walletClient: {
        // ... viem wallet client configuration
      }
  })
  ```

- Import as components with the [official React client](https://github.com/organigram/react):

  ```
  pnpm add @organigram/react
  ```
  ```jsx
  import { Diagram } from '@organigram/react'
  import { Organigram } from '@organigram/js'

  const OrganigramComponent = () => <Diagram organigram={new Organigram()} />
  ```

## Development

### Install Foundry

This package uses **Foundry** (Forge/Anvil) for local development. Install the Foundry toolchain with:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Start local node
Start a Sepolia fork for local development with Anvil:

```bash
pnpm anvil
```

### Deploy contracts

- Compile contracts: `pnpm build`
- Deploy script: `pnpm deploy:protocol`


## Contributing

We are looking for Solidity developers and testers to keep our contracts secure and up-to-date. Please create issues in our Github page, fork and create Pull-Requests.

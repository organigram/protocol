# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [0.1.5](https://github.com/organigram/organigram/compare/v0.1.4...v0.1.5) (2026-07-07)

**Note:** Version bump only for package @organigram/protocol





## [0.1.4](https://github.com/organigram/organigram/compare/v0.1.3...v0.1.4) (2026-06-16)

- Hardened the protocol formatting workflow.
- Refreshed deployment addresses and README references.
- Cleaned up generated artifacts and build output.

## [0.1.3](https://github.com/organigram/organigram/compare/v0.1.2...v0.1.3) (2026-05-04)

- Improved protocol security:
    - Harden the core contracts with stronger validation and reentrancy protection.
    - Add vote snapshots and broader multi-network deployment support.
    - Add security-focused checks and tests around the protocol.
- 13 new supported networks
- Multi-network deploy script
- Remove unused dependencies

## [0.1.2](https://github.com/organigram/organigram/compare/v0.1.1...v0.1.2) (2026-04-20)

- New organ capabilities:
    - Verify EIP-712 signatures for gasless transactions
    - executeWhitelisted() to execute arbitrary transaction
- Performance improvements:
    - switched from ethers to viem
    - switched from hardhat to foundry


## [0.1.1](https://github.com/organigram/organigram/compare/v0.1.0...v0.1.1) (2026-03-15)

### Improvements

- Release-only bump.

## [0.1.0](https://github.com/organigram/organigram/compare/v0.0.1...v0.1.0) (2026-03-05)

- Single-transaction deployments
- Deterministic addresses
- Replaced OpenGSN by custom relayer
- Updated packages structure

## 0.0.1 (2021-08-29)

- First smart-contract framework for organs, procedures, voting, assets, and deployment helpers.
- Establish the protocol foundation used by the app and SDKs.

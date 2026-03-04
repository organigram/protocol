import '@nomicfoundation/hardhat-ignition-viem'
import '@nomicfoundation/hardhat-viem'
// import "@tenderly/hardhat-tenderly"

const config = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 10
      }
    }
  },
  // tenderly: {
  //   username: 'lmd',
  //   project: 'organigram',

  //   // Contract visible only in Tenderly.
  //   // Omitting or setting to `false` makes it visible to the whole world.
  //   // Alternatively, admin-rpc verification visibility using
  //   // an environment variable `TENDERLY_PRIVATE_VERIFICATION`.
  //   privateVerification: true
  // },
  networks: {
    // sepolia: {
    //   url: 'http://127.0.0.1:8545',
    //   accounts: {
    //     mnemonic: process.env.MNEMONIC
    //   },
    //   chainId: 11155111
    // },
    sepolia: {
      url: process.env.RPC_URL,
      accounts: {
        mnemonic: process.env.MNEMONIC
      },
      chainId: 11155111
    }
  }
}

export default config

const HDWalletProvider = require('@truffle/hdwallet-provider')

module.exports = {
  networks: {
    pichain: {
      networkCheckTimeout: 100000,
      provider: () =>
        new HDWalletProvider({
          mnemonic: process.env.MNEMONIC,
          providerOrUrl: "http://192.168.1.30:8545",
          numberOfAddresses: 10
        }),
      network_id: "*",
      gasPrice: 89000000000
    },
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gasPrice: 89000000000
    },
    ganache: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gasPrice: 1,
      gas: 234881023
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider({
          mnemonic: process.env.MNEMONIC,
          providerOrUrl: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
          numberOfAddresses: 10
        }),
      network_id: 4
    }
  },
  compilers: {
    solc: {
      version: "^0.8.0",
      settings: {
        optimizer: {
          enabled: true,
          runs: 10
        }
      }
    }
  }
}

const HDWalletProvider = require('@truffle/hdwallet-provider')

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gasPrice: 150000000000  // 150 gwei
    },
    ganache: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gasPrice: 1
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider({
          mnemonic: process.env.MNEMONIC,
          providerOrUrl: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
          numberOfAddresses: 10
        }),
      network_id: 4,
      gasPrice: 1
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

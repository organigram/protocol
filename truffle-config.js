const HDWalletProvider = require('@truffle/hdwallet-provider')

module.exports = {
  networks: {
    dev: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gasPrice: 150000000000  // 150 gwei
    },
    ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
      gasPrice: 20000000000  // 20 gwei
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider({
          mnemonic: process.env.MNEMONIC,
          providerOrUrl: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
          numberOfAddresses: 10
        }),
      network_id: 4,
      // gas: 6700000,
      gasPrice: 1000000000 // 1 gwei
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

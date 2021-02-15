const HDWalletProvider = require('truffle-hdwallet-provider')
module.exports = {
  networks: {
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
        new HDWalletProvider(process.env.MNEMONIC, `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`),
      network_id: 4
    }
  },
  compilers: {
    solc: {
      version: "^0.6.0",
      settings: {
        optimizer: {
          enabled: true,
          runs: 10
        }
      }
    }
  }
}

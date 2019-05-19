const path = require("path");
const HDWalletProvider = require("truffle-hdwallet-provider");
require("dotenv").config();

module.exports = {
  // The defaults below provide an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  contracts_build_directory: path.join(__dirname, "build"),
  networks: {
    local: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gas: 80000000
    },
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
      gas: 80000000
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider(
          process.env.MNEMONIC,
          process.env.WEB3_PROVIDER
        );
      },
      network_id: 3,
      gas: 8000000,
      gasPrice: 10000000000
    },
    kovan: {
      provider: function() {
        return new HDWalletProvider(
          process.env.MNEMONIC,
          process.env.WEB3_PROVIDER
        );
      },
      network_id: 42,
      gas: 8000000,
      gasPrice: 10000000000
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider(process.env.MNENOMIC, process.env.WEB3_PROVIDER),
      network_id: 4,
      gas: 8000000,
      gasPrice: 10000000000
    },
    // main ethereum network(mainnet)
    main: {
      provider: () =>
        new HDWalletProvider(process.env.MNENOMIC, process.env.WEB3_PROVIDER),
      network_id: 1,
      gas: 8000000,
      gasPrice: 10000000000
    }
  },
  compilers: {
    solc: {
      version: "0.5.8",
      docker: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};

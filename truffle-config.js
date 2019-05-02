const path = require("path")

module.exports = {
  // The defaults below provide an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  contracts_build_directory: path.join(__dirname, "app/src/contracts"),
  networks: {
  	ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: 5777
    },
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    }
  }
}
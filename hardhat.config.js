require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
let secret = require('./secrets');

module.exports = {
  solidity: {
    version: '0.8.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    mumbai: {
      url: secret.url,
      accounts: [secret.key],
    },
  },
  etherscan: {
    apiKey: {
      polygonMumbai: secret.polygonscankey,
    },
  },
};

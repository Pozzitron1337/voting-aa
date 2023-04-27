require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require('hardhat-contract-sizer');
require("dotenv").config();

const {
  INFURA_KEY, 
  MNEMONIC,
  ETHERSCAN_API_KEY,
  COINMARKETCAP_API_KEY
  } = process.env;


module.exports = {
  solidity: {
    compilers: [
      { 
        version: "0.8.18", 
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${INFURA_KEY}`,
      },
      allowUnlimitedContractSize: false,
      timeout: 9999999999,
      blockGasLimit: 1000_000_000,
      gas: 100_000_000,
      gasPrice: 'auto',
      accounts: {mnemonic: MNEMONIC}
    },
    
    mainnet :{
      url: `https://mainnet.infura.io/v3/${INFURA_KEY}`,
      gas: 100_000_000,
      gasPrice: 90_000_000_000,
      accounts: {mnemonic: MNEMONIC}
    },
    bsc: {
      url: `https://bsc-dataseed.binance.org/`,
      gas: 1_000_000,
      gasPrice: 90_000_000_000,
      accounts: {mnemonic: MNEMONIC}
    },
    bsctest: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      gas: 2_000_000,
      gasPrice: 10_000_000_000,
      timeout: 99999999,
      accounts: {mnemonic: MNEMONIC}
    },
    goerli: {
      url: 'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      gas: 2_000_000,
      gasPrice: 50_000_000_000,
      timeout: 99999999,
      accounts: {mnemonic: MNEMONIC}
    }
    
  },
  gasReporter: {
    enabled: false,
    coinmarketcap: COINMARKETCAP_API_KEY,
    currency: 'ETH',
    gasPrice: 5
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  }
};

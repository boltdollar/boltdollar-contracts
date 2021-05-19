require('dotenv').config();
require('hardhat/types');
require('hardhat-deploy');
require("@nomiclabs/hardhat-waffle");


//require('hardhat-deploy-ethers');

let mnemonic = process.env.mnemonic;
if (!mnemonic) {
  // FOR DEV ONLY, SET IT IN .env files if you want to keep it private
  // (IT IS IMPORTANT TO HAVE A NON RANDOM MNEMONIC SO THAT SCRIPTS CAN ACT ON THE SAME ACCOUNTS)
  mnemonic = 'test test test test test test test test test test test test';
}
const accounts = {
  mnemonic,
  count: 10
};

require("@nomiclabs/hardhat-truffle5");

//usePlugin('buidler-gas-reporter');

module.exports = {
    defaultNetwork: "hardhat",
    namedAccounts: {
       deployer: 5,
    },
    networks: {
        fork : {
          url: 'http://127.0.0.1:8545/'
        },
        localhost : {
          url: 'http://127.0.0.1:7545/'
        },
        hardhat: {
           chainId: 31337
        },
        bsc: {
          chainId: 56,
          accounts,
          url: "https://bsc-dataseed.binance.org/"
        },
        bsc_test: {
          chainId: 56,
          accounts,
          url: "https://bsc-dataseed.binance.org/"
        },
        opera: {
          chainId: 250,
          accounts,
          url: "https://rpc.fantom.network/"
        }
  },
  solidity: {
     version: "0.7.3",
     settings: {
        optimizer: {
           enabled: true,
           runs: 200
        },
        outputSelection: {
          "*": {
              "*": ["storageLayout"],
          }
        }
     }
   },
   paths: {
      sources: "./contracts",
      tests: "./test",
      cache: "./cache",
      artifacts: "./artifacts"
   }

};

require("@nomiclabs/hardhat-waffle");
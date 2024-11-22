import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ],
  },
  defaultNetwork : "hardhat",
  networks: {
    hardhat: {
      hardfork: "london"
    },
    opbnb: {
      url: "https://opbnb-mainnet-rpc.bnbchain.org",
      chainId: 204,
      accounts: ['cade06d3f5ef251f7361702ecaafe1a9e4871cd4102abd431797882bd67bf7c9']
    }
  },
  etherscan: {
    apiKey: {
      opbnb: '{{ETHERSCAN_API_KEY}}'
    },
  },
  sourcify: {
    enabled: true
  }
};
export default config;


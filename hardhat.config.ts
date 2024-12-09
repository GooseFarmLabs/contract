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
      accounts: ['{{PRIVATE_KEY}}']
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


import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { vars } from "hardhat/config";

const PRIVATE_KEY = vars.get("PRIVATE_KEY");

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    mantaPacificMainnet: {
      url: "https://pacific-rpc.manta.network/http",
      accounts: [PRIVATE_KEY],
      chainId: 169,
    },
  },
  etherscan: {
    apiKey: {
      mantaPacificMainnet: "any",
    },
    customChains: [
      {
        network: "mantaPacificMainnet",
        chainId: 169,
        urls: {
          apiURL: "https://pacific-explorer.manta.network//api",
          browserURL: "https://pacific-explorer.manta.network/",
        },
      },
    ],
  },
};

export default config;

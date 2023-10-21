import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const Alchemy_Private_Key_Sepolia = process.env.Sepolia_PRIVATE_KEY;
const Account_Private_Key = process.env.Account_PRIVATE_KEY;
const Etherscan_API_KEY = process.env.Etherscan_API_KEY;
const Polygonscan_API_KEY = process.env.Polygonscan_API_KEY;

const config: HardhatUserConfig = {
  solidity: "0.8.13",
  ...(Account_Private_Key ?  {
       
    Sepolia: {
      chainId: 11155111,
      url: `https://eth-sepolia.g.alchemy.com/v2/${Alchemy_Private_Key_Sepolia}`,
      accounts: [Account_Private_Key as string],
      allowUnlimitedContractSize: true,
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
    },
    Mumbai: {
      chainId: 80001,
      url: 'https://polygon-mumbai-bor.publicnode.com',
      accounts: [Account_Private_Key as string]
    }

  } : {defaultHardhatNetwork: "hardhat"}),
  etherscan: {
    apiKey: Etherscan_API_KEY,
    customChains: [{
      network: 'Mumbai',
      chainId: 80001,
      urls: {
        apiURL: 'https://api-testnet.polygonscan.com/api',
        browserURL: 'https://mumbai.polygonscan.com/'
      }
    }]
  }
};

export default config;

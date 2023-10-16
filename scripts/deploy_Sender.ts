import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

const Router_Address_Sepolia = '0xD0daae2231E9CB96b94C8512223533293C3693Bf';
const Link_Address_Sepolia = '0x779877A7B0D9E8603169DdbD7836e478b4624789';
const Sepolia_RPC_URL = process.env.Sepolia_RPC_URL;
const Account_PRIVATE_KEY = process.env.Account_PRIVATE_KEY;

async function deployOnSepolia() {
      
  const sender = await ethers.deployContract('Sender', [
    Router_Address_Sepolia,
    Link_Address_Sepolia
  ]);

  await sender.waitForDeployment();

  sender.testSendMessageAndToken();

  console.log(
    `deploy sender on Sepolia : ${(await sender.getAddress())}`
  );
}

async function call() {
  const provider = new ethers.JsonRpcProvider(
    Sepolia_RPC_URL,
    {
        name: 'Sepolia',
        chainId: 11155111
    }
  );
  
  // Replace with the address of the deployed contract
  const senderContractAddress = "0x9e87c722d4AeDDa7b0Cc5D2B639C3c7d4943e943";
  const wallet = new ethers.Wallet(Account_PRIVATE_KEY as string, provider);
  const senderContract = await ethers.getContractAt("Sender", senderContractAddress, wallet);
  await senderContract.testSendMessageAndToken();
}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
// deployOnSepolia().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });


call().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

const Alchemy_Private_Key_Sepolia = process.env.Sepolia_PRIVATE_KEY;
const Account_Private_Key = process.env.Account_PRIVATE_KEY;

const Router_Address_Sepolia = '0xD0daae2231E9CB96b94C8512223533293C3693Bf';
const Chain_Selector_Sepolia = '16015286601757825753';
const Link_Address_Sepolia = '0x779877A7B0D9E8603169DdbD7836e478b4624789';

async function deployOnSepolia() {
    const provider = new ethers.JsonRpcProvider(
        `https://eth-sepolia.g.alchemy.com/v2/${Alchemy_Private_Key_Sepolia}`,
        {
            name: 'Sepolia',
            chainId: 11155111
        }
    );

    const wallet = new ethers.Wallet(
        Account_Private_Key as string,
        provider
    );
      
  const sender = await ethers.deployContract('Sender', [
    Router_Address_Sepolia,
    Link_Address_Sepolia
  ], wallet);

  await sender.waitForDeployment();

  console.log(
    `deploy sender on Sepolia : ${(await sender.getAddress())}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deployOnSepolia().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

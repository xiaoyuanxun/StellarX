import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

const Router_Address_Mumbai = '0x70499c328e1E2a3c41108bd3730F6670a44595D1';

async function deployOnMumbai() {
  const receiver = await ethers.deployContract("Receiver", [
    ethers.getAddress(Router_Address_Mumbai),
  ]);

  await receiver.waitForDeployment();

  console.log(
    `deploy receiver on Mumbai: ${(await receiver.getAddress())}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deployOnMumbai().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

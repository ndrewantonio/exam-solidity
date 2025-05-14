import { ethers } from "hardhat";
import dotenv from "dotenv";

// Load .env
dotenv.config();

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);

  // ✅ 1. Deploy ExamImplementation (Implementation)
  const ExamImplementation = await ethers.getContractFactory(
    "ExamImplementation"
  );
  const examImplementation = await ExamImplementation.deploy();
  await examImplementation.waitForDeployment();
  console.log(
    "ExamImplementation deployed at:",
    await examImplementation.getAddress()
  );

  // ✅ 2. Deploy ExamFactory with ExamImplementation's address
  const implementationAddr = examImplementation.getAddress();
  const idrxAddress = process.env.IDRX_ADDRESS || "";
  // const baseURI = process.env.BASE_URI || "";

  if (!idrxAddress) {
    throw new Error(
      "IDRX_ADDRESS is not defined in the environment variables."
    );
  }

  const ExamFactory = await ethers.getContractFactory("ExamFactory");
  const factory = await ExamFactory.deploy(implementationAddr, idrxAddress);
  await factory.waitForDeployment();
  console.log("ExamFactory deployed at:", await factory.getAddress());
}

main().catch((error) => {
  console.error("Error deploying contract:", error);
  process.exit(1);
});

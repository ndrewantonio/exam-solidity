import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);

  // ✅ 1. Deploy ExamContract (Implementation)
  // const ExamContract = await ethers.getContractFactory("ExamContract");
  // const examImplementation = await ExamContract.deploy();
  // await examImplementation.waitForDeployment();
  // console.log(
  //   "✅ ExamContract implementation deployed at:",
  //   await examImplementation.getAddress()
  // );

  // ✅ 2. Deploy ExamFactory with ExamContract's address
  const ExamFactory = await ethers.getContractFactory("ExamFactory");
  const factory = await ExamFactory.deploy(
    "0xfD71c80f8d5c01d96D05419Ae42F9b53018b8b1E"
  );
  await factory.waitForDeployment();
  console.log("✅ ExamFactory deployed at:", await factory.getAddress());
}

// async function main() {
//   // 1. Deploy Implementation FIRST
//   const ExamImplementation = await ethers.getContractFactory("ExamImplementation");
//   const examImpl = await ExamImplementation.deploy();
//   await examImpl.waitForDeployment();
//   console.log("Implementation deployed to:", await examImpl.getAddress());

//   // 2. Deploy Factory SECOND (with impl address)
//   const ExamFactory = await ethers.getContractFactory("ExamFactory");
//   const factory = await ExamFactory.deploy(await examImpl.getAddress());
//   await factory.waitForDeployment();
//   console.log("Factory deployed to:", await factory.getAddress());
// }

main().catch((error) => {
  console.error("Error deploying contract:", error);
  process.exit(1);
});

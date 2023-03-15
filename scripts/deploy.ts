import { ethers } from "hardhat";

async function main() {
  const CyclicArbitrage = await ethers.getContractFactory("CyclicArbitrage");
  const arbitrage = await CyclicArbitrage.deploy({gasPrice: '15000000000'}); // 15 gwei

  await arbitrage.deployed();

  console.log(
    `Arbitrage contract deployed to ${arbitrage.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

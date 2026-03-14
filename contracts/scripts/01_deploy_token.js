const hre = require("hardhat");

async function main() {
  console.log("Deploying NexusToken to", hre.network.name);
  
  // Deploy NexusToken
  const NexusToken = await hre.ethers.getContractFactory("NexusToken");
  const token = await NexusToken.deploy();
  
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  
  console.log("NexusToken deployed to:", tokenAddress);
  
  // Save deployment address
  const fs = require("fs");
  const deployment = {
    network: hre.network.name,
    tokenAddress: tokenAddress,
    timestamp: new Date().toISOString(),
  };
  
  fs.writeFileSync(
    `../deployment.${hre.network.name}.json`,
    JSON.stringify(deployment, null, 2)
  );
  
  console.log("Deployment saved to deployment." + hre.network.name + ".json");
  
  // Verify on Basescan (mainnet only)
  if (hre.network.name === "base") {
    try {
      await hre.run("verify:verify", {
        address: tokenAddress,
        constructorArguments: [],
      });
      console.log("Verified on Basescan");
    } catch (e) {
      console.log("Verification failed:", e.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

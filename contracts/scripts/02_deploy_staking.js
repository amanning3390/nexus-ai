const hre = require("hardhat");

async function main() {
  console.log("Deploying NexusStaking to", hre.network.name);
  
  // Load token address
  const fs = require("fs");
  let tokenAddress;
  
  try {
    const deployment = JSON.parse(fs.readFileSync(`../deployment.${hre.network.name}.json`));
    tokenAddress = deployment.tokenAddress;
  } catch (e) {
    console.log("Token deployment not found. Please deploy token first.");
    console.log("Run: npx hardhat run scripts/01_deploy_token.js --network baseSepolia");
    return;
  }
  
  // Deploy Staking
  const NexusStaking = await hre.ethers.getContractFactory("NexusStaking");
  const staking = await NexusStaking.deploy(tokenAddress);
  
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();
  
  console.log("NexusStaking deployed to:", stakingAddress);
  
  // Save deployment
  const deployment = {
    network: hre.network.name,
    tokenAddress: tokenAddress,
    stakingAddress: stakingAddress,
    timestamp: new Date().toISOString(),
  };
  
  fs.writeFileSync(
    `../deployment.${hre.network.name}.json`,
    JSON.stringify(deployment, null, 2)
  );
  
  console.log("Deployment updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

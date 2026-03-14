const hre = require("hardhat");

async function main() {
  console.log("Deploying NexusFaucet to", hre.network.name);
  
  const fs = require("fs");
  let tokenAddress;
  
  try {
    const deployment = JSON.parse(fs.readFileSync(`../deployment.${hre.network.name}.json`));
    tokenAddress = deployment.tokenAddress;
  } catch (e) {
    console.log("Token deployment not found. Please deploy token first.");
    return;
  }
  
  const NexusFaucet = await hre.ethers.getContractFactory("NexusFaucet");
  const faucet = await NexusFaucet.deploy(tokenAddress);
  
  await faucet.waitForDeployment();
  const faucetAddress = await faucet.getAddress();
  
  console.log("NexusFaucet deployed to:", faucetAddress);
  
  const deployment = {
    network: hre.network.name,
    tokenAddress: tokenAddress,
    faucetAddress: faucetAddress,
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

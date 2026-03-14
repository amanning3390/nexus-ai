# Nexus AI - Smart Contracts

## Directory Structure
```
contracts/
├── token/
│   └── NexusToken.sol
├── staking/
│   └── NexusStaking.sol
├── governance/
│   └── NexusGovernance.sol
├── distribution/
│   └── RewardDistributor.sol
└── test/
    └── NexusToken.t.sol
```

## Deployment Scripts
```
scripts/
├── 01_deploy_token.js
├── 02_setup_staking.js
├── 03_setup_governance.js
└── 04_verify.js
```

## How to Deploy

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Deploy to testnet
npx hardhat run scripts/01_deploy_token.js --network baseSepolia

# Deploy to mainnet
npx hardhat run scripts/01_deploy_token.js --network base
```

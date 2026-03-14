# Nexus AI - Quick Start Guide

## For Users

### 1. Run an Agent
```bash
# Clone the agent
git clone https://github.com/amanning3390/nexus-ai.git
cd nexus-ai

# Run installer
chmod +x install_agent.sh
./install_agent.sh

# Start agent
python agent.py
```

### 2. Get Testnet Tokens
- Join Discord: https://discord.gg/nexusai
- Request testnet NEXUS in #faucet channel

### 3. Stake for Rewards
- Once you have NEXUS, stake them to earn more

---

## For Developers

### Deploy Token (Testnet)
```bash
cd contracts

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your private key and RPC URL

# Deploy to Base Sepolia
npm run deploy:sepolia
```

### Deploy to Mainnet
```bash
npm run deploy:mainnet
```

### Verify Contract
```bash
npx hardhat verify --network base <TOKEN_ADDRESS>
```

---

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Agent     │────▶│ Coordinator │────▶│   Database  │
│  (Your PC)  │     │   (API)     │     │  (Postgres) │
└─────────────┘     └─────────────┘     └─────────────┘
                            │
                            ▼
                     ┌─────────────┐
                     │   Blockchain │
                     │   (Base L2)  │
                     └─────────────┘
```

---

## Contracts

| Contract | Address | Network |
|----------|---------|---------|
| NexusToken | TBD | Base Sepolia |
| NexusStaking | TBD | Base Sepolia |
| NexusToken | TBD | Base Mainnet |
| NexusStaking | TBD | Base Mainnet |

---

## Links

- **Website:** https://nexus-ai.vercel.app
- **GitHub:** https://github.com/amanning3390/nexus-ai
- **Discord:** https://discord.gg/nexusai
- **Twitter:** https://twitter.com/nexus_ai

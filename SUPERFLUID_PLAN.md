# Superfluid Integration - Streaming Rewards Plan

## Executive Summary

Integrate **Superfluid Protocol** with **$NEXUS** token for real-time streaming payments to contributors. This enables continuous rewards rather than one-time payments.

---

## 1. Why Superfluid?

| Feature | Benefit |
|---------|----------|
| **Streaming** | Pay contributors in real-time, not batched |
| **Gas Efficient** | One-time approval, then stream automatically |
| **Composable** | Works with DeFi, other protocols |
| **Instant** | No waiting for settlement |

---

## 2. Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   $NEXUS Token                           │
│  (ERC-20 + Superfluid Wrapper = Super Token)            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Superfluid Protocol                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │    CFA     │  │    GDA     │  │  Vesting   │       │
│  │ (Streams) │  │  (Pools)   │  │ Scheduler  │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Contributors                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ GPU #1   │  │ GPU #2   │  │ CPU #1   │   ...     │
│  │ ~1 NEXUS │  │ ~0.5 NEX │  │ ~0.1 NEX │              │
│  │  /hour   │  │  /hour   │  │  /hour   │              │
│  └──────────┘  └──────────┘  └──────────┘              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Use Cases

### A. Streaming Rewards (CFA - Constant Flow Agreement)
```solidity
// Stream NEXUS to GPU providers continuously
// 1 NEXUS per hour = 1/3600 per second

uint256 flowRate = 1e18 / 3600; // 1 NEXUS/hour in wei

// Create stream
superfluid.createFlow(
    tokenAddress,      // $NEXUS Super Token
    recipient,        // GPU provider wallet
    flowRate          // Continuous payment
);
```

### B. Pool Distribution (GDA - General Distribution Agreement)
```solidity
// Distribute rewards to all contributors from a pool
// No need to create individual streams

// Create distribution pool
gdaPool.createPool();

// Add members with units (weight)
gdaPool.addMember(gpuAgent1, 100); // 100 units
gdaPool.addMember(gpuAgent2, 80);
gdaPool.addMember(cpuAgent1, 20);

// Distribute from pool
gdaPool.distribute(1000e18); // 1000 NEXUS
```

### C. Vesting Streams
```solidity
// Team/Investor vesting with streaming
// Cliff + continuous release

vestingScheduler.createVesting(
    beneficiary: teamMember,
    amount: 10000e18,
    startTime: block.timestamp,
    cliffDuration: 365 days,  // 1 year cliff
    duration: 1460 days        // 4 years total
);
```

---

## 4. Smart Contract Integration

### 4.1 Wrap $NEXUS as Super Token
```solidity
// Deploy Super Token wrapper for $NEXUS
SuperTokenFactory factory = SuperTokenFactory(host);
ISuperToken superToken = factory.createSuperToken(
    "Nexus AI Token",
    "NxAI",
    18
);
```

### 4.2 Reward Distributor Contract
```solidity
contract NexusRewardDistributor is Ownable {
    IConstantFlowAgreement public cfa;
    IGeneralDistributionAgreement public gda;
    ISuperToken public nexusToken;
    
    mapping(address => uint256) public flowRates;
    
    // Stream to single recipient
    function startStream(address recipient, uint256 flowRate) external onlyOwner {
        (,,uint256 currentRate,,) = cfa.getFlow(nexusToken, address(this), recipient);
        if (currentRate > 0) {
            cfa.updateFlow(nexusToken, recipient, flowRate);
        } else {
            cfa.createFlow(nexusToken, recipient, flowRate);
        }
        flowRates[recipient] = flowRate;
    }
    
    // Batch distribute via GDA pool
    function distributeToPool(uint256 amount) external onlyOwner {
        // Distribute amount to all pool members
        gdaPool.distribute(amount);
    }
}
```

### 4.3 Auto-Staking with Stream
```solidity
// Stake and earn streaming rewards
contract NexusStaking is SuperAppBase {
    function stake(uint256 amount) external {
        // Stake tokens
        nexusToken.transferFrom(msg.sender, address(this), amount);
        
        // Stream rewards to staker
        uint256 rewardRate = calculateRewardRate(amount);
        cfa.createFlow(nexusToken, msg.sender, rewardRate);
    }
}
```

---

## 5. Reward Rates

| Role | Stream Rate (NEXUS/hr) | Monthly (est) |
|------|------------------------|----------------|
| GPU Provider (high) | 2.0 | ~1,440 |
| GPU Provider (low) | 0.5 | ~360 |
| CPU Provider | 0.1 | ~72 |
| Data Contributor | 0.2 | ~144 |
| Staker (1000 NEXUS) | 0.05 | ~36 |

### Flow Rate Calculation
```solidity
// NEXUS per hour → wei per second
uint256 ratePerSecond = (hourlyRate * 1e18) / 3600;

// Example: 1 NEXUS/hour
uint256 flowRate = 1e18 / 3600; // = 277777777777778 wei/sec
```

---

## 6. Implementation Steps

### Phase 1: Basic Streaming (Week 1)
- [ ] Deploy $NEXUS ERC-20
- [ ] Wrap as Super Token
- [ ] Build RewardDistributor contract
- [ ] Test streaming to single recipient

### Phase 2: Pool Distribution (Week 2)
- [ ] Set up GDA pool
- [ ] Implement batch distribution
- [ ] Add member management

### Phase 3: Staking Integration (Week 3)
- [ ] Build staking contract
- [ ] Auto-stream staking rewards
- [ ] Test unstaking with stream cleanup

### Phase 4: Vesting (Week 4)
- [ ] Integrate VestingSchedulerV3
- [ ] Team vesting with cliffs
- [ ] Investor token distribution

---

## 7. Cost Analysis

| Component | Est. Cost |
|-----------|-----------|
| Deploy contracts | ~0.5 ETH |
| Initial liquidity | 50 ETH |
| Audit | 20-50 ETH |
| **Total** | **~70-100 ETH** |

### Gas Costs (Base)
| Operation | Gas |
|-----------|------|
| Create Stream | ~150K |
| Update Stream | ~100K |
| Delete Stream | ~80K |
| Pool Distribution | ~200K |

---

## 8. Comparison: Batch vs Streaming

| Metric | Batch (Weekly) | Streaming (Real-time) |
|--------|----------------|----------------------|
| User Experience | Good | Excellent |
| Gas Efficiency | Poor | Excellent |
| Complexity | Low | Medium |
| Perceived Value | Low | High |

---

## 9. Superfluid Skills Available

We now have access to:
- **CFA** - Constant Flow Agreement (streaming)
- **GDA** - General Distribution Agreement (pool distribution)
- **VestingScheduler** - Vesting with streams
- **Super Apps** - Custom logic
- **ABI References** - Complete contract docs

---

## 10. Next Steps

1. **Deploy testnet** - Goerli/Base Sepolia
2. **Integrate Superfluid** - Use skill for smart contracts
3. **Audit** - Security review
4. **Launch** - Mainnet with streaming rewards

---

## Summary

Superfluid transforms our tokenomics from:
- **Batch payments** → **Real-time streams**
- **Weekly payouts** → **Continuous rewards**
- **Manual distribution** → **Automatic pools**

This creates a "**payroll for the AI age**" - contributors get paid continuously as the AI works.

# $NEXUS Tokenomics - Comprehensive Plan

## Executive Summary

**Token:** $NEXUS  
**Network:** Base (Ethereum L2)  
**Standard:** ERC-20 + OpenZeppelin  
**Total Supply:** 1,000,000,000 (1 Billion)

---

## 1. Token Contract Design

### Core Contract (OpenZeppelin Based)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NexusToken is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    
    // Vesting schedules
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Supply controls
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public mintedSupply;
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 duration;
        uint256 releasedAmount;
    }
    
    event VestingCreated(address indexed beneficiary, uint256 amount);
    event VestingReleased(address indexed beneficiary, uint256 amount);
    
    constructor() ERC20("Nexus AI", "NEXUS") Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(mintedSupply + amount <= MAX_SUPPLY, "Max supply exceeded");
        mintedSupply += amount;
        _mint(to, amount);
    }
    
    function createVesting(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 duration
    ) external onlyOwner {
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting exists");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            duration: duration,
            releasedAmount: 0
        });
        
        emit VestingCreated(beneficiary, amount);
    }
    
    function releaseVesting(address beneficiary) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting");
        
        uint256 releasable = _computeReleasable(schedule);
        require(releasable > 0, "No tokens due");
        
        schedule.releasedAmount += releasable;
        _mint(beneficiary, releasable);
        
        emit VestingReleased(beneficiary, releasable);
    }
    
    function _computeReleasable(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }
        uint256 timeFromStart = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.duration;
        return vestedAmount - schedule.releasedAmount;
    }
    
    function snapshot() external onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }
}
```

---

## 2. Token Distribution

| Category | Amount | % | Vesting | Cliff |
|----------|--------|---|---------|-------|
| **Community Rewards** | 400,000,000 | 40% | 36 months | 6 months |
| **Team** | 200,000,000 | 20% | 48 months | 12 months |
| **Investors** | 150,000,000 | 15% | 24 months | 6 months |
| **Treasury** | 150,000,000 | 15% | 36 months | 0 months |
| **Airdrop** | 50,000,000 | 5% | 12 months | 0 months |
| **Liquidity** | 50,000,000 | 5% | 12 months | 0 months |

### Community Rewards Breakdown
| Source | Amount | Purpose |
|--------|--------|----------|
| GPU Contributors | 200M | Running inference/training |
| Data Contributors | 100M | Quality datasets |
| Staking Rewards | 50M | Network security |
| referrals | 50M | User acquisition |

---

## 3. Utility Functions

### Staking (For Governance)
```solidity
contract NexusStaking is Ownable {
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 rewards;
    }
    
    mapping(address => Stake[]) public stakes;
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // 100 NEXUS per ETH staked per year
    
    function stake(uint256 amount) external {
        require(nexusToken.transferFrom(msg.sender, address(this), amount));
        stakes[msg.sender].push(Stake({
            amount: amount,
            startTime: block.timestamp,
            rewards: 0
        }));
        totalStaked += amount;
    }
    
    function calculateReward(address user) view returns (uint256) {
        uint256 total;
        for (Stake storage s : stakes[user]) {
            uint256 timeStaked = block.timestamp - s.startTime;
            total += (s.amount * timeStaked * rewardRate) / (365 days * 1000);
        }
        return total;
    }
}
```

### Governance
```solidity
contract NexusGovernance is Ownable {
    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        bool executed;
    }
    
    Proposal[] public proposals;
    uint256 public quorum = 50_000_000 * 1e18; // 50M tokens to propose
    
    function propose(string memory description) external {
        require(nexusToken.balanceOf(msg.sender) >= quorum, "Not enough tokens");
        proposals.push(Proposal({
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            startTime: block.timestamp,
            executed: false
        }));
    }
    
    function vote(uint256 proposalId, bool support) external {
        // Voting logic
    }
}
```

---

## 4. Fee Distribution

| Action | Fee | Distribution |
|--------|-----|--------------|
| Query Payment | 10 credits | 70% to GPU providers, 20% to stakers, 10% burn |
| Training Task | 50 credits | 80% to trainers, 15% to stakers, 5% burn |
| Withdrawal | 1% | 50% burn, 50% treasury |

---

## 5. Token Economics

### Inflation/Deflation
- **Inflation:** Fixed supply (no inflation)
- **Deflation:** 
  - 5-10% of fees burned
  - Community can vote to increase burn

### Price Stability
- Liquidity pool (50M tokens + equivalent ETH/USDC)
- Automatic market maker integration
- Price floor from staking utility

---

## 6. Security Features

### OpenZeppelin Modules Used
| Module | Purpose |
|--------|---------|
| ERC20 | Standard token |
| ERC20Burnable | Token burning |
| ERC20Snapshot | Historical balance snapshots |
| Ownable | Single admin |
| AccessControl | Role-based permissions |

### Additional Security
- Multi-sig for treasury (3/5)
- Timelock for governance (24 hour delay)
- Emergency pause functionality
- Bug bounty program (5% of treasury)

---

## 7. Deployment Checklist

| Step | Status |
|------|--------|
| Deploy to Base testnet | ⬜ |
| Security audit | ⬜ |
| Deploy to Base mainnet | ⬜ |
| Set up liquidity | ⬜ |
| Enable trading | ⬜ |

---

## 8. Image Assets

### Logo Concepts

**Option A: Geometric Nexus**
- Hexagon with interconnected nodes
- Colors: Gradient from #00FF88 to #00D4FF
- Represents: Decentralized network

**Option B: Brain Network**
- Neural network visualization
- Colors: Cyan (#00D4FF) + Purple (#7B2FF7)
- Represents: AI/Intelligence

**Option C: Infinity Loop**
- Mobius strip with AI circuit patterns
- Colors: Green (#00FF88) + Dark (#0A0A0F)
- Represents: Continuous learning

### Brand Colors
| Color | Hex | Usage |
|-------|-----|--------|
| Primary Green | #00FF88 | Growth, rewards |
| Secondary Blue | #00D4FF | Technology, trust |
| Accent Purple | #7B2FF7 | AI, intelligence |
| Dark Background | #0A0A0F | Modern, premium |
| White | #FFFFFF | Text, contrast |

### Token Icon Specs
- Format: SVG (scalable)
- Size: 512x512 base
- Style: Minimal, recognizable at small sizes

---

## 9. Visual Identity

### Typography
- **Headlines:** Inter Bold
- **Body:** Inter Regular  
- **Numbers:** JetBrains Mono

### Iconography Style
- Line-based icons
- 2px stroke weight
- Rounded corners (8px radius)

### Marketing Assets
- Presentation deck
- One-pager summary
- Social media kit (Twitter, Discord)
- Merchandise templates

---

## 10. Roadmap Integration

| Version | Token Features |
|---------|---------------|
| v0.1 | Basic ERC20, faucet |
| v0.2 | Staking, rewards |
| v0.3 | Governance, voting |
| v0.4 | Multi-sig treasury |
| v1.0 | Full DAO |

---

## Summary

| Parameter | Value |
|-----------|-------|
| Token | $NEXUS |
| Network | Base |
| Total Supply | 1B |
| Community Share | 40% |
| Team Share | 20% |
| Initial Circulating | 10% |
| Break-even | 150M tokens staked |

The tokenomics is designed to:
1. **Reward contributors** fairly (40% community)
2. **Incentivize staking** (governance utility)
3. **Burn fees** (deflationary pressure)
4. **Prevent dumping** (vesting schedules)

---

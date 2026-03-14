# Nexus AI - USDC-Only Refactor Plan

## Why USDC Instead of $NEXUS?

### Securities Risk with $NEXUS
- Token = potential security (Howey Test)
- Profit expectation = securities
- Team/investor vesting = investment contract
- Regulatory risk = potential SEC enforcement

### Why USDC is Safe
- USDC = payment token (not a security)
- Backed 1:1 by USD
- Regulated by US banks
- No profit expectation - just payment for service
- Similar to paying AWS for compute

---

## Gas Considerations

### Base Gas Costs
| Operation | Gas (avg) | Cost (USDC) |
|----------|-----------|-------------|
| Simple transfer | ~21K | $0.001 |
| Contract call | ~50K | $0.003 |
| ERC-20 transfer | ~65K | $0.004 |

### Base Paymaster
- Users don't need native ETH for gas
- Gas sponsored by Paymaster
- Fee comes from payment amount
- Minimum payment must cover gas + margin

---

## Current Architecture (Needs Change)

```
❌ $NEXUS Token (Security Risk)
❌ Staking (investment contract)
❌ Governance voting (profit expectation)
❌ Team/Investor vesting (securities)
```

---

## New Architecture (USDC Only)

```
✅ USDC Payments (Safe)
✅ USDCx Streaming (Superfluid)
✅ Supabase (Auth + Data)
✅ Compute Marketplace (Utility)
```

---

## Refactor Tasks

### Phase 1: Remove Token (Week 1)

| Task | Change |
|------|--------|
| Remove $NEXUS | Keep for community rewards only |
| Remove staking | USDC staking optional |
| Remove governance | Community Discord instead |
| Keep faucet | For testing only |

### Phase 2: USDC Payments (Week 2)

| Task | Implementation |
|------|---------------|
| Base Pay | Accept USDC via Base Pay SDK |
| x402 | Payment protocol for API |
| Agent payments | 90% USDC to compute providers |
| Treasury | 10% USDC to运营 |

### Phase 3: Supabase Integration (Week 3)

| Service | Use |
|---------|-----|
| Auth | User accounts (email, wallet) |
| Database | Task history, user data |
| Realtime | Agent status, task updates |
| Edge Functions | Payment verification |

### Phase 4: Agent Network (Week 4)

| Component | Implementation |
|----------|---------------|
| Agent registration | Supabase Auth |
| Task routing | Supabase Realtime |
| Payments | USDC to agent wallets |
| Earnings | USDCx streaming |

---

## New Payment Flow

```
User (USDC Wallet)
    ↓
Base Pay + Paymaster (sponsor gas)
    ↓
Pay $0.005 (min covers gas + compute)
    ↓
Coordinator → Agent
    ↓
Agent runs inference
    ↓
Agent gets paid (90% USDC)
Treasury gets (10% USDC)
```

---

## Pricing with Gas

### Minimum Prices (Must Cover Gas)
| Operation | Gas Cost | Min Price |
|-----------|----------|-----------|
| Chat message | $0.003 | $0.005 |
| Priority message | $0.003 | $0.01 |
| API call | $0.004 | $0.01 |

### Subscription Plans (Token Allowances)

| Plan | Price | Allowance | Per-Message |
|------|-------|-----------|-------------|
| **Free** | $0 | 10/day | $0 (rate limited) |
| **Basic** | $10/mo | 10,000 msgs | $0.001 |
| **Pro** | $50/mo | 100,000 msgs | $0.002 |
| **Enterprise** | $500/mo | Unlimited | $0.001 |

### Token Allowances
- Plans include USDC allowance (not $NEXUS)
- Prepay for compute ahead of time
- Auto-deduct from balance
- Never pay per-request gas

---

## Base Paymaster Integration

```javascript
// Paymaster sponsors gas for users
const result = await pay({
  amount: '10.00',  // $10 USDC
  to: treasuryAddress,
  paymaster: 'nexus-paymaster',  // Our paymaster
  sponsorship: {
    enabled: true,
    limits: ['chat', 'api']
  }
});
```

### How Paymaster Works
1. User pays USDC to treasury
2. Treasury covers gas via Paymaster
3. Net = Payment - Gas = Profit
4. Agent still gets 90% of payment

---

## Files to Change

| File | Action |
|------|--------|
| `contracts/NexusToken.sol` | Deprecate (keep but don't market) |
| `contracts/NexusStaking.sol` | Archive |
| `contracts/NexusGovernor.sol` | Archive |
| `api/main.py` | ✅ Add USDC payment |
| `supabase/` | Create new |
| `chat.html` | ✅ Add USDC pay button |
| `stake.html` | Remove (no staking) |

---

## New Pricing

| Service | Price (USDC) |
|---------|-------------|
| Chat message | $0.001 |
| Priority | $0.005 |
| Training (per hour) | $0.10 |
| API (per 1K tokens) | $0.002 |

---

## Legal Compliance

| Requirement | Implementation |
|-------------|---------------|
| No securities | USDC only - payment, not investment |
| KYC optional | Collect for large transactions only |
| AML | Use Base Pay (already compliant) |
| Money transmission | Base handles it |

---

## Contracts to Keep

| Contract | Purpose |
|----------|---------|
| NexusToken | Archive (for existing holders) |
| NexusFaucet | Keep for testing |

---

## New Stack

| Layer | Technology |
|-------|------------|
| Payments | Base Pay + x402 |
| Auth | Supabase Auth |
| Database | Supabase |
| Compute | Decentralized agents |
| Streaming | USDCx (Superfluid) |

---

## Action Items

1. ✅ Keep existing $NEXUS (existing holders)
2. ✅ Build new USDC payment flow
3. ✅ Add Supabase integration
4. ✅ Update website to emphasize USDC
5. ✅ Remove "tokenomics" from marketing
6. ✅ Focus on "compute marketplace"

---

## Marketing Shift

**Before:** "Community-owned AGI, earn $NEXUS"
**After:** "Decentralized AI compute marketplace, pay with USDC"

This is a utility platform, not a security.

# Nexus AI - x402 Payment Integration Plan

## Overview

Integrate x402 payments so users pay $NEXUS for AI responses, and agents get paid via the decentralized network.

---

## x402 Payment Flow

```
User → Chat Request → Coordinator
                       ↓
              Check balance / payment
                       ↓
         [Paid?] → Process LLM request → Return response
                       ↓
              Agent gets task → Runs inference → Gets paid
```

---

## Implementation

### 1. Payment Endpoints (x402 Compatible)

```javascript
// Server declares payment requirements via headers
app.get('/api/chat', paymentMiddleware({
  '/api/chat': {
    accepts: ['base-sepolia:USDC', 'base:USDC'],
    price: '0.001',  // $0.001 per message
    description: 'AI chat response'
  }
}));
```

### 2. Payment Flow

| Step | Action |
|------|--------|
| 1 | User sends chat request |
| 2 | Server returns 402 + payment requirements |
| 3 | User's wallet pays (USDC or $NEXUS) |
| 4 | Server verifies payment |
| 5 | Return chat response |
| 6 | Payment splits: 90% to agent, 10% treasury |

### 3. Price Tiers

| Tier | Price | Speed |
|------|-------|-------|
| Free | 0 | Rate limited |
| Basic | $0.001/msg | Normal |
| Priority | $0.005/msg | Fast track |

---

## Base Integration

### Base Account (Sign In)
```javascript
import { SignInWithBase } from '@base-org/account';

// User signs in with their Base wallet
const user = await SignInWithBase();
// Returns: { address, domain, statement }
```

### Base Pay (USDC Payments)
```javascript
import { pay, getPaymentStatus } from '@base-org/account';

const payment = await pay({
  amount: '0.001',  // $0.001 USDC
  to: treasuryAddress,
  testnet: false
});

// Verify on backend
const status = await getPaymentStatus(payment.id);
```

---

## Updated Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Chat UI   │  │   Staking   │  │  Profile    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓ x402
┌─────────────────────────────────────────────────────────────┐
│                      API Server                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  x402 Pay   │  │  Chat API   │  │ Staking API │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Coordinator                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Task Q    │  │   Agent     │  │   Rewards   │     │
│  │             │  │   Pool      │  │   Tracker   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Agent Network                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                   │
│  │ GPU 1    │ │ GPU 2    │ │ GPU 3    │  ...            │
│  └──────────┘ └──────────┘ └──────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Revenue Split

| Recipient | % |
|-----------|---|
| Agent (compute provider) | 90% |
| Treasury (development) | 10% |

---

## Staking Integration

Users stake $NEXUS for:
- Free tier access
- Reduced fees
- Governance voting
- Priority queue

```solidity
// Staking reduces fees
uint256 public stakingDiscount = 50; // 50% discount for stakers

function getPrice(address user) public view returns (uint256) {
    uint256 basePrice = 0.001e6; // $0.001 in USDC6
    if (stakedBalance[user] > 1000e18) {
        return basePrice / 2; // 50% discount
    }
    return basePrice;
}
```

---

## API Endpoints

### Chat (x402 Protected)
```
POST /api/chat
x402-payment: required
Body: { "message": "Hello" }
Response: { "reply": "Hi!" }
```

### Staking
```
POST /api/stake
Body: { "amount": 100 }

GET /api/balance/{address}
Response: { "staked": 100, "earned": 50 }
```

### Agent Rewards
```
GET /api/agent/rewards/{agentId}
Response: { "pending": 10, "claimed": 100 }
```

---

## Mini App (Farcaster)

For Frame/ Mini App:
```javascript
// Mini App must use Frame context
import { useFrame } from '@coinbase/onchainkit';

function ChatPage() {
  const { fid, walletAddress } = useFrame();
  // Authenticate via Frame context
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `/api/payments.js` | x402 payment middleware |
| `/api/chat.js` | Chat endpoint with x402 |
| `/api/staking.js` | Stake/unstake $NEXUS |
| `/frontend/chat.jsx` | Chat component |
| `/frontend/stake.jsx` | Staking component |

---

## Next Steps

1. Install x402 SDK
2. Create payment-protected endpoints
3. Build staking interface
4. Integrate Base Sign-In
5. Test payment flow
6. Deploy to Vercel

# Heliora Protocol

Optimistic execution layer for autonomous protocols on Base.

Heliora is execution infrastructure for on-chain automation with verifiable condition execution. It runs on Base with real transaction execution, cryptoeconomic guarantees, and a permissioned executor model.

## Overview

- On-chain condition-based automation (block, timestamp, price, balance triggers)
- 7 smart contracts covering execution, payments, staking, condition registry, oracle, and routing
- Crypto-native subscription payments in USDC and ETH
- Multi-tenant job management with per-key isolation and rate limiting
- Background execution worker for automatic condition checking
- Challenge and fraud proof mechanism for optimistic execution verification

## Quick Start

### Prerequisites

- Node.js 18+
- PostgreSQL (production) or in-memory (development)
- Base Sepolia ETH for testnet, or Base Mainnet ETH for production

### Installation

```bash
git clone https://github.com/HelioraProtocol/heliora-protocol.git
cd heliora-protocol
npm install
cp env.example .env.local
```

### Configuration

Edit `.env.local`:

```bash
DATABASE_URL=postgresql://user:pass@localhost:5432/heliora
RPC_URL=https://mainnet.base.org
TESTNET_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_APP_URL=http://localhost:3000
NODE_ENV=development
ADMIN_SECRET=your-secret
REQUIRE_EXECUTION_KEYS=false
EXECUTOR_PRIVATE_KEY=0x...
EXECUTOR_TEST_CONTRACT_ADDRESS=0x...
ONCHAIN_EXECUTION_ENABLED=false
USE_TESTNET=true
```

### Run

```bash
npm run dev
```

Open `http://localhost:3000`.

## Smart Contracts

7 Solidity contracts in `contracts/`:

| Contract | File | Description |
|---|---|---|
| HelioraExecutor | `ExecutorTest.sol` | Execution engine - arbitrary function calls on target contracts |
| HelioraInterface | `HelioraInterface.sol` | Protocol integration - condition registration, activation, execution lifecycle |
| HelioraPayment | `HelioraPayment.sol` | Subscription payments in USDC and ETH with tier management |
| HelioraStaking | `HelioraStaking.sol` | Executor and condition staking with slashing |
| ConditionRegistry | `ConditionRegistry.sol` | On-chain condition registry with challenge mechanism |
| HelioraPriceOracle | `HelioraPriceOracle.sol` | Chainlink price feed integration for price triggers |
| HelioraRouter | `HelioraRouter.sol` | Central router connecting all protocol contracts |

### Condition Types

- `BLOCK_NUMBER` - trigger at specific block
- `TIMESTAMP` - trigger at specific time
- `PRICE_ABOVE` - trigger when price exceeds threshold
- `PRICE_BELOW` - trigger when price drops below threshold
- `BALANCE_THRESHOLD` - trigger on balance change

### Payment Tiers

| Tier | Price | Conditions | Executions/day |
|---|---|---|---|
| Testnet | Free | 100 | 1,000 |
| Mainnet | 500 USDC/mo or 0.2 ETH/mo | Unlimited | 10,000 |
| Enterprise | Custom | Unlimited | Unlimited |

Payments are handled on-chain via `HelioraPayment.sol`. 30-day periods with 3-day grace. Both USDC and native ETH accepted on Base.

### Staking

- Executor minimum stake: 0.1 ETH (slashed for missed or invalid executions)
- Condition stake: 0.01 ETH per condition (returned on completion)
- Challenge period: 300 blocks for execution verification

### Contract Deployment Order

1. `HelioraExecutor`
2. `HelioraInterface` (pass executor address)
3. `HelioraPayment` (pass USDC address + treasury)
4. `HelioraStaking` (pass slasher address)
5. `ConditionRegistry` (pass executor address)
6. `HelioraPriceOracle` (register Chainlink feeds after deploy)
7. `HelioraRouter` (register all contract addresses)

## Project Structure

```
contracts/
  interfaces/IERC20.sol
  ExecutorTest.sol
  HelioraInterface.sol
  HelioraPayment.sol
  HelioraStaking.sol
  ConditionRegistry.sol
  HelioraPriceOracle.sol
  HelioraRouter.sol

src/
  protocol/
    types.ts              # Core type definitions
    index.ts              # Public exports
  app/
    page.tsx              # Landing page
    dashboard/            # Network interface
    docs/                 # Documentation
    contact/              # Contact form
    api/
      jobs/               # Job CRUD
      execute/            # Execution loop
      onchain/            # On-chain execution
      subscriptions/      # Payment verification
      stats/              # Network statistics
      contact/            # Contact messages
      newsletter/         # Newsletter
  lib/
    executor.ts           # Execution engine
    onchain-executor.ts   # On-chain execution via ethers.js
  components/
    sections/             # Landing page sections
    Header.tsx
    Footer.tsx
```

## API

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/jobs` | List jobs (filtered by key if enforcement on) |
| POST | `/api/jobs` | Create execution job |
| GET | `/api/jobs/[id]` | Job details + logs |
| PATCH | `/api/jobs/[id]` | Activate, pause, or retry job |
| DELETE | `/api/jobs/[id]` | Delete job |
| POST | `/api/execute` | Trigger execution loop |
| GET | `/api/execute` | Get network state + stats |
| POST | `/api/onchain/execute` | Direct on-chain execution |
| GET | `/api/subscriptions?address=0x...` | Check subscription status |
| POST | `/api/subscriptions` | Record payment (with tx verification) |
| GET | `/api/stats` | Network statistics |

### Access Control

Jobs API supports access key enforcement via `X-Execution-Key` header. Set `REQUIRE_EXECUTION_KEYS=true` to enable.

Keys are issued per-protocol with tier-based rate limits. SHA-256 hashed in storage.

## Security

On-chain:

- `onlyExecutor` modifier restricts execution to authorized addresses
- Executor staking with slashing for missed or invalid executions
- Condition staking as economic guarantee
- 300-block challenge period for fraud proofs
- 100-block execution window prevents stale executions
- Payment verification on-chain via HelioraPayment

Off-chain:

- Access keys hashed with SHA-256, raw key shown only once on creation
- Per-tier daily execution rate limits
- Multi-tenant job isolation by access key
- Admin access via secret-based authentication

## Tech Stack

- **Runtime** - Next.js 16 (App Router), TypeScript
- **Styling** - Tailwind CSS
- **Blockchain** - Base (Chain ID 8453), Solidity 0.8.19
- **Web3** - ethers.js v6
- **Database** - PostgreSQL
- **Contracts** - 7 Solidity contracts (execution, payment, staking, registry, oracle, router)

## License

MIT

## Links

- Website: https://heliora-protocol.xyz
- Docs: https://heliora-protocol.xyz/docs
- Twitter: https://twitter.com/helioraprotocol

# Heliora Protocol

Optimistic execution layer for autonomous protocols on Base.

Heliora is execution infrastructure for on-chain automation with verifiable condition execution. It runs on Base with real transaction execution, cryptoeconomic guarantees, and a permissioned executor model.

## Overview

- On-chain condition-based automation (block, timestamp, price, balance triggers)
- 7 audited smart contracts covering execution, payments, staking, condition registry, oracle, and routing
- Crypto-native subscription payments in USDC and ETH
- Challenge and fraud proof mechanism for optimistic execution verification
- Reentrancy-guarded ETH transfers across all staking and payment flows
- Chainlink oracle integration for price-based condition triggers
- 129 tests covering all contracts and edge cases

## Quick Start

### Prerequisites

- Node.js 18+
- Base Sepolia ETH for testnet, or Base Mainnet ETH for production

### Installation

```bash
git clone https://github.com/HelioraProtocol/heliora-protocol.git
cd heliora-protocol
npm install
```

### Compile

```bash
npx hardhat compile
```

### Test

```bash
npx hardhat test
```

129 tests across all 7 contracts. Covers deployment, access control, staking, slashing, subscriptions, oracle integration, challenge mechanism, and edge cases.

## Smart Contracts

7 Solidity contracts in `contracts/`:

| Contract | File | Description |
|---|---|---|
| HelioraExecutor | `ExecutorTest.sol` | Access-controlled execution engine with reentrancy guard |
| HelioraInterface | `HelioraInterface.sol` | Protocol integration - condition registration, activation, execution lifecycle |
| HelioraPayment | `HelioraPayment.sol` | Subscription payments in USDC and ETH with tier management |
| HelioraStaking | `HelioraStaking.sol` | Executor and condition staking with slashing and reentrancy protection |
| ConditionRegistry | `ConditionRegistry.sol` | On-chain condition registry with challenge mechanism |
| HelioraPriceOracle | `HelioraPriceOracle.sol` | Chainlink price feed integration with staleness checks |
| HelioraRouter | `HelioraRouter.sol` | Central router connecting all protocol contracts |

### Condition Types

- `BLOCK_NUMBER` - trigger at specific block
- `TIMESTAMP` - trigger at specific time
- `PRICE_ABOVE` - trigger when price exceeds threshold (via Chainlink)
- `PRICE_BELOW` - trigger when price drops below threshold (via Chainlink)
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

### Deployment Order

1. `HelioraExecutor`
2. `HelioraInterface` (pass executor address)
3. `HelioraPayment` (pass USDC address + treasury)
4. `HelioraStaking` (pass slasher address)
5. `ConditionRegistry` (pass executor address)
6. `HelioraPriceOracle` (register Chainlink feeds after deploy)
7. `HelioraRouter` (register all contract addresses)

### Chainlink Price Feeds (Base Mainnet)

| Pair | Address |
|---|---|
| ETH/USD | `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70` |
| BTC/USD | `0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E` |
| USDC/USD | `0x7e860098F58bBFC8648a4311b374B1D669a2bc6B` |

### USDC on Base

- Mainnet: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Sepolia: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

## Project Structure

```
contracts/
  ExecutorTest.sol          # Execution engine
  HelioraInterface.sol      # Protocol integration layer
  HelioraPayment.sol        # Subscription payments
  HelioraStaking.sol        # Stake/slash security
  ConditionRegistry.sol     # Condition management + challenges
  HelioraPriceOracle.sol    # Chainlink price feeds
  HelioraRouter.sol         # Central contract registry
  interfaces/
    IERC20.sol              # ERC20 interface
  mocks/
    MockERC20.sol           # Test mock for USDC
    MockChainlinkFeed.sol   # Test mock for price feeds
test/
  HelioraProtocol.test.js   # 129 tests
hardhat.config.js
package.json
```

## Security

- `onlyAuthorized` / `onlyExecutor` modifiers restrict execution to authorized addresses
- `nonReentrant` guard on all ETH transfer functions (stake, unstake, slash, release)
- Executor staking with slashing for missed or invalid executions
- Condition staking as economic guarantee
- 300-block challenge period for fraud proofs
- 100-block execution window prevents stale executions
- Staleness check on Chainlink price feeds (1 hour max)
- Emergency withdraw functions with event logging
- Payment verification on-chain via HelioraPayment

## Tech Stack

- **Blockchain** - Base (Chain ID 8453)
- **Language** - Solidity 0.8.19
- **Framework** - Hardhat
- **Testing** - Mocha, Chai, ethers.js v6
- **Oracles** - Chainlink Price Feeds

## License

MIT

## Links

- **Website**: https://heliora-protocol.xyz
- **Docs**: https://heliora-protocol.xyz/docs
- **Twitter**: https://twitter.com/helioraprotocol
- **App**: https://heliora-protocol.xyz/subscribe

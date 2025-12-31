# On-Chain Execution Setup

This guide explains how to set up and deploy the minimal on-chain execution for Heliora Protocol MVP.

## Overview

The `ExecutorTest.sol` contract is a minimal implementation that demonstrates real on-chain execution. It emits events when executed, proving that Heliora's execution layer can trigger real blockchain transactions.

## Prerequisites

1. **Node.js** and **npm** installed
2. **Foundry** or **Hardhat** for contract deployment (optional, can use Remix)
3. **Base Sepolia** testnet ETH (for testing) or **Base Mainnet** ETH (for production demo)
4. **Private key** for executor wallet (separate wallet with minimal funds)

## Step 1: Deploy ExecutorTest Contract

### Option A: Using Remix (Easiest)

1. Go to [Remix IDE](https://remix.ethereum.org)
2. Create new file `ExecutorTest.sol`
3. Copy contents from `contracts/ExecutorTest.sol`
4. Compile contract (Solidity 0.8.0+)
5. Deploy to Base Sepolia (or Base Mainnet):
   - Select "Injected Provider" (MetaMask)
   - Switch network to Base Sepolia
   - Deploy contract
   - Copy contract address

### Option B: Using Foundry

```bash
# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Create new project (if needed)
forge init heliora-contracts
cd heliora-contracts

# Copy ExecutorTest.sol to src/
cp ../contracts/ExecutorTest.sol src/

# Deploy to Base Sepolia
forge create ExecutorTest \
  --rpc-url https://sepolia.base.org \
  --private-key $EXECUTOR_PRIVATE_KEY \
  --constructor-args
```

## Step 2: Configure Environment Variables

Add to `.env.local`:

```bash
# Executor private key (wallet that will send transactions)
EXECUTOR_PRIVATE_KEY=0x...

# ExecutorTest contract address (from deployment)
EXECUTOR_TEST_CONTRACT_ADDRESS=0x...

# Use testnet (true for Base Sepolia, false for Base Mainnet)
USE_TESTNET=true

# Testnet RPC URL
TESTNET_RPC_URL=https://sepolia.base.org
```

## Step 3: Test On-Chain Execution

### Via API

```bash
# Execute condition on-chain
curl -X POST http://localhost:3000/api/onchain/execute \
  -H "Content-Type: application/json" \
  -d '{
    "conditionId": 1,
    "contractAddress": "0x..."
  }'
```

### Check Last Execution

```bash
# Get last on-chain execution
curl "http://localhost:3000/api/onchain/execute?contractAddress=0x..."
```

## Step 4: Verify on BaseScan

1. Go to [BaseScan Sepolia](https://sepolia.basescan.org) or [BaseScan Mainnet](https://basescan.org)
2. Search for your contract address
3. Check "Events" tab for `Executed` events
4. Verify transaction hash shows successful execution

## Security Notes

⚠️ **IMPORTANT:**

- Use a **separate wallet** with minimal funds for executor
- **Never commit** `EXECUTOR_PRIVATE_KEY` to git
- For production, use a **hardware wallet** or **multisig**
- Start with **Base Sepolia testnet** before mainnet
- Monitor gas costs and set appropriate limits

## What This Proves

- ✅ Heliora execution layer can trigger real on-chain transactions
- ✅ Events are emitted and verifiable on BaseScan
- ✅ Execution is not just simulated — it's real blockchain state changes
- ✅ Foundation for full execution contracts (staking, slashing, challenges)

## Next Steps

1. Deploy contract to Base Sepolia
2. Execute test transaction
3. Update website to show verified on-chain execution
4. Share transaction hash with investors/partners

## Example Transaction

After deployment and execution, you'll have:
- Contract address: `0x...`
- Transaction hash: `0x...`
- Block number: `12345678`
- Event: `Executed(conditionId, blockNumber, executor, timestamp)`

This proves execution works on-chain! 🎉


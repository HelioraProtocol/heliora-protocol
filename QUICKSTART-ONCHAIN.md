# Quick Start: On-Chain Execution

## 🚀 3-Step Setup

### 1. Deploy Contract (5 minutes)

**Using Remix:**
1. Go to https://remix.ethereum.org
2. Create `ExecutorTest.sol` with content from `contracts/ExecutorTest.sol`
3. Compile (Solidity 0.8.0+)
4. Deploy to **Base Sepolia** (testnet)
5. Copy contract address

### 2. Configure Environment

Add to `.env.local`:

```bash
EXECUTOR_PRIVATE_KEY=0x...          # Your executor wallet private key
EXECUTOR_TEST_CONTRACT_ADDRESS=0x... # Contract address from step 1
USE_TESTNET=true                     # true for Sepolia, false for Mainnet
TESTNET_RPC_URL=https://sepolia.base.org
```

### 3. Test Execution

```bash
# Execute on-chain
curl -X POST http://localhost:3000/api/onchain/execute \
  -H "Content-Type: application/json" \
  -d '{
    "conditionId": 1,
    "contractAddress": "YOUR_CONTRACT_ADDRESS"
  }'
```

## ✅ Verification

1. Check transaction on [BaseScan Sepolia](https://sepolia.basescan.org)
2. Look for `Executed` event in contract events
3. Website now shows: "✓ Minimal on-chain execution verified"

## 📝 What This Proves

- ✅ Execution is **not just simulated**
- ✅ Real on-chain transaction with event emission
- ✅ Verifiable on BaseScan
- ✅ Foundation for full execution contracts

## 🔒 Security

- Use **separate wallet** with minimal funds
- **Never commit** private key to git
- Start with **testnet** before mainnet

---

**Full documentation:** See `README-ONCHAIN.md`


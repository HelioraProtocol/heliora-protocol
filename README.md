# Heliora Protocol — Execution Layer MVP

> **Optimistic execution layer for autonomous protocols on Base.**

Heliora is an execution infrastructure that enables on-chain automation with verifiable condition execution. This MVP demonstrates core execution capabilities with real on-chain transaction verification.

## 🎯 What This MVP Demonstrates

- ✅ **Real on-chain execution** — Verified test transactions on Base network
- ✅ **Minimal execution contract** — ExecutorTest.sol emits events proving execution
- ✅ **Verifiable proof** — All executions visible on BaseScan

## 🚀 Quick Start: Reproduce Test Transaction

### Step 1: Deploy ExecutorTest Contract

1. Go to [Remix IDE](https://remix.ethereum.org)
2. Create new file `ExecutorTest.sol`
3. Copy content from `ExecutorTest.sol` in this repository
4. Compile (Solidity 0.8.0+)
5. Deploy to **Base Sepolia** testnet
6. Copy contract address

### Step 2: Execute On-Chain

Call the `execute(uint256 conditionId)` function on your deployed contract.

### Step 3: Verify on BaseScan

1. Go to [BaseScan Sepolia](https://sepolia.basescan.org)
2. Search for your contract address
3. Check "Events" tab for `Executed` events
4. Verify transaction hash shows successful execution

**Result:** You now have a verified on-chain transaction proving execution works! 🎉

## 📚 Documentation

- **On-Chain Setup:** See `README-ONCHAIN.md`
- **Quick Start:** See `QUICKSTART-ONCHAIN.md`
- **Live Demo:** [heliora-protocol.xyz](https://heliora-protocol.xyz)
- **Full Documentation:** [heliora-protocol.xyz/docs](https://heliora-protocol.xyz/docs)

## 🔍 What Investors See

This MVP demonstrates:

1. **Execution Infrastructure** — Real on-chain transaction capability
2. **Technical Execution** — Contract-based execution with event emission
3. **Verifiable Proof** — On-chain events on BaseScan
4. **Clear Roadmap** — Development phases and milestones

**Key Differentiator:** Execution is not just simulated — we have verified on-chain test transactions.

## 🛠️ Tech Stack

- **Blockchain:** Base (EVM)
- **Solidity:** 0.8.0+
- **Network:** Base Sepolia (testnet) / Base Mainnet

## ⚠️ MVP Status

This is an MVP demonstrating execution infrastructure concepts. Full production features (staking, slashing, challenge mechanism) are in development.

**Current Status:**
- ✅ Minimal on-chain execution verified
- ✅ Execution contracts in development
- 🚧 Full production rollout: Q2 2026

## 📝 License

Core execution contract is open-source ready. Application layer remains proprietary.

## 🔗 Links

- **Website:** https://heliora-protocol.xyz
- **Documentation:** https://heliora-protocol.xyz/docs
- **Twitter:** [@heliora](https://twitter.com/heliora)

---

**Repository Scope:** This public repository contains only the minimal execution contract and documentation to demonstrate on-chain execution capability. Full protocol implementation and application layer remain proprietary.

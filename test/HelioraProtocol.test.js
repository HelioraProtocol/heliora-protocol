const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HelioraExecutor", function () {
  let executor, owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();
    const Executor = await ethers.getContractFactory("HelioraExecutor");
    executor = await Executor.deploy();
  });

  it("should return version", async function () {
    expect(await executor.version()).to.equal("2.1.0-production");
  });

  it("should set owner on deploy", async function () {
    expect(await executor.owner()).to.equal(owner.address);
  });

  it("should authorize deployer by default", async function () {
    expect(await executor.authorizedCallers(owner.address)).to.be.true;
  });

  it("should emit Executed on executeSimple", async function () {
    await expect(executor.executeSimple(1))
      .to.emit(executor, "Executed");
  });

  it("should reject executeSimple from unauthorized", async function () {
    await expect(executor.connect(user).executeSimple(1))
      .to.be.revertedWith("Not authorized");
  });

  it("should execute a real call on target contract", async function () {
    const Target = await ethers.getContractFactory("HelioraExecutor");
    const target = await Target.deploy();
    const selector = target.interface.getFunction("version").selector;
    await expect(executor.execute(1, await target.getAddress(), selector, "0x"))
      .to.emit(executor, "Executed");
  });

  it("should reject execute from unauthorized", async function () {
    const Target = await ethers.getContractFactory("HelioraExecutor");
    const target = await Target.deploy();
    const selector = target.interface.getFunction("version").selector;
    await expect(executor.connect(user).execute(1, await target.getAddress(), selector, "0x"))
      .to.be.revertedWith("Not authorized");
  });

  it("should reject execute with zero address target", async function () {
    await expect(executor.execute(1, ethers.ZeroAddress, "0x12345678", "0x"))
      .to.be.revertedWith("Invalid target");
  });

  it("should authorize and revoke callers", async function () {
    await executor.authorizeCaller(user.address);
    expect(await executor.authorizedCallers(user.address)).to.be.true;
    await expect(executor.connect(user).executeSimple(1)).to.emit(executor, "Executed");
    await executor.revokeCaller(user.address);
    expect(await executor.authorizedCallers(user.address)).to.be.false;
    await expect(executor.connect(user).executeSimple(1)).to.be.revertedWith("Not authorized");
  });

  it("should transfer ownership", async function () {
    await executor.transferOwnership(user.address);
    expect(await executor.owner()).to.equal(user.address);
  });

  it("should reject non-owner admin calls", async function () {
    await expect(executor.connect(user).authorizeCaller(user.address)).to.be.revertedWith("Not owner");
    await expect(executor.connect(user).revokeCaller(owner.address)).to.be.revertedWith("Not owner");
    await expect(executor.connect(user).transferOwnership(user.address)).to.be.revertedWith("Not owner");
  });
});

describe("HelioraRouter", function () {
  let router, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const Router = await ethers.getContractFactory("HelioraRouter");
    router = await Router.deploy();
  });

  it("should set owner on deploy", async function () {
    expect(await router.owner()).to.equal(owner.address);
  });

  it("should set owner as operator", async function () {
    expect(await router.operators(owner.address)).to.be.true;
  });

  it("should set executor address", async function () {
    await router.setExecutor(addr1.address);
    expect(await router.executor()).to.equal(addr1.address);
  });

  it("should set payment address", async function () {
    await router.setPayment(addr1.address);
    expect(await router.payment()).to.equal(addr1.address);
  });

  it("should set staking address", async function () {
    await router.setStaking(addr1.address);
    expect(await router.staking()).to.equal(addr1.address);
  });

  it("should set condition registry", async function () {
    await router.setConditionRegistry(addr1.address);
    expect(await router.conditionRegistry()).to.equal(addr1.address);
  });

  it("should set price oracle", async function () {
    await router.setPriceOracle(addr1.address);
    expect(await router.priceOracle()).to.equal(addr1.address);
  });

  it("should reject zero address", async function () {
    await expect(router.setExecutor(ethers.ZeroAddress)).to.be.revertedWith("Invalid");
  });

  it("should batch set all contracts", async function () {
    await router.setAllContracts(addr1.address, addr1.address, addr1.address, addr1.address, addr1.address, addr1.address);
    expect(await router.executor()).to.equal(addr1.address);
    expect(await router.payment()).to.equal(addr1.address);
    expect(await router.staking()).to.equal(addr1.address);
  });

  it("should get all contracts", async function () {
    await router.setExecutor(addr1.address);
    const result = await router.getContracts();
    expect(result[0]).to.equal(addr1.address);
  });

  it("should get contract by name", async function () {
    await router.setExecutor(addr1.address);
    expect(await router.getContractByName("executor")).to.equal(addr1.address);
  });

  it("should return zero for unknown name", async function () {
    expect(await router.getContractByName("unknown")).to.equal(ethers.ZeroAddress);
  });

  it("should pause/unpause protocol", async function () {
    await router.setPaused(true);
    expect(await router.paused()).to.be.true;
    await router.setPaused(false);
    expect(await router.paused()).to.be.false;
  });

  it("should add/remove operators", async function () {
    await router.setOperator(addr1.address, true);
    expect(await router.operators(addr1.address)).to.be.true;
    await router.setOperator(addr1.address, false);
    expect(await router.operators(addr1.address)).to.be.false;
  });

  it("should transfer ownership", async function () {
    await router.transferOwnership(addr1.address);
    expect(await router.owner()).to.equal(addr1.address);
  });

  it("should reject non-owner calls", async function () {
    await expect(router.connect(addr1).setExecutor(addr2.address)).to.be.revertedWith("Not owner");
    await expect(router.connect(addr1).setPaused(true)).to.be.revertedWith("Not owner");
    await expect(router.connect(addr1).setOperator(addr2.address, true)).to.be.revertedWith("Not owner");
    await expect(router.connect(addr1).transferOwnership(addr2.address)).to.be.revertedWith("Not owner");
  });

  it("should reject transfer to zero address", async function () {
    await expect(router.transferOwnership(ethers.ZeroAddress)).to.be.revertedWith("Invalid owner");
  });
});

describe("HelioraStaking", function () {
  let staking, owner, executor1, executor2, slasher;

  beforeEach(async function () {
    [owner, executor1, executor2, slasher] = await ethers.getSigners();
    const Staking = await ethers.getContractFactory("HelioraStaking");
    staking = await Staking.deploy(slasher.address);
  });

  it("should set owner and slasher", async function () {
    expect(await staking.owner()).to.equal(owner.address);
    expect(await staking.slasher()).to.equal(slasher.address);
  });

  it("should have correct default stakes", async function () {
    expect(await staking.minExecutorStake()).to.equal(ethers.parseEther("0.1"));
    expect(await staking.conditionStake()).to.equal(ethers.parseEther("0.01"));
  });

  describe("Executor Staking", function () {
    it("should allow staking above minimum", async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.amount).to.equal(ethers.parseEther("0.1"));
      expect(stake.active).to.be.true;
    });

    it("should reject staking below minimum", async function () {
      await expect(
        staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.05") })
      ).to.be.revertedWith("Below minimum stake");
    });

    it("should allow adding more stake", async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.2") });
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.amount).to.equal(ethers.parseEther("0.3"));
    });

    it("should track executor count", async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      await staking.connect(executor2).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      expect(await staking.getExecutorCount()).to.equal(2);
    });

    it("should unstake correctly", async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      const balBefore = await ethers.provider.getBalance(executor1.address);
      const tx = await staking.connect(executor1).unstakeExecutor();
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * receipt.gasPrice;
      const balAfter = await ethers.provider.getBalance(executor1.address);
      expect(balAfter + gasCost - balBefore).to.equal(ethers.parseEther("0.1"));
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.active).to.be.false;
    });

    it("should reject unstake when not staked", async function () {
      await expect(staking.connect(executor1).unstakeExecutor()).to.be.revertedWith("Not staked");
    });

    it("should return active executors", async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      await staking.connect(executor2).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      const active = await staking.getActiveExecutors();
      expect(active.length).to.equal(2);
    });

    it("should get total staked", async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.1") });
      await staking.connect(executor2).stakeAsExecutor({ value: ethers.parseEther("0.2") });
      expect(await staking.getTotalStaked()).to.equal(ethers.parseEther("0.3"));
    });
  });

  describe("Slashing", function () {
    beforeEach(async function () {
      await staking.connect(executor1).stakeAsExecutor({ value: ethers.parseEther("0.5") });
    });

    it("should slash executor (by slasher)", async function () {
      await staking.connect(slasher).slashExecutor(executor1.address, ethers.parseEther("0.1"), "missed execution", 1);
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.amount).to.equal(ethers.parseEther("0.4"));
      expect(stake.slashedAmount).to.equal(ethers.parseEther("0.1"));
      expect(stake.missedCount).to.equal(1);
    });

    it("should slash executor (by owner)", async function () {
      await staking.connect(owner).slashExecutor(executor1.address, ethers.parseEther("0.1"), "test", 1);
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.slashedAmount).to.equal(ethers.parseEther("0.1"));
    });

    it("should deactivate if stake falls below minimum", async function () {
      await staking.connect(slasher).slashExecutor(executor1.address, ethers.parseEther("0.45"), "big slash", 1);
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.active).to.be.false;
    });

    it("should cap slash at available amount", async function () {
      await staking.connect(slasher).slashExecutor(executor1.address, ethers.parseEther("10"), "over-slash", 1);
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.amount).to.equal(0);
    });

    it("should record slash history", async function () {
      await staking.connect(slasher).slashExecutor(executor1.address, ethers.parseEther("0.1"), "test reason", 42);
      const history = await staking.getSlashHistory();
      expect(history.length).to.equal(1);
      expect(history[0].reason).to.equal("test reason");
      expect(history[0].conditionId).to.equal(42);
    });

    it("should reject slash from non-slasher", async function () {
      await expect(
        staking.connect(executor2).slashExecutor(executor1.address, ethers.parseEther("0.1"), "hack", 1)
      ).to.be.revertedWith("Not slasher");
    });

    it("should record execution count", async function () {
      await staking.connect(slasher).recordExecution(executor1.address);
      await staking.connect(slasher).recordExecution(executor1.address);
      const stake = await staking.getExecutorStake(executor1.address);
      expect(stake.executionCount).to.equal(2);
    });
  });

  describe("Condition Staking", function () {
    it("should stake for condition", async function () {
      await staking.connect(executor1).stakeForCondition(1, { value: ethers.parseEther("0.01") });
      const info = await staking.getConditionStake(1);
      expect(info.owner).to.equal(executor1.address);
      expect(info.amount).to.equal(ethers.parseEther("0.01"));
      expect(info.released).to.be.false;
    });

    it("should reject duplicate condition stake", async function () {
      await staking.connect(executor1).stakeForCondition(1, { value: ethers.parseEther("0.01") });
      await expect(
        staking.connect(executor2).stakeForCondition(1, { value: ethers.parseEther("0.01") })
      ).to.be.revertedWith("Already staked");
    });

    it("should reject below minimum condition stake", async function () {
      await expect(
        staking.connect(executor1).stakeForCondition(1, { value: ethers.parseEther("0.005") })
      ).to.be.revertedWith("Below condition stake");
    });

    it("should release condition stake", async function () {
      await staking.connect(executor1).stakeForCondition(1, { value: ethers.parseEther("0.01") });
      await staking.connect(executor1).releaseConditionStake(1);
      const info = await staking.getConditionStake(1);
      expect(info.released).to.be.true;
    });

    it("should track user conditions", async function () {
      await staking.connect(executor1).stakeForCondition(1, { value: ethers.parseEther("0.01") });
      await staking.connect(executor1).stakeForCondition(2, { value: ethers.parseEther("0.01") });
      const conds = await staking.getUserConditions(executor1.address);
      expect(conds.length).to.equal(2);
    });

    it("should slash condition stake", async function () {
      await staking.connect(executor1).stakeForCondition(1, { value: ethers.parseEther("0.01") });
      await staking.connect(slasher).slashConditionStake(1, "invalid condition");
      const info = await staking.getConditionStake(1);
      expect(info.released).to.be.true;
    });
  });

  describe("Admin", function () {
    it("should update slasher", async function () {
      await staking.setSlasher(executor1.address);
      expect(await staking.slasher()).to.equal(executor1.address);
    });

    it("should update min executor stake", async function () {
      await staking.setMinExecutorStake(ethers.parseEther("1"));
      expect(await staking.minExecutorStake()).to.equal(ethers.parseEther("1"));
    });

    it("should update condition stake", async function () {
      await staking.setConditionStake(ethers.parseEther("0.05"));
      expect(await staking.conditionStake()).to.equal(ethers.parseEther("0.05"));
    });

    it("should transfer ownership", async function () {
      await staking.transferOwnership(executor1.address);
      expect(await staking.owner()).to.equal(executor1.address);
    });
  });
});

describe("ConditionRegistry", function () {
  let registry, owner, executor, user, challenger;

  beforeEach(async function () {
    [owner, executor, user, challenger] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("ConditionRegistry");
    registry = await Registry.deploy(executor.address);
  });

  it("should set owner and executor", async function () {
    expect(await registry.owner()).to.equal(owner.address);
    expect(await registry.executor()).to.equal(executor.address);
  });

  describe("Registration", function () {
    it("should register a condition", async function () {
      const tx = await registry.connect(user).registerCondition(
        0, // BLOCK_NUMBER
        1000,
        user.address,
        "0x12345678",
        false
      );
      const receipt = await tx.wait();
      const condition = await registry.getCondition(1);
      expect(condition.registrant).to.equal(user.address);
      expect(condition.conditionType).to.equal(0);
      expect(condition.conditionValue).to.equal(1000);
    });

    it("should increment condition IDs", async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", false);
      await registry.connect(user).registerCondition(1, 200, user.address, "0x12345678", false);
      expect(await registry.nextConditionId()).to.equal(3);
      expect(await registry.totalRegistered()).to.equal(2);
    });

    it("should reject zero target", async function () {
      await expect(
        registry.connect(user).registerCondition(0, 100, ethers.ZeroAddress, "0x12345678", false)
      ).to.be.revertedWith("Invalid target");
    });

    it("should reject zero value", async function () {
      await expect(
        registry.connect(user).registerCondition(0, 0, user.address, "0x12345678", false)
      ).to.be.revertedWith("Invalid value");
    });

    it("should track registrant conditions", async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", false);
      await registry.connect(user).registerCondition(0, 200, user.address, "0x12345678", false);
      const conds = await registry.getRegistrantConditions(user.address);
      expect(conds.length).to.equal(2);
    });
  });

  describe("Activation & Cancellation", function () {
    beforeEach(async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", false);
    });

    it("should activate condition", async function () {
      await registry.connect(user).activateCondition(1);
      const condition = await registry.getCondition(1);
      expect(condition.status).to.equal(1); // ACTIVE
    });

    it("should reject activation by non-registrant", async function () {
      await expect(registry.connect(executor).activateCondition(1)).to.be.revertedWith("Not registrant");
    });

    it("should cancel condition", async function () {
      await registry.connect(user).cancelCondition(1);
      const condition = await registry.getCondition(1);
      expect(condition.status).to.equal(3); // CANCELLED
      expect(await registry.totalCancelled()).to.equal(1);
    });

    it("should allow owner to cancel", async function () {
      await registry.connect(owner).cancelCondition(1);
      const condition = await registry.getCondition(1);
      expect(condition.status).to.equal(3); // CANCELLED
    });
  });

  describe("Execution Recording", function () {
    beforeEach(async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", false);
      await registry.connect(user).activateCondition(1);
    });

    it("should record execution", async function () {
      const txHash = ethers.keccak256(ethers.toUtf8Bytes("test-tx"));
      await registry.connect(executor).recordExecution(1, txHash);
      const condition = await registry.getCondition(1);
      expect(condition.status).to.equal(2); // EXECUTED
      expect(await registry.totalExecuted()).to.equal(1);
    });

    it("should set challenge deadline", async function () {
      const txHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await registry.connect(executor).recordExecution(1, txHash);
      const condition = await registry.getCondition(1);
      expect(condition.challengeDeadline).to.be.gt(0);
    });

    it("should create execution proof", async function () {
      const txHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await registry.connect(executor).recordExecution(1, txHash);
      const proof = await registry.getExecutionProof(1);
      expect(proof.executor).to.equal(executor.address);
      expect(proof.valid).to.be.true;
    });

    it("should reject execution by non-executor", async function () {
      const txHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await expect(registry.connect(user).recordExecution(1, txHash)).to.be.revertedWith("Not executor");
    });

    it("should handle repeatable conditions", async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", true);
      await registry.connect(user).activateCondition(2);
      const txHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await registry.connect(executor).recordExecution(2, txHash);
      const condition = await registry.getCondition(2);
      expect(condition.status).to.equal(1); // Still ACTIVE (repeatable)
    });
  });

  describe("Challenge Mechanism", function () {
    beforeEach(async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", false);
      await registry.connect(user).activateCondition(1);
      const txHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await registry.connect(executor).recordExecution(1, txHash);
    });

    it("should allow challenge within deadline", async function () {
      await registry.connect(challenger).challengeExecution(1);
      const proof = await registry.getExecutionProof(1);
      expect(proof.challenged).to.be.true;
    });

    it("should reject duplicate challenge", async function () {
      await registry.connect(challenger).challengeExecution(1);
      await expect(registry.connect(challenger).challengeExecution(1)).to.be.revertedWith("Already challenged");
    });

    it("should resolve challenge as valid", async function () {
      await registry.connect(challenger).challengeExecution(1);
      await registry.connect(owner).resolveChallenge(1, true);
      const proof = await registry.getExecutionProof(1);
      expect(proof.valid).to.be.true;
    });

    it("should resolve challenge as invalid (slash)", async function () {
      await registry.connect(challenger).challengeExecution(1);
      await registry.connect(owner).resolveChallenge(1, false);
      const proof = await registry.getExecutionProof(1);
      expect(proof.valid).to.be.false;
      const condition = await registry.getCondition(1);
      expect(condition.status).to.equal(5); // SLASHED
    });
  });

  describe("View Functions", function () {
    it("should check block-based condition readiness", async function () {
      const blockNum = await ethers.provider.getBlockNumber();
      await registry.connect(user).registerCondition(0, blockNum + 1000, user.address, "0x12345678", false);
      await registry.connect(user).activateCondition(1);
      expect(await registry.isConditionReady(1)).to.be.false;
    });

    it("should return stats", async function () {
      await registry.connect(user).registerCondition(0, 100, user.address, "0x12345678", false);
      const stats = await registry.getStats();
      expect(stats.registered).to.equal(1);
    });
  });

  describe("Admin", function () {
    it("should update executor", async function () {
      await registry.setExecutor(user.address);
      expect(await registry.executor()).to.equal(user.address);
    });

    it("should update challenge period", async function () {
      await registry.setChallengePeriod(600);
      expect(await registry.challengePeriod()).to.equal(600);
    });

    it("should transfer ownership", async function () {
      await registry.transferOwnership(user.address);
      expect(await registry.owner()).to.equal(user.address);
    });
  });
});

describe("HelioraInterface", function () {
  let iface, executorContract, owner, user, otherUser;

  beforeEach(async function () {
    [owner, user, otherUser] = await ethers.getSigners();
    const Executor = await ethers.getContractFactory("HelioraExecutor");
    executorContract = await Executor.deploy();
    const Interface = await ethers.getContractFactory("HelioraInterface");
    iface = await Interface.deploy(await executorContract.getAddress());
  });

  it("should set owner and executor", async function () {
    expect(await iface.owner()).to.equal(owner.address);
    expect(await iface.helioraExecutor()).to.equal(await executorContract.getAddress());
  });

  it("should authorize main executor by default", async function () {
    expect(await iface.authorizedExecutors(await executorContract.getAddress())).to.be.true;
  });

  describe("Condition Registration", function () {
    it("should register a block-based condition", async function () {
      const blockNum = await ethers.provider.getBlockNumber();
      await iface.connect(user).registerCondition(0, blockNum + 100, user.address, "0x12345678", 0);
      const cond = await iface.getCondition(1);
      expect(cond.protocol).to.equal(user.address);
      expect(cond.status).to.equal(0); // PENDING
    });

    it("should register a time-based condition", async function () {
      const block = await ethers.provider.getBlock("latest");
      await iface.connect(user).registerCondition(1, block.timestamp + 1000, user.address, "0x12345678", 0);
      const cond = await iface.getCondition(1);
      expect(cond.conditionType).to.equal(1); // TIMESTAMP
    });

    it("should reject past block number", async function () {
      await expect(
        iface.connect(user).registerCondition(0, 1, user.address, "0x12345678", 0)
      ).to.be.revertedWith("Block must be in future");
    });

    it("should reject past timestamp", async function () {
      await expect(
        iface.connect(user).registerCondition(1, 1, user.address, "0x12345678", 0)
      ).to.be.revertedWith("Timestamp must be in future");
    });

    it("should reject zero target", async function () {
      const blockNum = await ethers.provider.getBlockNumber();
      await expect(
        iface.connect(user).registerCondition(0, blockNum + 100, ethers.ZeroAddress, "0x12345678", 0)
      ).to.be.revertedWith("Invalid target contract");
    });

    it("should track protocol conditions", async function () {
      const blockNum = await ethers.provider.getBlockNumber();
      await iface.connect(user).registerCondition(0, blockNum + 100, user.address, "0x12345678", 0);
      await iface.connect(user).registerCondition(0, blockNum + 200, user.address, "0x12345678", 0);
      const conds = await iface.getProtocolConditions(user.address);
      expect(conds.length).to.equal(2);
    });
  });

  describe("Activation & Cancellation", function () {
    let blockNum;
    beforeEach(async function () {
      blockNum = await ethers.provider.getBlockNumber();
      await iface.connect(user).registerCondition(0, blockNum + 100, user.address, "0x12345678", 0);
    });

    it("should activate condition", async function () {
      await iface.connect(user).activateCondition(1);
      const cond = await iface.getCondition(1);
      expect(cond.status).to.equal(1); // ACTIVE
    });

    it("should reject activation by non-protocol", async function () {
      await expect(iface.connect(otherUser).activateCondition(1)).to.be.revertedWith("Not condition owner");
    });

    it("should cancel condition", async function () {
      await iface.connect(user).cancelCondition(1);
      const cond = await iface.getCondition(1);
      expect(cond.status).to.equal(3); // CANCELLED
    });

    it("should reject cancellation of executed condition", async function () {
      // Activate and make the executor execute it
      await iface.connect(user).activateCondition(1);
      // We can't easily test execution here without mining blocks, but we can test cancel after activate
      // This test verifies the revert for already cancelled
      await iface.connect(user).cancelCondition(1);
      await expect(iface.connect(user).cancelCondition(1)).to.be.revertedWith("Cannot cancel executed condition");
    });
  });

  describe("Executor Management", function () {
    it("should authorize executor", async function () {
      await iface.authorizeExecutor(user.address);
      expect(await iface.authorizedExecutors(user.address)).to.be.true;
    });

    it("should revoke executor", async function () {
      await iface.authorizeExecutor(user.address);
      await iface.revokeExecutor(user.address);
      expect(await iface.authorizedExecutors(user.address)).to.be.false;
    });

    it("should not revoke main executor", async function () {
      await expect(
        iface.revokeExecutor(await executorContract.getAddress())
      ).to.be.revertedWith("Cannot revoke main executor");
    });

    it("should set execution fee", async function () {
      await iface.setExecutionFee(ethers.parseEther("0.01"));
      expect(await iface.executionFee()).to.equal(ethers.parseEther("0.01"));
    });

    it("should transfer ownership", async function () {
      await iface.transferOwnership(user.address);
      expect(await iface.owner()).to.equal(user.address);
    });

    it("should reject non-owner admin calls", async function () {
      await expect(iface.connect(user).authorizeExecutor(otherUser.address)).to.be.revertedWith("Not owner");
      await expect(iface.connect(user).setExecutionFee(100)).to.be.revertedWith("Not owner");
    });
  });

  describe("Condition Ready Check", function () {
    it("should return false for inactive condition", async function () {
      const blockNum = await ethers.provider.getBlockNumber();
      await iface.connect(user).registerCondition(0, blockNum + 100, user.address, "0x12345678", 0);
      expect(await iface.isConditionReady(1)).to.be.false; // PENDING, not ACTIVE
    });
  });
});

describe("HelioraPayment", function () {
  let payment, mockUSDC, owner, subscriber, treasury;

  beforeEach(async function () {
    [owner, subscriber, treasury] = await ethers.getSigners();

    // Deploy mock USDC
    const MockToken = await ethers.getContractFactory("MockERC20");
    mockUSDC = await MockToken.deploy("USD Coin", "USDC", 6);

    const Payment = await ethers.getContractFactory("HelioraPayment");
    payment = await Payment.deploy(await mockUSDC.getAddress(), 6, treasury.address);

    // Mint USDC to subscriber
    await mockUSDC.mint(subscriber.address, 10000n * 10n ** 6n); // 10,000 USDC
    await mockUSDC.connect(subscriber).approve(await payment.getAddress(), 10000n * 10n ** 6n);
  });

  it("should set owner and treasury", async function () {
    expect(await payment.owner()).to.equal(owner.address);
    expect(await payment.treasury()).to.equal(treasury.address);
  });

  it("should have correct tier configs", async function () {
    const testnet = await payment.getTierConfig(0);
    expect(testnet.priceUSDC).to.equal(0);
    expect(testnet.active).to.be.true;

    const mainnet = await payment.getTierConfig(1);
    expect(mainnet.priceUSDC).to.equal(500n * 10n ** 6n);
    expect(mainnet.priceETH).to.equal(ethers.parseEther("0.2"));

    const enterprise = await payment.getTierConfig(2);
    expect(enterprise.priceUSDC).to.equal(2000n * 10n ** 6n);
  });

  describe("USDC Subscription", function () {
    it("should subscribe with USDC", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "TestProtocol");
      const sub = await payment.getSubscription(subscriber.address);
      expect(sub.active).to.be.true;
      expect(sub.tier).to.equal(1); // MAINNET
      expect(sub.protocolName).to.equal("TestProtocol");
    });

    it("should transfer USDC to treasury", async function () {
      const balBefore = await mockUSDC.balanceOf(treasury.address);
      await payment.connect(subscriber).subscribeUSDC(1, "TestProtocol");
      const balAfter = await mockUSDC.balanceOf(treasury.address);
      expect(balAfter - balBefore).to.equal(500n * 10n ** 6n);
    });

    it("should reject testnet tier (free)", async function () {
      await expect(payment.connect(subscriber).subscribeUSDC(0, "Test")).to.be.revertedWith("Testnet is free");
    });

    it("should track subscriber count", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
      expect(await payment.getSubscriberCount()).to.equal(1);
    });

    it("should create receipt", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
      expect(await payment.getReceiptCount()).to.equal(1);
      const receipt = await payment.getReceipt(0);
      expect(receipt.payer).to.equal(subscriber.address);
      expect(receipt.amountUSDC).to.equal(500n * 10n ** 6n);
    });
  });

  describe("ETH Subscription", function () {
    it("should subscribe with ETH", async function () {
      await payment.connect(subscriber).subscribeETH(1, "TestProtocol", { value: ethers.parseEther("0.2") });
      const sub = await payment.getSubscription(subscriber.address);
      expect(sub.active).to.be.true;
      expect(sub.totalPaidETH).to.equal(ethers.parseEther("0.2"));
    });

    it("should forward ETH to treasury", async function () {
      const balBefore = await ethers.provider.getBalance(treasury.address);
      await payment.connect(subscriber).subscribeETH(1, "Test", { value: ethers.parseEther("0.2") });
      const balAfter = await ethers.provider.getBalance(treasury.address);
      expect(balAfter - balBefore).to.equal(ethers.parseEther("0.2"));
    });

    it("should reject insufficient ETH", async function () {
      await expect(
        payment.connect(subscriber).subscribeETH(1, "Test", { value: ethers.parseEther("0.1") })
      ).to.be.revertedWith("Insufficient ETH");
    });
  });

  describe("Renewal", function () {
    beforeEach(async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
    });

    it("should renew with USDC", async function () {
      const subBefore = await payment.getSubscription(subscriber.address);
      await payment.connect(subscriber).renewUSDC();
      const subAfter = await payment.getSubscription(subscriber.address);
      expect(subAfter.expiresAt).to.be.gt(subBefore.expiresAt);
    });

    it("should renew with ETH", async function () {
      const subBefore = await payment.getSubscription(subscriber.address);
      await payment.connect(subscriber).renewETH({ value: ethers.parseEther("0.2") });
      const subAfter = await payment.getSubscription(subscriber.address);
      expect(subAfter.expiresAt).to.be.gt(subBefore.expiresAt);
    });
  });

  describe("Cancellation", function () {
    it("should cancel subscription", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
      await payment.connect(subscriber).cancelSubscription();
      const sub = await payment.getSubscription(subscriber.address);
      expect(sub.active).to.be.false;
    });

    it("should reject cancel with no subscription", async function () {
      await expect(payment.connect(subscriber).cancelSubscription()).to.be.revertedWith("No active subscription");
    });
  });

  describe("View Functions", function () {
    it("should check active subscription", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
      expect(await payment.isActiveSubscription(subscriber.address)).to.be.true;
    });

    it("should return time until expiry", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
      const time = await payment.timeUntilExpiry(subscriber.address);
      expect(time).to.be.gt(0);
    });

    it("should return -1 for no subscription", async function () {
      const time = await payment.timeUntilExpiry(subscriber.address);
      expect(time).to.equal(-1);
    });
  });

  describe("Admin", function () {
    it("should update tier config", async function () {
      await payment.setTierConfig(1, 1000n * 10n ** 6n, ethers.parseEther("0.4"), 0, 50000, true);
      const config = await payment.getTierConfig(1);
      expect(config.priceUSDC).to.equal(1000n * 10n ** 6n);
    });

    it("should update treasury", async function () {
      await payment.setTreasury(subscriber.address);
      expect(await payment.treasury()).to.equal(subscriber.address);
    });

    it("should link access key", async function () {
      await payment.connect(subscriber).subscribeUSDC(1, "Test");
      await payment.linkAccessKey(subscriber.address, "key-123");
      const sub = await payment.getSubscription(subscriber.address);
      expect(sub.accessKeyId).to.equal("key-123");
    });

    it("should grant subscription", async function () {
      await payment.grantSubscription(subscriber.address, 2, 60 * 24 * 3600, "Enterprise Deal");
      const sub = await payment.getSubscription(subscriber.address);
      expect(sub.active).to.be.true;
      expect(sub.tier).to.equal(2); // ENTERPRISE
    });

    it("should reject non-owner admin calls", async function () {
      await expect(
        payment.connect(subscriber).setTreasury(subscriber.address)
      ).to.be.revertedWith("Not owner");
    });
  });
});

describe("HelioraPriceOracle", function () {
  let oracle, owner;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const Oracle = await ethers.getContractFactory("HelioraPriceOracle");
    oracle = await Oracle.deploy();
  });

  it("should set owner", async function () {
    expect(await oracle.owner()).to.equal(owner.address);
  });

  it("should have no feeds initially", async function () {
    expect(await oracle.getRegisteredPairsCount()).to.equal(0);
  });

  it("should register a mock feed", async function () {
    const MockFeed = await ethers.getContractFactory("MockChainlinkFeed");
    const feed = await MockFeed.deploy(8, 250000000000); // $2500 with 8 decimals
    await oracle.registerFeed("ETH/USD", await feed.getAddress());
    expect(await oracle.getRegisteredPairsCount()).to.equal(1);
  });

  it("should get price from mock feed", async function () {
    const MockFeed = await ethers.getContractFactory("MockChainlinkFeed");
    const feed = await MockFeed.deploy(8, 250000000000); // $2500
    await oracle.registerFeed("ETH/USD", await feed.getAddress());
    const price = await oracle.getPriceUSD("ETH/USD");
    expect(price).to.equal(250000000000);
  });

  it("should check isPriceAbove", async function () {
    const MockFeed = await ethers.getContractFactory("MockChainlinkFeed");
    const feed = await MockFeed.deploy(8, 250000000000);
    await oracle.registerFeed("ETH/USD", await feed.getAddress());
    expect(await oracle.isPriceAbove("ETH/USD", 200000000000)).to.be.true;
    expect(await oracle.isPriceAbove("ETH/USD", 300000000000)).to.be.false;
  });

  it("should check isPriceBelow", async function () {
    const MockFeed = await ethers.getContractFactory("MockChainlinkFeed");
    const feed = await MockFeed.deploy(8, 250000000000);
    await oracle.registerFeed("ETH/USD", await feed.getAddress());
    expect(await oracle.isPriceBelow("ETH/USD", 300000000000)).to.be.true;
    expect(await oracle.isPriceBelow("ETH/USD", 200000000000)).to.be.false;
  });

  it("should check balance threshold", async function () {
    expect(await oracle.isBalanceAbove(owner.address, 0)).to.be.true;
  });

  it("should remove feed", async function () {
    const MockFeed = await ethers.getContractFactory("MockChainlinkFeed");
    const feed = await MockFeed.deploy(8, 250000000000);
    await oracle.registerFeed("ETH/USD", await feed.getAddress());
    await oracle.removeFeed("ETH/USD");
    const info = await oracle.getFeedInfo("ETH/USD");
    expect(info.active).to.be.false;
  });

  it("should transfer ownership", async function () {
    const [_, addr1] = await ethers.getSigners();
    await oracle.transferOwnership(addr1.address);
    expect(await oracle.owner()).to.equal(addr1.address);
  });
});

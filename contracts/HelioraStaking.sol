// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelioraStaking
 * @notice Staking and slashing for Heliora executors and condition registrants
 * @dev Executors stake ETH as collateral. Slashed for invalid/missed executions.
 *      Condition registrants stake 0.01 ETH per condition as economic guarantee.
 */
contract HelioraStaking {
    address public owner;
    address public slasher; // Address authorized to slash (HelioraInterface or governance)

    uint256 public minExecutorStake = 0.1 ether;
    uint256 public conditionStake = 0.01 ether;

    bool private _locked;

    // --- Executor Stakes ---
    struct ExecutorStake {
        uint256 amount;
        uint256 stakedAt;
        uint256 slashedAmount;
        bool active;
        uint256 executionCount;
        uint256 missedCount;
    }

    mapping(address => ExecutorStake) public executorStakes;
    address[] public executors;
    mapping(address => bool) public isExecutor;

    // --- Condition Stakes ---
    struct ConditionStakeInfo {
        address owner;
        uint256 conditionId;
        uint256 amount;
        uint256 stakedAt;
        bool released;
    }

    mapping(uint256 => ConditionStakeInfo) public conditionStakes; // conditionId => stake
    mapping(address => uint256[]) public userConditions;

    // --- Slash Records ---
    struct SlashRecord {
        address executor;
        uint256 amount;
        string reason;
        uint256 timestamp;
        uint256 conditionId;
    }

    SlashRecord[] public slashHistory;

    // --- Events ---
    event ExecutorStaked(address indexed executor, uint256 amount);
    event ExecutorUnstaked(address indexed executor, uint256 amount);
    event ExecutorSlashed(address indexed executor, uint256 amount, string reason);
    event ConditionStaked(address indexed owner, uint256 indexed conditionId, uint256 amount);
    event ConditionStakeReleased(address indexed owner, uint256 indexed conditionId, uint256 amount);
    event ConditionStakeSlashed(uint256 indexed conditionId, uint256 amount, string reason);
    event SlasherUpdated(address newSlasher);
    event MinStakeUpdated(uint256 newMinStake);
    event ConditionStakeUpdated(uint256 newConditionStake);
    event OwnershipTransferred(address indexed prev, address indexed next_);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlySlasher() {
        require(msg.sender == slasher || msg.sender == owner, "Not slasher");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _slasher) {
        require(_slasher != address(0), "Invalid slasher");
        owner = msg.sender;
        slasher = _slasher;
    }

    // =========================================================================
    // EXECUTOR STAKING
    // =========================================================================

    function stakeAsExecutor() external payable {
        require(msg.value >= minExecutorStake, "Below minimum stake");

        ExecutorStake storage stake = executorStakes[msg.sender];
        stake.amount += msg.value;
        stake.stakedAt = block.timestamp;
        stake.active = true;

        if (!isExecutor[msg.sender]) {
            executors.push(msg.sender);
            isExecutor[msg.sender] = true;
        }

        emit ExecutorStaked(msg.sender, msg.value);
    }

    function unstakeExecutor() external nonReentrant {
        ExecutorStake storage stake = executorStakes[msg.sender];
        require(stake.active, "Not staked");
        require(stake.amount > 0, "Nothing to unstake");

        uint256 amount = stake.amount;
        stake.amount = 0;
        stake.active = false;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Transfer failed");

        emit ExecutorUnstaked(msg.sender, amount);
    }

    function slashExecutor(
        address _executor,
        uint256 _amount,
        string calldata _reason,
        uint256 _conditionId
    ) external onlySlasher nonReentrant {
        ExecutorStake storage stake = executorStakes[_executor];
        require(stake.active, "Executor not staked");
        
        uint256 slashAmount = _amount > stake.amount ? stake.amount : _amount;
        stake.amount -= slashAmount;
        stake.slashedAmount += slashAmount;
        stake.missedCount++;

        if (stake.amount < minExecutorStake) {
            stake.active = false;
        }

        // Send slashed amount to treasury (owner)
        (bool sent, ) = owner.call{value: slashAmount}("");
        require(sent, "Slash transfer failed");

        slashHistory.push(SlashRecord({
            executor: _executor,
            amount: slashAmount,
            reason: _reason,
            timestamp: block.timestamp,
            conditionId: _conditionId
        }));

        emit ExecutorSlashed(_executor, slashAmount, _reason);
    }

    function recordExecution(address _executor) external onlySlasher {
        executorStakes[_executor].executionCount++;
    }

    // =========================================================================
    // CONDITION STAKING
    // =========================================================================

    function stakeForCondition(uint256 _conditionId) external payable {
        require(msg.value >= conditionStake, "Below condition stake");
        require(conditionStakes[_conditionId].owner == address(0), "Already staked");

        conditionStakes[_conditionId] = ConditionStakeInfo({
            owner: msg.sender,
            conditionId: _conditionId,
            amount: msg.value,
            stakedAt: block.timestamp,
            released: false
        });

        userConditions[msg.sender].push(_conditionId);

        emit ConditionStaked(msg.sender, _conditionId, msg.value);
    }

    function releaseConditionStake(uint256 _conditionId) external nonReentrant {
        ConditionStakeInfo storage info = conditionStakes[_conditionId];
        require(info.owner == msg.sender || msg.sender == owner, "Not authorized");
        require(!info.released, "Already released");
        require(info.amount > 0, "No stake");

        info.released = true;
        uint256 amount = info.amount;

        (bool sent, ) = info.owner.call{value: amount}("");
        require(sent, "Transfer failed");

        emit ConditionStakeReleased(info.owner, _conditionId, amount);
    }

    function slashConditionStake(
        uint256 _conditionId,
        string calldata _reason
    ) external onlySlasher nonReentrant {
        ConditionStakeInfo storage info = conditionStakes[_conditionId];
        require(!info.released, "Already released");
        require(info.amount > 0, "No stake");

        info.released = true;
        uint256 amount = info.amount;

        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Slash transfer failed");

        emit ConditionStakeSlashed(_conditionId, amount, _reason);
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function getExecutorStake(address _executor) external view returns (ExecutorStake memory) {
        return executorStakes[_executor];
    }

    function getExecutorCount() external view returns (uint256) {
        return executors.length;
    }

    function getActiveExecutors() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < executors.length; i++) {
            if (executorStakes[executors[i]].active) count++;
        }
        address[] memory active = new address[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < executors.length; i++) {
            if (executorStakes[executors[i]].active) {
                active[j++] = executors[i];
            }
        }
        return active;
    }

    function getConditionStake(uint256 _conditionId) external view returns (ConditionStakeInfo memory) {
        return conditionStakes[_conditionId];
    }

    function getUserConditions(address _user) external view returns (uint256[] memory) {
        return userConditions[_user];
    }

    function getSlashHistory() external view returns (SlashRecord[] memory) {
        return slashHistory;
    }

    function getTotalStaked() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < executors.length; i++) {
            total += executorStakes[executors[i]].amount;
        }
        return total;
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    function setSlasher(address _slasher) external onlyOwner {
        slasher = _slasher;
        emit SlasherUpdated(_slasher);
    }

    function setMinExecutorStake(uint256 _minStake) external onlyOwner {
        minExecutorStake = _minStake;
        emit MinStakeUpdated(_minStake);
    }

    function setConditionStake(uint256 _conditionStake) external onlyOwner {
        conditionStake = _conditionStake;
        emit ConditionStakeUpdated(_conditionStake);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    receive() external payable {}
}

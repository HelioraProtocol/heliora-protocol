// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ConditionRegistry
 * @notice On-chain registry of all execution conditions with verification
 * @dev Stores condition metadata, tracks execution history, provides
 *      challenge/verification infrastructure for optimistic execution.
 */
contract ConditionRegistry {
    address public owner;
    address public executor; // HelioraExecutor address

    // --- Condition Types ---
    enum ConditionType { BLOCK_NUMBER, TIMESTAMP, PRICE_ABOVE, PRICE_BELOW, BALANCE_THRESHOLD }
    enum ConditionStatus { REGISTERED, ACTIVE, EXECUTED, CANCELLED, CHALLENGED, SLASHED }

    struct Condition {
        uint256 id;
        address registrant;
        ConditionType conditionType;
        uint256 conditionValue;
        address targetContract;
        bytes4 targetFunction;
        bool repeatable;
        ConditionStatus status;
        uint256 createdAt;
        uint256 activatedAt;
        uint256 executedAt;
        uint256 executionBlock;
        address executedBy;
        bytes32 executionTxHash;
        uint256 challengeDeadline; // Block until which execution can be challenged
    }

    // --- Storage ---
    mapping(uint256 => Condition) public conditions;
    mapping(address => uint256[]) public registrantConditions;
    uint256 public nextConditionId = 1;
    uint256 public totalRegistered;
    uint256 public totalExecuted;
    uint256 public totalCancelled;

    // Challenge period in blocks (~10 min on Base at 2s/block)
    uint256 public challengePeriod = 300;

    // --- Execution Proofs ---
    struct ExecutionProof {
        uint256 conditionId;
        address executor;
        uint256 blockNumber;
        uint256 timestamp;
        bytes32 txHash;
        bool challenged;
        bool valid; // Set after challenge resolution
    }

    mapping(uint256 => ExecutionProof) public executionProofs;

    // --- Events ---
    event ConditionRegistered(uint256 indexed id, address indexed registrant, ConditionType conditionType, uint256 value);
    event ConditionActivated(uint256 indexed id);
    event ConditionExecuted(uint256 indexed id, address indexed executor, uint256 blockNumber);
    event ConditionCancelled(uint256 indexed id);
    event ConditionChallenged(uint256 indexed id, address indexed challenger);
    event ChallengeResolved(uint256 indexed id, bool valid);
    event ExecutorUpdated(address newExecutor);
    event ChallengePeriodUpdated(uint256 newPeriod);
    event OwnershipTransferred(address indexed prev, address indexed next_);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == executor || msg.sender == owner, "Not executor");
        _;
    }

    constructor(address _executor) {
        owner = msg.sender;
        executor = _executor;
    }

    // =========================================================================
    // REGISTRATION
    // =========================================================================

    function registerCondition(
        ConditionType _type,
        uint256 _value,
        address _targetContract,
        bytes4 _targetFunction,
        bool _repeatable
    ) external returns (uint256) {
        require(_targetContract != address(0), "Invalid target");
        require(_value > 0, "Invalid value");

        uint256 id = nextConditionId++;
        conditions[id] = Condition({
            id: id,
            registrant: msg.sender,
            conditionType: _type,
            conditionValue: _value,
            targetContract: _targetContract,
            targetFunction: _targetFunction,
            repeatable: _repeatable,
            status: ConditionStatus.REGISTERED,
            createdAt: block.timestamp,
            activatedAt: 0,
            executedAt: 0,
            executionBlock: 0,
            executedBy: address(0),
            executionTxHash: bytes32(0),
            challengeDeadline: 0
        });

        registrantConditions[msg.sender].push(id);
        totalRegistered++;

        emit ConditionRegistered(id, msg.sender, _type, _value);
        return id;
    }

    function activateCondition(uint256 _id) external {
        Condition storage c = conditions[_id];
        require(c.registrant == msg.sender, "Not registrant");
        require(c.status == ConditionStatus.REGISTERED, "Not registered");

        c.status = ConditionStatus.ACTIVE;
        c.activatedAt = block.timestamp;

        emit ConditionActivated(_id);
    }

    function cancelCondition(uint256 _id) external {
        Condition storage c = conditions[_id];
        require(c.registrant == msg.sender || msg.sender == owner, "Not authorized");
        require(
            c.status == ConditionStatus.REGISTERED || c.status == ConditionStatus.ACTIVE,
            "Cannot cancel"
        );

        c.status = ConditionStatus.CANCELLED;
        totalCancelled++;

        emit ConditionCancelled(_id);
    }

    // =========================================================================
    // EXECUTION RECORDING
    // =========================================================================

    function recordExecution(
        uint256 _id,
        bytes32 _txHash
    ) external onlyExecutor {
        Condition storage c = conditions[_id];
        require(c.status == ConditionStatus.ACTIVE, "Not active");

        c.status = ConditionStatus.EXECUTED;
        c.executedAt = block.timestamp;
        c.executionBlock = block.number;
        c.executedBy = msg.sender;
        c.executionTxHash = _txHash;
        c.challengeDeadline = block.number + challengePeriod;

        executionProofs[_id] = ExecutionProof({
            conditionId: _id,
            executor: msg.sender,
            blockNumber: block.number,
            timestamp: block.timestamp,
            txHash: _txHash,
            challenged: false,
            valid: true // Assumed valid until challenged
        });

        totalExecuted++;

        // If repeatable, reactivate
        if (c.repeatable) {
            c.status = ConditionStatus.ACTIVE;
        }

        emit ConditionExecuted(_id, msg.sender, block.number);
    }

    // =========================================================================
    // CHALLENGE MECHANISM
    // =========================================================================

    function challengeExecution(uint256 _id) external {
        Condition storage c = conditions[_id];
        ExecutionProof storage proof = executionProofs[_id];

        require(proof.blockNumber > 0, "No execution proof");
        require(!proof.challenged, "Already challenged");
        require(block.number <= c.challengeDeadline, "Challenge period expired");

        proof.challenged = true;

        emit ConditionChallenged(_id, msg.sender);
    }

    function resolveChallenge(uint256 _id, bool _valid) external onlyOwner {
        ExecutionProof storage proof = executionProofs[_id];
        require(proof.challenged, "Not challenged");

        proof.valid = _valid;

        if (!_valid) {
            conditions[_id].status = ConditionStatus.SLASHED;
        }

        emit ChallengeResolved(_id, _valid);
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function getCondition(uint256 _id) external view returns (Condition memory) {
        return conditions[_id];
    }

    function getRegistrantConditions(address _registrant) external view returns (uint256[] memory) {
        return registrantConditions[_registrant];
    }

    function getExecutionProof(uint256 _id) external view returns (ExecutionProof memory) {
        return executionProofs[_id];
    }

    function isConditionReady(uint256 _id) external view returns (bool) {
        Condition memory c = conditions[_id];
        if (c.status != ConditionStatus.ACTIVE) return false;

        if (c.conditionType == ConditionType.BLOCK_NUMBER) {
            return block.number >= c.conditionValue;
        } else if (c.conditionType == ConditionType.TIMESTAMP) {
            return block.timestamp >= c.conditionValue;
        }
        // PRICE_ABOVE, PRICE_BELOW, BALANCE_THRESHOLD need oracle - checked off-chain
        return false;
    }

    function getStats() external view returns (
        uint256 registered,
        uint256 executed,
        uint256 cancelled,
        uint256 active
    ) {
        return (totalRegistered, totalExecuted, totalCancelled, totalRegistered - totalExecuted - totalCancelled);
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    function setExecutor(address _executor) external onlyOwner {
        executor = _executor;
        emit ExecutorUpdated(_executor);
    }

    function setChallengePeriod(uint256 _period) external onlyOwner {
        challengePeriod = _period;
        emit ChallengePeriodUpdated(_period);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

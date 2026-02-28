// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelioraInterface
 * @notice Interface for integrating Heliora Protocol into your smart contracts
 * @dev This contract allows protocols to register execution conditions with Heliora
 *      and manage execution jobs on-chain. Integration requires ~100-200 lines of Solidity.
 */
interface IHelioraExecutor {
    function execute(
        uint256 conditionId,
        address targetContract,
        bytes4 targetFunction,
        bytes calldata callData
    ) external payable;
}

contract HelioraInterface {
    // Heliora executor contract address
    address public immutable helioraExecutor;
    
    // Authorized executors (for permissioned model)
    mapping(address => bool) public authorizedExecutors;
    
    // Owner (can add/remove executors)
    address public owner;
    
    // Execution fee (optional, can be 0)
    uint256 public executionFee;
    
    // Execution window (blocks) - protection against front-running
    // Condition can only be executed within this window after condition is met
    uint256 public constant EXECUTION_WINDOW = 100; // ~20 minutes on Base
    
    // Condition registry
    struct Condition {
        uint256 conditionId;
        address protocol;
        ConditionType conditionType;
        uint256 conditionValue;
        address targetContract;
        bytes4 targetFunction;
        ExecutionMode executionMode;
        ConditionStatus status;
        uint256 createdAt;
        uint256 lastExecutedAt;
        uint256 executionWindowEnd; // Block/timestamp when execution window ends
    }
    
    enum ConditionType {
        BLOCK_NUMBER,
        TIMESTAMP
    }
    
    enum ExecutionMode {
        SINGLE,
        REPEATABLE
    }
    
    enum ConditionStatus {
        PENDING,
        ACTIVE,
        EXECUTED,
        CANCELLED
    }
    
    // Events
    event ConditionRegistered(
        uint256 indexed conditionId,
        address indexed protocol,
        ConditionType conditionType,
        uint256 conditionValue,
        address targetContract,
        bytes4 targetFunction
    );
    
    event ConditionActivated(uint256 indexed conditionId);
    event ConditionExecuted(
        uint256 indexed conditionId, 
        uint256 blockNumber,
        address executor,
        uint256 feePaid
    );
    event ConditionCancelled(uint256 indexed conditionId);
    event ExecutorAuthorized(address indexed executor);
    event ExecutorRevoked(address indexed executor);
    event ExecutionFeeUpdated(uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Storage
    mapping(uint256 => Condition) public conditions;
    mapping(address => uint256[]) public protocolConditions;
    uint256 private nextConditionId = 1;
    
    // Modifiers
    modifier onlyProtocol(uint256 conditionId) {
        require(conditions[conditionId].protocol == msg.sender, "Not condition owner");
        _;
    }
    
    modifier validCondition(uint256 conditionId) {
        require(conditions[conditionId].conditionId != 0, "Condition not found");
        _;
    }
    
    modifier onlyExecutor() {
        require(
            msg.sender == helioraExecutor || authorizedExecutors[msg.sender],
            "Not authorized executor"
        );
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _helioraExecutor) {
        require(_helioraExecutor != address(0), "Invalid executor address");
        helioraExecutor = _helioraExecutor;
        owner = msg.sender;
        authorizedExecutors[_helioraExecutor] = true; // Main executor is authorized by default
        executionFee = 0; // Default: no fee (can be set by owner)
    }
    
    /**
     * @notice Register a new execution condition
     * @param conditionType Type of condition (BLOCK_NUMBER or TIMESTAMP)
     * @param conditionValue Value that triggers execution
     * @param targetContract Contract address to call when condition is met
     * @param targetFunction Function selector to call
     * @param executionMode SINGLE (execute once) or REPEATABLE
     * @return conditionId The registered condition ID
     */
    function registerCondition(
        ConditionType conditionType,
        uint256 conditionValue,
        address targetContract,
        bytes4 targetFunction,
        ExecutionMode executionMode
    ) external returns (uint256) {
        require(targetContract != address(0), "Invalid target contract");
        require(conditionValue > 0, "Invalid condition value");
        
        // Validate condition value based on type
        if (conditionType == ConditionType.BLOCK_NUMBER) {
            require(conditionValue > block.number, "Block must be in future");
        } else if (conditionType == ConditionType.TIMESTAMP) {
            require(conditionValue > block.timestamp, "Timestamp must be in future");
        }
        
        uint256 conditionId = nextConditionId++;
        
        // Calculate execution window end
        uint256 windowEnd = 0;
        if (conditionType == ConditionType.BLOCK_NUMBER) {
            windowEnd = conditionValue + EXECUTION_WINDOW;
        } else {
            // For timestamp, convert window to seconds (assuming ~2s per block)
            windowEnd = conditionValue + (EXECUTION_WINDOW * 2);
        }
        
        conditions[conditionId] = Condition({
            conditionId: conditionId,
            protocol: msg.sender,
            conditionType: conditionType,
            conditionValue: conditionValue,
            targetContract: targetContract,
            targetFunction: targetFunction,
            executionMode: executionMode,
            status: ConditionStatus.PENDING,
            createdAt: block.timestamp,
            lastExecutedAt: 0,
            executionWindowEnd: windowEnd
        });
        
        protocolConditions[msg.sender].push(conditionId);
        
        emit ConditionRegistered(
            conditionId,
            msg.sender,
            conditionType,
            conditionValue,
            targetContract,
            targetFunction
        );
        
        return conditionId;
    }
    
    /**
     * @notice Activate a registered condition
     * @param conditionId The condition ID to activate
     */
    function activateCondition(uint256 conditionId) 
        external 
        onlyProtocol(conditionId) 
        validCondition(conditionId) 
    {
        require(
            conditions[conditionId].status == ConditionStatus.PENDING,
            "Condition not pending"
        );
        
        conditions[conditionId].status = ConditionStatus.ACTIVE;
        emit ConditionActivated(conditionId);
    }
    
    /**
     * @notice Cancel a condition
     * @param conditionId The condition ID to cancel
     */
    function cancelCondition(uint256 conditionId) 
        external 
        onlyProtocol(conditionId) 
        validCondition(conditionId) 
    {
        require(
            conditions[conditionId].status == ConditionStatus.ACTIVE ||
            conditions[conditionId].status == ConditionStatus.PENDING,
            "Cannot cancel executed condition"
        );
        
        conditions[conditionId].status = ConditionStatus.CANCELLED;
        emit ConditionCancelled(conditionId);
    }
    
    /**
     * @notice Execute a condition (called by authorized Heliora executor)
     * @param conditionId The condition ID to execute
     * @param callData Additional call data for the target function
     * @dev Requires: only authorized executor, condition active, condition met, within execution window
     * @dev Payment: msg.value must cover executionFee (if set)
     */
    function executeCondition(uint256 conditionId, bytes calldata callData) 
        external 
        payable
        validCondition(conditionId)
        onlyExecutor
    {
        Condition storage condition = conditions[conditionId];
        
        require(
            condition.status == ConditionStatus.ACTIVE,
            "Condition not active"
        );
        
        // Verify condition is met
        bool conditionMet = false;
        if (condition.conditionType == ConditionType.BLOCK_NUMBER) {
            conditionMet = block.number >= condition.conditionValue;
        } else if (condition.conditionType == ConditionType.TIMESTAMP) {
            conditionMet = block.timestamp >= condition.conditionValue;
        }
        
        require(conditionMet, "Condition not met");
        
        // Verify execution window (protection against front-running)
        bool withinWindow = false;
        if (condition.conditionType == ConditionType.BLOCK_NUMBER) {
            withinWindow = block.number <= condition.executionWindowEnd;
        } else {
            withinWindow = block.timestamp <= condition.executionWindowEnd;
        }
        
        require(withinWindow, "Execution window expired");
        
        // Verify fee payment (if executionFee > 0)
        require(msg.value >= executionFee, "Insufficient execution fee");
        
        // Forward payment to executor (executor can keep the fee)
        uint256 feeToForward = msg.value;
        
        // Execute via Heliora executor with payment
        IHelioraExecutor(helioraExecutor).execute{value: feeToForward}(
            conditionId,
            condition.targetContract,
            condition.targetFunction,
            callData
        );
        
        condition.lastExecutedAt = block.timestamp;
        
        // Update status based on execution mode
        if (condition.executionMode == ExecutionMode.SINGLE) {
            condition.status = ConditionStatus.EXECUTED;
        }
        // REPEATABLE conditions remain ACTIVE
        
        emit ConditionExecuted(conditionId, block.number, msg.sender, feeToForward);
    }
    
    /**
     * @notice Get condition details
     * @param conditionId The condition ID
     * @return condition The condition struct
     */
    function getCondition(uint256 conditionId) 
        external 
        view 
        validCondition(conditionId) 
        returns (Condition memory) 
    {
        return conditions[conditionId];
    }
    
    /**
     * @notice Get all conditions for a protocol
     * @param protocol The protocol address
     * @return conditionIds Array of condition IDs
     */
    function getProtocolConditions(address protocol) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return protocolConditions[protocol];
    }
    
    /**
     * @notice Check if a condition is ready for execution
     * @param conditionId The condition ID
     * @return ready True if condition is met and ready for execution
     */
    function isConditionReady(uint256 conditionId) 
        external 
        view 
        validCondition(conditionId) 
        returns (bool ready) 
    {
        Condition memory condition = conditions[conditionId];
        
        if (condition.status != ConditionStatus.ACTIVE) {
            return false;
        }
        
        if (condition.conditionType == ConditionType.BLOCK_NUMBER) {
            return block.number >= condition.conditionValue;
        } else if (condition.conditionType == ConditionType.TIMESTAMP) {
            return block.timestamp >= condition.conditionValue;
        }
        
        return false;
    }
    
    /**
     * @notice Owner functions: Manage authorized executors
     */
    
    /**
     * @notice Authorize an executor address
     * @param executor The executor address to authorize
     */
    function authorizeExecutor(address executor) external onlyOwner {
        require(executor != address(0), "Invalid executor");
        authorizedExecutors[executor] = true;
        emit ExecutorAuthorized(executor);
    }
    
    /**
     * @notice Revoke executor authorization
     * @param executor The executor address to revoke
     */
    function revokeExecutor(address executor) external onlyOwner {
        require(executor != helioraExecutor, "Cannot revoke main executor");
        authorizedExecutors[executor] = false;
        emit ExecutorRevoked(executor);
    }
    
    /**
     * @notice Set execution fee (can be 0 for no fee)
     * @param _executionFee The new execution fee in wei
     */
    function setExecutionFee(uint256 _executionFee) external onlyOwner {
        executionFee = _executionFee;
        emit ExecutionFeeUpdated(_executionFee);
    }
    
    /**
     * @notice Transfer ownership
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    /**
     * @notice Withdraw accumulated fees (if any)
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        (bool sent, ) = owner.call{value: balance}("");
        require(sent, "Withdraw failed");
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelioraRouter
 * @notice Central router connecting all Heliora Protocol contracts
 * @dev Manages contract addresses, access control, and cross-contract calls.
 *      Single entry point for protocol interactions.
 */
contract HelioraRouter {
    address public owner;

    // --- Protocol Contracts ---
    address public executor;         // HelioraExecutor
    address public helioraInterface; // HelioraInterface
    address public payment;          // HelioraPayment
    address public staking;          // HelioraStaking
    address public conditionRegistry;// ConditionRegistry
    address public priceOracle;      // HelioraPriceOracle

    // --- Protocol State ---
    bool public paused;
    uint256 public protocolVersion = 2;

    // --- Authorized Operators ---
    mapping(address => bool) public operators;

    // --- Events ---
    event ContractUpdated(string name, address addr);
    event ProtocolPaused(bool paused);
    event OperatorUpdated(address operator, bool authorized);
    event OwnershipTransferred(address indexed prev, address indexed next_);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Protocol paused");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner, "Not operator");
        _;
    }

    constructor() {
        owner = msg.sender;
        operators[msg.sender] = true;
    }

    // =========================================================================
    // CONTRACT REGISTRY
    // =========================================================================

    function setExecutor(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid");
        executor = _addr;
        emit ContractUpdated("executor", _addr);
    }

    function setHelioraInterface(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid");
        helioraInterface = _addr;
        emit ContractUpdated("helioraInterface", _addr);
    }

    function setPayment(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid");
        payment = _addr;
        emit ContractUpdated("payment", _addr);
    }

    function setStaking(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid");
        staking = _addr;
        emit ContractUpdated("staking", _addr);
    }

    function setConditionRegistry(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid");
        conditionRegistry = _addr;
        emit ContractUpdated("conditionRegistry", _addr);
    }

    function setPriceOracle(address _addr) external onlyOwner {
        require(_addr != address(0), "Invalid");
        priceOracle = _addr;
        emit ContractUpdated("priceOracle", _addr);
    }

    // Batch set all contracts
    function setAllContracts(
        address _executor,
        address _helioraInterface,
        address _payment,
        address _staking,
        address _conditionRegistry,
        address _priceOracle
    ) external onlyOwner {
        if (_executor != address(0)) { executor = _executor; emit ContractUpdated("executor", _executor); }
        if (_helioraInterface != address(0)) { helioraInterface = _helioraInterface; emit ContractUpdated("helioraInterface", _helioraInterface); }
        if (_payment != address(0)) { payment = _payment; emit ContractUpdated("payment", _payment); }
        if (_staking != address(0)) { staking = _staking; emit ContractUpdated("staking", _staking); }
        if (_conditionRegistry != address(0)) { conditionRegistry = _conditionRegistry; emit ContractUpdated("conditionRegistry", _conditionRegistry); }
        if (_priceOracle != address(0)) { priceOracle = _priceOracle; emit ContractUpdated("priceOracle", _priceOracle); }
    }

    // =========================================================================
    // VIEW: Get all contract addresses
    // =========================================================================

    function getContracts() external view returns (
        address _executor,
        address _helioraInterface,
        address _payment,
        address _staking,
        address _conditionRegistry,
        address _priceOracle
    ) {
        return (executor, helioraInterface, payment, staking, conditionRegistry, priceOracle);
    }

    function getContractByName(string calldata _name) external view returns (address) {
        bytes32 h = keccak256(abi.encodePacked(_name));
        if (h == keccak256("executor")) return executor;
        if (h == keccak256("helioraInterface")) return helioraInterface;
        if (h == keccak256("payment")) return payment;
        if (h == keccak256("staking")) return staking;
        if (h == keccak256("conditionRegistry")) return conditionRegistry;
        if (h == keccak256("priceOracle")) return priceOracle;
        return address(0);
    }

    // =========================================================================
    // PROTOCOL CONTROL
    // =========================================================================

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ProtocolPaused(_paused);
    }

    function setOperator(address _operator, bool _authorized) external onlyOwner {
        operators[_operator] = _authorized;
        emit OperatorUpdated(_operator, _authorized);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

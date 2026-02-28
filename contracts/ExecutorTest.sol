// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelioraExecutor
 * @notice Production execution contract for Heliora Protocol
 * @dev Handles real on-chain execution of conditions with arbitrary function calls.
 *      Access-controlled: only authorized callers (HelioraInterface) can trigger execution.
 */
contract HelioraExecutor {
    address public owner;
    mapping(address => bool) public authorizedCallers;

    bool private _locked;

    event Executed(
        uint256 indexed conditionId,
        address indexed targetContract,
        bytes4 targetFunction,
        uint256 blockNumber,
        address executor,
        uint256 timestamp,
        bool success
    );

    event ExecutionFailed(
        uint256 indexed conditionId,
        address indexed targetContract,
        bytes4 targetFunction,
        string reason
    );

    event CallerAuthorized(address indexed caller);
    event CallerRevoked(address indexed caller);
    event OwnershipTransferred(address indexed prev, address indexed next_);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor() {
        owner = msg.sender;
        authorizedCallers[msg.sender] = true;
    }

    /**
     * @notice Execute a condition by calling a function on a target contract
     * @param conditionId The condition identifier
     * @param targetContract The contract address to call
     * @param targetFunction The function selector to call (first 4 bytes of function signature)
     * @param callData Additional call data for the function
     * @dev This function performs a real on-chain call to the target contract
     */
    function execute(
        uint256 conditionId,
        address targetContract,
        bytes4 targetFunction,
        bytes calldata callData
    ) external payable onlyAuthorized nonReentrant {
        require(targetContract != address(0), "Invalid target");

        // Construct full call data
        bytes memory fullCallData = abi.encodePacked(targetFunction, callData);
        
        // Perform the call
        (bool success, bytes memory returnData) = targetContract.call{value: msg.value}(fullCallData);
        
        if (success) {
            emit Executed(
                conditionId,
                targetContract,
                targetFunction,
                block.number,
                msg.sender,
                block.timestamp,
                true
            );
        } else {
            // Extract revert reason safely
            string memory reason = _extractRevertReason(returnData);

            emit ExecutionFailed(
                conditionId,
                targetContract,
                targetFunction,
                reason
            );
            
            revert(reason);
        }
    }

    /**
     * @notice Simple execute for backward compatibility (emits event only)
     * @param conditionId The condition identifier
     */
    function executeSimple(uint256 conditionId) external payable onlyAuthorized {
        emit Executed(
            conditionId,
            address(0),
            bytes4(0),
            block.number,
            msg.sender,
            block.timestamp,
            true
        );
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    function authorizeCaller(address _caller) external onlyOwner {
        require(_caller != address(0), "Invalid address");
        authorizedCallers[_caller] = true;
        emit CallerAuthorized(_caller);
    }

    function revokeCaller(address _caller) external onlyOwner {
        authorizedCallers[_caller] = false;
        emit CallerRevoked(_caller);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    /**
     * @notice Get contract version
     * @return version string
     */
    function version() external pure returns (string memory) {
        return "2.1.0-production";
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _extractRevertReason(bytes memory returnData) internal pure returns (string memory) {
        if (returnData.length < 68) return "Execution failed";

        // Check for standard Error(string) selector: 0x08c379a0
        bytes4 selector;
        assembly {
            selector := mload(add(returnData, 0x20))
        }
        if (selector != 0x08c379a0) return "Execution failed";

        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    receive() external payable {}
}


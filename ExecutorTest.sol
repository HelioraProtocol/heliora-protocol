// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ExecutorTest
 * @notice Minimal test contract for on-chain execution verification
 * @dev Simple contract that emits events when executed, demonstrating
 *      that Heliora execution layer can trigger real on-chain transactions.
 */
contract ExecutorTest {
    event Executed(
        uint256 indexed conditionId,
        uint256 blockNumber,
        address executor,
        uint256 timestamp
    );

    /**
     * @notice Execute a condition - emits event to verify on-chain execution
     * @param conditionId The condition identifier being executed
     * @dev This is a minimal implementation for MVP demonstration.
     *      In production, this would include condition verification,
     *      stake management, and challenge mechanisms.
     */
    function execute(uint256 conditionId) external payable {
        // Emit event to prove execution happened on-chain
        emit Executed(
            conditionId,
            block.number,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @notice Get contract version
     * @return version string
     */
    function version() external pure returns (string memory) {
        return "1.0.0-mvp";
    }
}


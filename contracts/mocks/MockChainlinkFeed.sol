// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockChainlinkFeed {
    uint8 private _decimals;
    int256 private _price;

    constructor(uint8 dec, int256 price) {
        _decimals = dec;
        _price = price;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock Feed";
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, _price, block.timestamp, block.timestamp, 1);
    }

    function setPrice(int256 price) external {
        _price = price;
    }
}

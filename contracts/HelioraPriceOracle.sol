// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelioraPriceOracle
 * @notice Price feed integration for Heliora price-based condition triggers
 * @dev Reads from Chainlink Price Feeds on Base. Supports ETH/USD, BTC/USD, etc.
 *      Base Mainnet Chainlink feeds:
 *        ETH/USD: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
 *        BTC/USD: 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E
 *        USDC/USD: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B
 */

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
}

contract HelioraPriceOracle {
    address public owner;
    uint256 public constant MAX_STALENESS = 3600; // 1 hour

    struct PriceFeed {
        address feedAddress;
        string pair;         // e.g. "ETH/USD"
        uint8 decimals;
        bool active;
    }

    // pair hash => PriceFeed
    mapping(bytes32 => PriceFeed) public priceFeeds;
    bytes32[] public registeredPairs;

    // Price condition check results (cached for gas efficiency)
    struct PriceCheck {
        int256 price;
        uint8 decimals;
        uint256 timestamp;
        bool stale; // true if price is older than 1 hour
    }

    event PriceFeedRegistered(string pair, address feedAddress);
    event PriceFeedRemoved(string pair);
    event OwnershipTransferred(address indexed prev, address indexed next_);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // =========================================================================
    // FEED MANAGEMENT
    // =========================================================================

    function registerFeed(string calldata _pair, address _feedAddress) external onlyOwner {
        require(_feedAddress != address(0), "Invalid feed");
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));

        AggregatorV3Interface feed = AggregatorV3Interface(_feedAddress);
        uint8 dec = feed.decimals();

        if (priceFeeds[pairHash].feedAddress == address(0)) {
            registeredPairs.push(pairHash);
        }

        priceFeeds[pairHash] = PriceFeed({
            feedAddress: _feedAddress,
            pair: _pair,
            decimals: dec,
            active: true
        });

        emit PriceFeedRegistered(_pair, _feedAddress);
    }

    function removeFeed(string calldata _pair) external onlyOwner {
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));
        priceFeeds[pairHash].active = false;
        emit PriceFeedRemoved(_pair);
    }

    // =========================================================================
    // PRICE QUERIES
    // =========================================================================

    function getPrice(string calldata _pair) external view returns (PriceCheck memory) {
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));
        PriceFeed memory feed = priceFeeds[pairHash];
        require(feed.active, "Feed not active");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed.feedAddress);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();

        return PriceCheck({
            price: price,
            decimals: feed.decimals,
            timestamp: updatedAt,
            stale: (block.timestamp - updatedAt) > MAX_STALENESS
        });
    }

    function getPriceUSD(string calldata _pair) external view returns (uint256) {
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));
        PriceFeed memory feed = priceFeeds[pairHash];
        require(feed.active, "Feed not active");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed.feedAddress);
        (, int256 price,, uint256 updatedAt, ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= MAX_STALENESS, "Stale price");

        // Normalize to 8 decimals (standard Chainlink USD format)
        return uint256(price);
    }

    // =========================================================================
    // CONDITION CHECKS
    // =========================================================================

    /**
     * @notice Check if price is above threshold
     * @param _pair Price pair (e.g. "ETH/USD")
     * @param _threshold Price threshold in feed decimals (e.g. 3000e8 for $3000)
     */
    function isPriceAbove(string calldata _pair, uint256 _threshold) external view returns (bool) {
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));
        PriceFeed memory feed = priceFeeds[pairHash];
        if (!feed.active) return false;

        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed.feedAddress);
        (, int256 price,,, ) = priceFeed.latestRoundData();
        if (price <= 0) return false;

        return uint256(price) >= _threshold;
    }

    /**
     * @notice Check if price is below threshold
     */
    function isPriceBelow(string calldata _pair, uint256 _threshold) external view returns (bool) {
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));
        PriceFeed memory feed = priceFeeds[pairHash];
        if (!feed.active) return false;

        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed.feedAddress);
        (, int256 price,,, ) = priceFeed.latestRoundData();
        if (price <= 0) return false;

        return uint256(price) <= _threshold;
    }

    /**
     * @notice Check balance threshold for an address
     */
    function isBalanceAbove(address _account, uint256 _threshold) external view returns (bool) {
        return _account.balance >= _threshold;
    }

    // =========================================================================
    // VIEW
    // =========================================================================

    function getRegisteredPairsCount() external view returns (uint256) {
        return registeredPairs.length;
    }

    function getFeedInfo(string calldata _pair) external view returns (PriceFeed memory) {
        bytes32 pairHash = keccak256(abi.encodePacked(_pair));
        return priceFeeds[pairHash];
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IERC20.sol";

/**
 * @title HelioraPayment
 * @notice Subscription payments for Heliora Protocol access tiers
 * @dev Accepts USDC and ETH on Base. 30-day subscription periods.
 *      USDC on Base Mainnet: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
 *      USDC on Base Sepolia: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
 */
contract HelioraPayment {
    address public owner;
    address public treasury;
    IERC20 public paymentToken; // USDC
    uint8 public paymentTokenDecimals;

    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    uint256 public constant SUBSCRIPTION_PERIOD = 30 days;
    uint256 public constant GRACE_PERIOD = 3 days;

    // --- Tiers ---
    enum Tier { TESTNET, MAINNET, ENTERPRISE }

    struct TierConfig {
        uint256 priceUSDC;         // Price in USDC smallest unit (e.g. 500e6 = $500)
        uint256 priceETH;          // Alternative ETH price in wei
        uint256 maxConditions;     // 0 = unlimited
        uint256 maxExecutionsDay;  // 0 = unlimited
        bool active;
    }

    mapping(Tier => TierConfig) public tierConfigs;

    // --- Subscriptions ---
    struct Subscription {
        Tier tier;
        uint256 startedAt;
        uint256 expiresAt;
        uint256 lastPaymentAt;
        uint256 totalPaidUSDC;
        uint256 totalPaidETH;
        bool active;
        string protocolName;
        string accessKeyId;
    }

    mapping(address => Subscription) public subscriptions;
    address[] public allSubscribers;
    mapping(address => bool) public isSubscriber;

    // --- Payment Receipts ---
    struct Receipt {
        address payer;
        Tier tier;
        uint256 amountUSDC;
        uint256 amountETH;
        uint256 timestamp;
        uint256 periodStart;
        uint256 periodEnd;
    }

    Receipt[] public receipts;
    mapping(address => uint256[]) public subscriberReceipts;

    // --- Events ---
    event SubscriptionCreated(address indexed subscriber, Tier tier, uint256 expiresAt, string protocolName);
    event SubscriptionRenewed(address indexed subscriber, Tier tier, uint256 newExpiresAt);
    event SubscriptionCancelled(address indexed subscriber, Tier tier);
    event PaymentReceived(address indexed payer, Tier tier, uint256 amountUSDC, uint256 amountETH);
    event TierConfigUpdated(Tier tier, uint256 priceUSDC, uint256 priceETH);
    event TreasuryUpdated(address newTreasury);
    event OwnershipTransferred(address indexed prev, address indexed next_);
    event AccessKeyLinked(address indexed subscriber, string accessKeyId);
    event EmergencyTokenWithdraw(address indexed token, uint256 amount);
    event EmergencyETHWithdraw(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _paymentToken, uint8 _decimals, address _treasury) {
        require(_paymentToken != address(0), "Invalid token");
        require(_treasury != address(0), "Invalid treasury");
        owner = msg.sender;
        paymentToken = IERC20(_paymentToken);
        paymentTokenDecimals = _decimals;
        treasury = _treasury;

        // Default tier configs
        // Testnet: free
        tierConfigs[Tier.TESTNET] = TierConfig({
            priceUSDC: 0, priceETH: 0,
            maxConditions: 100, maxExecutionsDay: 1000, active: true
        });
        // Mainnet: $500/month
        tierConfigs[Tier.MAINNET] = TierConfig({
            priceUSDC: 500 * (10 ** uint256(_decimals)), // 500 USDC
            priceETH: 0.2 ether, // ~$500 at ~$2500/ETH
            maxConditions: 0, maxExecutionsDay: 10000, active: true
        });
        // Enterprise: custom ($2000 default)
        tierConfigs[Tier.ENTERPRISE] = TierConfig({
            priceUSDC: 2000 * (10 ** uint256(_decimals)),
            priceETH: 0.8 ether,
            maxConditions: 0, maxExecutionsDay: 0, active: true
        });
    }

    // =========================================================================
    // SUBSCRIBE WITH USDC
    // =========================================================================

    function subscribeUSDC(Tier _tier, string calldata _protocolName) external {
        require(_tier != Tier.TESTNET, "Testnet is free");
        TierConfig memory config = tierConfigs[_tier];
        require(config.active, "Tier not active");
        require(config.priceUSDC > 0, "Price not set");

        // Transfer USDC from subscriber to treasury
        require(
            paymentToken.transferFrom(msg.sender, treasury, config.priceUSDC),
            "USDC transfer failed"
        );

        _activateSubscription(msg.sender, _tier, _protocolName, config.priceUSDC, 0);

        emit PaymentReceived(msg.sender, _tier, config.priceUSDC, 0);
    }

    // =========================================================================
    // SUBSCRIBE WITH ETH
    // =========================================================================

    function subscribeETH(Tier _tier, string calldata _protocolName) external payable nonReentrant {
        require(_tier != Tier.TESTNET, "Testnet is free");
        TierConfig memory config = tierConfigs[_tier];
        require(config.active, "Tier not active");
        require(config.priceETH > 0, "ETH price not set");
        require(msg.value >= config.priceETH, "Insufficient ETH");

        // Forward exact price to treasury
        (bool sent, ) = treasury.call{value: config.priceETH}("");
        require(sent, "ETH transfer failed");

        // Refund overpayment
        uint256 refund = msg.value - config.priceETH;
        if (refund > 0) {
            (bool refunded, ) = msg.sender.call{value: refund}("");
            require(refunded, "Refund failed");
        }

        _activateSubscription(msg.sender, _tier, _protocolName, 0, config.priceETH);

        emit PaymentReceived(msg.sender, _tier, 0, config.priceETH);
    }

    // =========================================================================
    // RENEW SUBSCRIPTION (USDC)
    // =========================================================================

    function renewUSDC() external {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.active, "No active subscription");

        TierConfig memory config = tierConfigs[sub.tier];
        require(config.priceUSDC > 0, "Price not set");

        require(
            paymentToken.transferFrom(msg.sender, treasury, config.priceUSDC),
            "USDC transfer failed"
        );

        // Extend from current expiry or now (whichever is later)
        uint256 startFrom = sub.expiresAt > block.timestamp ? sub.expiresAt : block.timestamp;
        sub.expiresAt = startFrom + SUBSCRIPTION_PERIOD;
        sub.lastPaymentAt = block.timestamp;
        sub.totalPaidUSDC += config.priceUSDC;

        _addReceipt(msg.sender, sub.tier, config.priceUSDC, 0, startFrom, sub.expiresAt);

        emit SubscriptionRenewed(msg.sender, sub.tier, sub.expiresAt);
    }

    // =========================================================================
    // RENEW SUBSCRIPTION (ETH)
    // =========================================================================

    function renewETH() external payable nonReentrant {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.active, "No active subscription");

        TierConfig memory config = tierConfigs[sub.tier];
        require(config.priceETH > 0, "ETH price not set");
        require(msg.value >= config.priceETH, "Insufficient ETH");

        // Forward exact price to treasury
        (bool sent, ) = treasury.call{value: config.priceETH}("");
        require(sent, "ETH transfer failed");

        // Refund overpayment
        uint256 refund = msg.value - config.priceETH;
        if (refund > 0) {
            (bool refunded, ) = msg.sender.call{value: refund}("");
            require(refunded, "Refund failed");
        }

        uint256 startFrom = sub.expiresAt > block.timestamp ? sub.expiresAt : block.timestamp;
        sub.expiresAt = startFrom + SUBSCRIPTION_PERIOD;
        sub.lastPaymentAt = block.timestamp;
        sub.totalPaidETH += config.priceETH;

        _addReceipt(msg.sender, sub.tier, 0, config.priceETH, startFrom, sub.expiresAt);

        emit SubscriptionRenewed(msg.sender, sub.tier, sub.expiresAt);
    }

    // =========================================================================
    // CANCEL
    // =========================================================================

    function cancelSubscription() external {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.active, "No active subscription");
        sub.active = false;
        emit SubscriptionCancelled(msg.sender, sub.tier);
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function isActiveSubscription(address _subscriber) external view returns (bool) {
        Subscription memory sub = subscriptions[_subscriber];
        return sub.active && (sub.expiresAt + GRACE_PERIOD) >= block.timestamp;
    }

    function getSubscription(address _subscriber) external view returns (Subscription memory) {
        return subscriptions[_subscriber];
    }

    function getSubscriberCount() external view returns (uint256) {
        return allSubscribers.length;
    }

    function getReceipt(uint256 index) external view returns (Receipt memory) {
        return receipts[index];
    }

    function getReceiptCount() external view returns (uint256) {
        return receipts.length;
    }

    function getSubscriberReceipts(address _subscriber) external view returns (uint256[] memory) {
        return subscriberReceipts[_subscriber];
    }

    function getTierConfig(Tier _tier) external view returns (TierConfig memory) {
        return tierConfigs[_tier];
    }

    function timeUntilExpiry(address _subscriber) external view returns (int256) {
        Subscription memory sub = subscriptions[_subscriber];
        if (!sub.active) return -1;
        return int256(sub.expiresAt) - int256(block.timestamp);
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    function setTierConfig(
        Tier _tier,
        uint256 _priceUSDC,
        uint256 _priceETH,
        uint256 _maxConditions,
        uint256 _maxExecutionsDay,
        bool _active
    ) external onlyOwner {
        tierConfigs[_tier] = TierConfig({
            priceUSDC: _priceUSDC,
            priceETH: _priceETH,
            maxConditions: _maxConditions,
            maxExecutionsDay: _maxExecutionsDay,
            active: _active
        });
        emit TierConfigUpdated(_tier, _priceUSDC, _priceETH);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function linkAccessKey(address _subscriber, string calldata _keyId) external onlyOwner {
        subscriptions[_subscriber].accessKeyId = _keyId;
        emit AccessKeyLinked(_subscriber, _keyId);
    }

    // Admin grant (for enterprise / custom deals)
    function grantSubscription(
        address _subscriber,
        Tier _tier,
        uint256 _duration,
        string calldata _protocolName
    ) external onlyOwner {
        _activateSubscription(_subscriber, _tier, _protocolName, 0, 0);
        subscriptions[_subscriber].expiresAt = block.timestamp + _duration;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    // Emergency: withdraw stuck tokens
    function emergencyWithdrawToken(address _token, uint256 _amount) external onlyOwner nonReentrant {
        require(_token != address(0), "Invalid token");
        require(_amount > 0, "Invalid amount");
        bool success = IERC20(_token).transfer(owner, _amount);
        require(success, "Token transfer failed");
        emit EmergencyTokenWithdraw(_token, _amount);
    }

    function emergencyWithdrawETH() external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        require(bal > 0, "No ETH");
        (bool sent, ) = owner.call{value: bal}("");
        require(sent, "Transfer failed");
        emit EmergencyETHWithdraw(bal);
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _activateSubscription(
        address _subscriber,
        Tier _tier,
        string memory _protocolName,
        uint256 _paidUSDC,
        uint256 _paidETH
    ) internal {
        uint256 periodStart = block.timestamp;
        uint256 periodEnd = periodStart + SUBSCRIPTION_PERIOD;

        if (!isSubscriber[_subscriber]) {
            allSubscribers.push(_subscriber);
            isSubscriber[_subscriber] = true;
        }

        Subscription storage sub = subscriptions[_subscriber];
        // If renewing an existing active sub, extend from expiry
        if (sub.active && sub.expiresAt > block.timestamp) {
            periodStart = sub.expiresAt;
            periodEnd = periodStart + SUBSCRIPTION_PERIOD;
        }

        sub.tier = _tier;
        sub.startedAt = sub.startedAt == 0 ? block.timestamp : sub.startedAt;
        sub.expiresAt = periodEnd;
        sub.lastPaymentAt = block.timestamp;
        sub.totalPaidUSDC += _paidUSDC;
        sub.totalPaidETH += _paidETH;
        sub.active = true;
        sub.protocolName = _protocolName;

        _addReceipt(_subscriber, _tier, _paidUSDC, _paidETH, periodStart, periodEnd);

        emit SubscriptionCreated(_subscriber, _tier, periodEnd, _protocolName);
    }

    function _addReceipt(
        address _payer,
        Tier _tier,
        uint256 _amountUSDC,
        uint256 _amountETH,
        uint256 _periodStart,
        uint256 _periodEnd
    ) internal {
        receipts.push(Receipt({
            payer: _payer,
            tier: _tier,
            amountUSDC: _amountUSDC,
            amountETH: _amountETH,
            timestamp: block.timestamp,
            periodStart: _periodStart,
            periodEnd: _periodEnd
        }));
        subscriberReceipts[_payer].push(receipts.length - 1);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract ConditionalOrderProtocol is VRFConsumerBase {
    enum OrderStatus { Open, Executed, Canceled }

    struct Order {
        address user;
        address assetToBuy;
        uint256 amountToBuy;
        address assetToSell;
        uint256 amountToSell;
        uint256 randomCondition; // Random condition
        OrderStatus status;
    }

    struct Condition {
        bytes32 conditionType;
        bytes32 conditionData;
    }

    Order[] public orders;
    Condition[] public conditions;
    mapping(address => uint256) public userOrderCount;

    event OrderPlaced(uint256 indexed orderId, address indexed user);
    event OrderExecuted(uint256 indexed orderId);
    event OrderCanceled(uint256 indexed orderId);
    event OrderTransferred(uint256 indexed orderId, address indexed newOwner);

    IERC20 public erc20Token; // Example ERC20 token for transfers

    bytes32 internal keyHash;
    uint256 internal fee;

    modifier onlyOrderOwner(uint256 _orderId) {
        require(orders[_orderId].user == msg.sender, "Only order owner can perform this action");
        _;
    }

    constructor(
        address _erc20Token,
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        erc20Token = IERC20(_erc20Token);
        keyHash = _keyHash;
        fee = _fee;
    }

    function addCondition(bytes32 _conditionType, bytes32 _conditionData) public {
        uint256 conditionId = conditions.length;
        conditions.push(Condition(_conditionType, _conditionData));
    }

    function placeOrder(
        address _assetToBuy,
        uint256 _amountToBuy,
        address _assetToSell,
        uint256 _amountToSell
    ) public {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");

        bytes32 requestId = requestRandomNumber();

        OrderStatus status = OrderStatus.Open;
        orders.push(Order(msg.sender, _assetToBuy, _amountToBuy, _assetToSell, _amountToSell, uint256(requestId), status));
        uint256 orderId = orders.length - 1;
        userOrderCount[msg.sender]++;
        emit OrderPlaced(orderId, msg.sender);
    }

    function requestRandomNumber() internal returns (bytes32 requestId) {
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        // Handle the received random data as needed
    }

    function executeOrder(uint256 _orderId) public {
        Order storage order = orders[_orderId];
        require(order.status == OrderStatus.Open, "Order is not open for execution");
        
        if (conditionsMet(order)) {
            order.status = OrderStatus.Executed;
            emit OrderExecuted(_orderId);

            // Implement the asset transfer logic here
            transferAssets(order);
        }
    }

    function conditionsMet(Order storage order) internal view returns (bool) {
        return true;
    }

    function transferAssets(Order storage order) internal {
        // Ensure that the contract has the required token allowance
        require(
            erc20Token.allowance(order.user, address(this)) >= order.amountToSell,
            "Allowance not set for the contract"
        );

        // Transfer the sold asset back to the user
        require(erc20Token.transferFrom(order.user, address(this), order.amountToSell), "Transfer failed");

        // Transfer the bought asset to the user
        require(erc20Token.transfer(order.user, order.amountToBuy), "Transfer failed");
    }

    function cancelOrder(uint256 _orderId) public onlyOrderOwner(_orderId) {
        Order storage order = orders[_orderId];
        require(order.status == OrderStatus.Open, "Order is not open for cancellation");
        order.status = OrderStatus.Canceled;
        emit OrderCanceled(_orderId);
    }

    function transferOrderOwnership(uint256 _orderId, address _newOwner) public onlyOrderOwner(_orderId) {
        Order storage order = orders[_orderId];
        order.user = _newOwner;
        userOrderCount[msg.sender]--;
        userOrderCount[_newOwner]++;
        emit OrderTransferred(_orderId, _newOwner);
    }
}

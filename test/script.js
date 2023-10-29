
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ConditionalOrderProtocol', function () {
  let protocol;
  let linkToken;
  let vrfCoordinator;
  const keyHash = 'YOUR_KEY_HASH'; // Replace with your Chainlink VRF key hash
  const fee = 100000000000000000; // Replace with the appropriate fee amount

  beforeEach(async () => {
    const protocol = await ethers.deployContract('LinkToken','VRFCoordinatorMock','ConditionalOrderProtocol');

  });

  it('Should place an order with random condition', async function () {
    const assetToBuy = '0xAssetToBuy';
    const amountToBuy = 10;
    const assetToSell = '0xAssetToSell';
    const amountToSell = 5;

    await linkToken.transfer(protocol.address, fee); // Fund the protocol with LINK tokens

    const placeOrderTx = await protocol.placeOrder(assetToBuy, amountToBuy, assetToSell, amountToSell);
    const receipt = await placeOrderTx.wait();

    const requestId = receipt.events[0].args.requestId;
    expect(requestId).to.not.be.empty;

    const order = await protocol.orders(0);
    expect(order.user).to.equal(await ethers.provider.getSigner(0).getAddress());
    expect(order.assetToBuy).to.equal(assetToBuy);
    expect(order.amountToBuy).to.equal(amountToBuy);
    expect(order.assetToSell).to.equal(assetToSell);
    expect(order.amountToSell).to.equal(amountToSell);
    expect(order.randomCondition).to.equal(requestId);

    const orderCount = await protocol.getOrderCount();
    expect(orderCount).to.equal(1);
  });

  it('Should execute an order with random condition', async function () {
    // Fund the protocol with LINK tokens
    await linkToken.transfer(protocol.address, fee);

    // Place an order with a random condition
    await protocol.placeOrder('0xAssetToBuy', 10, '0xAssetToSell', 5);

    const order = await protocol.orders(0);

    // Request randomness and fulfill it (simulate Chainlink VRF response)
    const requestId = order.randomCondition;
    const randomness = 12345; // Replace with a real random number
    await vrfCoordinator.callBackWithRandomness(requestId, randomness, protocol.address);

    // Execute the order
    await protocol.executeOrder(0);

    // Check that the order is executed (you can add more detailed checks)
    const updatedOrder = await protocol.orders(0);
    expect(updatedOrder.status).to.equal(1); // OrderStatus.Executed
  });
});

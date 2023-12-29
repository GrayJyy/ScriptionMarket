// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMscMarketV1} from "../../script/DeployMscMarketV1.s.sol";
import {MscMarketV1} from "../../src/MscMarketV1.sol";
import {SigUtils} from "../utils/SigUtils.sol";

contract MscMarketV1Test is Test {
    HelperConfig public helperConfig;
    MscMarketV1 public mscMarketV1;
    uint256 public deployerKey;
    address public adminAddress;
    uint96 public feeBps;
    uint256 public STARTING_BALANCE_100ether = 100 ether;
    uint256 public MOCK_ORDER_NUMBER_1 = 1;
    uint256 public MOCK_ORDER_PRICE_100ether = 100 ether;
    uint256 public MOCK_ORDER_PRICE_10ether = 10 ether;
    uint256 public MOCK_ORDER_AMOUNT_100 = 100;
    string public MOCK_TICK = "MSCMOCK";
    SigUtils internal sigUtils;

    event mxcscriptions_protocol_TransferMSC20Token(
        address indexed from, address indexed buyer, uint256 indexed number, uint256 amount
    );

    constructor() {}

    modifier mockBalance() {
        if (block.chainid == 31337) {
            vm.deal(address(mscMarketV1), STARTING_BALANCE_100ether);
        }
        _;
    }

    modifier skipTest() {
        if (block.chainid == 31337) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
        _;
    }

    function setUp() external {
        DeployMscMarketV1 deployer = new DeployMscMarketV1();
        (mscMarketV1, helperConfig) = deployer.run();
        (deployerKey, adminAddress, feeBps) = helperConfig.activeNetworkConfig();
        sigUtils = new SigUtils(mscMarketV1.getDomainSeparator());
    }

    function testInitialize_ShouldGetsCorrectly_WhenItIsRuns() public {
        assertEq(adminAddress, mscMarketV1.owner());
        assertEq(adminAddress, mscMarketV1.getAdminAddress());
        assertEq(feeBps, mscMarketV1.getFeeBps());
        assertEq(true, mscMarketV1.getFeatureStatus("list"));
        assertEq(true, mscMarketV1.getFeatureStatus("buy"));
        assertEq(true, mscMarketV1.getFeatureStatus("withdraw"));
    }

    function testGetVersion_ShouldReturnsOne_WhenItIsWorks() public {
        uint256 expectedVersion = 1;
        uint256 realVersion = mscMarketV1.getVersion();
        assertEq(expectedVersion, realVersion);
    }

    function testGetFeatureStatus_ShouldReturnsTrue_WhenItIsWorks() public {
        bool expectedStatus = true;
        bool realStatus1 = mscMarketV1.getFeatureStatus("list");
        bool realStatus2 = mscMarketV1.getFeatureStatus("buy");
        bool realStatus3 = mscMarketV1.getFeatureStatus("withdraw");
        assertEq(expectedStatus, realStatus1);
        assertEq(expectedStatus, realStatus2);
        assertEq(expectedStatus, realStatus3);
    }

    function testGetFeeBps_ShouldReturnsTwo_WhenItIsWorks() public {
        uint96 realFeeBps = mscMarketV1.getFeeBps();
        assertEq(feeBps, realFeeBps);
    }

    function testGetAdminAddress_ShouldReturnsAdmin_WhenItIsWorks() public {
        assertEq(adminAddress, mscMarketV1.getAdminAddress());
    }

    function testComputeFee_ShouldReturnsFee_WhenHasPrice() public {
        uint256 price = 100;
        uint256 expectedFee = 100 * 2 / 100;
        uint256 realFee = price * uint256(feeBps) / 100;
        assertEq(expectedFee, realFee);
    }

    function testSetFeeBps_ShouldSetsCorrectly_WhenItIsWorks() public {
        vm.startPrank(adminAddress);
        mscMarketV1.setFeeBps(4);
        vm.stopPrank();
        assertEq(mscMarketV1.getFeeBps(), 4);
    }

    function testSetAdminAddress_ShouldSetsCorrectly_WhenItIsWorks() public {
        vm.startPrank(adminAddress);
        address expectedAdmin = 0xF42f4b5cb102b3f5A180E08E6BA726c0179D172E;
        mscMarketV1.setAdminAddress(expectedAdmin);
        vm.stopPrank();
        assertEq(mscMarketV1.getAdminAddress(), expectedAdmin);
    }

    function testSetFeatureStatus_ShouldSetsCorrectly_WhenItIsWorks() public {
        vm.startPrank(adminAddress);
        mscMarketV1.setFeatureStatus("list", false);
        mscMarketV1.setFeatureStatus("buy", false);
        mscMarketV1.setFeatureStatus("withdraw", false);
        vm.stopPrank();
        assertEq(mscMarketV1.getFeatureStatus("list"), false);
        assertEq(mscMarketV1.getFeatureStatus("buy"), false);
        assertEq(mscMarketV1.getFeatureStatus("withdraw"), false);
    }

    function testSetAllFeatuteStatus_ShouldSetsCorrectly_WhenItIsWorks() public {
        vm.startPrank(adminAddress);
        mscMarketV1.setAllFeatuteStatus(false);
        vm.stopPrank();
        assertEq(mscMarketV1.getFeatureStatus("list"), false);
        assertEq(mscMarketV1.getFeatureStatus("buy"), false);
        assertEq(mscMarketV1.getFeatureStatus("withdraw"), false);
    }

    function testMscWithdraw_ShouldReverts_WhenFeatureIsNotEnabled() public {
        vm.startPrank(adminAddress);
        mscMarketV1.setFeatureStatus("withdraw", false);
        vm.expectRevert(abi.encodeWithSelector(MscMarketV1.MscMarketV1__FeatureDisabled.selector, "withdraw"));
        mscMarketV1.mscWithdraw();
        vm.stopPrank();
    }

    function testMscWithdraw_ShouldBeCorrectly_WhenItIsWorks() public mockBalance skipTest {
        assertEq(adminAddress.balance, 0);
        assertEq(address(mscMarketV1).balance, STARTING_BALANCE_100ether);
        vm.startPrank(adminAddress);
        mscMarketV1.mscWithdraw();
        vm.stopPrank();
        assertEq(adminAddress.balance, STARTING_BALANCE_100ether);
        assertEq(address(mscMarketV1).balance, 0);
    }

    function testMscPurchase_ShouldReverts_WhenFeatureIsNotEnabled() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        vm.startPrank(adminAddress);
        mscMarketV1.setFeatureStatus("buy", false);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        vm.expectRevert(abi.encodeWithSelector(MscMarketV1.MscMarketV1__FeatureDisabled.selector, "buy"));
        mscMarketV1.mscPurchase(marketStorage, mockSignature);
        vm.stopPrank();
    }

    function testMscPruchase_ShouldReverts_WhenUnderpayment() public payable {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        address _buyer = vm.addr(2);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_100ether,
            tick: MOCK_TICK
        });
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        vm.expectRevert(MscMarketV1.MscMarketV1__PurchaseFailed.selector);
        mscMarketV1.mscPurchase{value: MOCK_ORDER_PRICE_10ether}(marketStorage, mockSignature);
        vm.stopPrank();
    }

    function testMscPurchase_ShouldReverts_WhenSignatureIsNotVerifled() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        (address _invalidSeller,) = makeAddrAndKey("invalidSeller");
        address _buyer = vm.addr(2);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _invalidSeller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        vm.expectRevert(MscMarketV1.MscMarketV1__InvalidSignature.selector);
        mscMarketV1.mscPurchase{value: MOCK_ORDER_PRICE_100ether}(marketStorage, mockSignature);
        vm.stopPrank();
    }

    function testGetDomainSeparator_ShouldReturnsCorrectly_WhenItIsWorks() public skipTest {
        bytes32 expectedDomainSeparator = 0x2d2d34366329a7c78c810eb9536e470c980b8190046919b344021384aef9dde0;
        bytes32 realDomainSeparator = mscMarketV1.getDomainSeparator(); // 0x2d2d34366329a7c78c810eb9536e470c980b8190046919b344021384aef9dde0
        assertEq(realDomainSeparator, expectedDomainSeparator);
    }

    function testMscPurchase_ShouldEmits_WhenItIsWorks() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        (address _buyer,) = makeAddrAndKey("buyer");
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        vm.expectEmit(true, true, true, false);
        emit mxcscriptions_protocol_TransferMSC20Token(_seller, _buyer, MOCK_ORDER_NUMBER_1, MOCK_ORDER_AMOUNT_100);
        mscMarketV1.mscPurchase{value: STARTING_BALANCE_100ether}(marketStorage, mockSignature);
        vm.stopPrank();
    }

    function testMscPurchase_Shouldreverts_WhenOrderIsProcessing() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        (address _buyer,) = makeAddrAndKey("buyer");
        (address _buyer2,) = makeAddrAndKey("buyer2");
        console.log(block.timestamp);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        vm.expectEmit(true, true, true, false);
        emit mxcscriptions_protocol_TransferMSC20Token(_seller, _buyer, MOCK_ORDER_NUMBER_1, MOCK_ORDER_AMOUNT_100);
        mscMarketV1.mscPurchase{value: STARTING_BALANCE_100ether}(marketStorage, mockSignature);
        vm.stopPrank();
        vm.deal(_buyer2, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer2);
        vm.expectRevert(MscMarketV1.MscMarketV1__OrderIsProcessing.selector);
        mscMarketV1.mscPurchase{value: STARTING_BALANCE_100ether}(marketStorage, mockSignature);
        vm.stopPrank();
    }

    function testMscBatchPurchase_ShouldReverts_WhenFeatureIsNotEnabled() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        vm.startPrank(adminAddress);
        mscMarketV1.setFeatureStatus("buy", false);
        MscMarketV1.MarketStorage[] memory marketStorages = new MscMarketV1.MarketStorage[](1);
        bytes[] memory signatures = new bytes[](1);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        marketStorages[0] = marketStorage;
        signatures[0] = mockSignature;
        vm.expectRevert(abi.encodeWithSelector(MscMarketV1.MscMarketV1__FeatureDisabled.selector, "buy"));
        mscMarketV1.mscBatchPurchase(marketStorages, signatures, 100);
        vm.stopPrank();
    }

    function testMscBatchPurchase_ShouldReverts_WhenUnderpayment() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        address _buyer = vm.addr(2);
        MscMarketV1.MarketStorage[] memory marketStorages = new MscMarketV1.MarketStorage[](1);
        bytes[] memory signatures = new bytes[](1);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_100ether,
            tick: MOCK_TICK
        });
        marketStorages[0] = marketStorage;
        signatures[0] = mockSignature;
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        vm.expectRevert(MscMarketV1.MscMarketV1__PurchaseFailed.selector);
        mscMarketV1.mscBatchPurchase{value: MOCK_ORDER_PRICE_10ether}(
            marketStorages, signatures, MOCK_ORDER_PRICE_100ether
        );
        vm.stopPrank();
    }

    function testMscBatchPurchase_ShouldRecerts_WhenLengthNotEqual() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        address _buyer = vm.addr(2);
        MscMarketV1.MarketStorage[] memory marketStorages = new MscMarketV1.MarketStorage[](1);
        bytes[] memory signatures = new bytes[](2);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_100ether,
            tick: MOCK_TICK
        });
        marketStorages[0] = marketStorage;
        signatures[0] = mockSignature;
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        vm.expectRevert(MscMarketV1.MscMarketV1__LengthNotEqual.selector);
        mscMarketV1.mscBatchPurchase{value: MOCK_ORDER_PRICE_10ether}(
            marketStorages, signatures, MOCK_ORDER_PRICE_10ether
        );
        vm.stopPrank();
    }

    function testMscBatchPurchase_ShouldSetsOrderStatusCorrectly_WhenItIsWorks() public {
        (address _seller, uint256 _sellerKey) = makeAddrAndKey("seller");
        (address _invalidSeller,) = makeAddrAndKey("invalidSeller");
        bytes memory mockSignature = sigUtils.mockSignature(_seller, _sellerKey);
        address _buyer = vm.addr(2);
        MscMarketV1.MarketStorage[] memory marketStorages = new MscMarketV1.MarketStorage[](3);
        bytes[] memory signatures = new bytes[](3);
        MscMarketV1.MarketStorage memory marketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _seller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        MscMarketV1.MarketStorage memory invalidMarketStorage = MscMarketV1.MarketStorage({
            number: MOCK_ORDER_NUMBER_1,
            maker: _invalidSeller,
            time: block.timestamp,
            amount: MOCK_ORDER_AMOUNT_100,
            price: MOCK_ORDER_PRICE_10ether,
            tick: MOCK_TICK
        });
        marketStorages[0] = marketStorage;
        marketStorages[1] = marketStorage;
        marketStorages[2] = invalidMarketStorage;
        signatures[0] = mockSignature;
        signatures[1] = mockSignature;
        signatures[2] = mockSignature;
        vm.deal(_buyer, STARTING_BALANCE_100ether);
        vm.startPrank(_buyer);
        mscMarketV1.mscBatchPurchase{value: MOCK_ORDER_PRICE_100ether}(
            marketStorages, signatures, MOCK_ORDER_PRICE_10ether
        );
        vm.stopPrank();
        assert(mscMarketV1.getOrderStatus(_seller, MOCK_ORDER_NUMBER_1) == MscMarketV1.OrderStatus.Sold);
        assert(mscMarketV1.getOrderStatus(_invalidSeller, MOCK_ORDER_NUMBER_1) == MscMarketV1.OrderStatus.Listing);
    }

    function testGetOrderStatus_ShouldGetsCorrectly_WhenItConfigured() public view {
        address _seller = vm.addr(1);
        assert(mscMarketV1.getOrderStatus(_seller, MOCK_ORDER_NUMBER_1) == MscMarketV1.OrderStatus.Listing);
    }
}

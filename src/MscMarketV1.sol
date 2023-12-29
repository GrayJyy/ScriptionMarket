// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract MscMarketV1 is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    UUPSUpgradeable
{
    error MscMarketV1__FeatureDisabled(string featurePoint);
    error MscMarketV1__PurchaseFailed();
    error MscMarketV1__WithdrawFailed();
    error MscMarketV1__InvalidSignature();
    error MscMarketV1__LengthNotEqual();
    error MscMarketV1__NotFailureOrder();
    error MscMarketV1__OrderIsProcessing();

    using ECDSA for bytes32;

    enum OrderStatus {
        Listing,
        Canceled,
        Sold
    }

    struct MarketStorage {
        uint256 number;
        address maker;
        uint256 time;
        uint256 amount;
        uint256 price;
        string tick;
    }

    uint96 private s_feeBps;
    address private s_adminAddress;
    mapping(string featurePoint => bool isEnabled) private s_featureIsEnabled;
    mapping(address seller => uint256 amount) private s_failureOrder;
    mapping(address seller => mapping(uint256 number => OrderStatus)) private s_processing;

    event mxcscriptions_protocol_TransferMSC20Token(
        address indexed from, address indexed buyer, uint256 indexed number, uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() {
        _disableInitializers();
    }

    function initialize(address adminAddress, uint96 feeBps) public initializer {
        __Ownable_init(adminAddress);
        __EIP712_init("MscMarketV1", "1.0");
        s_adminAddress = adminAddress;
        s_feeBps = feeBps;
        s_featureIsEnabled["list"] = true;
        s_featureIsEnabled["buy"] = true;
        s_featureIsEnabled["withdraw"] = true;
        __UUPSUpgradeable_init();
    }

    function setAdminAddress(address newAdminAddress) public {
        transferOwnership(newAdminAddress);
        s_adminAddress = newAdminAddress;
    }

    fallback() external payable {}

    receive() external payable {}

    function mscPurchase(MarketStorage calldata marketStorage, bytes calldata signature)
        external
        payable
        nonReentrant
    {
        bytes32 hashedMessage = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("Listing(address maker,uint256 time,uint256 amount,uint256 price,string tick)"),
                    marketStorage.maker,
                    marketStorage.time,
                    marketStorage.amount,
                    marketStorage.price,
                    marketStorage.tick
                )
            )
        );
        if (s_processing[marketStorage.maker][marketStorage.number] != OrderStatus.Listing) {
            revert MscMarketV1__OrderIsProcessing();
        }
        s_processing[marketStorage.maker][marketStorage.number] = OrderStatus.Sold;
        if (!s_featureIsEnabled["buy"]) revert MscMarketV1__FeatureDisabled("buy");
        if (msg.value < marketStorage.price) revert MscMarketV1__PurchaseFailed();
        if (!_verifySign(hashedMessage, signature, marketStorage.maker)) revert MscMarketV1__InvalidSignature();
        (bool success,) = marketStorage.maker.call{value: marketStorage.price - computeFee(marketStorage.price)}("");
        if (!success) revert MscMarketV1__PurchaseFailed();
        emit mxcscriptions_protocol_TransferMSC20Token(
            marketStorage.maker, msg.sender, marketStorage.number, marketStorage.amount
        );
    }

    function mscBatchPurchase(MarketStorage[] calldata marketStorages, bytes[] calldata signatures, uint256 totalPrice)
        external
        payable
        nonReentrant
    {
        if (!s_featureIsEnabled["buy"]) revert MscMarketV1__FeatureDisabled("buy"); // check if buy feature is enabled
        if (msg.value < totalPrice) revert MscMarketV1__PurchaseFailed(); // check the total price
        if (marketStorages.length != signatures.length) revert MscMarketV1__LengthNotEqual(); // check the length
        for (uint256 i = 0; i < marketStorages.length; i++) {
            bytes32 hashedMessage = _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("Listing(address maker,uint256 time,uint256 amount,uint256 price,string tick)"),
                        marketStorages[i].maker,
                        marketStorages[i].time,
                        marketStorages[i].amount,
                        marketStorages[i].price,
                        marketStorages[i].tick
                    )
                )
            );
            if (s_processing[marketStorages[i].maker][marketStorages[i].number] != OrderStatus.Listing) continue;
            if (!_verifySign(hashedMessage, signatures[i], marketStorages[i].maker)) {
                continue;
            }
            s_processing[marketStorages[i].maker][marketStorages[i].number] = OrderStatus.Sold;

            (bool success,) =
                marketStorages[i].maker.call{value: marketStorages[i].price - computeFee(marketStorages[i].price)}("");
            if (!success) {
                // if not suceess, store the failure order
                s_failureOrder[marketStorages[i].maker] = marketStorages[i].price - computeFee(marketStorages[i].price);
            } else {
                // if success,send mxc to seller and emit event
                emit mxcscriptions_protocol_TransferMSC20Token(
                    marketStorages[i].maker, msg.sender, marketStorages[i].number, marketStorages[i].amount
                );
            }
        }
    }

    function manualGetIncome(address seller) public {
        if (s_failureOrder[seller] == 0) revert MscMarketV1__NotFailureOrder();
        (bool success,) = seller.call{value: s_failureOrder[seller]}("");
        if (!success) revert MscMarketV1__PurchaseFailed();
    }

    function mscWithdraw() external onlyOwner {
        if (!s_featureIsEnabled["withdraw"]) revert MscMarketV1__FeatureDisabled("withdraw");
        (bool success,) = s_adminAddress.call{value: address(this).balance}("");
        if (!success) revert MscMarketV1__WithdrawFailed();
    }

    function setFeeBps(uint96 newFeeBps) external onlyOwner {
        s_feeBps = newFeeBps;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setFeatureStatus(string memory feature, bool enabled) public onlyOwner {
        s_featureIsEnabled[feature] = enabled;
    }

    function setAllFeatuteStatus(bool enabled) public onlyOwner {
        s_featureIsEnabled["list"] = enabled;
        s_featureIsEnabled["buy"] = enabled;
        s_featureIsEnabled["withdraw"] = enabled;
    }

    function _verifySign(bytes32 hashedMessage, bytes calldata signature, address signer)
        internal
        pure
        returns (bool isVerified)
    {
        isVerified = hashedMessage.recover(signature) == signer;
    }

    function computeFee(uint256 price) public view returns (uint256 fee) {
        fee = (price * uint256(s_feeBps)) / 100;
    }

    function getAdminAddress() public view returns (address adminAddress) {
        return s_adminAddress;
    }

    function getFeeBps() public view returns (uint96 feeBps) {
        return s_feeBps;
    }

    function getFeatureStatus(string memory feature) public view returns (bool isEnabled) {
        return s_featureIsEnabled[feature];
    }

    function getVersion() public pure returns (uint256 version) {
        version = 1;
    }

    function getDomainSeparator() public view returns (bytes32 domainSeparator) {
        domainSeparator = _domainSeparatorV4();
    }

    function getFailureOrder(address failureAddress) public view returns (uint256 failureAmount) {
        failureAmount = s_failureOrder[failureAddress];
    }

    function getOrderStatus(address processingAddress, uint256 number) public view returns (OrderStatus status) {
        status = s_processing[processingAddress][number];
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

error MscMarketV2Mock__FeatureDisabled(string featurePoint);
error MscMarketV2Mock__PurchaseFailed();
error MscMarketV2Mock__WithdrawFailed();
error MscMarketV2Mock__InvalidSignature();

contract MscMarketV2Mock is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;

    struct MarketStorage {
        bytes32 msccriptionId;
        address from;
        address to;
        uint256 timestamp;
        uint256 amount;
        uint256 totalPrice;
        string ticker;
    }

    uint96 private s_feeBps;
    address private s_adminAddress;
    mapping(string featurePoint => bool isEnabled) private s_featureIsEnabled;

    event mxcscriptions_protocol_TransferMSC20Token(
        address indexed from, address indexed to, string indexed ticker, uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address adminAddress, uint96 feeBps) public initializer {
        __Ownable_init(adminAddress);
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
        if (!s_featureIsEnabled["buy"]) revert MscMarketV2Mock__FeatureDisabled("buy");
        if (msg.value < marketStorage.totalPrice) revert MscMarketV2Mock__PurchaseFailed();
        bytes32 hashedMessage = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "Listing(bytes32 msccriptionId,address from,address to,"
                        "uint256 timestamp,uint256 amount,uint256 totalPrice,string ticker)"
                    ),
                    marketStorage.msccriptionId,
                    marketStorage.from,
                    marketStorage.to,
                    marketStorage.timestamp,
                    marketStorage.amount,
                    marketStorage.totalPrice,
                    marketStorage.ticker
                )
            )
        );
        if (!_verifySign(hashedMessage, signature, marketStorage.from)) revert MscMarketV2Mock__InvalidSignature();
        (bool success,) =
            marketStorage.from.call{value: marketStorage.totalPrice - computeFee(marketStorage.totalPrice)}("");
        if (!success) revert MscMarketV2Mock__PurchaseFailed();
        emit mxcscriptions_protocol_TransferMSC20Token(
            marketStorage.from, marketStorage.to, marketStorage.ticker, marketStorage.amount
        );
    }

    function mscWithdraw() external onlyOwner {
        if (!s_featureIsEnabled["withdraw"]) revert MscMarketV2Mock__FeatureDisabled("withdraw");
        (bool success,) = s_adminAddress.call{value: address(this).balance}("");
        if (!success) revert MscMarketV2Mock__WithdrawFailed();
    }

    function setFeeBps(uint96 newFeeBps) external onlyOwner {
        s_feeBps = newFeeBps;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _setFeatureStatus(string memory feature, bool enabled) internal onlyOwner {
        s_featureIsEnabled[feature] = enabled;
    }

    function _setAllFeatuteStatus(bool enabled) internal onlyOwner {
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
        fee = (price * s_feeBps) / 100;
    }

    function getAdminAddress() public view returns (address adminAddress) {
        return s_adminAddress;
    }

    function getFeeBps() public view returns (uint256 feeBps) {
        return s_feeBps;
    }

    function getFeatureStatus(string memory feature) public view returns (bool isEnabled) {
        return s_featureIsEnabled[feature];
    }

    function getVersion() public pure returns (uint256 version) {
        version = 2;
    }
}

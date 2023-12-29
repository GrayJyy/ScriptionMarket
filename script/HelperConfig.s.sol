// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__ChainIdNotSupported();

    struct NetworkConfig {
        uint256 deployerKey;
        address adminAddress;
        uint96 feeBps;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public DEFAULT_ANVIL_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint96 public DEFAULT_FEE_BPS = 2;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        } else if (block.chainid == 5167003) {
            activeNetworkConfig = getMxcTestNetworkConfig();
        } else if (block.chainid == 18686) {
            activeNetworkConfig = getMxcMainNetworkConfig();
        } else {
            revert HelperConfig__ChainIdNotSupported();
        }
    }

    function getOrCreateAnvilNetworkConfig() internal returns (NetworkConfig memory _anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.deployerKey == DEFAULT_ANVIL_PRIVATE_KEY) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        // deploy the mocks...
        vm.stopBroadcast();

        _anvilNetworkConfig = NetworkConfig({
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY,
            adminAddress: DEFAULT_ANVIL_ADDRESS,
            feeBps: DEFAULT_FEE_BPS
        });
    }

    function getMxcTestNetworkConfig() internal view returns (NetworkConfig memory _mxcTestNetworkConfig) {
        _mxcTestNetworkConfig = NetworkConfig({
            deployerKey: vm.envUint("TESTNETWORK_PRIVATE_KEY"),
            adminAddress: vm.envAddress("TESTNETWORK_ADMIN_ADDRESS"),
            feeBps: DEFAULT_FEE_BPS
        });
    }

    function getMxcMainNetworkConfig() internal view returns (NetworkConfig memory _mxcMainNetworkConfig) {
        _mxcMainNetworkConfig = NetworkConfig({
            deployerKey: vm.envUint("MAINNETWORK_PRIVATE_KEY"),
            adminAddress: vm.envAddress("MAINNETWORK_ADMIN_ADDRESS"),
            feeBps: DEFAULT_FEE_BPS
        });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MscMarketV1} from "../src/MscMarketV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployMscMarketV1 is Script {
    // HelperConfig public helperConfig;

    constructor() {}

    function run() external returns (MscMarketV1 mscMarketV1, HelperConfig helperConfig) {
        (mscMarketV1, helperConfig) = deployMarket();
    }

    function deployMarket() public returns (MscMarketV1 mscMarketV1, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (uint256 deployKey, address adminAddress, uint96 feeBps) = helperConfig.activeNetworkConfig();
        vm.startBroadcast(deployKey);
        console.log("Starting to deploy the mscMarketV1...");
        mscMarketV1 = new MscMarketV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(mscMarketV1), "");
        MscMarketV1(payable(address(proxy))).initialize(adminAddress, feeBps);
        console.log("Deployed the mscMarketV1 at address: %s", address(proxy));
        vm.stopBroadcast();
        return (MscMarketV1(payable(address(proxy))), helperConfig);
    }
}

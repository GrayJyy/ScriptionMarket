// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MscMarketV1} from "../src/MscMarketV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract UpgradeMarket is Script {
    function run() external returns (address) {
        address mostRecentlyDeployedProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);

        vm.startBroadcast();
        MscMarketV1 mscMarketV1 = new MscMarketV1();
        vm.stopBroadcast();
        address proxy = upgradeMarket(mostRecentlyDeployedProxy, address(mscMarketV1));
        return proxy;
    }

    function upgradeMarket(address proxyAddress, address newMarket) public returns (address payable) {
        vm.startBroadcast();
        MscMarketV1 proxy = MscMarketV1(payable(proxyAddress));
        proxy.upgradeToAndCall(payable(newMarket), "");
        vm.stopBroadcast();
        return payable(address(proxy));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DeployMscMarketV1} from "../../script/DeployMscMarketV1.s.sol";
import {UpgradeMarket} from "../../script/UpgradeMarket.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MscMarketV1} from "../../src/MscMarketV1.sol";
import {MscMarketV2Mock} from "../mock/MscMarketV2Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DeployAndUpgradeTest is StdCheats, Test {
    DeployMscMarketV1 public deployMscMarket;
    UpgradeMarket public upgradeMarket;
    address public OWNER = address(1);

    function setUp() public {
        deployMscMarket = new DeployMscMarketV1();
        upgradeMarket = new UpgradeMarket();
    }

    function testMscMarketWorks() public {
        (MscMarketV1 mscMarketV1,) = deployMscMarket.deployMarket();
        uint256 expectedValue = 1;
        assertEq(expectedValue, mscMarketV1.getVersion());
    }

    function testUpgradeWorks() public {
        (MscMarketV1 mscMarketV1,) = deployMscMarket.deployMarket();
        MscMarketV2Mock mscMarketV2 = new MscMarketV2Mock();
        vm.prank(mscMarketV1.owner());
        mscMarketV1.transferOwnership(msg.sender);
        address payable proxy = upgradeMarket.upgradeMarket(address(mscMarketV1), address(mscMarketV2));
        uint256 expectedValue = 2;
        assertEq(expectedValue, MscMarketV2Mock(proxy).getVersion());
    }
}

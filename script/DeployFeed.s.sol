// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { MockPriceFeed } from "../src/MockPriceFeed.sol";

/// @notice Deploys the price feed on the origin chain (Ethereum Sepolia).
contract DeployFeed is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 initialPrice = vm.envOr("INITIAL_PRICE", uint256(2000));

        vm.startBroadcast(deployerKey);
        MockPriceFeed feed = new MockPriceFeed(initialPrice);
        vm.stopBroadcast();

        console.log("MockPriceFeed:", address(feed));
    }
}

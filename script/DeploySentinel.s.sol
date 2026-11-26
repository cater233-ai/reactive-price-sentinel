// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { PriceSentinel } from "../src/PriceSentinel.sol";

/// @notice Deploys the reactive sentinel on Reactive Lasna, funded with lREACT
///         so it can pay for reactive transactions.
contract DeploySentinel is Script {
    uint256 internal constant SEPOLIA = 11155111;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address feed = vm.envAddress("FEED_ADDRESS");
        uint256 floor = vm.envOr("FLOOR_PRICE", uint256(1500));
        uint256 ceiling = vm.envOr("CEILING_PRICE", uint256(2500));
        uint256 fund = vm.envOr("SENTINEL_FUND_LREACT", uint256(2 ether));

        vm.startBroadcast(deployerKey);
        PriceSentinel sentinel = new PriceSentinel{ value: fund }(
            SEPOLIA,
            feed,
            SEPOLIA,
            floor,
            ceiling
        );
        vm.stopBroadcast();

        console.log("PriceSentinel:", address(sentinel));
    }
}

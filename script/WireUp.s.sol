// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { PriceSentinel } from "../src/PriceSentinel.sol";

/// @notice Points the sentinel (on Lasna) at the vault (on Sepolia). This is
///         step 3 of the documented deployment order: reactive contract first,
///         callback contract second (it needs the sentinel's address), then
///         the recipient is set on the reactive contract.
contract WireUp is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address sentinel = vm.envAddress("SENTINEL_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(deployerKey);
        PriceSentinel(payable(sentinel)).setRecipient(vault);
        vm.stopBroadcast();

        console.log("Recipient set on PriceSentinel:", sentinel);
    }
}

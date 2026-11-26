// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { GuardedVault } from "../src/GuardedVault.sol";

/// @notice Deploys the vault on the destination chain (Ethereum Sepolia),
///         funded with Sepolia ETH so it can pay callback execution charges.
contract DeployVault is Script {
    /// @notice Reactive callback proxy on Ethereum Sepolia (docs: Origins & Destinations).
    address internal constant SEPOLIA_CALLBACK_PROXY = 0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address sentinel = vm.envAddress("SENTINEL_ADDRESS");
        uint256 fund = vm.envOr("VAULT_FUND_ETH", uint256(0.05 ether));

        vm.startBroadcast(deployerKey);
        GuardedVault vault = new GuardedVault{ value: fund }(
            IPayable(payable(SEPOLIA_CALLBACK_PROXY)),
            sentinel
        );
        vm.stopBroadcast();

        console.log("GuardedVault:", address(vault));
    }
}

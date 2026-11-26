// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractPayer } from "@reactive/src/base/AbstractPayer.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";
import { GuardedVault } from "../src/GuardedVault.sol";

contract GuardedVaultTest is Test {
    address internal proxy = makeAddr("callbackProxy");
    address internal sentinel = makeAddr("sentinel");
    address internal user = makeAddr("user");

    GuardedVault internal vault;

    function setUp() public {
        vault = new GuardedVault{ value: 1 ether }(IPayable(payable(proxy)), sentinel);
        vm.deal(user, 10 ether);
    }

    function test_depositAndWithdraw() public {
        vm.prank(user);
        vault.deposit{ value: 2 ether }();
        assertEq(vault.balances(user), 2 ether);

        uint256 before = user.balance;
        vm.prank(user);
        vault.withdraw(2 ether);
        assertEq(vault.balances(user), 0);
        assertEq(user.balance, before + 2 ether);
    }

    function test_withdrawRejectsOverdraw() public {
        vm.expectRevert(GuardedVault.InsufficientBalance.selector);
        vm.prank(user);
        vault.withdraw(1 ether);
    }

    function test_protectionFreezesAndReleasesWithdrawals() public {
        vm.prank(user);
        vault.deposit{ value: 1 ether }();

        vm.prank(proxy);
        vault.applyProtection(sentinel, 3000, true);
        assertEq(vault.protectedMode(), true);
        assertEq(vault.lastTriggerPrice(), 3000);
        assertEq(vault.triggerCount(), 1);

        vm.expectRevert(GuardedVault.WithdrawalsProtected.selector);
        vm.prank(user);
        vault.withdraw(1 ether);

        vm.prank(proxy);
        vault.applyProtection(sentinel, 2000, false);
        assertEq(vault.protectedMode(), false);

        vm.prank(user);
        vault.withdraw(1 ether);
        assertEq(vault.balances(user), 0);
    }

    function test_applyProtectionRejectsDirectCallers() public {
        vm.expectRevert(
            abi.encodeWithSelector(AbstractPayer.NotAuthorized.selector, address(this), proxy)
        );
        vault.applyProtection(sentinel, 3000, true);
    }

    function test_applyProtectionRejectsForeignReactiveContracts() public {
        address foreign = makeAddr("foreignReactive");
        vm.expectRevert(
            abi.encodeWithSelector(
                AbstractCallback.CallbackNotAuthorized.selector, foreign, sentinel
            )
        );
        vm.prank(proxy);
        vault.applyProtection(foreign, 3000, true);
    }
}

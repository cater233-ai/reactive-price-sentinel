// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractPayer } from "@reactive/src/base/AbstractPayer.sol";
import { MockPriceFeed } from "../src/MockPriceFeed.sol";
import { PriceSentinel } from "../src/PriceSentinel.sol";
import { MockSystemContract } from "./MockSystemContract.sol";

contract PriceSentinelTest is Test {
    address internal constant SYSTEM_ADDR = 0x8888888888888888888888888888888888888888;
    uint256 internal constant SEPOLIA = 11155111;

    MockSystemContract internal system;
    MockPriceFeed internal feed;
    PriceSentinel internal sentinel;
    address internal vault = makeAddr("vault");

    function setUp() public {
        MockSystemContract deployed = new MockSystemContract();
        vm.etch(SYSTEM_ADDR, address(deployed).code);
        system = MockSystemContract(payable(SYSTEM_ADDR));

        feed = new MockPriceFeed(2000);
        sentinel = new PriceSentinel{ value: 1 ether }(SEPOLIA, address(feed), SEPOLIA, 1500, 2500);
        sentinel.setRecipient(vault);
    }

    function _priceLog(uint256 price) internal view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: SEPOLIA,
            contractAddress: address(feed),
            topic0: uint256(keccak256("PriceUpdated(uint256,uint256)")),
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: abi.encode(price, uint256(1_700_000_000)),
            blockNumber: 1,
            opCode: 1,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function test_subscribesToFeedOnDeploy() public view {
        assertEq(system.subscriptionCount(), 1);
        (uint256 chainId, address contractAddress, uint256 topic0,,,) = system.subscriptions(0);
        assertEq(chainId, SEPOLIA);
        assertEq(contractAddress, address(feed));
        assertEq(topic0, uint256(keccak256("PriceUpdated(uint256,uint256)")));
    }

    function test_inBandTickRequestsNoCallback() public {
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(2100));
        assertEq(sentinel.lastPrice(), 2100);
        assertEq(sentinel.protectionOn(), false);
        assertEq(system.callbackRequestCount(), 0);
    }

    function test_outOfBandTickRequestsProtection() public {
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(3000));

        assertEq(sentinel.protectionOn(), true);
        assertEq(system.callbackRequestCount(), 1);

        (uint256 chainId, address recipient, uint64 gasLimit, bytes memory payload) =
            system.callbackRequests(0);
        assertEq(chainId, SEPOLIA);
        assertEq(recipient, vault);
        assertEq(gasLimit, 1_000_000);

        // Payload: applyProtection(address,uint256,bool) with the placeholder
        // address still zero — the network overwrites it at delivery time.
        (address placeholder, uint256 price, bool protect) =
            abi.decode(_stripSelector(payload), (address, uint256, bool));
        assertEq(placeholder, address(0));
        assertEq(price, 3000);
        assertEq(protect, true);
    }

    function test_secondOutOfBandTickDoesNotRepeatCallback() public {
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(3000));
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(3100));
        assertEq(system.callbackRequestCount(), 1);
        assertEq(sentinel.lastPrice(), 3100);
    }

    function test_returnToBandRequestsRelease() public {
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(3000));
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(2000));

        assertEq(sentinel.protectionOn(), false);
        assertEq(system.callbackRequestCount(), 2);
        (,,, bytes memory payload) = system.callbackRequests(1);
        (, uint256 price, bool protect) = abi.decode(_stripSelector(payload), (address, uint256, bool));
        assertEq(price, 2000);
        assertEq(protect, false);
    }

    function test_belowFloorAlsoProtects() public {
        vm.prank(SYSTEM_ADDR);
        sentinel.react(_priceLog(900));
        assertEq(sentinel.protectionOn(), true);
        assertEq(system.callbackRequestCount(), 1);
    }

    function test_reactRejectsNonSystemCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(AbstractPayer.NotAuthorized.selector, address(this), SYSTEM_ADDR)
        );
        sentinel.react(_priceLog(3000));
    }

    function test_unrelatedLogIsIgnored() public {
        IReactive.LogRecord memory log_ = _priceLog(3000);
        log_.topic0 = uint256(keccak256("SomethingElse(uint256)"));
        vm.prank(SYSTEM_ADDR);
        sentinel.react(log_);
        assertEq(sentinel.lastPrice(), 0);
        assertEq(system.callbackRequestCount(), 0);
    }

    function test_onlyOwnerManages() public {
        vm.expectRevert(PriceSentinel.NotOwner.selector);
        vm.prank(makeAddr("stranger"));
        sentinel.setRecipient(makeAddr("otherVault"));

        vm.expectRevert(PriceSentinel.InvalidBand.selector);
        sentinel.updateBand(2500, 2500);
    }

    function _stripSelector(bytes memory payload) internal pure returns (bytes memory) {
        bytes memory args = new bytes(payload.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = payload[i + 4];
        }
        return args;
    }
}

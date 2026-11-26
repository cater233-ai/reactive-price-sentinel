// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";

/// @notice Test double for the Reactive system contract. Etch it at
///         0x8888888888888888888888888888888888888888 and interact with it
///         through that address: it records subscriptions and callback
///         requests instead of talking to the network.
contract MockSystemContract is ISystemContract {
    struct Subscription {
        uint256 chainId;
        address contractAddress;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
    }

    Subscription[] public subscriptions;
    CallbackConfiguration_V_1_0[] public callbackRequests;

    receive() external payable {}

    function debt(address) external pure returns (uint256) {
        return 0;
    }

    function subscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external {
        subscriptions.push(Subscription(chainId_, contract_, topic0_, topic1_, topic2_, topic3_));
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {}

    function requestCallback(CallbackVersion, bytes memory) external {}

    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 memory config_) external {
        callbackRequests.push(config_);
    }

    function subscriptionCount() external view returns (uint256) {
        return subscriptions.length;
    }

    function callbackRequestCount() external view returns (uint256) {
        return callbackRequests.length;
    }
}

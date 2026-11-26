// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title MockPriceFeed
/// @notice A minimal stand-in price oracle on the origin chain. It stores one
///         price and emits `PriceUpdated` whenever the price is set.
/// @dev In a production version of this system the event source would be a real
///      oracle or a DEX pool. The sentinel reacts to the event, so the source
///      can be swapped without touching the rest of the system. The event has
///      no indexed parameters, so it arrives at `react()` as a LOG1 record
///      (opCode 1) with both values in `data`.
contract MockPriceFeed {
    event PriceUpdated(uint256 price, uint256 updatedAt);

    error NotOwner();

    /// @notice The only account allowed to set the price (the demo operator).
    address public immutable owner;

    /// @notice The current price, in whole units (e.g. 2000 means $2,000).
    uint256 public price;

    constructor(uint256 initialPrice_) {
        owner = msg.sender;
        price = initialPrice_;
    }

    /// @notice Sets a new price and emits the event the sentinel watches for.
    function setPrice(uint256 price_) external {
        if (msg.sender != owner) revert NotOwner();
        price = price_;
        emit PriceUpdated(price_, block.timestamp);
    }
}

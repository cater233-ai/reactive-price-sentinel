// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/// @title PriceSentinel
/// @notice A reactive contract on Reactive Lasna that watches a price feed on
///         the origin chain. When the price leaves the configured band it
///         orders the vault on the destination chain to protect withdrawals;
///         when the price returns inside the band it orders a release.
/// @dev The contract only requests a callback on band transitions, not on
///      every tick, so a price oscillating inside the band costs nothing and a
///      price sitting outside the band does not spam the vault. Deploy it
///      funded: reactive transactions are paid from this contract's balance.
contract PriceSentinel is AbstractReactive {
    /// @notice Topic 0 of `MockPriceFeed.PriceUpdated(uint256,uint256)`.
    uint256 private constant PRICE_UPDATED_TOPIC = uint256(keccak256("PriceUpdated(uint256,uint256)"));

    /// @notice Gas limit forwarded to the destination call by the callback proxy.
    uint64 private constant CALLBACK_GAS_LIMIT = 1_000_000;

    event BandUpdated(uint256 floor, uint256 ceiling);
    event RecipientSet(address recipient);
    event ProtectionRequested(bool protect, uint256 price);

    error NotOwner();
    error ZeroAddress();
    error InvalidBand();

    /// @notice The account that deployed the contract; manages band and recipient.
    address public immutable owner;

    /// @notice Chain the price feed lives on (the origin).
    uint256 public immutable originChainId;

    /// @notice The price feed contract watched by this sentinel.
    address public immutable feed;

    /// @notice Chain the vault lives on (the destination).
    uint256 public immutable destinationChainId;

    /// @notice Prices strictly below the floor are out of band.
    uint256 public floor;

    /// @notice Prices strictly above the ceiling are out of band.
    uint256 public ceiling;

    /// @notice The vault contract on the destination chain. Set after the vault
    ///         is deployed, because the vault needs this contract's address at
    ///         construction time (see the deployment-order note in the docs).
    address public recipient;

    /// @notice The last protection state this contract has ordered.
    bool public protectionOn;

    /// @notice The most recent price seen from the feed.
    uint256 public lastPrice;

    constructor(
        uint256 originChainId_,
        address feed_,
        uint256 destinationChainId_,
        uint256 floor_,
        uint256 ceiling_
    ) payable {
        if (feed_ == address(0)) revert ZeroAddress();
        if (floor_ >= ceiling_) revert InvalidBand();

        owner = msg.sender;
        originChainId = originChainId_;
        feed = feed_;
        destinationChainId = destinationChainId_;
        floor = floor_;
        ceiling = ceiling_;

        SYSTEM.subscribe(
            originChainId_,
            feed_,
            PRICE_UPDATED_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /// @notice Points the sentinel at the vault. Owner only, set once per vault.
    function setRecipient(address recipient_) external {
        if (msg.sender != owner) revert NotOwner();
        if (recipient_ == address(0)) revert ZeroAddress();
        recipient = recipient_;
        emit RecipientSet(recipient_);
    }

    /// @notice Adjusts the watched band. Owner only. Transitions are still
    ///         driven by feed events; a band change takes effect on the next tick.
    function updateBand(uint256 floor_, uint256 ceiling_) external {
        if (msg.sender != owner) revert NotOwner();
        if (floor_ >= ceiling_) revert InvalidBand();
        floor = floor_;
        ceiling = ceiling_;
        emit BandUpdated(floor_, ceiling_);
    }

    /// @notice Settles any outstanding debt to the system contract from this
    ///         contract's own balance. Open to anyone: it can only restart the
    ///         sentinel, never extract funds.
    function coverDebt() external {
        _coverDebt();
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external override onlySystem {
        // The subscription already filters by chain, contract and topic; the
        // re-checks below are cheap defense in depth and document the shape of
        // the records this contract acts on.
        if (log_.chainId != originChainId) return;
        if (log_.contractAddress != feed) return;
        if (log_.topic0 != PRICE_UPDATED_TOPIC) return;
        // PriceUpdated carries no indexed parameters: LOG1, price and the
        // timestamp packed in `data` in declaration order.
        if (log_.opCode != 1) return;

        (uint256 price,) = abi.decode(log_.data, (uint256, uint256));
        lastPrice = price;

        bool outOfBand = price < floor || price > ceiling;
        if (outOfBand == protectionOn) return; // No transition: nothing to do.
        if (recipient == address(0)) return; // Nowhere to send the order yet.

        protectionOn = outOfBand;
        emit ProtectionRequested(outOfBand, price);

        // The first payload argument is an address placeholder: Reactive
        // Network overwrites it with this contract's address, which is how the
        // vault authenticates the callback.
        bytes memory payload = abi.encodeWithSignature(
            "applyProtection(address,uint256,bool)",
            address(0),
            price,
            outOfBand
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId,
                recipient: recipient,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }
}

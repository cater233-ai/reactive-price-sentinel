// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";

/// @title GuardedVault
/// @notice A small vault on the destination chain whose withdrawals are frozen
///         and released by callbacks from its PriceSentinel on Reactive Lasna.
/// @dev Callback authenticity is enforced twice by AbstractCallback: the call
///      must arrive through this chain's callback proxy (`onlyServiceProvider`)
///      and the address Reactive Network injects into the payload must be the
///      authorized sentinel (`onlyCallbackSender`).
///
///      Funding note: callback execution charges are paid from this contract's
///      ETH balance by the proxy, so the deployment funds the vault with an
///      operator float on top of user deposits. For this demo the float and
///      the deposits share one balance; a production version should escrow
///      callback fees separately so user funds never subsidize execution.
contract GuardedVault is AbstractCallback {
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ProtectionApplied(uint256 price, bool protect, uint256 appliedAt);

    error WithdrawalsProtected();
    error InsufficientBalance();
    // TransferFailed() is inherited from AbstractPayer.

    /// @notice Per-user deposited balances.
    mapping(address => uint256) public balances;

    /// @notice While true, all withdrawals revert.
    bool public protectedMode;

    /// @notice Price carried by the most recent protection callback.
    uint256 public lastTriggerPrice;

    /// @notice Destination-chain time of the most recent protection callback.
    uint256 public lastTriggerAt;

    /// @notice How many protection callbacks have been applied.
    uint256 public triggerCount;

    /// @param callbackProxy_ This chain's Reactive callback proxy.
    /// @param sentinel_ The PriceSentinel contract authorized to drive this vault.
    constructor(IPayable callbackProxy_, address sentinel_)
        payable
        AbstractCallback(callbackProxy_, sentinel_)
    {}

    /// @notice Deposits ETH into the vault.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraws deposited ETH. Reverts while protection is on.
    function withdraw(uint256 amount_) external {
        if (protectedMode) revert WithdrawalsProtected();
        if (balances[msg.sender] < amount_) revert InsufficientBalance();

        balances[msg.sender] -= amount_;
        (bool ok,) = msg.sender.call{ value: amount_ }("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount_);
    }

    /// @notice Applies a protection order from the sentinel. The `reactive_`
    ///         argument is not supplied by the caller: the callback proxy
    ///         overwrites the first payload slot with the requesting reactive
    ///         contract's address, and `onlyCallbackSender` checks it.
    function applyProtection(address reactive_, uint256 price_, bool protect_)
        external
        onlyServiceProvider
        onlyCallbackSender(reactive_)
    {
        protectedMode = protect_;
        lastTriggerPrice = price_;
        lastTriggerAt = block.timestamp;
        triggerCount += 1;
        emit ProtectionApplied(price_, protect_, block.timestamp);
    }

    /// @notice Settles any outstanding debt to the callback proxy from this
    ///         contract's own balance. Open to anyone: it can only restart
    ///         callback delivery, never extract funds.
    function coverDebt() external {
        _coverDebt();
    }
}

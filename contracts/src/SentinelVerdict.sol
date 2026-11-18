// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractCallback} from "@reactive/base/AbstractCallback.sol";
import {IPayable} from "@reactive/interfaces/IPayable.sol";

/// @title SentinelVerdict — Sepolia callback contract for the Sentinel demo.
/// @notice Receives callbacks from SentinelReactive (Lasna) via the Sepolia
///         callback proxy and records the verdict on-chain.
/// @dev Two guards: onlyServiceProvider (caller must be the callback proxy)
///      AND onlyCallbackSender (payload sender must be the reactive contract).
contract SentinelVerdict is AbstractCallback {
    event VerdictRecorded(address indexed from, address indexed to, uint256 amount, string label, bytes32 reasonHash);

    constructor(address payable callbackProxy_, address callbackSender_)
        payable
        AbstractCallback(IPayable(callbackProxy_), callbackSender_)
    {}

    /// @param sender Reactive contract address, injected by Reactive into the
    ///               first payload argument (was address(0) when requested).
    function verdict(address sender, address from, address to, uint256 amount, string calldata label, bytes32 reasonHash)
        external
        onlyServiceProvider
        onlyCallbackSender(sender)
    {
        emit VerdictRecorded(from, to, amount, label, reasonHash);
    }
}

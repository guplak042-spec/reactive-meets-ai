// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractReactive} from "@reactive/base/AbstractReactive.sol";
import {ISystemContract} from "@reactive/interfaces/ISystemContract.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";

/// @title SentinelReactive — Lasna reactive contract for the Sentinel demo.
/// @notice Subscribes to Transfer events of SentinelToken on Sepolia. When a
///         transfer is >= `threshold`, it records the transfer as PENDING and
///         emits TransferFlagged — it does NOT request a callback yet. The
///         off-chain AI watcher (Groq gpt-oss-120b) classifies the transfer
///         and calls submitDecision(), which is what requests the callback to
///         SentinelVerdict on Sepolia carrying the AI label + reasonHash.
///         The AI is therefore the decision-maker inside the loop; no
///         placeholder verdict is ever written on-chain.
/// @dev NEVER revert to filter logs: a revert inside react() is still fully
///      charged. Below-threshold logs (and logs before a recipient is set)
///      fall through silently. Duplicate deliveries of the same log are
///      ignored (pending already recorded).
/// @dev v3 (18 Nov 2026): phase 1 (v1/v2) requested the callback directly
///      from react() with a hardcoded "PENDING_AI" label. That made the AI
///      a post-hoc annotator, not a decision-maker, because the payload is
///      baked into the callback request. v3 defers the request until the AI
///      has classified. This also means a fresh SentinelVerdict must be
///      deployed: the verdict contract's _CALLBACK_SENDER is immutable and
///      bound to the reactive contract address, so the v2 verdict (bound to
///      the v2 reactive) would reject callbacks from this contract.
contract SentinelReactive is AbstractReactive {
    uint256 public constant ORIGIN_CHAIN_ID = 11155111; // Sepolia
    uint256 public constant DESTINATION_CHAIN_ID = 11155111; // Sepolia
    uint256 public constant TRANSFER_TOPIC0 =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef; // Transfer(address,address,uint256)
    /// @dev 500k, not 200k: the Sepolia callback proxy reserves _extraGas
    ///      (150,000) plus _maxChargeGas (50,000) from the requested limit
    ///      before forwarding the remainder to the recipient, so 200,000
    ///      would leave 0 gas for verdict() and delivery would fail with
    ///      InsufficientGas. 500,000 leaves ~300,000 for the call; the fee
    ///      is charged on gas actually used, so the higher limit costs nothing
    ///      extra. (Found live 18 Nov 2026: two callbacks requested at 200k
    ///      were never attempted — no CallbackFailure, no charge, empty
    ///      getCallbacks — while another user's callback executed.)
    uint64 public constant CALLBACK_GAS_LIMIT = 500_000;

    address public immutable token;
    uint256 public immutable threshold;
    address public recipient;
    address public immutable owner;

    struct PendingTransfer {
        address from;
        address to;
        uint256 amount;
        bool decided;
    }

    /// @notice Transfers awaiting an AI decision, keyed by Sepolia txHash.
    mapping(uint256 => PendingTransfer) public pending;

    event TransferFlagged(address indexed from, address indexed to, uint256 amount, uint256 indexed txHash);
    event DecisionSubmitted(uint256 indexed txHash, string label, bytes32 reasonHash);
    event RecipientSet(address indexed recipient);

    error NotOwner();
    error NotPending();
    error AlreadyDecided();

    constructor(address token_, uint256 threshold_) payable {
        token = token_;
        threshold = threshold_;
        owner = msg.sender;
        // Subscribe only when the system contract exists (Lasna). In local
        // tests / anvil the system contract has no code, so skip there.
        if (address(SYSTEM).code.length > 0) {
            SYSTEM.subscribe(
                ORIGIN_CHAIN_ID, token_, TRANSFER_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
        }
    }

    /// @notice Set the callback recipient (SentinelVerdict on Sepolia).
    /// @dev Owner-only; the recipient is only known after the callback contract
    ///      is deployed, so it is set post-deploy (see deploy scripts).
    ///      Setting it to address(0) disables the contract (react() returns
    ///      early) — used to retire the v2 reactive contract.
    function setRecipient(address recipient_) external {
        if (msg.sender != owner) revert NotOwner();
        recipient = recipient_;
        emit RecipientSet(recipient_);
    }

    function react(IReactive.LogRecord calldata log) external override onlySystem {
        address from = address(uint160(log.topic1));
        address to = address(uint160(log.topic2));
        uint256 amount = abi.decode(log.data, (uint256));

        // Silent fall-through for non-matching logs (see contract notice).
        if (amount < threshold) return;
        if (recipient == address(0)) return;
        // Duplicate delivery of the same log: already recorded, ignore.
        if (pending[log.txHash].amount != 0) return;

        pending[log.txHash] = PendingTransfer({from: from, to: to, amount: amount, decided: false});
        emit TransferFlagged(from, to, amount, log.txHash);
        // No callback here — the AI watcher decides first (submitDecision).
    }

    /// @notice Submit the AI classification for a pending transfer. Only the
    ///         owner (the AI watcher service) may call this. Requesting the
    ///         callback here is what carries the AI label + reasonHash to
    ///         SentinelVerdict on Sepolia.
    /// @param txHash Sepolia transaction hash of the flagged transfer.
    /// @param label AI verdict: "normal" | "whale" | "suspicious".
    /// @param reasonHash keccak256 of the AI's one-sentence reason text
    ///        (the reason text itself is published in the watcher logs and
    ///        STATUS.md; anyone can verify keccak(reason) == reasonHash).
    function submitDecision(uint256 txHash, string calldata label, bytes32 reasonHash) external {
        if (msg.sender != owner) revert NotOwner();
        PendingTransfer storage p = pending[txHash];
        if (p.amount == 0) revert NotPending();
        if (p.decided) revert AlreadyDecided();
        p.decided = true;

        emit DecisionSubmitted(txHash, label, reasonHash);

        bytes memory payload = abi.encodeWithSignature(
            "verdict(address,address,address,uint256,string,bytes32)",
            address(0), // overwritten by Reactive with this contract's address
            p.from,
            p.to,
            p.amount,
            label,
            reasonHash
        );
        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: DESTINATION_CHAIN_ID,
                recipient: recipient,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }
}

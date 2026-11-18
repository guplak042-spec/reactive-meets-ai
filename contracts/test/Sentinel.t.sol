// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SentinelToken} from "../src/SentinelToken.sol";
import {SentinelReactive} from "../src/SentinelReactive.sol";
import {SentinelVerdict} from "../src/SentinelVerdict.sol";
import {ISystemContract} from "@reactive/interfaces/ISystemContract.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";

/// @notice Minimal mock of the Lasna system contract, etched at 0x8888...8888.
/// Records subscribe() and requestCallbackV_1_0() calls so tests can assert
/// the reactive contract behaves correctly.
contract MockSystem {
    bool public subscribed;
    ISystemContract.CallbackConfiguration_V_1_0 public lastCallback;
    bool public callbackRequested;

    receive() external payable {}

    function debt(address) external pure returns (uint256) {
        return 0;
    }

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        subscribed = true;
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {}

    function requestCallback(ISystemContract.CallbackVersion, bytes memory) external {}

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config_) external {
        lastCallback = config_;
        callbackRequested = true;
    }
}

contract SentinelTest is Test {
    address constant SYSTEM_ADDR = 0x8888888888888888888888888888888888888888;
    address constant SEPOLIA_PROXY = 0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4;
    uint256 constant THRESHOLD = 1000 ether;

    SentinelToken token;
    SentinelReactive reactive;
    SentinelVerdict verdict;
    MockSystem mockSystem; // handle to the code etched at SYSTEM_ADDR (state lives there)
    MockSystem mockSystemImpl; // the deployed instance (only its code is used)

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    event TransferFlagged(address indexed from, address indexed to, uint256 amount, uint256 indexed txHash);
    event VerdictRecorded(address indexed from, address indexed to, uint256 amount, string label, bytes32 reasonHash);

    function setUp() public {
        mockSystemImpl = new MockSystem();
        vm.etch(SYSTEM_ADDR, address(mockSystemImpl).code);
        // State written by the etched code lives at SYSTEM_ADDR, not at the
        // deployed instance's address — read through this handle.
        mockSystem = MockSystem(payable(SYSTEM_ADDR));

        token = new SentinelToken();
        reactive = new SentinelReactive(address(token), THRESHOLD);
        verdict = new SentinelVerdict(payable(SEPOLIA_PROXY), address(reactive));
        reactive.setRecipient(address(verdict));

        token.transfer(alice, 10_000 ether);
    }

    function _log(address from, address to, uint256 amount, uint256 txHash) internal pure returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: 11155111,
            contractAddress: address(0),
            topic0: 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
            topic1: uint256(uint160(from)),
            topic2: uint256(uint160(to)),
            topic3: 0,
            data: abi.encode(amount),
            blockNumber: 1,
            opCode: 0,
            blockHash: 0,
            txHash: txHash,
            logIndex: 0
        });
    }

    function testFullLoopEndToEnd() public {
        // 1. Real token transfer >= threshold (1.500 SENT), capture the log.
        vm.recordLogs();
        vm.prank(alice);
        token.transfer(bob, 1500 ether);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertGt(logs.length, 0);
        Vm.Log memory transferLog = logs[logs.length - 1];
        assertEq(transferLog.topics[0], bytes32(uint256(0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef)));

        // 2. System contract delivers the log to react() on Lasna.
        //    v3: react() records the transfer as pending and emits
        //    TransferFlagged — it does NOT request a callback yet.
        IReactive.LogRecord memory record = IReactive.LogRecord({
            chainId: 11155111,
            contractAddress: address(token),
            topic0: uint256(transferLog.topics[0]),
            topic1: uint256(transferLog.topics[1]),
            topic2: uint256(transferLog.topics[2]),
            topic3: 0,
            data: transferLog.data,
            blockNumber: 1,
            opCode: 0,
            blockHash: 0,
            txHash: 0xabc123,
            logIndex: 0
        });
        vm.prank(SYSTEM_ADDR);
        reactive.react(record);
        assertFalse(mockSystem.callbackRequested(), "v3 react() must NOT request a callback before the AI decides");
        (address pFrom, address pTo, uint256 pAmount, bool pDecided) = reactive.pending(0xabc123);
        assertEq(pFrom, alice);
        assertEq(pTo, bob);
        assertEq(pAmount, 1500 ether);
        assertFalse(pDecided);

        // 3. The AI watcher classifies and submits its decision (owner call).
        //    Only now is the callback requested, carrying the AI label.
        bytes32 reasonHash = keccak256("routine test transfer to a known address");
        reactive.submitDecision(0xabc123, "normal", reasonHash);
        assertTrue(mockSystem.callbackRequested(), "submitDecision must request a callback");
        (pFrom, pTo, pAmount, pDecided) = reactive.pending(0xabc123);
        assertTrue(pDecided);

        // 4. Reactive network delivers the callback to Sepolia: the proxy
        //    calls verdict() with sender = reactive address (injected).
        (,, uint64 gasLimit, bytes memory payload) = mockSystem.lastCallback();
        assertGe(gasLimit, 100_000);
        bytes memory args = new bytes(payload.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = payload[i + 4];
        }
        (, address from, address to, uint256 amount, string memory label, bytes32 rHash) =
            abi.decode(args, (address, address, address, uint256, string, bytes32));

        vm.expectEmit(true, true, false, true, address(verdict));
        emit VerdictRecorded(from, to, amount, label, rHash);
        vm.prank(SEPOLIA_PROXY);
        verdict.verdict(address(reactive), from, to, amount, label, rHash);

        assertEq(from, alice);
        assertEq(to, bob);
        assertEq(amount, 1500 ether);
        assertEq(label, "normal");
        assertEq(rHash, reasonHash);
    }

    function testTokenMintAndTransfer() public view {
        assertEq(token.balanceOf(address(this)), 990_000 ether);
        assertEq(token.balanceOf(alice), 10_000 ether);
    }

    function testReactiveSubscribesOnDeploy() public view {
        assertTrue(mockSystem.subscribed());
    }

    function testReactBelowThresholdDoesNothing() public {
        vm.recordLogs();
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 999 ether, 0x1234));
        assertEq(vm.getRecordedLogs().length, 0, "below-threshold log must emit nothing");
        assertFalse(mockSystem.callbackRequested(), "below-threshold log must not request a callback");
    }

    function testReactAtThresholdRecordsPending() public {
        vm.recordLogs();
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
        assertFalse(mockSystem.callbackRequested(), "v3 react() must not request a callback before the AI decides");
        // TransferFlagged must be emitted.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "react() must emit exactly TransferFlagged");
        assertEq(logs[0].topics[0], keccak256("TransferFlagged(address,address,uint256,uint256)"));
        // Pending entry recorded.
        (address pFrom, address pTo, uint256 pAmount, bool pDecided) = reactive.pending(0x1234);
        assertEq(pFrom, alice);
        assertEq(pTo, bob);
        assertEq(pAmount, 1000 ether);
        assertFalse(pDecided);
    }

    function testSubmitDecisionRequestsCallbackWithAiLabel() public {
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
        bytes32 reasonHash = keccak256("first transfer to a brand-new address");
        reactive.submitDecision(0x1234, "suspicious", reasonHash);
        assertTrue(mockSystem.callbackRequested());
        (uint256 chainId, address recipient, uint64 gasLimit, bytes memory payload) = mockSystem.lastCallback();
        assertEq(chainId, 11155111);
        assertEq(recipient, address(verdict));
        assertGe(gasLimit, 100_000);
        // Payload decodes to verdict(address(0), from, to, amount, "suspicious", reasonHash).
        // Strip the 4-byte selector first (memory slicing is not supported).
        bytes memory args = new bytes(payload.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = payload[i + 4];
        }
        (address sender, address from, address to, uint256 amount, string memory label, bytes32 rHash) =
            abi.decode(args, (address, address, address, uint256, string, bytes32));
        assertEq(sender, address(0));
        assertEq(from, alice);
        assertEq(to, bob);
        assertEq(amount, 1000 ether);
        assertEq(label, "suspicious");
        assertEq(rHash, reasonHash);
    }

    function testSubmitDecisionOnlyOwner() public {
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SentinelReactive.NotOwner.selector));
        reactive.submitDecision(0x1234, "normal", bytes32(0));
    }

    function testSubmitDecisionUnknownReverts() public {
        vm.expectRevert(abi.encodeWithSelector(SentinelReactive.NotPending.selector));
        reactive.submitDecision(0x9999, "normal", bytes32(0));
    }

    function testSubmitDecisionTwiceReverts() public {
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
        reactive.submitDecision(0x1234, "normal", bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(SentinelReactive.AlreadyDecided.selector));
        reactive.submitDecision(0x1234, "whale", bytes32(0));
    }

    function testReactDuplicateDeliveryIgnored() public {
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
        vm.recordLogs();
        vm.prank(SYSTEM_ADDR);
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
        assertEq(vm.getRecordedLogs().length, 0, "duplicate delivery must emit nothing");
        assertFalse(mockSystem.callbackRequested());
    }

    function testReactOnlySystem() public {
        vm.expectRevert();
        reactive.react(_log(alice, bob, 1000 ether, 0x1234));
    }

    function testSetRecipientOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SentinelReactive.NotOwner.selector));
        reactive.setRecipient(alice);
    }

    function testVerdictGuards() public {
        // Wrong caller (not the proxy) reverts.
        vm.expectRevert();
        verdict.verdict(address(reactive), alice, bob, 1000 ether, "PENDING_AI", bytes32(0));
        // Right caller (proxy) but wrong sender reverts.
        vm.prank(SEPOLIA_PROXY);
        vm.expectRevert();
        verdict.verdict(alice, alice, bob, 1000 ether, "PENDING_AI", bytes32(0));
    }

    function testVerdictEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(verdict));
        emit VerdictRecorded(alice, bob, 1000 ether, "PENDING_AI", bytes32(uint256(0x1234)));
        vm.prank(SEPOLIA_PROXY);
        verdict.verdict(address(reactive), alice, bob, 1000 ether, "PENDING_AI", bytes32(uint256(0x1234)));
    }
}

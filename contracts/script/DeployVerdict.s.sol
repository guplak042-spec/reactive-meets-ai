// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {SentinelVerdict} from "../src/SentinelVerdict.sol";

/// @notice Deploy SentinelVerdict to Sepolia.
/// REACTIVE=<SentinelReactive Lasna address> forge script script/DeployVerdict.s.sol --rpc-url sepolia --broadcast
contract DeployVerdict is Script {
    address constant SEPOLIA_CALLBACK_PROXY = 0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4;

    function run() external {
        address reactive = vm.envAddress("REACTIVE");
        vm.startBroadcast();
        SentinelVerdict verdict = new SentinelVerdict(payable(SEPOLIA_CALLBACK_PROXY), reactive);
        vm.stopBroadcast();
        console.log("SentinelVerdict:", address(verdict));
        console.log("callbackProxy:", SEPOLIA_CALLBACK_PROXY);
        console.log("callbackSender (reactive):", reactive);
    }
}

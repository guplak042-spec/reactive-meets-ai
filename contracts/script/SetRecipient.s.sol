// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {SentinelReactive} from "../src/SentinelReactive.sol";

/// @notice Point SentinelReactive at the deployed SentinelVerdict (Lasna).
/// REACTIVE=<reactive> RECIPIENT=<verdict> forge script script/SetRecipient.s.sol --rpc-url lasna --broadcast
contract SetRecipient is Script {
    function run() external {
        address reactive = vm.envAddress("REACTIVE");
        address recipient = vm.envAddress("RECIPIENT");
        vm.startBroadcast();
        SentinelReactive(payable(reactive)).setRecipient(recipient);
        vm.stopBroadcast();
        console.log("reactive:", reactive);
        console.log("recipient set to:", recipient);
    }
}

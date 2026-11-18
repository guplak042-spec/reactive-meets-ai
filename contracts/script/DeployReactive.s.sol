// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {SentinelReactive} from "../src/SentinelReactive.sol";

/// @notice Deploy SentinelReactive to Lasna.
/// TOKEN=<SentinelToken Sepolia address> forge script script/DeployReactive.s.sol --rpc-url lasna --broadcast
contract DeployReactive is Script {
    function run() external {
        address token = vm.envAddress("TOKEN");
        uint256 threshold = vm.envOr("THRESHOLD", uint256(1000 ether));
        vm.startBroadcast();
        SentinelReactive reactive = new SentinelReactive(token, threshold);
        vm.stopBroadcast();
        console.log("SentinelReactive:", address(reactive));
        console.log("token:", token);
        console.log("threshold:", threshold);
    }
}

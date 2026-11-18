// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {SentinelToken} from "../src/SentinelToken.sol";

/// @notice Deploy SentinelToken to Sepolia.
/// forge script script/DeployToken.s.sol --rpc-url sepolia --broadcast
contract DeployToken is Script {
    function run() external {
        vm.startBroadcast();
        SentinelToken token = new SentinelToken();
        vm.stopBroadcast();
        console.log("SentinelToken:", address(token));
    }
}

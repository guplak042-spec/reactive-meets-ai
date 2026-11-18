// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SentinelToken — demo ERC-20 on Sepolia whose Transfer events Sentinel watches.
/// @notice Plain ERC-20; 1,000,000 SENT minted to the deployer. Every Transfer
///         (including small ones) emits the standard Transfer event; the reactive
///         contract filters by amount on Lasna.
contract SentinelToken is ERC20 {
    constructor() ERC20("Sentinel Demo Token", "SENT") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

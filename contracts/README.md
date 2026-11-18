# Contracts — Sentinel

Foundry project (Solidity 0.8.29) for the Sentinel loop. See the repo-root
[`README.md`](../README.md) for the full picture and live addresses.

## Contracts

| Contract | File | Role |
|---|---|---|
| `SentinelToken` | `src/SentinelToken.sol` | ERC-20 demo token (1,000,000 SENT), the origin of `Transfer` events on Sepolia. |
| `SentinelReactive` | `src/SentinelReactive.sol` | Reactive contract on Lasna. Subscribes to `Transfer` ≥ 1,000 SENT; `react()` records the transfer as pending and emits `TransferFlagged`; `submitDecision(txHash, label, reasonHash)` (owner-only) requests the callback carrying the AI verdict. |
| `SentinelVerdict` | `src/SentinelVerdict.sol` | Callback contract on Sepolia. Accepts callbacks only from the Reactive system contract and only from its bound reactive contract (`_CALLBACK_SENDER`, immutable); emits `VerdictRecorded(from, to, amount, label, reasonHash)`. |

## Build & test

```bash
forge build
forge test        # 14/14 pass, incl. full loop end-to-end
```

RPC endpoints are in `foundry.toml` (`sepolia`, `lasna`).

## Deploy

Use the repo-root helper (reads the build keypair from
`../.wallet/keypair.json` at runtime — never paste a key on the command
line):

```bash
# order: token (Sepolia) -> reactive (Lasna) -> verdict (Sepolia) -> recipient (Lasna)
scripts/deploy.sh token
TOKEN=0x... scripts/deploy.sh reactive
REACTIVE=0x... scripts/deploy.sh verdict
REACTIVE=0x... RECIPIENT=0x... scripts/deploy.sh recipient
```

Lasna writes go through `scripts/send_raw.py` (offline signing + raw-tx
broadcast) because the Lasna RPC intermittently drops Foundry's TLS
connections. Fund the reactive contract with ~1 lREACT and the verdict
contract with 0.05 Sepolia ETH via the callback proxy's `depositTo()` —
callbacks are charged to the destination contract, so an unfunded verdict
contract never receives them (found live, see `STATUS.md`).

Deploy scripts: `script/DeployToken.s.sol`, `script/DeployReactive.s.sol`,
`script/DeployVerdict.s.sol`, `script/SetRecipient.s.sol`.

# Sentinel — AI Triage for Suspicious Token Transfers

**DoraHacks Reactive Omni Buildathon — track: Reactive Meets AI ($1,000, 1st place)**
**Submission deadline: 5 Dec 2026, 20:00 UTC (6 Dec 2026, 03:00 WIB)**

Sentinel watches a token on Sepolia and lets an AI model decide — at runtime,
on-chain — whether a large transfer is `normal`, a `whale` move, or
`suspicious`. The verdict is recorded back on-chain. The AI is not a tool that
wrote this code: **without the model, there is no verdict and no callback**.
The reactive contract only flags; the model produces the payload that gets
delivered.

## The loop (live, proven on-chain)

```
Sepolia (origin)                 Lasna (reactive)              Sepolia (destination)
SentinelToken  --Transfer-->  SentinelReactive  --callback-->  SentinelVerdict
  (ERC-20 demo)   >= 1,000 SENT   (flags + routes)              (VerdictRecorded)
                      ^                          ^
                      |                          |
                 Groq gpt-oss-120b decides      |
                 (watcher, off-chain)           |
                      |                          |
                      +---- submitDecision -----+
```

1. **Origin event** — a transfer of ≥ 1,000 SENT on Sepolia. `SentinelReactive`
   on Lasna subscribes to the token's `Transfer` events.
2. **Flag, don't decide** — `react()` records the transfer as *pending* and
   emits `TransferFlagged`. No callback is requested yet. (In v1/v2 the
   callback was requested immediately with a hardcoded `"PENDING_AI"` label —
   the AI was only a post-facto annotation. v3 fixed that.)
3. **AI decides** — the watcher (`watcher/`) reads the flagged event, gathers
   on-chain facts from Sepolia (sender history, recipient history, balances),
   and asks Groq `gpt-oss-120b` (free tier) for a strict-JSON verdict:
   `{"label": "normal" | "whale" | "suspicious", "reason": "..."}`.
4. **Decision on-chain** — the watcher calls `submitDecision(txHash, label,
   reasonHash)` on the reactive contract (owner-only), where
   `reasonHash = keccak256(reason)`. Only now does the reactive contract call
   `SYSTEM.requestCallbackV_1_0` with the AI's label in the payload.
5. **Verdict recorded** — the Reactive relayer delivers the callback to
   `SentinelVerdict` on Sepolia, which emits
   `VerdictRecorded(from, to, amount, label, reasonHash)`. Anyone can verify
   `keccak256(reason) == reasonHash` — the full reason text is published in
   `watcher/decisions.jsonl` and in `STATUS.md`.

## Live deployment (active set: v3)

| Contract | Chain | Address |
|---|---|---|
| SentinelToken (ERC-20, 1,000,000 SENT) | Sepolia (11155111) | [0x1DAF205424104F8a9249bA5F3AD5466887a9C888](https://sepolia.etherscan.io/address/0x1DAF205424104F8a9249bA5F3AD5466887a9C888) |
| SentinelReactive v3 | Lasna (5318007) | `0xe755d37713c92c58a2fb09ffc8e75c6618bd1f82` |
| SentinelVerdict v3 | Sepolia (11155111) | [0x42c393834692a0c9bbb3910c34612b13e0b05f54](https://sepolia.etherscan.io/address/0x42c393834692a0c9bbb3910c34612b13e0b05f54) |

Build wallet: `0x361Ff0DE45C2Ed52f5098FBdEa4eed45b5d6a3e1`. Lasna RPC:
`https://lasna-rpc.rnk.dev/` (chain ID 5318007). Both contracts are funded
(reactive v3: ~1 lREACT; verdict v3: 0.05 Sepolia ETH in callback-proxy
reserves) so callbacks deliver.

## Proof: the AI loop, end to end (18 Nov 2026)

Transfer **#4** — 2,000 SENT to a brand-new address:

| Step | Transaction | Chain / block |
|---|---|---|
| Transfer (2,000 SENT → `0xC325…9478`) | [0x64c2eaed6cfec22da2d9b0ab4a68f4c54ad66c1468e9e7f30966a54658989456](https://sepolia.etherscan.io/tx/0x64c2eaed6cfec22da2d9b0ab4a68f4c54ad66c1468e9e7f30966a54658989456) | Sepolia 12160959 |
| `react()` → `TransferFlagged` | `0x99b9f10b0b2ae296169fc6e33ac894ef6dd97b472d841e51c628cffea0e7f40e` | Lasna 8646093 |
| Groq classification | label **`"suspicious"`** — *"2000 SENT (0.2% supply) sent to a brand-new address with no prior activity, a large first-time transfer that could indicate testing or laundering."* · reasonHash `0x2c40d19f2759dd36e321550e660c14ad2de58ea38e0b393ca521b4269707739f` | `openai/gpt-oss-120b` |
| `submitDecision(txHash, "suspicious", reasonHash)` | `0x01df54f5d9ee801e95ecdcc52747b16fef68d59c20ee61f0247a3cf5498751ed` | Lasna 8646817 |
| Callback → `VerdictRecorded` | [0x6c4da867f6bfda1771a546838c46538343fadc679b944cbc6dafc5fe9e93e572](https://sepolia.etherscan.io/tx/0x6c4da867f6bfda1771a546838c46538343fadc679b944cbc6dafc5fe9e93e572) | Sepolia 12161024 |

`keccak256(reason) == reasonHash` was recomputed independently and matches.
No `"PENDING_AI"` placeholder anywhere in this loop.

An earlier loop (v2, transfer #3, 2,000 SENT) proved the plumbing first:
transfer
[0x877b6e1510b3c487e5be49002c856a35326685241cb0c9d64849a6e8f0376cd3](https://sepolia.etherscan.io/tx/0x877b6e1510b3c487e5be49002c856a35326685241cb0c9d64849a6e8f0376cd3)
→ callback
[0x046b2dc9e539fa2ddc92459147298bc486de55adc1c6a54c27cd31ce343abf04](https://sepolia.etherscan.io/tx/0x046b2dc9e539fa2ddc92459147298bc486de55adc1c6a54c27cd31ce343abf04)
(`VerdictRecorded`, 1 block after the transfer). Full history — including the
two live bugs found and fixed along the way (unfunded callback contract;
callback gas limit 200k → 500k) — is in [`STATUS.md`](STATUS.md).

## Repo layout

```
reactive-meets-ai/
  contracts/        # Foundry project: SentinelToken, SentinelReactive, SentinelVerdict
    src/            #   + tests (14 tests) and deploy scripts
  watcher/          # Node.js watcher: reads flagged events -> Groq -> submitDecision
    watch.js        #   single-pass poller (no npm deps), state.json checkpoint
    groq_classify.py#   Groq chat completions -> {"label","reason","reasonHash"}
    decisions.jsonl #   one JSON line per AI decision (public record)
  scripts/          # deploy.sh (Foundry), send_raw.py (raw-tx sender for Lasna)
  CONCEPT.md        # design doc: why Sentinel, alternatives considered
  BUILD-PLAN.md     # build plan + milestones
  STATUS.md         # build log: live addresses, tx hashes, balances, blockers
```

## Build & test

```bash
git submodule update --init   # fetch forge-std, openzeppelin, reactive-lib (or: forge install)
cd contracts
forge build
forge test        # 14/14 pass (incl. full loop end-to-end on a local fork)
```

Requires [Foundry](https://book.getfoundry.sh/) 1.9.0+, Solidity 0.8.29.

## Run the watcher

```bash
export GROQ_API_KEY=...   # free key: https://console.groq.com/keys
node watcher/watch.js      # single pass, then exits
```

Design: single-pass + `watcher/state.json` checkpoint (last scanned Lasna
block, processed tx hashes, retry queue). Run it on a schedule (e.g. cron
every 3 minutes); it is restart-safe and never double-processes a transfer.
The watcher sends `submitDecision` via `scripts/send_raw.py`, which signs
offline with the build keypair (`.wallet/keypair.json`, never committed) and
broadcasts the raw transaction — the Lasna RPC intermittently drops Foundry's
TLS connections, while plain HTTPS works.

## Reproduce the demo loop

1. Get Sepolia ETH from a faucet, swap some to lREACT by sending ETH to the
   Reactive faucet contract `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
   (1 ETH = 100 lREACT, max 5 ETH/tx).
2. Deploy (in order): `scripts/deploy.sh token` (Sepolia) →
   `TOKEN=... scripts/deploy.sh reactive` (Lasna) →
   `REACTIVE=... scripts/deploy.sh verdict` (Sepolia) →
   `REACTIVE=... RECIPIENT=... scripts/deploy.sh recipient` (Lasna).
   Fund the reactive contract with ~1 lREACT and the verdict contract with
   0.05 Sepolia ETH via the callback proxy's `depositTo()`.
3. Start the watcher (above) on a 3-minute schedule.
4. Send ≥ 1,000 SENT from the build wallet to any address.
5. Within a couple of minutes: `TransferFlagged` on Lasna → Groq verdict →
   `submitDecision` → `VerdictRecorded` on Sepolia carrying the AI label.
   Verify with `cast`: `cast logs --rpc-url sepolia --address <verdict>
   --from-block <transfer-block>`.

## Why this is useful

Large-transfer triage is a real problem (AML monitoring, whale alerts,
exchange risk desks). Today it is done by off-chain dashboards that nobody
can audit. Sentinel puts the triage decision itself on-chain, with the
reason hash verifiable by anyone — a flagged transfer carries its AI verdict
in the same transaction record as the transfer.

## Security notes

- Testnets only (Sepolia + Lasna). No real money anywhere in this repo.
- The build keypair (`.wallet/keypair.json`) is **never committed**
  (`.gitignore`), never pasted on a command line, and only ever read at
  runtime by `scripts/deploy.sh` / `scripts/send_raw.py`. Rotate it if it
  ever leaves the build machine.
- `SentinelVerdict` only accepts callbacks from the Reactive system contract
  and only from its bound reactive contract (`_CALLBACK_SENDER` is
  immutable); `submitDecision` is owner-only.

## Links

- Event: https://dorahacks.io/hackathon/reactive-omni-buildathon/detail
- Reactive docs: https://dev.reactive.network
- Groq (free tier, `openai/gpt-oss-120b`): https://console.groq.com

## License

MIT — see [LICENSE](LICENSE).

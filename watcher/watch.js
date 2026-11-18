#!/usr/bin/env node
/**
 * Sentinel watcher — Groq AI in the loop (stage 2).
 *
 * Single-pass poller (NOT a long-running daemon): each run scans Lasna for
 * new TransferFlagged events from SentinelReactive v3, classifies each
 * flagged transfer with Groq gpt-oss-120b, and submits the AI decision
 * on-chain via submitDecision(). The callback to Sepolia then carries the
 * AI label + reasonHash (keccak256 of the model's one-sentence reason).
 *
 * Run it manually or from cron (every 3 min). State lives in state.json
 * (checkpoint block + processed decisions) so a VM restart loses nothing.
 * Failed items stay in state.retry and are retried on the next run.
 *
 * No npm dependencies — only Node built-ins (fetch, fs, child_process).
 * Private key: NEVER handled here. Lasna writes go through
 * scripts/send_raw.py, which reads .wallet/keypair.json at runtime.
 * Groq key: handled by watcher/groq_classify.py (env GROQ_API_KEY).
 *
 * Usage: node watch.js [--once]   (default: single pass and exit)
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { execFile } = require("child_process");
const { promisify } = require("util");
const execFileAsync = promisify(execFile);

const ROOT = path.resolve(__dirname, "..");
// Make sure `cast` (foundry) is on PATH even when run from cron.
process.env.PATH = `${process.env.HOME}/.foundry/bin:${process.env.PATH}`;
const STATE_FILE = path.join(__dirname, "state.json");
const LOG_FILE = path.join(__dirname, "decisions.jsonl");

const LASNA_RPC = "https://lasna-rpc.rnk.dev/";
const SEPOLIA_RPC = "https://ethereum-sepolia-rpc.publicnode.com";
const TOKEN = "0x1DAF205424104F8a9249bA5F3AD5466887a9C888";
const REACTIVE_V3 = "0xe755d37713c92c58a2fb09ffc8e75c6618bd1f82";
const VERDICT_V3 = "0x42c393834692a0c9bbb3910c34612b13e0b05f54";
const DEPLOY_BLOCK = 8640124; // Lasna block of the v3 reactive deploy (0x83eb7c)
const TOTAL_SUPPLY_SENT = 1_000_000n;
const TRANSFER_TOPIC0 =
  "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";
const FLAGGED_TOPIC0 =
  "0x035d7c61179e2e2b59ddb2f6d2f26289c95d7664b89860a44c091dca22c64346";
const PENDING_SEL = "0xaf6e6238"; // pending(uint256)
const BALANCEOF_SEL = "0x70a08231"; // balanceOf(address)

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const nowWib = () => new Date().toLocaleString("en-GB", { timeZone: "Asia/Jakarta" });
const log = (...a) => console.log(`[${nowWib()} WIB]`, ...a);

function fmtSent(wei) {
  const w = BigInt(wei);
  const whole = (w / 10n ** 18n).toString();
  const frac = (w % 10n ** 18n).toString().padStart(18, "0").replace(/0+$/, "");
  return frac ? `${whole}.${frac}` : whole;
}
const padTopic = (addr) => "0x" + "0".repeat(24) + addr.slice(2).toLowerCase();

async function rpc(url, method, params, tries = 4) {
  const body = JSON.stringify({ jsonrpc: "2.0", method, params, id: 1 });
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        signal: AbortSignal.timeout(30000),
      });
      const j = await res.json();
      if (j.error) throw new Error(`${method}: ${JSON.stringify(j.error)}`);
      return j.result;
    } catch (e) {
      lastErr = e;
      await sleep(3000 * (i + 1));
    }
  }
  throw lastErr;
}

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
  } catch {
    return { lastBlock: DEPLOY_BLOCK - 1, processed: {}, retry: {} };
  }
}
function saveState(s) {
  const tmp = STATE_FILE + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
  fs.renameSync(tmp, STATE_FILE);
}
function appendLog(record) {
  fs.appendFileSync(LOG_FILE, JSON.stringify({ ts: nowWib(), ...record }) + "\n");
}

async function run(cmd, args) {
  // NOTE: never pass `input` here — Node's execFile `input` option does not
  // reliably deliver stdin to the child in some environments (child blocks
  // forever on EOF). Pass data via temp files / argv instead.
  const opts = { timeout: 180000, maxBuffer: 4 * 1024 * 1024 };
  const { stdout } = await execFileAsync(cmd, args, opts);
  return stdout;
}

// --- Sepolia facts for one transfer (state BEFORE the transfer) ----------
async function gatherFacts(flag) {
  const { from, to, amountWei, txHash } = flag;
  const amountSent = fmtSent(amountWei);
  const amountPct = (Number(amountWei) / 1e18 / 1e6 * 100).toFixed(3);
  let sepBlock = null;
  try {
    const rc = await rpc(SEPOLIA_RPC, "eth_getTransactionReceipt", [txHash]);
    if (rc && rc.blockNumber) sepBlock = parseInt(rc.blockNumber, 16);
  } catch (e) {
    log(`  facts: receipt lookup failed (${e.message}), using latest-state facts`);
  }
  const atBlock = sepBlock ? sepBlock - 1 : "latest";
  const atTag = sepBlock ? "0x" + atBlock.toString(16) : "latest";

  const [senderBal, recipientBal, recipientTxCount] = await Promise.all([
    rpc(SEPOLIA_RPC, "eth_call", [{ to: TOKEN, data: BALANCEOF_SEL + padTopic(from).slice(2) }, atTag]),
    rpc(SEPOLIA_RPC, "eth_call", [{ to: TOKEN, data: BALANCEOF_SEL + padTopic(to).slice(2) }, atTag]),
    rpc(SEPOLIA_RPC, "eth_getTransactionCount", [to, atTag]),
  ]);

  // Prior transfers in a bounded window before the transfer block.
  // Sepolia public RPCs prune old history (error 4444) — start narrow and
  // shrink further on failure instead of dying. The sender's history for
  // this demo sits within a few hundred blocks anyway.
  async function logsWindowed(filter, sepBlock) {
    const endTag = sepBlock ? "0x" + (sepBlock - 1).toString(16) : "latest";
    for (const span of [5000, 1000, 200]) {
      const fromBlock = "0x" + Math.max(0, (sepBlock ?? 0) - span).toString(16);
      try {
        return await rpc(SEPOLIA_RPC, "eth_getLogs", [{ ...filter, fromBlock, toBlock: endTag }]);
      } catch (e) {
        if (!String(e.message).includes("pruned")) throw e;
        log(`  facts: log window ${span} pruned, shrinking`);
      }
    }
    log(`  facts: log history unavailable — prior-transfer counts set to 0`);
    return [];
  }
  const priorLogs = await logsWindowed(
    { address: TOKEN, topics: [TRANSFER_TOPIC0, padTopic(from)] }, sepBlock);
  let senderPriorTransfers = 0;
  let senderPriorVolume = 0n;
  for (const l of priorLogs || []) {
    if (l.transactionHash && l.transactionHash.toLowerCase() === txHash.toLowerCase()) continue;
    senderPriorTransfers++;
    senderPriorVolume += BigInt(l.data);
  }
  const recvLogs = await logsWindowed(
    { address: TOKEN, topics: [TRANSFER_TOPIC0, null, padTopic(to)] }, sepBlock);
  const recipientPriorTransfers = (recvLogs || []).filter(
    (l) => !(l.transactionHash && l.transactionHash.toLowerCase() === txHash.toLowerCase())
  ).length;

  // Sender balance AFTER the transfer (latest) — useful context for the model.
  const senderBalAfter = await rpc(SEPOLIA_RPC, "eth_call",
    [{ to: TOKEN, data: BALANCEOF_SEL + padTopic(from).slice(2) }, "latest"]);

  return {
    from, to, txHash,
    amountSent,
    amountPctSupply: amountPct,
    senderBalanceAfterSent: fmtSent(senderBalAfter),
    senderPriorTransfers,
    senderPriorVolumeSent: fmtSent(senderPriorVolume),
    recipientTxCount: parseInt(recipientTxCount, 16),
    recipientPriorTransfers,
    recipientBalanceBeforeSent: fmtSent(recipientBal),
  };
}

async function classify(facts) {
  const factsFile = `/tmp/sentinel-facts-${facts.txHash.slice(2, 10)}.json`;
  fs.writeFileSync(factsFile, JSON.stringify(facts));
  const out = await run("python3", [path.join(__dirname, "groq_classify.py"), factsFile]);
  return JSON.parse(out.trim().split("\n").pop());
}

async function submitDecision(flag, verdict) {
  const calldata = (await run("cast", [
    "calldata", "submitDecision(uint256,string,bytes32)",
    flag.txHash, verdict.label, verdict.reasonHash,
  ])).trim();
  const dataFile = `/tmp/submit-${flag.txHash.slice(2, 10)}.txt`;
  fs.writeFileSync(dataFile, calldata);
  const out = await run("python3", [
    path.join(ROOT, "scripts", "send_raw.py"),
    "--rpc", LASNA_RPC, "--to", REACTIVE_V3,
    "--data-file", dataFile, "--gas-limit", "1000000", "--wait",
  ]);
  const m = out.match(/tx_hash:\s*(0x[0-9a-fA-F]+)/);
  if (!m) throw new Error(`submitDecision broadcast failed: ${out.slice(0, 400)}`);
  if (!/receipt status:\s*0x1/.test(out)) throw new Error(`submitDecision tx mined but status != 1: ${out.slice(0, 400)}`);
  return m[1];
}

async function pendingOnChain(txHash) {
  const data = PENDING_SEL + txHash.slice(2).padStart(64, "0");
  const res = await rpc(LASNA_RPC, "eth_call", [{ to: REACTIVE_V3, data }, "latest"]);
  // returns (address from, address to, uint256 amount, bool decided)
  const amount = BigInt("0x" + res.slice(2 + 64 * 2, 2 + 64 * 3));
  const decided = res.slice(2 + 64 * 3, 2 + 64 * 4) !== "0".repeat(64);
  return { exists: amount > 0n, decided, amount };
}

async function processFlag(flag, state) {
  const { txHash } = flag;
  log(`Flagged transfer ${txHash} — ${fmtSent(flag.amountWei)} SENT ${flag.from} -> ${flag.to}`);
  const pend = await pendingOnChain(txHash);
  if (!pend.exists) {
    log(`  WARN: not pending on-chain (yet?) — will retry next run`);
    state.retry[txHash] = { ...flag, attempts: (state.retry[txHash]?.attempts || 0) + 1, error: "not-pending-on-chain" };
    return;
  }
  if (pend.decided) {
    log(`  already decided on-chain — marking processed`);
    state.processed[txHash] = { ...flag, status: "already-decided" };
    delete state.retry[txHash];
    return;
  }
  const facts = await gatherFacts(flag);
  log(`  facts: sender priors=${facts.senderPriorTransfers} (${facts.senderPriorVolumeSent} SENT), recipient txs=${facts.recipientTxCount}, recipient priors=${facts.recipientPriorTransfers}`);
  const verdict = await classify(facts);
  log(`  Groq verdict: ${verdict.label} — "${verdict.reason}" (reasonHash ${verdict.reasonHash})`);
  const submitTx = await submitDecision(flag, verdict);
  log(`  submitDecision tx: ${submitTx}`);
  // Build the stored record from explicit fields (flag may carry stale
  // retry bookkeeping like attempts/error — do not persist those).
  const record = {
    from: flag.from, to: flag.to, amountWei: flag.amountWei, txHash: flag.txHash,
    lasnaBlock: flag.lasnaBlock, lasnaTx: flag.lasnaTx,
    verdict, submitTx, status: "submitted", verdictContract: VERDICT_V3,
  };
  state.processed[txHash] = record;
  delete state.retry[txHash];
  appendLog(record);
}

async function main() {
  const state = loadState();
  const latest = parseInt(await rpc(LASNA_RPC, "eth_blockNumber", []), 16);
  log(`Watcher run — Lasna latest block ${latest}, checkpoint ${state.lastBlock}`);

  // Retry previously failed items first.
  for (const txHash of Object.keys(state.retry)) {
    const flag = state.retry[txHash];
    try {
      await processFlag(flag, state);
    } catch (e) {
      log(`  ERROR processing ${txHash}: ${e.message}`);
      state.retry[txHash] = { ...flag, attempts: (flag.attempts || 0) + 1, error: String(e.message).slice(0, 300) };
    }
    saveState(state);
  }

  // Scan new blocks.
  const fromBlock = state.lastBlock + 1;
  if (fromBlock <= latest) {
    const logs = await rpc(LASNA_RPC, "eth_getLogs", [{
      address: REACTIVE_V3,
      fromBlock: "0x" + fromBlock.toString(16),
      toBlock: "0x" + latest.toString(16),
      topics: [FLAGGED_TOPIC0],
    }]);
    log(`  ${logs.length} new TransferFlagged event(s) in blocks ${fromBlock}..${latest}`);
    for (const l of logs) {
      const flag = {
        from: "0x" + l.topics[1].slice(26),
        to: "0x" + l.topics[2].slice(26),
        amountWei: BigInt(l.data).toString(),
        txHash: "0x" + BigInt(l.topics[3]).toString(16).padStart(64, "0"),
        lasnaBlock: parseInt(l.blockNumber, 16),
        lasnaTx: l.transactionHash,
      };
      if (state.processed[flag.txHash]) { log(`  ${flag.txHash} already processed — skip`); continue; }
      try {
        await processFlag(flag, state);
      } catch (e) {
        log(`  ERROR processing ${flag.txHash}: ${e.message}`);
        state.retry[flag.txHash] = { ...flag, attempts: 1, error: String(e.message).slice(0, 300) };
      }
      saveState(state);
    }
  } else {
    log(`  no new blocks to scan`);
  }
  state.lastBlock = latest;
  saveState(state);
  log(`Watcher run done — checkpoint ${latest}, processed=${Object.keys(state.processed).length}, retry=${Object.keys(state.retry).length}`);
}

main().catch((e) => { console.error("FATAL:", e); process.exit(1); });

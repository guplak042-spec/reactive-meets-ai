#!/usr/bin/env python3
"""Classify one flagged SENT transfer with Groq gpt-oss-120b (free tier).

Reads transfer facts as JSON on stdin, asks the model for a strict-JSON
verdict, and prints {"label","reason","reasonHash"} to stdout.

The model — not a hardcoded rule in the watcher — decides the label. The
watcher only gathers on-chain facts and passes them along. The reason text
is hashed with keccak256; that hash is what goes on-chain (the verdict
contract stores label + reasonHash), so anyone can verify
keccak256(reason) == reasonHash.

Usage:
  echo '<facts json>' | python3 groq_classify.py          # shell use (stdin)
  python3 groq_classify.py <facts-file.json>               # watcher use (file)
Exit non-zero on any failure (bad reply, unknown label, API error).

NOTE: facts must come from a FILE when this helper is spawned from Node:
stdin delivery from Node's child_process is unreliable in some environments
(the child can block forever waiting for EOF). Do not pipe facts to this
script from Node — write a temp file and pass its path instead.

API key: set GROQ_API_KEY (free key: https://console.groq.com/keys). If it
is not set, the script falls back to the stored workspace credential when
one is available.
"""
import json
import os
import re
import sys
import urllib.request

try:
    sys.path.insert(0, "/opt/muse/skills/custom-connector-setup/bin")
    from dynamic_credentials import add_surrogate_to_request, read_json_response
    HAVE_SURROGATE = True
except Exception:
    HAVE_SURROGATE = False

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".ethlibs"))
from eth_utils import keccak

LABELS = {"normal", "whale", "suspicious"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        raise RuntimeError("redirect refused, verify the endpoint")


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            facts = json.load(f)
    else:
        facts = json.load(sys.stdin)

    prompt = (
        "You are a fraud-triage analyst for a token-monitoring system called Sentinel. "
        "Classify ONE ERC-20 token transfer. Reply with STRICT JSON only, no other text:\n"
        '{"label": "normal" | "whale" | "suspicious", "reason": "<one sentence, max 200 characters>"}\n\n'
        "Label guide (use your judgment on the facts, do not just apply cutoffs blindly):\n"
        '- "whale": an exceptionally large transfer relative to total supply or to the sender\'s usual size — a single move that could move the market.\n'
        '- "suspicious": patterns that look like laundering, draining, or testing: a large first-time transfer to a brand-new address with no history, a burst of rapid repeat transfers, round amounts to fresh wallets, or a sender emptying itself.\n'
        '- "normal": routine activity — modest size vs supply, known counterparties with history, no burst pattern.\n\n'
        "Transfer facts (all on-chain, Sepolia testnet, token SENT, total supply 1,000,000):\n"
        f"- amount: {facts['amountSent']} SENT ({facts['amountPctSupply']}% of total supply; threshold for flagging is 1,000 SENT)\n"
        f"- from: {facts['from']} (balance after transfer: {facts['senderBalanceAfterSent']} SENT; "
        f"transfers sent before this one (recent window): {facts['senderPriorTransfers']}, "
        f"volume sent before (recent window): {facts['senderPriorVolumeSent']} SENT)\n"
        f"- to: {facts['to']} (prior transactions on-chain: {facts['recipientTxCount']}; "
        f"prior token transfers received (recent window): {facts['recipientPriorTransfers']}; "
        f"token balance before this transfer: {facts['recipientBalanceBeforeSent']} SENT)\n"
        f"- txHash: {facts['txHash']}\n\n"
        "Classify it. Strict JSON only."
    )

    payload = json.dumps({
        "model": "openai/gpt-oss-120b",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        # gpt-oss spends most of a small budget on hidden reasoning; a 400
        # token budget truncated the visible JSON mid-reason (found live
        # 18 Nov 2026). Low reasoning effort + a bigger budget leaves room
        # for the full reply.
        "reasoning_effort": "low",
        "max_tokens": 800,
    }).encode()

    request = urllib.request.Request(
        "https://api.groq.com/openai/v1/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json", "User-Agent": "curl/8.5.0"},
        method="POST",
    )
    api_key = os.environ.get("GROQ_API_KEY")
    if api_key:
        request.add_header("Authorization", f"Bearer {api_key}")
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=120) as response:
            body = json.load(response)
    elif HAVE_SURROGATE:
        add_surrogate_to_request(request, "custom.groq", allowed_hosts=["api.groq.com"])
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=120) as response:
            body = read_json_response(response)
    else:
        raise RuntimeError("no Groq API key: set GROQ_API_KEY (https://console.groq.com/keys)")

    content = body["choices"][0]["message"]["content"]
    verdict = None
    m = re.search(r"\{.*\}", content, re.DOTALL)
    if m:
        try:
            verdict = json.loads(m.group(0))
        except json.JSONDecodeError:
            verdict = None
    if verdict is None:
        # Lenient fallback: the model sometimes truncates the JSON (budget
        # spent on reasoning). The label + a partial reason are still usable.
        lm = re.search(r'"label"\s*:\s*"(normal|whale|suspicious)"', content)
        rm = re.search(r'"reason"\s*:\s*"([^"]*)', content)
        if lm and rm:
            verdict = {"label": lm.group(1), "reason": rm.group(1)}
    if verdict is None:
        raise RuntimeError(f"model did not return JSON: {content[:300]!r}")
    label = str(verdict["label"]).strip().lower()
    reason = str(verdict["reason"]).strip()
    if label not in LABELS:
        raise RuntimeError(f"unknown label {label!r} in {verdict!r}")
    if not reason:
        raise RuntimeError(f"empty reason in {verdict!r}")
    reason = reason[:200]
    reason_hash = "0x" + keccak(reason.encode()).hex()
    print(json.dumps({"label": label, "reason": reason, "reasonHash": reason_hash,
                      "model": "openai/gpt-oss-120b"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

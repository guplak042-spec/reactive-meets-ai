#!/usr/bin/env python3
"""Send a signed legacy transaction to an EVM RPC that foundry's HTTP client
cannot reliably reach (the Lasna RPC drops forge/cast TLS connections
intermittently, while plain urllib/curl works). Signs OFFLINE with
eth-account; the private key is read from the keypair file at runtime and
never appears on the command line or in logs.

Keypair location: $KEYPAIR, or .wallet/keypair.json under the repo root.
That file is gitignored and must never be committed.

Usage:
  send_raw.py --rpc <url> --data-file <hex file> [--to <addr>] [--value-wei N]
              [--gas-limit N] [--gas-price-wei N] [--wait]
Prints the tx hash (and receipt status with --wait).
"""
import argparse
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".ethlibs"))

from eth_account import Account
from eth_utils import to_checksum_address

_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
KEYPAIR = os.environ.get("KEYPAIR", os.path.join(_REPO_ROOT, ".wallet", "keypair.json"))


def rpc(url, method, params, tries=4):
    body = json.dumps(
        {"jsonrpc": "2.0", "method": method, "params": params, "id": 1}
    ).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}
    )
    last = None
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)["result"]
        except Exception as e:  # Lasna RPC drops/timeouts intermittently; retry
            last = e
            time.sleep(3 * (attempt + 1))
    raise last


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rpc", required=True)
    ap.add_argument("--data-file", required=True)
    ap.add_argument("--to", default=None)
    ap.add_argument("--value-wei", type=int, default=0)
    ap.add_argument("--gas-limit", type=int, default=3_000_000)
    ap.add_argument("--gas-price-wei", type=int, default=None)
    ap.add_argument("--wait", action="store_true")
    args = ap.parse_args()

    with open(KEYPAIR) as f:
        kp = json.load(f)
    acct = Account.from_key(kp["private_key"])
    sender = acct.address

    chain_id = int(rpc(args.rpc, "eth_chainId", []), 16)
    nonce = int(rpc(args.rpc, "eth_getTransactionCount", [sender, "pending"]), 16)
    gas_price = args.gas_price_wei or int(rpc(args.rpc, "eth_gasPrice", []), 16)
    with open(args.data_file) as f:
        data = f.read().strip()
    if data.startswith("0x"):
        data = data[2:]
    data_bytes = bytes.fromhex(data)

    tx = {
        "chainId": chain_id,
        "nonce": nonce,
        "gasPrice": gas_price,
        "gas": args.gas_limit,
        "value": args.value_wei,
        "data": data_bytes,
    }
    if args.to:
        tx["to"] = to_checksum_address(args.to)
    signed = acct.sign_transaction(tx)
    raw = "0x" + signed.raw_transaction.hex()
    tx_hash = rpc(args.rpc, "eth_sendRawTransaction", [raw])
    print("tx_hash:", tx_hash)
    print("from:", sender, "nonce:", nonce, "gas_price_wei:", gas_price)
    if args.wait:
        for _ in range(60):
            rc = rpc(args.rpc, "eth_getTransactionReceipt", [tx_hash])
            if rc:
                print("receipt status:", rc.get("status"), "block:", rc.get("blockNumber"))
                print("contractAddress:", rc.get("contractAddress"))
                print("gasUsed:", rc.get("gasUsed"))
                break
            time.sleep(2)
        else:
            print("receipt: not mined after 120s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env bash
# Deploy helper for Sentinel (Sepolia + Lasna).
# Reads the private key from .wallet/keypair.json at runtime — NEVER paste the
# key on the command line (it would leak into shell history and logs), so
# deploys must go through this script (or --unlocked on anvil).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY=$(python3 -c "import json;print(json.load(open('$ROOT/.wallet/keypair.json'))['private_key'])")
SENDER=$(python3 -c "import json;print(json.load(open('$ROOT/.wallet/keypair.json'))['address'])")
cd "$ROOT/contracts"

usage() {
  echo "Usage: $0 <token|reactive|verdict|recipient>"
  echo "  Env: TOKEN=<token addr> REACTIVE=<reactive addr> RECIPIENT=<verdict addr>"
  echo "  Order: token (Sepolia) -> reactive (Lasna) -> verdict (Sepolia) -> recipient (Lasna)"
  exit 1
}

[ $# -eq 1 ] || usage
case "$1" in
  token)
    forge script script/DeployToken.s.sol --rpc-url sepolia --broadcast \
      --private-key "$KEY" --sender "$SENDER" ;;
  reactive)
    [ -n "${TOKEN:-}" ] || { echo "TOKEN env required"; exit 1; }
    TOKEN="$TOKEN" forge script script/DeployReactive.s.sol --rpc-url lasna --broadcast \
      --private-key "$KEY" --sender "$SENDER" ;;
  verdict)
    [ -n "${REACTIVE:-}" ] || { echo "REACTIVE env required"; exit 1; }
    REACTIVE="$REACTIVE" forge script script/DeployVerdict.s.sol --rpc-url sepolia --broadcast \
      --private-key "$KEY" --sender "$SENDER" ;;
  recipient)
    [ -n "${REACTIVE:-}" ] && [ -n "${RECIPIENT:-}" ] || { echo "REACTIVE and RECIPIENT env required"; exit 1; }
    REACTIVE="$REACTIVE" RECIPIENT="$RECIPIENT" forge script script/SetRecipient.s.sol --rpc-url lasna --broadcast \
      --private-key "$KEY" --sender "$SENDER" ;;
  *) usage ;;
esac

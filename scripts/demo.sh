#!/usr/bin/env bash
# End-to-end demonstration of the Price Sentinel loop, run against the live
# testnet deployment recorded in deployments.json:
#
#   1. Deposit Sepolia ETH into the vault.
#   2. Set an in-band price (2100). The sentinel sees it; nothing happens.
#   3. Set an out-of-band price (3000). The sentinel reacts on Lasna and the
#      callback freezes withdrawals on Sepolia. A withdrawal attempt reverts.
#   4. Set an in-band price again (2200). The callback releases the vault and
#      the withdrawal succeeds.
#
# Every step prints the transaction hash; callback arrivals are detected by
# polling the vault's protectedMode flag. Evidence is appended to
# demo/evidence.md.
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$PATH:$HOME/.foundry/bin"
set -a; source .env; set +a

SEPOLIA_RPC="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
LASNA_RPC="${LASNA_RPC_URL:-https://lasna-rpc.rnk.dev/}"
FEED=$(python3 -c "import json; print(json.load(open('deployments.json'))['mockPriceFeed']['address'])")
SENTINEL=$(python3 -c "import json; print(json.load(open('deployments.json'))['priceSentinel']['address'])")
VAULT=$(python3 -c "import json; print(json.load(open('deployments.json'))['guardedVault']['address'])")
mkdir -p demo
EVIDENCE=demo/evidence.md

say() { echo; echo "### $*"; echo "### $*" >> "$EVIDENCE"; }
log() { echo "$*"; echo "$*" >> "$EVIDENCE"; }

protected_mode() {
  cast call "$VAULT" "protectedMode()(bool)" --rpc-url "$SEPOLIA_RPC"
}

wait_for_mode() { # $1 = expected (true/false)
  local want=$1
  for i in $(seq 1 36); do
    local got
    got=$(protected_mode)
    [ "$got" = "$want" ] && return 0
    sleep 10
  done
  echo "TIMEOUT waiting for protectedMode=$want (last seen: $(protected_mode))"
  return 1
}

say "1. Deposit 0.01 Sepolia ETH into the vault"
TX=$(cast send "$VAULT" "deposit()" --value 0.01ether \
  --rpc-url "$SEPOLIA_RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
log "deposit tx: $TX"

say "2. In-band price: setPrice(2100) — expect no protection"
TX=$(cast send "$FEED" "setPrice(uint256)" 2100 \
  --rpc-url "$SEPOLIA_RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
log "origin tx (in-band tick): $TX"
sleep 30
log "protectedMode after in-band tick: $(protected_mode) (expected: false)"

say "3. Out-of-band price: setPrice(3000) — expect protection"
TX=$(cast send "$FEED" "setPrice(uint256)" 3000 \
  --rpc-url "$SEPOLIA_RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
log "origin tx (out-of-band tick): $TX"
wait_for_mode true
log "protectedMode: true — callback delivered, withdrawals frozen"
CB=$(cast logs --rpc-url "$SEPOLIA_RPC" --from-block "$(( $(cast block-number --rpc-url "$SEPOLIA_RPC") - 5000 ))" --address "$VAULT" \
  "ProtectionApplied(uint256,bool,uint256)" --json | python3 -c "import json,sys; print(json.load(sys.stdin)[-1]['transactionHash'])")
log "callback tx (ProtectionApplied): $CB"

say "3b. Withdrawal attempt while protected — expect a revert"
if cast call "$VAULT" "withdraw(uint256)" 1000000000000000 --from "$(cast wallet address --private-key "$PRIVATE_KEY")" --rpc-url "$SEPOLIA_RPC" 2>&1 | grep -qiE "WithdrawalsProtected|0xf2b7d6ee"; then
  log "withdraw reverted with WithdrawalsProtected, as designed"
else
  log "WARNING: withdraw simulation did not revert as expected"
fi

say "4. Back in band: setPrice(2200) — expect release"
TX=$(cast send "$FEED" "setPrice(uint256)" 2200 \
  --rpc-url "$SEPOLIA_RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
log "origin tx (release tick): $TX"
wait_for_mode false
log "protectedMode: false — vault released"
CB=$(cast logs --rpc-url "$SEPOLIA_RPC" --from-block "$(( $(cast block-number --rpc-url "$SEPOLIA_RPC") - 5000 ))" --address "$VAULT" \
  "ProtectionApplied(uint256,bool,uint256)" --json | python3 -c "import json,sys; print(json.load(sys.stdin)[-1]['transactionHash'])")
log "callback tx (ProtectionApplied): $CB"

say "5. Withdrawal now succeeds"
TX=$(cast send "$VAULT" "withdraw(uint256)" 10000000000000000 \
  --rpc-url "$SEPOLIA_RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])")
log "withdraw tx: $TX"

say "Reactive transactions on Lasna"
# The explorer API is not always reachable; scan the sentinel's
# ProtectionRequested events straight from the Lasna RPC instead
# (getLogs there is capped at 30k blocks per request, so scan in chunks).
python3 - "$SENTINEL" "$LASNA_RPC" <<'PYEOF' | tee -a "$EVIDENCE"
import json, subprocess, sys
sentinel, rpc = sys.argv[1], sys.argv[2]
def cast(*args):
    out = subprocess.run(["cast", *args], capture_output=True, text=True)
    return out.stdout
now = int(cast("block-number", "--rpc-url", rpc))
events = []
start = now
for _ in range(8):
    frm = max(0, start - 29999)
    raw = cast("logs", "--rpc-url", rpc, "--from-block", str(frm),
               "--to-block", str(start), "--address", sentinel,
               "ProtectionRequested(bool,uint256)", "--json")
    try:
        events += json.loads(raw)
    except Exception:
        pass
    start = frm - 1
    if start < 0:
        break
events.sort(key=lambda e: int(e["blockNumber"], 16))
for e in events:
    data = e["data"]
    protect = int(data[2:66], 16) == 1
    price = int(data[66:130], 16)
    print(f"lasna react tx (ProtectionRequested protect={str(protect).lower()}, price={price}): {e['transactionHash']}")
PYEOF

echo
echo "Demo complete. Evidence written to $EVIDENCE"

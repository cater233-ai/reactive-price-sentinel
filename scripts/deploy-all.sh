#!/usr/bin/env bash
# Deploys the full Price Sentinel system and records the result in
# deployments.json. Stops early with a clear message if the deployer wallet
# is not funded — testnet funds are the only external prerequisite.
#
# Order (per the Reactive docs, "Callback Contracts → Deployment Order"):
#   1. MockPriceFeed      on Ethereum Sepolia (origin)
#   2. lREACT swap        Sepolia ETH -> Reactive faucet contract -> lREACT on Lasna
#   3. PriceSentinel      on Reactive Lasna (reactive contract first)
#   4. GuardedVault       on Ethereum Sepolia (needs the sentinel's address)
#   5. WireUp             sentinel.setRecipient(vault) on Lasna
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$PATH:$HOME/.foundry/bin"
set -a; source .env; set +a

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
SEPOLIA_RPC="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
LASNA_RPC="${LASNA_RPC_URL:-https://lasna-rpc.rnk.dev/}"
FAUCET_SEPOLIA=0x9b9BB25f1A81078C544C829c5EB7822d747Cf434
SWAP_ETH="${FAUCET_SWAP_ETH:-0.02}"

echo "Deployer: $DEPLOYER"
SEP_BAL=$(cast balance --rpc-url "$SEPOLIA_RPC" "$DEPLOYER")
echo "Sepolia balance: $SEP_BAL wei"
if [ "$SEP_BAL" = "0" ]; then
  echo "STOP: deployer has no Sepolia ETH. Fund $DEPLOYER with ~0.1 Sepolia ETH"
  echo "from any testnet faucet, then re-run this script."
  exit 1
fi

extract_addr() { # $1 = broadcast run-latest.json path
  python3 -c "import json,sys; d=json.load(open('$1')); print([t for t in d['transactions'] if t['transactionType']=='CREATE'][0]['contractAddress'])"
}

echo "== 1/5 Deploy MockPriceFeed (Sepolia)"
forge script script/DeployFeed.s.sol --rpc-url "$SEPOLIA_RPC" --broadcast -q
FEED=$(extract_addr broadcast/DeployFeed.s.sol/11155111/run-latest.json)
echo "FEED_ADDRESS=$FEED"

echo "== 2/5 Swap $SWAP_ETH Sepolia ETH for lREACT (Reactive faucet)"
cast send "$FAUCET_SEPOLIA" "request(address)" "$DEPLOYER" \
  --value "${SWAP_ETH}ether" --rpc-url "$SEPOLIA_RPC" --private-key "$PRIVATE_KEY" -q
for i in $(seq 1 30); do
  LREACT=$(cast balance --rpc-url "$LASNA_RPC" "$DEPLOYER")
  [ "$LREACT" != "0" ] && break
  sleep 10
done
echo "Lasna balance: $LREACT wei lREACT"
if [ "$LREACT" = "0" ]; then
  echo "STOP: lREACT did not arrive within 5 minutes. The faucet sometimes lags;"
  echo "check https://lasna.reactscan.net/address/$DEPLOYER and re-run from step 3"
  echo "by deploying the sentinel manually (see README)."
  exit 1
fi

echo "== 3/5 Deploy PriceSentinel (Lasna)"
FEED_ADDRESS=$FEED forge script script/DeploySentinel.s.sol --rpc-url "$LASNA_RPC" --broadcast -q
SENTINEL=$(extract_addr broadcast/DeploySentinel.s.sol/5318007/run-latest.json)
echo "SENTINEL_ADDRESS=$SENTINEL"

echo "== 4/5 Deploy GuardedVault (Sepolia)"
SENTINEL_ADDRESS=$SENTINEL forge script script/DeployVault.s.sol --rpc-url "$SEPOLIA_RPC" --broadcast -q
VAULT=$(extract_addr broadcast/DeployVault.s.sol/11155111/run-latest.json)
echo "VAULT_ADDRESS=$VAULT"

echo "== 5/5 Wire sentinel -> vault (Lasna)"
SENTINEL_ADDRESS=$SENTINEL VAULT_ADDRESS=$VAULT \
  forge script script/WireUp.s.sol --rpc-url "$LASNA_RPC" --broadcast -q

python3 - "$FEED" "$SENTINEL" "$VAULT" "$DEPLOYER" <<'EOF'
import json, sys
feed, sentinel, vault, deployer = sys.argv[1:5]
json.dump({
    "deployer": deployer,
    "mockPriceFeed": {"chain": "Ethereum Sepolia (11155111)", "address": feed},
    "priceSentinel": {"chain": "Reactive Lasna (5318007)", "address": sentinel},
    "guardedVault": {"chain": "Ethereum Sepolia (11155111)", "address": vault},
}, open("deployments.json", "w"), indent=2)
print("Wrote deployments.json")
EOF
echo "Done. Run scripts/demo.sh for the end-to-end demonstration."

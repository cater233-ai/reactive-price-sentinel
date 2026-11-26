#!/usr/bin/env bash
# Prints the live state of the whole system from the three chains' RPCs.
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$PATH:$HOME/.foundry/bin"
set -a; source .env; set +a

SEPOLIA_RPC="${SEPOLIA_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
LASNA_RPC="${LASNA_RPC_URL:-https://lasna-rpc.rnk.dev/}"
FEED=$(python3 -c "import json; print(json.load(open('deployments.json'))['mockPriceFeed']['address'])")
SENTINEL=$(python3 -c "import json; print(json.load(open('deployments.json'))['priceSentinel']['address'])")
VAULT=$(python3 -c "import json; print(json.load(open('deployments.json'))['guardedVault']['address'])")

echo "MockPriceFeed  (Sepolia) $FEED"
echo "  price:            $(cast call "$FEED" 'price()(uint256)' --rpc-url "$SEPOLIA_RPC")"
echo "PriceSentinel  (Lasna)   $SENTINEL"
echo "  balance (lREACT): $(cast balance "$SENTINEL" --rpc-url "$LASNA_RPC")"
echo "  band:             [$(cast call "$SENTINEL" 'floor()(uint256)' --rpc-url "$LASNA_RPC"), $(cast call "$SENTINEL" 'ceiling()(uint256)' --rpc-url "$LASNA_RPC")]"
echo "  lastPrice:        $(cast call "$SENTINEL" 'lastPrice()(uint256)' --rpc-url "$LASNA_RPC")"
echo "  protectionOn:     $(cast call "$SENTINEL" 'protectionOn()(bool)' --rpc-url "$LASNA_RPC")"
echo "GuardedVault   (Sepolia) $VAULT"
echo "  balance (ETH):    $(cast balance "$VAULT" --rpc-url "$SEPOLIA_RPC")"
echo "  protectedMode:    $(cast call "$VAULT" 'protectedMode()(bool)' --rpc-url "$SEPOLIA_RPC")"
echo "  triggerCount:     $(cast call "$VAULT" 'triggerCount()(uint256)' --rpc-url "$SEPOLIA_RPC")"
echo "  lastTriggerPrice: $(cast call "$VAULT" 'lastTriggerPrice()(uint256)' --rpc-url "$SEPOLIA_RPC")"

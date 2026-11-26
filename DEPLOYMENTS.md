# Deployments

Status: **pending testnet funds.** Contracts are built, unit-tested (14/14
passing) and validated against the live RPCs in deploy simulation. The deploy
scripts stop cleanly at step 0 until the deployer wallet holds Sepolia ETH.

## Deployer

| Role | Address |
|---|---|
| Deployer / contract owner (testnet only) | `0xBD6593d8E45590956da1F25458fB694C8535Df28` |

Funding needed: ~0.1 Sepolia ETH at the deployer address. Of that, 0.02 ETH is
swapped to 2 lREACT through Reactive's official faucet contract on Sepolia
(`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`, 1 ETH → 100 lREACT).

## Contracts

| Contract | Chain | Address | Deploy tx |
|---|---|---|---|
| MockPriceFeed | Ethereum Sepolia (11155111) | _pending_ | _pending_ |
| PriceSentinel | Reactive Lasna (5318007) | _pending_ | _pending_ |
| GuardedVault | Ethereum Sepolia (11155111) | _pending_ | _pending_ |

## Full-loop evidence (from `scripts/demo.sh`, to be filled after the run)

| Leg | Tx hash |
|---|---|
| Origin event — in-band tick `setPrice(2100)` | _pending_ |
| Origin event — out-of-band tick `setPrice(3000)` | _pending_ |
| Reactive transaction on Lasna (`react()`) | _pending_ |
| Callback on Sepolia — protection applied | _pending_ |
| Origin event — release tick `setPrice(2200)` | _pending_ |
| Callback on Sepolia — protection released | _pending_ |
| Withdrawal after release | _pending_ |

Explorers: Sepolia — https://sepolia.etherscan.io · Lasna — https://lasna.reactscan.net

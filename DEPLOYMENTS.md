# Deployments

Status: **deployed live on testnet (2026-11-26).** All three contracts are
deployed and wired; state verified on-chain via `scripts/status.sh`
(feed price 2000, sentinel band [1500, 2500] with 2 lREACT balance, vault
holding 0.05 ETH, `protectedMode` false).

## Deployer

| Role | Address |
|---|---|
| Deployer / contract owner (testnet only) | `0xBD6593d8E45590956da1F25458fB694C8535Df28` |

Funding used: the deployer was funded with 0.8725 Sepolia ETH from the public
PoW faucet. 0.04 ETH in total was swapped to 4 lREACT through Reactive's
official faucet contract on Sepolia
(`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`, 1 ETH → 100 lREACT): a first
0.02 ETH swap left the deployer 0.09 lREACT short of the sentinel deployment
cost (2 lREACT contract funding + gas), so a second 0.02 ETH swap followed.

## Contracts

| Contract | Chain | Address | Deploy tx |
|---|---|---|---|
| MockPriceFeed | Ethereum Sepolia (11155111) | `0x86c7c9416e9e0500c4749fc183cccdead1bb0d94` | `0xd44b96b6e04f68c444bcdd329992f7c1571c1da6d4611164033979284c46eb1b` |
| PriceSentinel | Reactive Lasna (5318007) | `0x86c7c9416e9e0500c4749fc183cccdead1bb0d94` | `0xa272a199614d28ecf6982489668c6e46727d056284754f07f1891883d79aa74d` |
| GuardedVault | Ethereum Sepolia (11155111) | `0xd1ce2585674ecf60b8b441820caf9bc6b66ab4f4` | `0xc0dc52e75c63dbe2adbdeecab15fc8ce2ff11c55a4f545523fe449fccdb4feb2` |

Note: MockPriceFeed (Sepolia) and PriceSentinel (Lasna) share an address —
both were the deployer's nonce-0 CREATE on their respective chains. The
bytecode at that address differs per chain (verified on-chain).

Wiring: `sentinel.setRecipient(vault)` on Lasna, tx
`0xab11cd10c1ab95687a4439c38b22581c2056dc01a958386da5f0d4314fcb6912`.
lREACT funding: two faucet swaps of 0.02 Sepolia ETH each
(`0x4a5c6c3f267ac01b9842b88b47fd8794c0cebbbe36e83fecab56c5a79619d9e9`,
`0x031e9aff49c6a92f5c69cdc272db70a7edf1844ebfcb8797d00fa49e684aaef4`),
4 lREACT total received on Lasna.

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

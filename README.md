# Price Sentinel — a set-and-forget vault guardian

**Track:** Reactive Omni Buildathon · *Set It and Forget It*
**Networks:** Ethereum Sepolia (origin & destination) · Reactive Lasna (reactive layer)

Price Sentinel watches a price for you and protects your vault when the price
leaves a band you chose — no keeper, no bot, no server to keep alive. You set a
floor and a ceiling once. If the price breaks out of the band, withdrawals from
the vault freeze automatically; when the price comes back inside the band, they
unfreeze. The watcher is a *reactive contract* on Reactive Network: it
subscribes to events on Ethereum Sepolia and, when its condition fires, the
network itself delivers a callback transaction to the vault.

## How it works

```
Ethereum Sepolia                     Reactive Lasna                 Ethereum Sepolia
┌────────────────┐   PriceUpdated   ┌──────────────────┐  callback  ┌────────────────┐
│ MockPriceFeed  │ ───────────────▶ │  PriceSentinel   │ ─────────▶ │  GuardedVault  │
│ (event source) │                  │  (reactive)      │            │  (destination) │
└────────────────┘                  └──────────────────┘            └────────────────┘
                                     band check in react()           applyProtection()
```

1. `MockPriceFeed.setPrice()` emits `PriceUpdated(price, updatedAt)` on Sepolia.
   In production this role belongs to a real oracle or DEX pool; the sentinel
   reacts to the event, so the source can be replaced without touching the
   rest of the system.
2. `PriceSentinel` is subscribed to that event. The Reactive system contract
   calls its `react()` with the log. The sentinel compares the price against
   its band and **only acts on transitions**: in-band → out-of-band orders
   protection, out-of-band → in-band orders release. Repeated out-of-band
   ticks cost nothing and cannot spam the vault.
3. On a transition the sentinel calls `requestCallbackV_1_0` on the system
   contract. Reactive Network posts a transaction on Sepolia through its
   callback proxy, which calls `GuardedVault.applyProtection(...)`.
4. The vault flips `protectedMode`. While it is on, every `withdraw()` reverts
   with `WithdrawalsProtected`. The callback also records the trigger price
   and time on-chain.

### Security properties

- `react()` accepts calls only from the Reactive system contract
  (`onlySystem`), so nobody can feed the sentinel a fabricated log.
- The vault authenticates callbacks twice (the pattern the Reactive docs
  prescribe): the caller must be Sepolia's callback proxy
  (`onlyServiceProvider`), and the address the network injects into the
  payload must be the authorized sentinel (`onlyCallbackSender`).
- Band and recipient changes are owner-only; `coverDebt()` is deliberately
  open because it can only restart a contract, never move funds.

### Funding model (and one documented limitation)

Both Reactive-side execution and destination callbacks are paid by the
contracts themselves: the sentinel holds lREACT, the vault holds Sepolia ETH,
each funded at deployment. In this demo the vault's callback float and user
deposits share one balance, so callback charges are effectively paid from the
float the operator deposited at deployment. A production version should
escrow callback fees separately from user funds.

## Repository layout

```
src/        MockPriceFeed.sol · PriceSentinel.sol · GuardedVault.sol
script/     Foundry deploy scripts (feed, sentinel, vault, wiring)
scripts/    deploy-all.sh · demo.sh · status.sh
test/       Unit tests, incl. a mock system contract etched at 0x8888…8888
demo/       Demo evidence and the video shot list / narration script
lib/        forge-std + Reactive's reactive-lib-omni (git submodules)
```

The contracts build on Reactive's official `reactive-lib-omni`
(`AbstractReactive`, `AbstractCallback`) — no protocol code is reimplemented.

## Build and test

```bash
git clone --recurse-submodules https://github.com/cater233-ai/reactive-price-sentinel
cd reactive-price-sentinel
forge build
forge test        # 14 tests: band logic, transition-only callbacks, auth, freeze/release
```

## Deploy (testnet)

Prerequisite: a deployer wallet funded with ~0.1 Sepolia ETH (any public
Sepolia faucet). The deploy script converts part of it to lREACT through
Reactive's official faucet contract (1 ETH → 100 lREACT).

```bash
cp .env.example .env   # fill in PRIVATE_KEY (testnet only)
./scripts/deploy-all.sh
```

`deploy-all.sh` follows the documented deployment order — feed, faucet swap,
sentinel (reactive first), vault (it needs the sentinel's address), then
wiring — and writes the addresses to `deployments.json`. All three deploy
scripts were validated against the live RPCs in simulation mode.

## Run the demo

```bash
./scripts/demo.sh    # deposits, ticks the price in/out of band, shows the
                     # freeze, the reverted withdrawal, the release, and a
                     # successful withdrawal; evidence lands in demo/evidence.md
./scripts/status.sh  # live state of all three contracts from RPC reads
```

## Deployment status

See [DEPLOYMENTS.md](DEPLOYMENTS.md). Contracts are built, unit-tested
(14/14) and deploy-simulated against the live networks; the on-chain
deployment runs as soon as the deployer wallet holds testnet funds.

## License

MIT — see [LICENSE](LICENSE).

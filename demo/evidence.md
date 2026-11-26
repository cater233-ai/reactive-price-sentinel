### 1. Deposit 0.01 Sepolia ETH into the vault
deposit tx: 0x775eb50ef069fb6ff3a59984c93242f4a8cd36558aa7cb7c76b2257ac58107ab
### 2. In-band price: setPrice(2100) — expect no protection
origin tx (in-band tick): 0x69d4bed732722d643a6de4d97e5e612668aceb74b8183d3b1e1a10a89470894e
protectedMode after in-band tick: false (expected: false)
### 3. Out-of-band price: setPrice(3000) — expect protection
origin tx (out-of-band tick): 0x124f67ea46ff1b884b748ced201ee79958cc25eb99f90ef2d3bc1a7d5ad2a153
protectedMode: true — callback delivered, withdrawals frozen
callback tx (ProtectionApplied): 0xa3a5700e1c8b93d71e9c845cb186dfe22c47f2e3a625e3ff83e3d11f428d3214
### 3b. Withdrawal attempt while protected — expect a revert
withdraw reverted with WithdrawalsProtected, as designed — confirmed in a
follow-up protected-state check after this run (the in-script grep missed
cast's error format on this run; raw output: "Error: execution reverted:
WithdrawalsProtected", error data 0xf2b7d6ee; retest origin tick
0x6bc8e2ae7f48306e36e38a3aaa87e7592bf6f93c7a5766db8c9a760f10a40ac0,
released again with tick
0xb7cbb0e0be824c74be9a88663a8dbd6dc1da8e1e7767180af7041e254780d483)
### 4. Back in band: setPrice(2200) — expect release
origin tx (release tick): 0x36cb0de1355a702bf90a40852dfa59bc2a481e4db4a32000965595c0bcc92d74
protectedMode: false — vault released
callback tx (ProtectionApplied): 0xb24d9052f0559de0dbe2b842a47b66de4d7385170730aec9161d6bbde5005124
### 5. Withdrawal now succeeds
withdraw tx: 0xa59fbc31f60086e71577f5ae7f94e86269b5d4dd6ab426883f3bcc82980f628d
### Reactive transactions on Lasna
lasna react tx (ProtectionRequested protect=true, price=3000): 0xb1272c7013a5c5c73d39e8b0ccd4616212e28e6f78174edb6e1dc63a405f38d2
lasna react tx (ProtectionRequested protect=false, price=2200): 0x2751e6882f4619e23344cb78e5a375a168b2130861a7c00aa0639ecd19133d0f

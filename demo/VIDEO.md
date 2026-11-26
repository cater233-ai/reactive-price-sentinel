# Demo video — shot list and narration script

Status: **ready to produce as soon as the live deployment exists.** The video
must show real transactions, so it is recorded after `scripts/deploy-all.sh`
and one full `scripts/demo.sh` run. Target length ≈ 2 min 20 s (limit: under
3 minutes). Production pattern (same as our previous entry): headless Chrome
screenshots of terminal + explorer pages, stitched with ffmpeg, English
narration as a TTS voice track.

## Shot list

| # | Time | Visual | Source |
|---|---|---|---|
| 1 | 0:00–0:08 | Title card: "Price Sentinel — a set-and-forget vault guardian" + track line | generated card |
| 2 | 0:08–0:30 | Terminal: `scripts/status.sh` output — three contracts, band [1500, 2500], price 2000, protection off | live terminal capture |
| 3 | 0:30–0:50 | Terminal: demo step 2 — `setPrice(2100)`, wait, `protectedMode` still false. Caption: "In band: the sentinel sees it and does nothing." | live terminal capture |
| 4 | 0:50–1:15 | Terminal: demo step 3 — `setPrice(3000)`, poll flips to `protectedMode: true`. Then the withdrawal attempt reverting with `WithdrawalsProtected` | live terminal capture |
| 5 | 1:15–1:40 | Browser: the Lasna explorer page for the sentinel's `react()` transaction, then the Sepolia explorer page for the callback transaction (`ProtectionApplied` log) | lasna.reactscan.net + sepolia.etherscan.io, hashes from demo/evidence.md |
| 6 | 1:40–2:05 | Terminal: demo steps 4–5 — `setPrice(2200)`, release callback lands, withdrawal succeeds | live terminal capture |
| 7 | 2:05–2:20 | End card: repo URL, the three contract addresses, "Set it once. It watches while you don't." | generated card |

## Narration script (English, ≈55–65 seconds of speech)

> This is Price Sentinel, a set-and-forget guardian for a vault on Ethereum
> Sepolia. I set a price band once — fifteen hundred to twenty-five hundred —
> and a reactive contract on Reactive Lasna watches the price feed for me.
> While the price stays inside the band, nothing happens. When it breaks
> above the ceiling, the sentinel reacts on Lasna and Reactive delivers a
> callback to Sepolia: the vault freezes withdrawals on its own, and this
> withdrawal attempt is rejected. When the price returns inside the band, a
> second callback releases the vault, and the same withdrawal goes through.
> No keeper, no bot, no server — the rule lives on-chain, and it only acts on
> transitions, so it never spams the vault. Set it once, and forget it.

## Capture notes

- Run `scripts/demo.sh` once first; use the hashes in `demo/evidence.md` for
  the explorer shots so every screen shows the real loop.
- Terminal font ≥ 20 px, window 1440×1000, same framing as the title card.
- Do not show `.env` or any key material in any frame. The deployer address
  is safe to show (testnet only).

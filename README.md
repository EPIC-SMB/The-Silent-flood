# Silent Flood — Roblox Game

A horror-survival obby inspired by the trending "DONT SPLASH" style games.
Navigate flooded rooms without splashing — a blind monster ("The Listener") hunts by sound.
Throw pebbles to distract it, open valves at the Maintenance Lock, then sprint for the exit as the water rises.

**Genre:** Horror obby / survival
**Max players per server:** 10
**Floors:** 8 (escalating difficulty)
**Round time:** 5 minutes + 10s intermission

---

## Controls

| Key / Action | Effect |
|---|---|
| WASD | Move |
| Space | Jump |
| Left Click | Throw pebble (distraction) |
| E | Open valve (Maintenance Lock floor) |
| F | Revive (if you have a Revive Token) |
| Left Shift | Sprint |
| Tab | Open / close store |

Mobile: on-screen buttons mirror the above.

---

## Free vs Paid

### Free players get a COMPLETE loop
- Earn **Coins** from every escape (50 × floor, +rep).
- Spend Coins in the store on real upgrades: Throwing Range, Pebble Capacity, Rescue Speed, Valve Speed.
- Earn **Rep** from escapes and achievements; Rep tiers unlock free gameplay perks (speed, pickup radius, throw range).
- Daily login rewards (escalating 7-day cycle) + streak milestones at 7/14/30/60/100 days.
- Full access to all 8 floors and the round loop. No paywall on progression.

### Robux buys multipliers, cosmetics, and convenience (never core progression)
| Item | Type | Price (R$) | What it does |
|---|---|---|---|
| VIP Pass | Game Pass (one-time) | 99 | 1.5× coins, VIP trail, respawn shield, VIP chat tag |
| Auto-Sprint Pass | Game Pass (one-time) | 49 | Permanent sprint speed boost |
| Extra Pebble Slot | Game Pass (one-time) | 29 | +4 pebble capacity |
| Coin Pack S/M/L/Mega | Dev Product (repeatable) | 25/75/150/300 | 250/800/2000/5000 coins |
| Revive Token | Dev Product (repeatable) | 15 | Instant revive mid-run |
| Speed Boost (5 min) | Dev Product (repeatable) | 20 | +30% move speed for 5 min |
| Lucky Pebble | Dev Product (repeatable) | 30 | Paid random item (odds disclosed) |
| Neon Trail | Dev Product (repeatable) | 50 | Cosmetic trail |
| Golden Pebble | Dev Product (repeatable) | 40 | Cosmetic pebble skin |

### Free currency sink check (no dead currency)
- Coins are earned from escapes AND spent on 6 upgrades (ThrowRange1/2, PebbleCap8/12, RescueSpeed, ValveSpeed).
- Rep tiers grant free gear with real gameplay effects (speed, pickup radius, throw range).
- Every gear entry declares a `Source` field (`rep` / `coils` / `robux`) and the harness asserts the lists agree.

---

## Psychology-driven engagement (built in, not bolted on)

| Mechanic | Psychology | Where in code |
|---|---|---|
| Variable-ratio loot | Skinner box / dopamine | Lucky Pebble roll (Config.LOOT_TABLES), floor-clear bonuses |
| Zeigarnik (incomplete tasks) | Cognitive tension | "Door X/8", "Floor 3/8" labels, progress bars |
| Loss aversion | Losses loom 2× | Near-miss toast: "You were only N doors away!" |
| FOMO | Anticipated regret | Limited-time cosmetics with truthful dates only |
| Commitment / consistency | Habit formation | 7-day escalating daily rewards, streak milestones |
| Sunk cost | Continued investment | Cosmetic collection, achievement progress, stat tracking |
| Endowment effect | Ownership increases value | "Your collection", owned items, personal stats |
| Social proof | Peer behavior | "X players escaped today · Y online now" banner |
| Dopamine anticipation | Uncertainty sustains play | Variable rewards across waiting periods |

Rules enforced: FOMO timers are truthful (no fake/restarting countdowns), paid random odds are disclosed and sum to 100%, near-miss messages use actual distance, streaks reset after 36h (never punish offline excessively), streak bonuses capped at 3×.

---

## Compliance table (Creator Hub rule → where satisfied)

| Rule | Where in code |
|---|---|
| Passes are one-time permanent privileges | `Config.PASSES` (VIP, AutoSprint, ExtraPebbleSlot) — granted via `grantPass`, stored in profile |
| Developer products are repeatable | `Config.PRODUCTS` — granted inside `processReceipt` |
| ProcessReceipt validates User ID / Product ID / receipt status | `processReceipt()` in BloxServer — checks PlayerId, maps ProductId, checks ProductPurchaseDecision (1=Open) |
| Grant only on Open receipt, acknowledge so it never re-fires | `grantProduct` + `Receipts[receiptId]` idempotency + return PurchaseGranted |
| Paid random items disclose every outcome + exact odds, sum to 100 | `Config.LOOT_TABLES.LuckyPebble` + `validateLootTables()` assert (weights & DisplayPct = 100) |
| PolicyService for paid random items | `grantProduct` checks `PaidRandomAllowed` attribute; attribute set on join via `GetPolicyInfoForPlayerAsync` |
| No free-text chat (no TextChatService requirement) | Quick chat sends an index into `QUICK_CHAT_LINES` (fixed list), proximity-scoped 50 studs |
| No UGC uploads | No player-authored images/meshes/text |
| Free players can play without spending | Complete free loop (coins earnable + spendable, rep tiers grant real perks) |
| No misleading "almost out of stock" / fake countdowns | None used; FOMO limited to truthful availability |
| Transparent, honest, user-friendly monetization | Source color-coding in UI (rep/coils/robux), "Setup pending" when ID=0 |
| Maturity questionnaire mirrored in config | `Config.Maturity` table |
| Rate limiting on repeatable remotes | `rateLimit()` per player per action |
| Client sends intents only; server decides | All remotes are intents; money/purchases server-side |

---

## Setup checklist (before publishing)

1. Create the experience in the Creator Dashboard and note the Place ID.
2. **Passes:** Monetization → Passes → create 3 passes (VIP 99R$, Auto-Sprint 49R$, Extra Pebble Slot 29R$). Copy each Asset ID into `Config.PASSES[...].Id` (or the `PASS_IDS` table in BloxServer).
3. **Developer products:** Monetization → Developer Products → create 9 products with prices above. Copy IDs into `Config.PRODUCTS[...].Id` / `PRODUCT_IDS`.
4. **Content maturity:** Audience → Maturity & Compliance → fill questionnaire using `Config.Maturity` answers (Mild violence, Moderate fear, no blood/gambling/alcohol/romance/language). Game will be restricted without this.
5. **PolicyService:** already integrated; verify `ArePaidRandomItemsRestricted` handling in Studio test.
6. **DataStore:** Game Settings → Security → Enable Studio Access to API Services (otherwise DataStore returns 403 in Studio).
7. **Studio test:** open `SilentFlood.rbxlx`, Test → Start (Solo and with 2+ players). Check Output panel for errors.
8. **Paid random items:** ensure odds panel visible in-game (store tab + always-reachable panel).
9. Set all IDs from 0 → real IDs before publishing. The game shows "Setup pending" while any ID is 0 (safe for testing).
10. Publish and verify on a fresh account.

### File layout (paste into Studio, or just double-click the .rbxlx)
```
ReplicatedStorage/
  BloxConfig          (ModuleScript)
ServerScriptService/
  BloxServer          (Script)
StarterPlayer/
  StarterCharacterScripts/
    BloxClient        (LocalScript)
```

---

## Honest earning notes

- You receive **70% of Robux spent**; the 30% marketplace fee is not negotiable.
- Robux become real money only via **DevEx**: age 13+, verified email, 30,000 earned Robux minimum, tax form on file.
- Paid access to a game requires age 13+ with verified ID and a 30-day-old account.
- There is a **30-day escrow hold** on each purchase before the Robux are available.
- **Retention beats pricing.** A fun free loop drives repeat visits, which drives Robux spend. Dark patterns (paywalled progression, fake timers, misleading odds) get your products hidden from sale surfaces by Roblox audits.
- Creator Rewards: 5 R$ when an Active Spender plays 10+ min (first 3 experiences/day), plus 35% revenue share on first $100 from new/returning users via direct link/search.

---

## Verification performed

- `luac -p` equivalent (lupa `load()`) passes on all three scripts.
- Economy harness: open receipt credits exactly the right amount; duplicate PurchaseId credits nothing extra; non-Open statuses acknowledged but grant nothing; unknown product IDs rejected (NotProcessedYet); offline players deferred; multiplier purchased earlier changes a later grant.
- Free loop: reaching a rep tier grants free gear; coins earnable and spendable; Robux-only gear cannot be bought with coins; every gear entry declares a Source and lists agree.
- Loot table weights and displayed percentages both total 100; 10,000 simulated rolls only land on disclosed outcomes.
- Round loop: phase transitions Lobby→Playing→Results→Lobby; floor advances on escape; death/timeout do not advance floor; auto-restart guards against duplicate rounds.
- Luau-vs-Lua audit: no bitwise operators, goto, string.pack, table.pack, compound assignment, or `$` identifiers.

### Not verified without Studio (you must Test > Start)
- UI rendering (HUD, store, toast, daily popup).
- Combat feel and entity movement.
- Map flow across all 8 floors.
- Actual Roblox API behavior (DataStore, PolicyService, MarketplaceService) — stubs assume documented behavior.

---

## Deliverables

- `ReplicatedStorage/BloxConfig.lua`
- `ServerScriptService/BloxServer.server.lua`
- `StarterPlayer/StarterCharacterScripts/BloxClient.client.lua`
- `SilentFlood.rbxlx` (double-click to open in Studio)
- This README

Built with the roblox-game-development skill. Compliance-first, psychology-driven engagement, free-to-play friendly.

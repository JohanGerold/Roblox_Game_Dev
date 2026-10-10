# Eggs, Hatching and Stands Earning Money Implementation Plan (Build Step 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Killing the boss gives every participant a rank egg (top 3 → `Stage1_Top`, the rest → `Stage1_Normal`). Eggs hatch after a timer into stands. Stands stand on your base's slots and earn money every second, and while you're offline. Stands can be placed, stored and upgraded with money. The UI shows money, eggs (with odds), stands and announcements.

**Architecture:** Rules are pure, unit-tested modules: `Uid`, `LootRank`, `EggRules`, `StandPlace` in `server/Logic`; `Income` and `OddsDisplay` in `shared/Util`, because the client shows the same $/s, upgrade costs and odds the server uses. Server services: `AnnounceService` (messages), `EggService` (grant, hatch), `LootService` (rank eggs on `BossService.Defeated`), `StandService` (place/store, stand models on base slots), `EconomyService` (income tick, offline earnings, `TrySpend`), `UpgradeService`. Client: `HudController`, `EggsController`, `StandsController`, built from a small `Ui/Widgets` helper.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`).

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (section 4 services, 6 player data, 7 networking, 9 step 3 rank eggs, 11 eggs and stands, 12 income, offline earnings, upgrades). Design: [stands.md](../../../Steal%20a%20boss%20fight/design/stands.md), [progression-and-economy.md](../../../Steal%20a%20boss%20fight/design/progression-and-economy.md), decisions 15, 16, 18.

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/eggs-stands`, created from `main` after `feat/combat-core` is merged.
2. **Unique ids:** `Uid.new(prefix, taken, rng)` → `prefix .. "_" .. 8 lowercase hex`, regenerated on collision. Eggs `e_…`, stands `c_…`.
3. **Egg storage cap 50** (`Economy.eggCap`). A boss kill with full storage grants nothing and sends a `Notice`. Hatching with 200 stands (`inventoryCap`) is refused with a `Notice`. No selling in this step.
4. **Times:** `readyAt` and `lastSeen` are unix seconds from `os.time()` on the server. The client compares against `workspace:GetServerTimeNow()`.
5. **New stands are auto-placed** in the lowest free unlocked slot (1..`baseSlots`), else go to storage.
6. **Upgrade cost scales with the stand's income** so a Celestial isn't upgraded for pocket change: `floor(baseIncome × standUpgradeCostSeconds × standUpgradeCostGrowth^(level − 1))`, max level `standMaxLevel`. Replaces `Economy.standUpgradeBaseCost`.
7. **Boss rank eggs are data:** `Bosses.Boss_Lofy.rankEggs = { top = "Stage1_Top", normal = "Stage1_Normal", topCount = 3 }`. Armor and moveset rolls stay in build step 9.
8. **New server → client messages:** `Hatched { uid, id }`, `Notice (text)` (personal toast), `Welcome { seconds, amount }` (offline earnings popup). `Announce (text, rarity)` stays server-wide.
9. **`DataService.Changed: Signal`** (`Fire(player, key, value)`, fired by `Update`) lets StandService react to data changes. DataService stamps `lastSeen = os.time()` just before `EndSession`; EconomyService also stamps it every `lastSeenStampSeconds` in case the server crashes.
10. **Stand models at bases are server-side and static** (anchored, no collisions). Placeholder when `Assets.Characters[model]` is missing: a 3×5×2 part in the rarity colour (Neon from Mythic up) named `Root`, with a BillboardGui showing name, `Lv N` and `$X/s`. Shadowbox animation arrives with real assets in step 12.
11. **Studio test hook:** `StudioTestController` gains the attribute `FireRemote = "Name|arg1|arg2"`. It fires that client→server message (numeric args converted to numbers) and clears the attribute. Studio only. The server still validates everything.
12. **Not in this step:** stand team and stands in combat (`SetTeam`, step 8), buying base slots, giant egg (step 7), armor and moves (step 9), rebirth (step 10), shadowbox animation and hatch effects (step 12).

## Global Constraints

- The server decides money, eggs, stands and levels. Clients send `HatchEgg(eggUid)`, `PlaceStand(charUid, slot?)`, `UpgradeStand(charUid)` only, each validated by NetSchema and re-checked in the handler against the player's own data.
- Only DataService writes player data, via `DataService:Update(player, key, fn)`. Money never goes below 0.
- Pure modules (`server/Logic`, `shared/Util`) never call `game:GetService`.
- Every number is in config (`Economy`, `Eggs`, `Bosses`), never a literal in a service.
- Each service loop body runs in `xpcall`; errors log `[ServiceName] ...` and the loop continues (spec 16).
- One task = one commit. Commit author `Johan Gerold <johangerold385@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- MCP `execute_luau` runs in its own Lua environment: to call services during play, parent a temporary `Script` under `ServerScriptService` that `require`s the service, then destroy it. Runtime config edits (e.g. `hatchSeconds = 2`) are done the same way and never saved to the files.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (112 passing now; each task adds to that).

## Review Focus

1. **Hatch spam or forged uids** (unknown uid, someone else's uid, not-ready egg, same uid twice in one frame) → at most one stand per egg, nothing else changes. Tests in Task 1 (`EggRules`), play-check in Task 3.
2. **Placing into a locked or nonexistent slot** (slot 5 with `baseSlots = 4`, unknown `charUid`) → rejected, data unchanged. Tests in Task 2 (`StandPlace`).
3. **Upgrade without enough money or at max level** → no level change, money unchanged and never negative. Tests in Task 2 (`Income.upgradeCost`), play-check in Task 5.
4. **Odd clocks for offline earnings** (`lastSeen = 0` on first join, `lastSeen` in the future, away longer than 8 h) → 0, 0, capped. Tests in Task 2.
5. **Boss dies with a ledger player who has left, or whose egg storage is full** → that player skipped or told "full", no error, others still rewarded. Tests in Task 1 (`LootRank`, `EggRules.canReceive`), play-check in Task 3.

---

### Task 1: Egg rules, loot ranking, uids, odds display

**Files:**
- Create: `src/server/Logic/Uid.luau`, `src/server/Logic/LootRank.luau`, `src/server/Logic/EggRules.luau`, `src/shared/Util/OddsDisplay.luau`, `tests/specs/Uid.spec.luau`, `tests/specs/LootRank.spec.luau`, `tests/specs/EggRules.spec.luau`, `tests/specs/OddsDisplay.spec.luau`
- Modify: `src/shared/Config/Eggs.luau` (add `displayName`: `Stage1_Normal = "Egg"`, `Stage1_Top = "Top Egg"`, `Stage1_Giant = "Giant Egg"`), `src/shared/Config/Bosses.luau` (decision 7), `src/shared/Config/Economy.luau` (add `eggCap = 50`), `tests/specs/Config.spec.luau`

**Interfaces:**
- Produces `Uid.new(prefix: string, taken: { [string]: any }, rng: Random): string` (decision 2).
- Produces `LootRank.rank(ledger: { [number]: number }, minShare: number, topCount: number): { { userId: number, damage: number, rank: number, top: boolean } }`. Total = sum of positive damage; keep entries with `damage / total >= minShare`; sort by damage descending, ties by `userId` ascending; `rank` from 1; `top = rank <= topCount`. Empty ledger or total 0 → `{}`.
- Produces `EggRules.canReceive(eggCount: number, Economy): boolean` (`eggCount < eggCap`) and `EggRules.canHatch(egg: { readyAt: number }?, now: number, characterCount: number, Economy): (boolean, string?)` with reasons, checked in this order: `"no egg"`, `"not ready"` (`now < readyAt`), `"inventory full"` (`characterCount >= inventoryCap`).
- Produces `OddsDisplay.rows(odds: { [string]: number }, Rarities): { { rarity: string, percent: number } }`, sorted by rarity index ascending, `percent = weight / total × 100`.

- [ ] **Step 1: Write the tests.**
  - `Uid`: `uid has prefix and 8 hex chars` (matches `^c_%x%x%x%x%x%x%x%x$`, lowercase); `same seed gives same uid`; `taken uid is never returned` (put the first uid from `Random.new(5)` in `taken`, call again with a fresh `Random.new(5)` → different).
  - `LootRank`: ledger `{[1]=500,[2]=300,[3]=100,[4]=90,[5]=10}`, minShare 0.05, topCount 3 → 4 entries, userIds `1,2,3,4` in order, `top` true for the first three, false for 4; user 5 absent (1 %). `ties sorted by userId`: `{[7]=50,[3]=50}` → `3` first. `empty ledger gives no ranks`: `{}` and `{[1]=0}` → `#result == 0`. `solo player is rank 1 top`.
  - `EggRules`: `canReceive(49)` true, `canReceive(50)` false; `canHatch(nil, …)` → `false, "no egg"`; `readyAt = 100`, now 99 → `"not ready"`; now 100, 200 characters → `"inventory full"`; now 100, 199 characters → `true`.
  - `OddsDisplay`: `Stage1_Normal` → rows `Common 60, Rare 25, Epic 12, Legendary 3` in that order; `percents sum to 100` for every egg in config (`expect.near`, 1e-9).
  - `Config.spec`: `every egg rarity has a character` (for each egg and each rarity in its odds, some `Characters` entry has that rarity, so the shown odds are the real odds); `boss rank eggs exist` (`Eggs[rankEggs.top]` and `Eggs[rankEggs.normal]` exist, `topCount == 3`); `every egg has a displayName`.
- [ ] **Step 2:** Run the test command. Expected: the new specs FAIL (modules missing).
- [ ] **Step 3:** Add the config fields and implement the four modules.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add egg rules, loot ranking and odds display`.

### Task 2: Income, upgrade cost and stand placement rules

**Files:**
- Create: `src/shared/Util/Income.luau`, `src/server/Logic/StandPlace.luau`, `tests/specs/Income.spec.luau`, `tests/specs/StandPlace.spec.luau`
- Modify: `src/shared/Config/Economy.luau` (remove `standUpgradeBaseCost`; add `standUpgradeCostSeconds = 100`, `standMaxLevel = 50`, `lastSeenStampSeconds = 60`), `tests/specs/Config.spec.luau` if it references the removed field

**Interfaces:**
- Produces `Income.standIncome(charId: string, level: number, Characters, Economy): number` = `baseIncome × standLevelIncomeGrowth^(level − 1)`; unknown id → 0.
- Produces `Income.perSecond(characters: { [string]: { id: string, level: number, slot: number? } }, rebirths: number, Characters, Economy, Progression): number` = sum of `standIncome` over entries with `slot ~= nil`, times `1 + rebirths × incomeMultiplierPerRebirth`.
- Produces `Income.offline(perSecond: number, now: number, lastSeen: number, Economy): (number, number)` → `(amount, seconds)`. `lastSeen <= 0` or `lastSeen > now` → `(0, 0)`. `seconds = min(now − lastSeen, offlineCapSeconds)`, `amount = floor(seconds × perSecond × offlineRate)`.
- Produces `Income.upgradeCost(charId: string, level: number, Characters, Economy): number?` (decision 6); `nil` when `level >= standMaxLevel` or the id is unknown.
- Produces `StandPlace.place(characters, uid: string, slot: number?, baseSlots: number): (boolean, string?)`, mutating `characters`. Unknown uid → `false, "unknown stand"`. `slot` not nil and not an integer in `1..baseSlots` → `false, "slot locked"`. Any other stand in that slot moves to storage (`slot = nil`); then `characters[uid].slot = slot`.
- Produces `StandPlace.firstFreeSlot(characters, baseSlots: number): number?`.

- [ ] **Step 1: Write the tests.**
  - `standIncome`: `Lofy_Base` level 1 → 1; level 3 → `1.8225` (`expect.near`, 1e-9).
  - `perSecond counts placed stands only`: Lofy L1 slot 1, Zoru L2 slot 2, Narto L1 slot nil, rebirths 0 → `11.8`; same with rebirths 2 → `23.6`; an unknown id in a slot adds 0.
  - `offline`: perSecond 10, `lastSeen = now − 3600` → `(18000, 3600)`; `now − 86400` → `(144000, 28800)`; `lastSeen = 0` → `(0, 0)`; `lastSeen = now + 60` → `(0, 0)`.
  - `upgradeCost`: Lofy L1 → 100; Lofy L2 → 160; Zoru L1 → 800; Lofy L50 → nil; unknown id → nil.
  - `StandPlace`: placing into an empty slot sets it; placing into an occupied slot sends the old stand to storage; `slot = nil` stores; slot 5 with `baseSlots = 4` → `false, "slot locked"` and `characters` unchanged; slot 0 and slot 1.5 → `"slot locked"`; unknown uid → `"unknown stand"`. `firstFreeSlot` with slots 1 and 3 used, `baseSlots = 4` → 2; all four used → nil.
- [ ] **Step 2:** Run the test command. Expected: the new specs FAIL.
- [ ] **Step 3:** Update `Economy` and implement both modules.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add income, upgrade cost and stand placement rules`.

### Task 3: AnnounceService, EggService, LootService

**Files:**
- Create: `src/server/Services/AnnounceService.luau`, `src/server/Services/EggService.luau`, `src/server/Services/LootService.luau`
- Modify: `src/shared/NetSchema.luau` (add s2c `Hatched = { "table" }`, `Notice = { "string" }`, `Welcome = { "table" }`), `src/server/Services/DataService.luau` (decision 9), `src/client/Controllers/StudioTestController.luau` (decision 11), spec section 7 (new messages) and section 11 (decisions 3 and 5)

**Interfaces:**
- Consumes: Task 1 modules, `EggRoll.roll`, `Config/Eggs`, `Config/Characters`, `Config/Rarities`, `Config/Economy`, `Config/Combat.minDamageShare`, `Config/Bosses[id].rankEggs`, `StandPlace.firstFreeSlot`, `BossService.Defeated`, `DataService:Get/Update`.
- Produces `DataService.Changed: Signal` → `Fire(player, key, value)`.
- Produces `AnnounceService:All(text: string, rarity: string)` (fires `Announce` to everyone) and `AnnounceService:Notice(player, text: string)`.
- Produces `EggService:Grant(player, eggId: string): string?`. Returns the egg uid; `nil` if data isn't loaded, the egg id is unknown, or `EggRules.canReceive` fails (then Notice `"Egg storage full (50). Hatch some eggs!"`, cap from config). `readyAt = os.time() + hatchSeconds`.
- Produces the `HatchEgg(eggUid)` handler: `EggRules.canHatch(data.eggs[eggUid], os.time(), count, Economy)`, where `count` is the number of entries in `data.characters` (a dictionary, so not `#`); on failure, Notice the reason. On success: remove the egg, roll with `EggRoll.roll(egg, Characters, rng)` (one `Random.new()` per service), add `characters[Uid.new("c", …)] = { id, level = 1, slot = StandPlace.firstFreeSlot(…) }`, fire `Hatched(player, { uid, id })`. Rarity index ≥ 6 (Mythic+) → `AnnounceService:All(player.DisplayName .. " hatched " .. displayName .. "!", rarity)`.
- Produces `LootService`: on `BossService.Defeated(bossId, ledger)`, `LootRank.rank(ledger, minDamageShare, rankEggs.topCount)`; for each entry whose player is still in the game, `EggService:Grant(player, top and rankEggs.top or rankEggs.normal)`, and on success Notice `"Rank #" .. rank .. "! You got a " .. displayName`. A boss with no `rankEggs` grants nothing.

- [ ] **Step 1:** Update NetSchema, DataService and the spec text. Run the test command: `FAIL 0`.
- [ ] **Step 2:** Implement the three services and the `FireRemote` hook.
- [ ] **Step 3:** Run the test command (`FAIL 0`). Start play; console has no `[Boot]` errors.
- [ ] **Step 4: Kill → egg.** Temporary Script: set `Eggs.Stage1_Top.hatchSeconds = 2` and `Bosses.Boss_Lofy.respawnSeconds = 5` at runtime, then `BossService:DamageBoss(boss, player, 999999)`. Expected: `data.eggs` has exactly one entry with `eggId == "Stage1_Top"` (solo player = rank 1) and the console shows no errors.
- [ ] **Step 5: Hatch.** After 2 s, set `FireRemote = "HatchEgg|<uid>"` on the player. Expected: `data.eggs` empty, one character with `level == 1` and `slot == 1`, a Mythic or Celestial id. Set the same `FireRemote` again: still one character (Review Focus 1). `FireRemote = "HatchEgg|e_nope"`: no change.
- [ ] **Step 6: Not ready and storage full.** Grant a `Stage1_Normal` (30 s) and hatch it at once → no new character. Temporary Script fills `data.eggs` to 50 through `DataService:Update`, then kills the boss → still 50 eggs, no error (Review Focus 5). Stop play.
- [ ] **Step 7: Commit** `feat: add rank eggs on boss kill and egg hatching`.

### Task 4: StandService (placing, stand models at bases)

**Files:**
- Create: `src/server/Services/StandService.luau`

**Interfaces:**
- Consumes: `StandPlace.place`, `Income.standIncome`, `Format.number`, `DataService.Changed`, `DataService.Loaded`, `BaseService.Assigned`, `BaseService:GetBase`, `Config/Characters`, `Config/Rarities`, `AnnounceService:Notice`.
- Produces the `PlaceStand(charUid, slot?)` handler: `DataService:Update(player, "characters", …)` with `StandPlace.place(…, data.baseSlots)`; on failure, Notice the reason and leave the data as it was.
- Produces `StandService:Refresh(player)`: rebuilds `Workspace.Stands[tostring(userId)]` (folder created on demand). For each stand with a slot, find the `StandSlot` part with matching `SlotIndex` in the player's base and put the model there (`Assets.Characters[cfg.model]` clone or the decision 10 placeholder), standing on the slot's top face and facing the slot's `LookVector`. Called on `Loaded`, `Assigned`, and on `Changed` with key `characters` or `baseSlots`. A no-op until both base and data exist. The folder is destroyed on `PlayerRemoving`.

- [ ] **Step 1:** Implement `StandService`.
- [ ] **Step 2:** Run the test command (`FAIL 0`). Start play, grant and hatch two eggs as in Task 3 (with `hatchSeconds = 2`).
- [ ] **Step 3: Check models.** Expected: `workspace.Stands[userId]` has 2 models, each within 4 studs (XZ) of the `StandSlot` parts with `SlotIndex` 1 and 2 of the player's base. `screen_capture` near the base shows the coloured placeholders with labels.
- [ ] **Step 4: Place and store.** `FireRemote = "PlaceStand|<uid of slot 1>"` (no slot = store) → 1 model left. `"PlaceStand|<same uid>|5"` → Notice, data unchanged (Review Focus 2). `"PlaceStand|<same uid>|2"` → it takes slot 2 and the other stand goes to storage. Stop play.
- [ ] **Step 5: Commit** `feat: add stand placement and base stand models`.

### Task 5: EconomyService and UpgradeService

**Files:**
- Create: `src/server/Services/EconomyService.luau`, `src/server/Services/UpgradeService.luau`

**Interfaces:**
- Consumes: `Income`, `Config/Economy`, `Config/Characters`, `Config/Progression`, `DataService`, `AnnounceService:Notice`, `Net` (`Welcome`).
- Produces `EconomyService:IncomePerSecond(player): number` (0 if no data), `EconomyService:Add(player, amount: number)` (ignores non-finite or ≤ 0), `EconomyService:TrySpend(player, amount: number): boolean` (false unless amount is finite, > 0 and ≤ money), `EconomyService:ApplyOffline(player)`.
  - `ApplyOffline` (on `DataService.Loaded`): `Income.offline(perSecond, os.time(), data.lastSeen, Economy)`, sets `lastSeen = os.time()`, adds the amount, and fires `Welcome(player, { seconds, amount })` if amount > 0.
  - `Start`: a loop every 1 s pays `IncomePerSecond` to each loaded player, and every `lastSeenStampSeconds` sets `lastSeen = os.time()`. Each player's step runs in `xpcall`.
- Produces the `UpgradeStand(charUid)` handler in UpgradeService: unknown stand → nothing. `Income.upgradeCost` nil → Notice `"Max level"`. `TrySpend` false → Notice `"Not enough money"`. Otherwise level + 1.

- [ ] **Step 1:** Implement both services.
- [ ] **Step 2:** Run the test command (`FAIL 0`). Start play; hatch one egg as in Task 3.
- [ ] **Step 3: Income.** Sample `data.money` twice, 5 s apart. Expected: the gain is within ±1 tick of `5 × IncomePerSecond`.
- [ ] **Step 4: Offline.** Temporary Script: `Update(player, "lastSeen", fn → os.time() − 3600)`, then `ApplyOffline(player)`. Expected: money rises by `floor(3600 × perSecond × 0.5)` (plus any income tick).
- [ ] **Step 5: Upgrade.** Set money to 0, `FireRemote = "UpgradeStand|<uid>"` → level unchanged, money 0 (Review Focus 3). Give exactly `upgradeCost` money and fire again → level 2, money ≈ 0 plus any income tick. Stop play.
- [ ] **Step 6: Persistence (only if Studio API access is enabled).** Stop and restart play: money, eggs and stands are kept, and money includes the offline amount for the time away.
- [ ] **Step 7: Commit** `feat: add income tick, offline earnings and stand upgrades`.

### Task 6: Client UI and end-to-end play-test

**Files:**
- Create: `src/client/Ui/Widgets.luau`, `src/client/Controllers/HudController.luau`, `src/client/Controllers/EggsController.luau`, `src/client/Controllers/StandsController.luau`
- Modify: `CLAUDE.md` (Status), `Steal a boss fight/INDEX.md` or the relevant design note only if a decision above changes the design

**Interfaces:**
- Consumes: `DataController` (`money`, `eggs`, `characters`, `baseSlots`, `rebirths`; `Changed`), `Income`, `OddsDisplay`, `Format.number`, `Config/Eggs`, `Config/Characters`, `Config/Rarities`, `Config/Economy`, `Config/Progression`, `Net` (`HatchEgg`, `PlaceStand`, `UpgradeStand` out; `Hatched`, `Notice`, `Announce`, `Welcome` in).
- Produces `Widgets.frame(props)`, `Widgets.label(props)`, `Widgets.button(props, onClick)`, `Widgets.list(parent)` (scrolling, vertical layout): thin `Instance.new` helpers with one shared style (dark panel, rounded corners, `GothamBold`, scales on small screens with `UIScale`).
- Produces `HudController`: top-centre money `$1.2K` and `+$X/s` (`Income.perSecond` on the client copy); left-side buttons `Eggs (n)` and `Stands (n)`, which toggle the two panels (only one open at a time); toast stack for `Notice` (white) and `Announce` (rarity colour), 4 s each, max 4 shown; `Welcome` popup: `"Welcome back! You were away 2h 13m and earned $X"` with an OK button.
- Produces `EggsController`: a panel listing eggs, ready ones first. Each row: egg `displayName`, countdown `m:ss` (from `readyAt − GetServerTimeNow()`, refreshed each second) or a `Hatch` button. Below it, an odds line from `OddsDisplay.rows` (`"Common 60% · Rare 25% · …"`, each rarity in its colour). `Hatched` → centre reveal `"You hatched <name>!"` in the rarity colour for 2.5 s.
- Produces `StandsController`: a panel listing stands sorted by rarity index descending, then level descending. Each row: name in the rarity colour, `Lv N`, `$X/s` (`Income.standIncome`), `Place` (sends `PlaceStand(uid, lowest free slot)`; if none, local toast `"All base slots full. Store a stand first."`) or `Store`, and `Upgrade $cost` (hidden at max level).

- [ ] **Step 1:** Implement the four client modules.
- [ ] **Step 2:** Run the test command (`FAIL 0`). Start play; no console errors.
- [ ] **Step 3: Screens.** Kill the boss with a temporary Script (`hatchSeconds = 2`). `screen_capture`: the toast `"Rank #1! You got a Top Egg"` and `Eggs (1)`. Open the Eggs panel by clicking its button with `user_mouse_input` (if clicking doesn't work through MCP, ask the user to click); capture the odds line and the `Hatch` button after 2 s. Hatch → capture the reveal and the server announcement. Open Stands → capture the row with `Upgrade $cost`. Re-run Task 5 Step 4 → capture the Welcome popup. Stop play.
- [ ] **Step 4: User check.** Ask the user to play for two minutes: kill the boss (or use the temporary kill), hatch, place and store a stand, upgrade it, and say whether the UI is clear. Wait for their answer. Tuning goes in config only.
- [ ] **Step 5:** Update `CLAUDE.md` Status: build step 6 done on `feat/eggs-stands`; next is plan 5 (build step 7: giant egg).
- [ ] **Step 6: Commit** `feat: add money HUD, egg and stand panels`.

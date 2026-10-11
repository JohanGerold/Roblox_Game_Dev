# Round Cycle Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the day/night round cycle: a 4-minute day that starts with field eggs spawning in the domain, and a 45-second night that sends everyone home with their eggs counted, clears the field, and resets the boss. Lighting and an on-screen countdown follow the timer.

**Architecture:** A new `RoundService` owns the phase timer and replicates it as workspace attributes `RoundPhase` / `RoundEndsAt`. At each phase change it calls into existing services: `CarryService` (field eggs, nightfall delivery and clearing), `BossService` (dormant at night) and `BaseService` (home spawn). The decisions are pure modules `RoundRules`, `FieldEggRoll` and `ZoneCheck`. A client `RoundController` shows the countdown.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`).

**Spec:** [docs/specs/2026-10-11-strip-map-and-egg-chase-design.md](../../specs/2026-10-11-strip-map-and-egg-chase-design.md) (D10, D11, D12; section 3 "Day / night", "Field eggs"; section 6 risks). Builds on [Plan A](2026-10-11-strip-map-carry-eggs.md) (branch `feat/strip-map`, not merged yet).

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/round-cycle`, cut from `feat/strip-map` (Plan A is unmerged and waiting on the user's 2-player test). Do not merge either branch.
2. **The server boots into Day**, so sunrise (field eggs) runs once at start.
3. **At nightfall every carrier counts as delivered**, including carriers already at home (D10: "carriers keep their egg and it counts as delivered"). If egg storage is full, the carrier **keeps carrying** at home with a Notice and can deliver on the pad after hatching (never lose an egg the player earned).
4. **"Field" means outside `HomeZone`.** At nightfall, uncarried eggs outside `HomeZone` vanish, as do giant eggs still counting down (no part yet). Uncarried eggs lying inside home stay.
5. **The night is a rest:** the boss is *dormant*. It is reset to full HP, stands still at home, never attacks, and `DamageBoss` deals 0. Players can still walk to the domain, but there is nothing to fight and no eggs to take. The model attribute `Dormant = true` lets the HUD show it.
6. **Field eggs** are a third egg kind `"Field"`: anyone can grab them, a player hit drops them (`stealable = true`), no head start, no return, and they expire when the day ends (`expireAt = RoundEndsAt`). The extra giant egg (D12, 25 %) is a field egg with `eggId = "Stage1_Giant"`. It uses the giant's 0.6 slowdown, but has no countdown, no banner and no `maxActive` count, and it is announced once.
7. **Field egg counts:** small slots = players + `smallExtra` (2), capped at the number of `FieldEggSpawn` points minus the one reserved for a giant when it rolls. Spawn points are shuffled each sunrise.
8. **Field egg odds** (spec says "normal-like" and "better"): `Field_Small` uses `Stage1_Normal`'s odds; `Field_Shiny` uses `{ Rare = 40, Epic = 35, Legendary = 20, Mythic = 5 }`.
9. **Teleporting a carrier resets their speed check** (`CarryService:ResetCheck`). Otherwise the nightfall teleport would trip the speed drop.
10. **Lighting** tweens over `Rounds.lightingTweenSeconds` (3). Day values are the ones Plan A's builder set; night values are in `Config/Rounds`.
11. **Countdown UI** sits top-right (top-centre is taken by the money HUD and boss bar).
12. **Studio test hook:** `RoundService:SkipPhase()` ends the current phase at once. It is called from temporary test Scripts only, with no remote.

## Global Constraints

- The server decides phases, egg spawns, deliveries and teleports; the client only displays `RoundPhase` / `RoundEndsAt`.
- Only `EggService:Grant` adds eggs to player data.
- Pure modules (`server/Logic`) never call `game:GetService`; randomness comes in as a `Random` argument.
- Every number lives in `Config/Rounds`, `Config/Eggs`, `Config/Carry` or `Config/Map`, never as a literal in a service.
- Heartbeat bodies run in `xpcall`; errors log `[RoundService] ...` and the loop continues.
- Never delete a folder Rojo watches.
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending with the session's attribution line.
- MCP `execute_luau` runs in its own Lua environment: to call services during play, parent a temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`), log into a `StringValue` in `ServerStorage`, then read it. Move characters with per-frame steps at or below the allowed speed (coarse teleports trip the speed check). Clear test eggs/money from the dev profile before stopping play.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (173 passing at the start).

## Review Focus

1. **A carrier is out in the corridor at nightfall:** they are teleported to their plot with the egg, the egg is granted, and they are never speed-dropped by the teleport. Covered by a play-check in Task 4.
2. **A carrier has full storage at nightfall:** they are teleported home still carrying, get one Notice, and the egg is not destroyed by the field clear. Covered by a play-check in Task 4.
3. **A player is dead or has no character at nightfall:** no error; they respawn at their plot as usual. Covered by `RoundService` skipping players without a living root, and a play-check in Task 4 (kill yourself, skip the phase).
4. **Many players or few spawn points** (8 players, 12 spawns, giant rolled): never more eggs than spawn points, and no two eggs on one point. Tested in Task 1 (`FieldEggRoll` caps and unique indices).
5. **A phase change happens while the boss is dead, or a giant egg is still counting down:** the boss comes back at full HP and dormant, and the counting-down giant is removed with no orphan banner. Tested in Task 2 (`Nightfall` removes eggs without parts and broadcasts `Despawned`) and Task 3 (a dormant boss after death).

---

### Task 1: Round config, field eggs and pure rules

**Files:**
- Create: `src/shared/Config/Rounds.luau`, `src/server/Logic/RoundRules.luau`, `src/server/Logic/FieldEggRoll.luau`, `src/server/Logic/ZoneCheck.luau`, `tests/specs/RoundRules.spec.luau`, `tests/specs/FieldEggRoll.spec.luau`, `tests/specs/ZoneCheck.spec.luau`
- Modify: `src/shared/Config/Eggs.luau`, `tests/specs/Config.spec.luau`

**Interfaces:**
- Produces `Config/Rounds`:
  `{ daySeconds = 240, nightSeconds = 45, lightingTweenSeconds = 3, fieldEggs = { small = "Field_Small", shiny = "Field_Shiny", giant = "Stage1_Giant", smallExtra = 2, shinyChance = 0.10, giantChance = 0.25 }, lighting = { Day = { ClockTime = 17.6, Ambient = Color3.fromRGB(90, 30, 20), OutdoorAmbient = Color3.fromRGB(120, 50, 30), Density = 0.35, Color = Color3.fromRGB(255, 110, 60), Decay = Color3.fromRGB(120, 30, 20), Haze = 2, Glare = 0.5 }, Night = { ClockTime = 0, Ambient = Color3.fromRGB(25, 20, 40), OutdoorAmbient = Color3.fromRGB(30, 25, 50), Density = 0.45, Color = Color3.fromRGB(60, 50, 90), Decay = Color3.fromRGB(20, 15, 40), Haze = 1, Glare = 0 } } }`
  (`Density`/`Color`/`Decay`/`Haze`/`Glare` are `Atmosphere` properties; the rest are `Lighting` properties.)
- `Config/Eggs` gains `Field_Small = { displayName = "Field Egg", hatchSeconds = 30, carryFactor = 0.95, color = Color3.fromRGB(150, 230, 120), odds = <same as Stage1_Normal> }` and `Field_Shiny = { displayName = "Shiny Egg", hatchSeconds = 45, carryFactor = 0.85, color = Color3.fromRGB(120, 230, 255), glow = true, odds = { Rare = 40, Epic = 35, Legendary = 20, Mythic = 5 } }`.
- Produces `RoundRules.nextPhase(phase: "Day" | "Night"): "Day" | "Night"` and `RoundRules.duration(phase, cfg): number` (`cfg` = `Config/Rounds`). An unknown phase errors.
- Produces `FieldEggRoll.roll(playerCount: number, spawnCount: number, cfg, rng: Random): { { eggId: string, spawnIndex: number } }`. Algorithm: `giant = rng:NextNumber() < cfg.giantChance and spawnCount ≥ 1`; `small = min(playerCount + cfg.smallExtra, spawnCount − (giant and 1 or 0))`, never below 0. Shuffle `1..spawnCount` (Fisher–Yates with `rng:NextInteger`). Hand out indices in order: the giant first if rolled, then each small slot is `cfg.shiny` when `rng:NextNumber() < cfg.shinyChance`, else `cfg.small`.
- Produces `ZoneCheck.inside(zoneCFrame: CFrame, zoneSize: Vector3, pos: Vector3): boolean`. True when `pos` lies inside the box on all three axes (boundary counts as inside).

- [ ] **Step 1: Write the failing tests.**
  - `RoundRules.spec`: `Day → Night`, `Night → Day`; `duration("Day") == 240`, `duration("Night") == 45`; `nextPhase("Dusk")` errors (`pcall` is false).
  - `FieldEggRoll.spec` (seed with `Random.new(1)` etc.; force outcomes by passing a cfg copy with `giantChance = 1`/`0`, `shinyChance = 1`/`0`):
    - `3 players, no giant, no shiny`: 5 entries, all `Field_Small`.
    - `giant rolled comes first`: `giantChance = 1` → entry 1 is `Stage1_Giant`, then 5 smalls (6 total).
    - `all shiny`: `shinyChance = 1`, `giantChance = 0` → every entry `Field_Shiny`.
    - `capped by spawn points`: 8 players, 12 spawns, `giantChance = 1` → 12 entries (1 giant + 11 smalls); 8 players, 6 spawns, `giantChance = 0` → 6.
    - `unique spawn indices in range`: over seeds 1..20 with 8 players and 12 spawns, indices are unique and within 1..12.
    - `no spawn points`: `spawnCount = 0` → empty, even with `giantChance = 1`.
    - `zero players still spawns the extras`: 0 players, 12 spawns, `giantChance = 0` → 2.
  - `ZoneCheck.spec`: box `CFrame.new(120, 20, 0)`, size `(240, 40, 120)`: `(10, 3, 0)` true, `(239.9, 3, 59)` true, `(241, 3, 0)` false, `(100, 3, 61)` false, `(100, 41, 0)` false; a box rotated 90° about Y with size `(10, 4, 2)` contains `(0, 0, 4)` but not `(4, 0, 0)`.
  - `Config.spec`: `rounds config matches the spec` (240, 45, smallExtra 2, shinyChance 0.10, giantChance 0.25; `Eggs[fieldEggs.small/shiny/giant]` exist); `field eggs are lighter than the giant` (`Eggs.Field_Small.carryFactor == 0.95`, `Field_Shiny == 0.85`); `both lighting presets set every key` (Day and Night each have the 8 keys above). The existing tests "every egg rarity has at least one character" and "every egg has a carry factor and a color" already cover the new eggs.
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL (missing modules / config).
- [ ] **Step 3:** Create `Config/Rounds`, extend `Config/Eggs`, implement `RoundRules`, `FieldEggRoll`, `ZoneCheck`.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: round config, field eggs and round rules`.

### Task 2: CarryService field eggs, nightfall and teleport reset

**Files:**
- Modify: `src/server/Services/CarryService.luau`

**Interfaces:**
- Consumes `Config/Eggs.Field_*` (incl. `glow`) and `ZoneCheck.inside` (Task 1).
- Produces `CarryService:SpawnField(eggId: string, groundPos: Vector3, expireAt: number): string?`. Egg id `"f<n>"`, `kind = "Field"`, `stealable = true`, no owner, `size = Carry.personalSize` (a giant field egg uses `GiantEgg.size`), `readyAt = headStartUntil = now`, `top = {}`, `returnAt = nil`. The part is made at once, with phase `"Free"`. The label is `displayName:upper()`. When `Eggs[eggId].glow` is set, a `PointLight` in the egg's colour (Range 12, Brightness 2) is added. Returns nil for an unknown `eggId`.
- Produces `CarryService:Nightfall(isHome: (Vector3) -> boolean): ()`:
  1. For every carrier: `EggService:Grant(player, egg.eggId)`. On success, `detach`, destroy the egg, and Notice `"Your <displayName> made it home!"` (Giant kind also broadcasts `"Delivered"` and announces as on delivery). On failure, keep carrying; `Grant` already sent the storage-full Notice.
  2. For every egg not carried: destroy it if it has no part (still counting down), or if its part is not `isHome(part.Position)`. Giant-kind eggs broadcast `"Despawned"` first. The owner of a personal egg gets the Notice `"The night took your <displayName>."`.
- Produces `CarryService:ResetCheck(player: Player): ()`. If they are carrying, `carry.check = CarryCheck.new(root.Position, now(), Carry)`. Call it after any server teleport.
- Pickup/delivery Notices for `Field` kind are the same as for `Personal` (`"Carry your <displayName> home!"` / `"Delivered your <displayName>!"`). A field giant (`eggId == GiantEgg.eggId`, kind `Field`) announces `"<name> grabbed a Giant Egg!"` globally instead.

- [ ] **Step 1:** Add `SpawnField`, `Nightfall`, `ResetCheck` and the Field-kind messages. Keep `onDefeated`'s `maxActive` count to `kind == "Giant"` only.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (temporary Script):
  - `SpawnField("Field_Shiny", <home ground point>, now + 60)` → a glowing cyan ball labelled `SHINY EGG`. Pick it up → `WalkSpeed == 16 × 0.85`. Call `CarrierInReach(nil, root.Position, 10)` → returns the player (stealable).
  - With the egg carried and the character teleported 300 studs, call `ResetCheck(player)` right after the move. Walking on per-frame at 13 studs/s for 2 s → still carrying.
  - Kill the boss (giant counting down). Spawn a field egg in the domain and a personal egg inside home. Call `Nightfall(function(p) return ZoneCheck.inside(homeZone.CFrame, homeZone.Size, p) end)` while carrying the shiny → the shiny is granted, the domain field egg and the counting-down giant are gone, and the personal egg inside home stays. Console has no errors.
  - Fill storage to 50, carry a field egg, call `Nightfall` → still carrying, one storage-full Notice. Clean up.
- [ ] **Step 4:** Commit `feat: field eggs and nightfall in carry service`.

### Task 3: Dormant boss at night

**Files:**
- Modify: `src/server/Services/BossService.luau`

**Interfaces:**
- Produces `BossService:SetDormant(on: boolean): ()`. With `on = true`, every record gets `resetBoss(rec)` (full HP, home, `Dead` cleared), `rec.dormant = true`, and model attribute `Dormant = true`. With `on = false`, it clears both. Calling it twice with the same value is harmless (the reset runs again).
- `step(rec)` returns at once while `rec.dormant` (no chase, no attacks, no respawn timer).
- `BossService:DamageBoss` returns 0 and changes nothing while `boss.dormant`; `BossService:Parry` does nothing while dormant.

- [ ] **Step 1:** Implement as above.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check:** kill the boss → `State == "Dead"`. `SetDormant(true)` → `Hp == MaxHp`, the boss is at `BossSpawn`, `Dormant == true`, and `DamageBoss(boss, player, 100)` returns 0. Stand next to it for 5 s with `AutoDefend` off → no damage taken. `SetDormant(false)` → `DamageBoss` deals damage again.
- [ ] **Step 4:** Commit `feat: dormant boss during the night`.

### Task 4: RoundService and the countdown

**Files:**
- Create: `src/server/Services/RoundService.luau`, `src/client/Controllers/RoundController.luau`
- Modify: `tools/BuildGraybox.luau` (only to stop setting lighting: remove the "Day look" block, since `RoundService` owns lighting now)

**Interfaces:**
- Consumes `RoundRules`, `FieldEggRoll`, `ZoneCheck`, `Config/Rounds` (Task 1); `CarryService:SpawnField / Nightfall / ResetCheck` (Task 2); `BossService:SetDormant` (Task 3); `BaseService:GetSpawnCFrame(player)`.
- Workspace attributes: `RoundPhase: "Day" | "Night"` and `RoundEndsAt: number` (server time, `workspace:GetServerTimeNow()`).
- `RoundService:Start()` enters `Day`. Heartbeat (in `xpcall`): when `now ≥ RoundEndsAt`, enter `RoundRules.nextPhase(phase)`.
- Entering a phase: set `RoundEndsAt = now + RoundRules.duration(phase, Rounds)` **before** running the phase actions (field eggs read it as their expiry), then set `RoundPhase`, then tween lighting (`Lighting` properties + the one `Atmosphere` under `Lighting`, created if missing) to `Rounds.lighting[phase]` over `lightingTweenSeconds`.
- **Sunrise (enter Day):** `BossService:SetDormant(false)`, then `FieldEggRoll.roll(#Players:GetPlayers(), #spawns, Rounds.fieldEggs, rng)`. Spawn each entry with `CarryService:SpawnField(eggId, spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0), RoundEndsAt)`. `spawns` = parts tagged `FieldEggSpawn`, sorted by name so indices are stable; `rng` = one `Random.new()` per server. If a giant rolled: `AnnounceService:All("A Giant Egg appeared in the domain!", GiantEgg.announceRarity)`. On the very first Day this runs too (decision 2).
- **Nightfall (enter Night):** in this order:
  1. `BossService:SetDormant(true)`.
  2. `CarryService:Nightfall(isHome)`.
  3. For every player with a living root outside `HomeZone`: `character:PivotTo(BaseService:GetSpawnCFrame(player))`, then `CarryService:ResetCheck(player)`.
  4. `AnnounceService:All("Night falls. Everyone is home.", "Common")`.
  `isHome(p)` = `ZoneCheck.inside(homeZone.CFrame, homeZone.Size, p)`. `homeZone` is the one part tagged `HomeZone`; if it is missing, warn once and treat nothing as home.
- Produces `RoundService:SkipPhase(): ()`. Sets `RoundEndsAt = now` so the next heartbeat changes phase (test hook, decision 12).
- `RoundController` (client): a label top-right (`AnchorPoint (1, 0)`, `Position UDim2.new(1, -16, 0, 16)`, size 200 × 36, built with `Widgets.label`). Text `"DAY m:ss"` in warm orange `(255, 170, 90)` or `"NIGHT m:ss"` in pale blue `(170, 190, 255)`, from the workspace attributes, refreshed every 0.2 s. Hidden until `RoundPhase` exists. Seconds left = `max(0, ceil(RoundEndsAt − GetServerTimeNow()))`.

- [ ] **Step 1:** Create `RoundService` and `RoundController`; remove the lighting block from the builder (no re-run needed: `RoundService` sets lighting on start).
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (temporary Scripts; use `SkipPhase` instead of waiting):
  - On start: `RoundPhase == "Day"`, `RoundEndsAt − now ≈ 240`, and 3 field eggs (1 player + 2), or 4 if a giant rolled, sit on `FieldEggSpawn` points in the domain. `screen_capture` during play shows the `DAY 3:5x` label top-right and does not overlap the money HUD.
  - Carry a field egg into the corridor (per-frame walk at ≤ 0.95 × walk speed), then `SkipPhase()` → `RoundPhase == "Night"`. The player is on their plot's `BaseSpawn`, the egg is granted (inventory +1) with no `"speed"` drop in the console, the other field eggs are gone, `ClockTime` tweens to 0, the boss is `Dormant` at full HP, and the label reads `NIGHT 0:4x`.
  - Full storage case: fill to 50, carry a field egg outside home, `SkipPhase()` to Night → home, still carrying, one storage-full Notice, egg not destroyed. Clean up.
  - Dead at nightfall: from Day, set `Health = 0`, then `SkipPhase()` → no errors; the player respawns on their plot.
  - `SkipPhase()` to Day → `Dormant == false`, new field eggs, lighting back to the day values.
  - Clean the dev profile (eggs, money) before stopping play.
- [ ] **Step 4:** Commit `feat: round service with day/night cycle and countdown`.

### Task 5: Docs and status

**Files:**
- Modify: `CLAUDE.md` (Status), `Steal a boss fight/planning/decisions.md` (section 21: add one line under D10/D12 noting decisions 3, 4, 5 and 6 of this plan)

- [ ] **Step 1:** Update Status: Plan B built on `feat/round-cycle` (from `feat/strip-map`); both branches wait on the user's tests; Next: Plan C (boss chase). Plan C must not chase at night (D15), and must treat `HomeZone` through `ZoneCheck`.
- [ ] **Step 2:** Commit `docs: update status after round cycle`.

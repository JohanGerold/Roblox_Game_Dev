# Strip Map and Carried Eggs Implementation Plan (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ring map with the straight strip (home with 8 plots → 500-stud corridor → cursed domain with the arena), make carry speed depend on the egg (walk speed × slowdown), and make the personal rank eggs drop in the arena so their owner has to carry them home.

**Architecture:** Map math stays pure in `MapLayout`/`MapContract` and is rebuilt by `tools/BuildGraybox.luau`. `GiantEggService` becomes `CarryService`, which owns every carryable egg (giant and personal) through one egg record with `kind`, `eggId`, `ownerUserId?` and `stealable`. `GiantEggRules` becomes `CarryRules` (owner check, per-egg timeouts, carry speed, ring positions). `LootService` spawns personal eggs through `CarryService` instead of granting them.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`).

**Spec:** [docs/specs/2026-10-11-strip-map-and-egg-chase-design.md](../../specs/2026-10-11-strip-map-and-egg-chase-design.md) (D1, D2, D3, D7, D8, D9, D13; sections 2, 3 "Carrying"/"Delivery"/"On boss death", 4). Builds on [the giant egg plan](2026-10-10-giant-egg.md).

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/strip-map` from `main`.
2. **Names in code stay "Base"** (tag `Base`, `BaseService`, `baseCount`); "plot" is only the design word. `Config/Map.baseCount = 8`.
3. **The map is built once with everything Plans B and C need:** `HomeZone`, `SpeedSign` (placeholder text "SPEED CHECK"), 12 `FieldEggSpawn` markers. Plans B/C only add behaviour.
4. **Shared carry tuning moves to a new `Config/Carry.luau`**; `Config/GiantEgg` keeps only giant-specific values. `personalExpireSeconds` lives in `Config/Carry` (the spec says Eggs/GiantEgg).
5. **Personal eggs:** ready at once (no countdown, no head start), never return, expire 300 s after spawning, are not hit-droppable (`stealable = false`: a player hit on their carrier does nothing, D8 "can't be stolen"). The owner leaving destroys them. Dying drops them where the owner last stood on the ground.
6. **Carry speed** = the humanoid's server-side `WalkSpeed` at pickup × `Eggs[eggId].carryFactor`. The speed check uses that same value. Build step 10 (treadmill) must recompute `WalkSpeed = newSpeed × carryFactor` for carriers instead of setting it directly.
7. **Player attribute** `CarryingGiantEgg` is renamed `CarryingEgg` (true for any egg). Build step 8 checks `CarryService:IsCarrying` / `CarryingEgg`.
8. **`GiantEggState` stays giant-only**; personal eggs are shown by a billboard (`"<DisplayName>'s Top Egg"`) and Notices.
9. **Non-owners can't see the Grab prompt** on personal eggs: the server tags the prompt with attribute `OwnerUserId`; a new client `EggPromptController` sets `MaxActivationDistance = 0` locally on prompts that aren't theirs. The server never changes `MaxActivationDistance` after creation, and still refuses with `"not yours"`.
10. **Egg folder** `workspace.GiantEggs` becomes `workspace.Eggs`; parts are named `Egg_<id>` (ids `g1…` giant, `p1…` personal).
11. **8-player cap** is a Studio Game Settings value (Places → Max Players = 8), not code; the user sets it when publishing.
12. **Day look only** (red-orange sky, fog) is set by the builder; Plan B moves lighting to the round timer.

## Global Constraints

- The server decides who holds each egg and who gets it; pickup only through the server-side ProximityPrompt, re-checked with `CarryRules.canPickUp`.
- Only `EggService:Grant` adds eggs to player data, and only on delivery.
- Pure modules (`server/Logic`) never call `game:GetService`.
- Every number lives in `Config/Map`, `Config/Carry`, `Config/GiantEgg` or `Config/Eggs`, never as a literal in a service.
- Heartbeat bodies run in `xpcall`; errors log `[CarryService] ...` and the loop continues.
- Never delete a folder Rojo watches (`git mv` of single files is fine while `rojo serve` runs).
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- MCP `execute_luau` runs in its own Lua environment: to call services during play, parent a temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`), then destroy it. Clear test eggs/stands/money from the dev profile before stopping play.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (157 passing now).

## Review Focus

1. **Owner dies, respawns or falls off while carrying a personal egg** → the egg drops on solid ground where they last stood and only they can grab it again; it never vanishes early. Play-check in Task 4.
2. **Another player tries to grab or hit-drop a personal egg** → no prompt shown, server refuses `"not yours"`, hits do nothing. Test in Task 3 (`"not yours"`), play-check in Task 4 (`TryPickUp` as a fake second user id).
3. **Carrier with a trained walk speed** (e.g. 30) → carry speed 30 × factor, and the speed check doesn't false-drop them. Test in Task 3 (`CarryCheck` at speed 27), play-check in Task 4.
4. **Delivery with full egg storage** → Notice once per pad entry, keeps carrying, egg not lost. Play-check in Task 4 (unchanged path, re-verify for personal eggs).
5. **Many participants** (8 ranked players) → 8 personal eggs on the ring, none inside the boss spawn or overlapping each other. Test in Task 3 (`ringPositions` spacing) and Task 1 (ring clear of `BossSpawn`).

---

### Task 1: Strip layout config, layout math and contract

**Files:**
- Modify: `src/shared/Config/Map.luau`, `src/server/Logic/MapLayout.luau`, `src/server/Logic/MapContract.luau`, `tests/specs/MapLayout.spec.luau`, `tests/specs/MapContract.spec.luau`

**Interfaces:**
- Produces `Config/Map` (replace the file; keep the axis comment updated: base local −Z faces the path):
  `stageId = "Stage1"`, `baseCount = 8`, `plotsPerRow = 4`, `baseSize = 44`, `plotFirstX = 82.5`, `plotSpacing = 45`, `plotRowOffset = 36`, `slotGrid = 4`, `slotSpacing = 6`, `slotSize = 5`, `slotRowStart = 0`, `deliveryPadOffset = 15`, `deliveryPadSize = 10`, `pathWidth = 24`, `home = { minX = 0, maxX = 240, halfWidth = 60 }`, `corridor = { minX = 240, maxX = 740, halfWidth = 20 }`, `domain = { minX = 740, maxX = 920, halfWidth = 90 }`, `arenaCenter = Vector3.new(830, 0, 0)`, `arenaRadius = 70`, `arenaWallHeight = 3`, `giantEggOffset = Vector3.new(-30, 0, 0)` (from arena centre), `fieldEggRingRadius = 50`, `fieldEggSpawnCount = 12`, `stations = { HubSpawn = Vector3.new(16, 0, 0), WeaponShop = Vector3.new(40, 0, -34), FuseMachine = Vector3.new(14, 0, -34), Treadmill = Vector3.new(40, 0, 34), Sandbag = Vector3.new(14, 0, 34) }`, `stationSpread = 6`, `treadmillCount = 4`, `sandbagCount = 4`, `wallHeight = 60`. Remove `baseRingRadius`, `stationRadius`, `stationAngles`, `boundaryHalfSize`.
- Produces `MapLayout.plotCFrames(map): { CFrame }` (replaces `baseCFrames`): index 1–4 on row z = −`plotRowOffset`, 5–8 on z = +`plotRowOffset`, x = `plotFirstX + (col − 1) × plotSpacing`, y = 0, each `CFrame.lookAt(pos, Vector3.new(pos.X, 0, 0))`.
- `MapLayout.slotOffsets(map)` unchanged.
- `MapLayout.stationCFrames(map)` returns `{ HubSpawn, WeaponShop, FuseMachine: CFrame, Treadmill: { CFrame }, Sandbag: { CFrame } }`. A station with |z| < 1 faces +X; others face `Vector3.new(x, 0, 0)`. Rows spread along X (`stationSpread`).
- Produces `MapLayout.fieldEggSpawns(map): { Vector3 }`: `fieldEggSpawnCount` points on a circle of `fieldEggRingRadius` around `arenaCenter`, first at angle 0, evenly spaced.
- `MapContract.check` additionally requires exactly 1 `HomeZone`, exactly 1 `SpeedSign`, and at least 1 `FieldEggSpawn` (messages in the existing style: `Map: expected 1 HomeZone, found N`, `Map: expected at least 1 FieldEggSpawn, found 0`).

- [ ] **Step 1: Rewrite `MapLayout.spec`** (drop the ring tests):
  - `8 plots in two rows facing the path`: 8 CFrames; 1–4 have z = −36, 5–8 z = 36; `cf.LookVector:Dot(Vector3.new(0, 0, -math.sign(z))) > 0.999`.
  - `plots inside home and clear of the path`: for each plot, `x ± baseSize/2` within `home.minX..home.maxX`, `|z| + baseSize/2 ≤ home.halfWidth`, `|z| − baseSize/2 ≥ pathWidth/2`.
  - `plots never overlap`: neighbours in a row are ≥ `baseSize` apart on X.
  - `slot grid fits behind the pad`: 16 offsets (= `Economy.maxBaseSlots`), unique; `|x| + slotSize/2 ≤ baseSize/2`; `z + slotSize/2 ≤ baseSize/2`; `z − slotSize/2 > −deliveryPadOffset + deliveryPadSize/2`.
  - `stations sit at the home end`: every station position has `x < plotFirstX − baseSize/2` and `x ≥ home.minX`, `|z| < home.halfWidth`; 4 treadmills, 4 sandbags; HubSpawn's LookVector ≈ +X.
  - `arena inside the domain`: `arenaCenter.X ± arenaRadius` within `domain.minX..domain.maxX`, `arenaRadius ≤ domain.halfWidth`.
  - `field egg spawns inside the arena, clear of spawns`: 12 points; each within `arenaRadius − 5` of `arenaCenter`; each ≥ 10 from `arenaCenter` (boss spawn) and from `arenaCenter + giantEggOffset`.
  - `zones line up`: `home.maxX == corridor.minX`, `corridor.maxX == domain.minX`, `corridor.maxX − corridor.minX == 500`.
- [ ] **Step 2: Extend `MapContract.spec`**: `makeMap` adds one `HomeZone`, one `SpeedSign`, one `FieldEggSpawn` under root. New tests: `missing HomeZone`, `two SpeedSigns`, `no FieldEggSpawn` each produce their exact message.
- [ ] **Step 3:** Run the test command. Expected: the new/changed tests FAIL.
- [ ] **Step 4:** Update `Config/Map`, `MapLayout`, `MapContract`.
- [ ] **Step 5:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 6:** Commit `feat: strip map layout for 8 plots`.

### Task 2: Rebuild the graybox strip in Studio

**Files:**
- Modify: `tools/BuildGraybox.luau`

**Interfaces:**
- Consumes `Config/Map`, `MapLayout.plotCFrames / slotOffsets / stationCFrames / fieldEggSpawns`, `MapContract.check` (Task 1).
- Produces in `Workspace.Map`: the tags of the map contract plus `HomeZone`, `SpeedSign`, `FieldEggSpawn`. `GiantEggSpawn` at `arenaCenter + giantEggOffset`, `BossSpawn` at `arenaCenter`.

- [ ] **Step 1: Rewrite the builder sections** (keep `part`, `marker`, `label` helpers and the "returns MapContract problems" contract):
  - **Grounds** (top at y = 0): home 240 × 120 Grass; path strip 24 wide along the home centre line, slightly raised (0.05) Concrete; corridor 500 × 40 Slate dark; domain 180 × 180 `CrackedLava`, dark red.
  - **Walls** (`wallHeight` tall, thickness 2): home perimeter (z = ±60, x = 0, and the x = 240 segments beside the corridor mouth) invisible plus a visible 3-stud fence on the same lines; corridor sides (z = ±20) and domain perimeter (with a 40-wide opening at x = 740) visible, dark.
  - **Gate arch** at x = 740: two pillars and a top beam; the beam is the `SpeedSign` part (size (1, 8, 30), y ≈ 16), labelled `"SPEED CHECK"` on both faces.
  - **HomeZone**: one invisible box x 0 → 240, z −60 → 60, y 0 → 40; `CanCollide = false`, `CanTouch = false`, `CanQuery = false`.
  - **Arena** model (tag `BossArena`, `StageId`) at `arenaCenter`: same floor/wall ring as now, `BossSpawn` at the centre, `GiantEggSpawn` at `giantEggOffset`, and 12 `FieldEggSpawn` markers (transparent, non-colliding) from `fieldEggSpawns`.
  - **Stations** from `stationCFrames`: `HubSpawn` SpawnLocation, `WeaponShop`, treadmills, sandbags as now, and a plain grey 8 × 1 × 8 pad named `FuseMachineSpot` (no tag).
  - **Bases** from `plotCFrames`: floor 44 × 44, back/left/right walls, 16 slots, delivery pad at local z = −15, `BaseSpawn` marker at local (0, 3, −6), `BaseSign` on the back wall (local z = 21.5, y ≈ 7) so its Front face reads from the path.
  - **Lighting (day look):** `ClockTime = 17.6`; `Ambient = (90, 30, 20)`; `OutdoorAmbient = (120, 50, 30)`; replace `Lighting.Atmosphere` with `Density 0.35`, `Color (255, 110, 60)`, `Decay (120, 30, 20)`, `Haze 2`, `Glare 0.5`.
- [ ] **Step 2:** Run the builder: MCP `execute_luau` (Edit) with the file's contents. Expected: returns an empty table (no contract problems).
- [ ] **Step 3:** `screen_capture` from above the home area and above the domain; check plots, path, corridor and arena look right.
- [ ] **Step 4:** Play-check (start play, then stop): the player spawns on their plot's `BaseSpawn`; the boss stands at (830, y, 0) and chases inside the arena; an owned stand appears on a slot. Console has no errors.
- [ ] **Step 5:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 6:** Commit `feat: rebuild graybox as home, corridor and cursed domain`. Tell the user the Studio place changed and to save it (File → Save).

### Task 3: Carry config and rules for every egg

**Files:**
- Create: `src/shared/Config/Carry.luau`
- Modify: `src/shared/Config/GiantEgg.luau`, `src/shared/Config/Eggs.luau`, `src/shared/Config/Training.luau`, `tests/specs/Config.spec.luau`, `tests/specs/CarryCheck.spec.luau`
- Rename: `src/server/Logic/GiantEggRules.luau` → `CarryRules.luau`, `tests/specs/GiantEggRules.spec.luau` → `CarryRules.spec.luau` (`git mv`)

**Interfaces:**
- Produces `Config/Carry`: `{ pickupRange = 10, regrabCooldown = 1, carrierHitDamage = 10, speedSampleSeconds = 0.25, speedTolerance = 4, speedSlack = 4, speedGraceSeconds = 0.5, padHeight = 8, personalExpireSeconds = 300, personalRingRadius = 10, personalSize = 3 }`.
- `Config/GiantEgg` keeps `{ eggId, countdownSeconds, headStartSeconds, headStartCount, returnAfterSeconds, despawnAfterSeconds, maxActive, announceRarity, size }`.
- `Config/Eggs`: every egg gains `carryFactor` (`Stage1_Normal 0.9`, `Stage1_Top 0.8`, `Stage1_Giant 0.6`) and `color: Color3` (Normal `(235, 235, 235)`, Top `(170, 90, 255)`, Giant `(255, 205, 60)`).
- `Config/Training`: remove `carryWalkSpeed`.
- Produces `type EggState = { readyAt: number, headStartUntil: number, top: { [number]: boolean }, ownerUserId: number?, carrierUserId: number?, lastCarrierUserId: number?, regrabUntil: number, returnAt: number?, expireAt: number, returned: boolean }`.
- `CarryRules.canPickUp(egg, userId, carryingOther, distance, now, cfg)`: same signature and reasons as before, plus `"not yours"` (egg has `ownerUserId` ≠ `userId`) checked right after `"not ready"`. `cfg` is `Config/Carry`.
- `CarryRules.timeoutAction(egg, now): "despawn" | "return" | nil`: `"despawn"` when `now ≥ expireAt`; else `"return"` when `returnAt` is set, `now ≥ returnAt` and not `returned`.
- `CarryRules.onPad(...)` unchanged.
- Produces `CarryRules.carrySpeed(walkSpeed: number, carryFactor: number): number` (product).
- Produces `CarryRules.ringPositions(center: Vector3, radius: number, count: number): { Vector3 }`: `count` points on a horizontal circle, first at angle 0 (`center + (radius, 0, 0)`), evenly spaced; empty for count 0.

- [ ] **Step 1: Update and add tests.**
  - `CarryRules.spec` (renamed): existing cases with `cfg = Config.Carry`; `timeoutAction` cases rewritten on `returnAt = 180, expireAt = 300` (179 → nil, 180 → `"return"`, 180 returned → nil, 300 → `"despawn"`), and `no returnAt never returns` (`expireAt = 300`, now 250 → nil). `not yours`: `ownerUserId = 5`: user 6 → `"not yours"`, user 5 → true; `ownerUserId = 5` with `now < readyAt` → `"not ready"`.
  - `carrySpeed`: `(16, 0.6) → 9.6`, `(30, 0.9) → 27`.
  - `ringPositions`: count 1 → `{center + (10, 0, 0)}`; count 8 → 8 points, each exactly `radius` from center (flat), neighbours ≥ `2 × radius × sin(π/8) − 0.01` apart, all `Y == center.Y`; count 0 → empty.
  - `CarryCheck.spec`: load `Config.Carry` instead of `Config.GiantEgg`; add `trained walker passes at 27` (steps every 0.25 s moving 6.75 studs, t = 1..5 → all true).
  - `Config.spec`: replace the giant egg config test: `Eggs[GiantEgg.eggId]` exists; every egg has `0 < carryFactor ≤ 1` and a `Color3` color; `GiantEgg.returnAfterSeconds < GiantEgg.despawnAfterSeconds`; `Rarities.byName[GiantEgg.announceRarity]` exists; `Training.carryWalkSpeed == nil`; personal ring clears the boss: `Carry.personalRingRadius + Carry.personalSize < Map.giantEggOffset.Magnitude − 5`.
- [ ] **Step 2:** Run the test command. Expected: the new/changed tests FAIL.
- [ ] **Step 3:** Make the config changes and implement `CarryRules`. Keep `GiantEggService` booting with the minimum edits: require `CarryRules`, read the moved values from `Config/Carry`, set `returnAt`/`expireAt` on new eggs, and use `savedSpeed × Eggs[GiantEgg.eggId].carryFactor` where it used `Training.carryWalkSpeed`. Start play once: no boot warnings.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: carry config and rules for every egg`.

### Task 4: CarryService (giant and personal eggs) and personal egg drops

**Files:**
- Rename: `src/server/Services/GiantEggService.luau` → `CarryService.luau` (`git mv`)
- Create: `src/client/Controllers/EggPromptController.luau`
- Modify: `src/server/Services/LootService.luau`, `src/server/Services/CombatService.luau`, `src/client/Controllers/CombatController.luau` (controllers load automatically from the folder)

**Interfaces:**
- Consumes `Config/Carry`, `Config/Eggs.carryFactor/color`, `CarryRules.*`, `CarryCheck` (Task 3), `Map.giantEggOffset` indirectly via the `GiantEggSpawn` tag.
- Egg record: `{ id, kind: "Giant" | "Personal", eggId: string, ownerUserId: number?, stealable: boolean, spawnPos: Vector3, phase?, part?, prompt?, carrier?, ...EggState }`. Giant: `stealable = true`, `returnAt = readyAt + returnAfterSeconds`, `expireAt = readyAt + despawnAfterSeconds`. Personal: `stealable = false`, `readyAt = headStartUntil = now`, `top = {}`, `returnAt = nil`, `expireAt = now + personalExpireSeconds`.
- Keeps `CarryService:GetEggs()`, `:IsCarrying(player): boolean`, `:Drop(player, reason)`, `:TryPickUp(player, eggId): (boolean, string?)`.
- `CarryService:CarrierInReach(attacker, position, reach): Player?` now only considers carriers of `stealable` eggs.
- Produces `CarryService:SpawnPersonal(player: Player, eggId: string, position: Vector3): string?` → egg id (`"p<n>"`), or nil for an unknown `eggId`.
- Produces `CarryService:GetArenaEggSpawn(bossId: string): Vector3?` (the existing `arenaSpawnFor`, made public; LootService uses it as the ring centre).
- Carry record gains `speed = CarryRules.carrySpeed(savedSpeed, Eggs[eggId].carryFactor)`; pickup sets `humanoid.WalkSpeed = speed`; `stepCarrier` passes `carry.speed` to `CarryCheck.step`. Attribute `CarryingEgg` (replaces `CarryingGiantEgg`; update `CombatController:129`).
- `GiantEggState` broadcasts and global announcements only for `kind == "Giant"`. Personal: Notice on pickup (`"Carry your Top Egg home!"`), on delivery (`"Delivered your Top Egg!"`), on expiry (`"Your Top Egg crumbled away."`).
- Personal egg part: Ball of `personalSize`, Neon, `Eggs[eggId].color`, billboard `"<DisplayName>'s <displayName>"`, prompt attribute `OwnerUserId`. Carry highlight uses the egg's color.
- `PlayerRemoving`: drop what they carry (as now), then destroy every personal egg they own.
- `LootService.onDefeated`: rank as now; for the i-th of n ranked players, `CarryService:SpawnPersonal(player, eggId, ringPositions(GetArenaEggSpawn(bossId), personalRingRadius, n)[i])` and Notice `"Rank #%d! Carry your %s home"`. No `EggService:Grant` here any more. If there is no arena spawn, warn and fall back to `Grant` (so a broken map never eats rewards).
- `EggPromptController`: on start and on `workspace.Eggs.DescendantAdded`, for each `ProximityPrompt` whose `OwnerUserId` attribute is set and ≠ `LocalPlayer.UserId`, set `MaxActivationDistance = 0`.

- [ ] **Step 1:** `git mv` the service; rename module-level names, folder `Eggs`, part names `Egg_<id>`, log prefix `[CarryService]`; update `CombatService` (`require` + `Carry.carrierHitDamage`).
- [ ] **Step 2:** Generalise the egg record and carrying as above; add `SpawnPersonal`, `GetArenaEggSpawn`, owner cleanup on leave.
- [ ] **Step 3:** Update `LootService`, `CombatController`; add `EggPromptController`.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Play-test** (start play; give the dev profile enough power to kill the boss; temporary Scripts as in Global Constraints):
  - Kill the boss → a personal `Stage1_Top` egg appears on the ring next to `GiantEggSpawn`, labelled with your name; the giant egg still appears after 3 s.
  - Grab the personal egg → `WalkSpeed == 16 × 0.8 = 12.8`, `CarryingEgg == true`; try grabbing the giant egg → refused `"already carrying"` (D7).
  - `TryPickUp` for a personal egg with a fake second player is impossible in solo play: instead call `CarryRules.canPickUp(egg, userId + 1, ...)` on the live record and expect `"not yours"`.
  - Walk/teleport carry to the plot pad (teleport a few studs at a time, under the speed limit) → egg granted, appears in the eggs UI, `WalkSpeed` back to 16.
  - Set `WalkSpeed = 30` server-side before pickup, carry → speed 27 for the personal Normal egg, no `"speed"` drop in the console while walking.
  - Kill yourself while carrying → egg drops on the ground at your last spot, still yours after respawn; leave it 300 s (or set `expireAt` via a temp script) → it vanishes with the Notice.
  - Grab the giant egg → speed 9.6, the giant banner and announcements still work, delivery still grants `Stage1_Giant`.
  - Fill egg storage, deliver → one Notice per pad entry, keeps carrying.
  - Clean the dev profile (test eggs, stands, money) before stopping play.
- [ ] **Step 6:** Commit `feat: carry personal eggs home and scale carry speed by egg`.

### Task 5: Docs and status

**Files:**
- Modify: `CLAUDE.md` (Scope: 8-player servers / 8 bases; Not in V1: drop "day/night" per D11; Status), `Steal a boss fight/planning/decisions.md` (one line per D1–D15 summary linking the spec)

- [ ] **Step 1:** Update both files. Status: Plan A built on `feat/strip-map`; Next: Plan B (round cycle) then Plan C (boss chase); note decisions 6, 7 and 11 for later steps.
- [ ] **Step 2:** Commit `docs: update status after strip map and carried eggs`.

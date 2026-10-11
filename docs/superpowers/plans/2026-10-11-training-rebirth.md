# Training and Rebirth Implementation Plan (build step 10)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players train speed on treadmills and power on sandbags at home, and can rebirth (reset money, training and stand levels for permanent income and damage bonuses and extra team slots). Walk speed follows trained speed everywhere, including the carry rule (carry speed = walk speed × egg slowdown).

**Architecture:** The decisions are pure modules, `TrainingRules` (walk speed, may train) and `RebirthRules` (cost, may rebirth, what resets). A new `ProgressionService` owns training sessions (`Train` remote, a 1 s tick with position re-checks), the walk speed of every character, and the `Rebirth` remote. `CarryService` gains `SetBaseSpeed` so a speed change while carrying keeps the egg slowdown. Two client controllers add a training prompt and status on the stations, and a Rebirth button and panel.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP.

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (services table: `ProgressionService`; section 5 Training/Progression; section 6 data; section 7 `Train`, `Rebirth`; section 11 "Training", "Rebirth"; section 12 position checks; section 13 player leaves), with [the strip map spec](../../specs/2026-10-11-strip-map-and-egg-chase-design.md) D3 (carry speed = walk speed × slowdown). `CLAUDE.md`: training must not raise walk speed while carrying; carriers' `WalkSpeed = newSpeed × carryFactor`.

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/training-rebirth`, cut from `feat/gogo-attacks` (the stacked branches are unmerged). Do not merge.
2. **Walk speed = `min(maxWalkSpeed, baseWalkSpeed + training.speed)`**: one speed point = one stud/s. With `speedPerSecond = 0.05` that is +1 walk speed per 20 s on a treadmill and the cap of 60 after about 15 minutes. Power keeps its existing damage rule (`powerDamageFactor`).
3. **A session** starts with `Train(kind, true)` only if the player is alive, within `Training.trainRange = 6` studs (flat) of a part tagged with that kind, and not carrying an egg. Each `Training.tickSeconds = 1` the server re-checks the same conditions. If any fails, the session ends; otherwise it adds `rate × tickSeconds` to `training.speed` or `training.power`. `Train(_, false)`, death, leaving and picking up an egg end it. One session per player. Player attribute `Training = "Treadmill" | "Sandbag" | nil`.
4. **Walk speed is applied by `ProgressionService`** on every character spawn, on data load, after each speed tick and after a rebirth. While carrying, it calls `CarryService:SetBaseSpeed(player, walkSpeed)` instead of setting `WalkSpeed` directly.
5. **Rebirth cost** = `rebirthCostBase × rebirthCostGrowth ^ rebirths` (1M, 5M, 25M, …). On rebirth: `money = 0`, `training = { speed = 0, power = 0 }`, every stand's `level = 1` (slots and team kept), `rebirths += 1`. Eggs, stands, boss moves, armor, weapons, base slots and settings are kept. It is allowed while carrying (walk speed is re-applied through `SetBaseSpeed`).
6. **The rebirth panel needs a second click** ("Rebirth" then "Confirm") on the client. The server needs no confirmation, only the money check.
7. **UI:** a client `ProximityPrompt` on each `Treadmill`/`Sandbag` ("Train speed" / "Train power"; it shows "Stop" while training on that station). There is a status label above the money HUD while training: `"Training speed: 12.4  (walk 28)"` or `"Training power: 3.1  (+3% damage)"`. A `Rebirth` button sits in the left column under Stands (`Position UDim2.new(0, 16, 0.5, 90)`, 120 × 48) and opens the panel.

## Global Constraints

- The server decides gains, walk speed and rebirths; it validates `Train` args (kind already limited by `NetSchema`), the position, and the money.
- Data changes only through `DataService:Update`; money only reaches 0 through the rebirth `Update`.
- Pure modules (`server/Logic`) never call `game:GetService`.
- Every number lives in `Config/Training` or `Config/Progression`.
- Heartbeat bodies run in `xpcall`; errors log `[ProgressionService] ...`.
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending with the session's attribution line.
- MCP play-tests: temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`; `execute_luau`'s own `require` is a separate module copy). Log into a `StringValue` in `ServerStorage`. Patch `DataService.Get/Update` with an in-memory table and fire `DataService.Changed` from the patch, so the real dev profile (it holds test power 1,000,000) is never reset by a test rebirth. Set `Combat.standDamageFactor = 0` in tests that stand in the arena.
- Write files with the editor tools, not shell heredocs.
- Check that Rojo really synced (`Source:find(...)`) before trusting a test run. If a file stays stale, make a tiny real edit to it.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (260 passing at the start).

## Review Focus

1. **An exploiter fires `Train("Treadmill", true)` from across the map, or keeps it on and walks away:** no gains. Refused at start and ended on the next tick. Play-checked in Task 2.
2. **A player trains speed, then picks up an egg:** the session ends, and carry speed = trained walk speed × slowdown (for example walk 26 → Top Egg 20.8). After delivery, walk speed returns to 26, not 16. Play-checked in Task 2.
3. **A rebirth while carrying an egg:** walk speed drops to 16, and the carry speed becomes 16 × slowdown without a speed-check drop. Play-checked in Task 3.
4. **Exactly the rebirth cost:** succeeds, leaving 0. One less is refused with a Notice, and nothing changes. Tested in Task 1 (`canRebirth`) and play-checked in Task 3.
5. **A walk speed above the cap from old data** (`training.speed = 500`): walk speed 60. Tested in Task 1.

---

### Task 1: Config and pure rules

**Files:**
- Create: `src/server/Logic/TrainingRules.luau`, `src/server/Logic/RebirthRules.luau`, `tests/specs/TrainingRules.spec.luau`, `tests/specs/RebirthRules.spec.luau`
- Modify: `src/shared/Config/Training.luau`, `tests/specs/Config.spec.luau`

**Interfaces:**
- `Config/Training` gains `trainRange = 6`, `tickSeconds = 1`.
- Produces `TrainingRules.walkSpeed(speedStat: number, cfg): number` = `min(cfg.maxWalkSpeed, cfg.baseWalkSpeed + max(0, speedStat))`.
- Produces `TrainingRules.canTrain(kind: string, distance: number, carrying: boolean, alive: boolean, cfg): (boolean, string?)`. Reasons in order: `"bad kind"` (not Treadmill/Sandbag), `"dead"`, `"carrying"`, `"too far"` (`distance > trainRange`).
- Produces `TrainingRules.statFor(kind): "speed" | "power"` and `TrainingRules.rateFor(kind, cfg): number`.
- Produces `RebirthRules.cost(rebirths: number, cfg): number` = `rebirthCostBase × rebirthCostGrowth ^ rebirths`.
- Produces `RebirthRules.canRebirth(money: number, rebirths: number, cfg): (boolean, string?)`. The reason is `"poor"`.
- Produces `RebirthRules.apply(data): { money: number, rebirths: number, training: { speed: number, power: number }, characters: { [string]: any } }`: the new values for the four keys only. `characters` is a deep copy with every `level = 1` and every other field kept.

- [ ] **Step 1: Write the failing tests.**
  - `TrainingRules.spec`: `walk speed starts at base` (0 → 16); `one point per stud` (10 → 26); `capped` (500 → 60); `negative stat counts as zero` (−5 → 16); `canTrain` reasons (`"Bench"` → `"bad kind"`; dead → `"dead"`; carrying → `"carrying"`; distance 7 → `"too far"`; 6 → true); `statFor`/`rateFor` (Treadmill → `"speed"`, 0.05; Sandbag → `"power"`, 0.05).
  - `RebirthRules.spec`: `cost grows` (0 → 1,000,000; 1 → 5,000,000; 2 → 25,000,000); `exactly the cost is enough` (1,000,000 at 0 rebirths → true; 999,999 → `"poor"`); `apply resets only what it should` (data with money 5e6, rebirths 1, training {12, 3}, characters `c1` {id, level 7, slot 2} → money 0, rebirths 2, training {0, 0}, `c1.level == 1`, `c1.slot == 2`, `c1.id` unchanged, and the input data is untouched); `apply never returns other keys` (the result has exactly those 4 keys).
  - `Config.spec`: `training values` (`trainRange == 6`, `tickSeconds == 1`, `baseWalkSpeed < maxWalkSpeed`).
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement the config and both modules.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: training and rebirth rules`.

### Task 2: ProgressionService training and walk speed

**Files:**
- Create: `src/server/Services/ProgressionService.luau`
- Modify: `src/server/Services/CarryService.luau`

**Interfaces:**
- Consumes `TrainingRules`, `Config/Training` (Task 1); `DataService:Get/Update/Changed/Loaded`; `CarryService:IsCarrying`; `CollectionService` tags `Treadmill`, `Sandbag`.
- Produces `CarryService:SetBaseSpeed(player: Player, walkSpeed: number): boolean`. If they are carrying, it sets `carry.savedSpeed = walkSpeed` and `carry.speed = CarryRules.carrySpeed(walkSpeed, Eggs[egg.eggId].carryFactor)`, sets `humanoid.WalkSpeed = carry.speed`, then `ResetCheck(player)` (so a slowdown is never read as speeding), and returns true. If not carrying, it returns false and changes nothing.
- Produces `ProgressionService:ApplyWalkSpeed(player: Player)`: `walk = TrainingRules.walkSpeed(data.training.speed, Training)`. If `CarryService:SetBaseSpeed(player, walk)` returns false, set `humanoid.WalkSpeed = walk`. It runs on `CharacterAdded` (after the humanoid exists), on `DataService.Loaded`, and whenever `DataService.Changed` fires for `training`.
- Produces `ProgressionService:StartTraining(player, kind): (boolean, string?)` and `ProgressionService:StopTraining(player)`. The `Train(kind, active)` remote calls them. Starting uses `TrainingRules.canTrain(kind, nearest station distance, IsCarrying, alive)`; the distance is the flat distance from the root to the nearest part with that tag (`math.huge` if none). On a refusal: Notice `"Stand on a treadmill to train speed."` / `"Stand on a sandbag to train power."` / `"You can't train while carrying an egg."` (for `"dead"`, no Notice).
- Tick: a Heartbeat accumulator. Every `tickSeconds`, for each training player, re-check `canTrain` with the same kind. If it fails, `StopTraining`. Otherwise `DataService:Update(player, "training", …)` adds `rateFor(kind) × tickSeconds` to `statFor(kind)`.
- Player attribute `Training` is set and cleared by start and stop. Sessions are dropped on `PlayerRemoving` and `CharacterRemoving`.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (in-memory data with `training = { speed = 0, power = 0 }`; call the service methods directly):
  - On spawn: `WalkSpeed == 16`. Set `training.speed = 10` through `Update` → `WalkSpeed == 26`.
  - `StartTraining("Treadmill")` far from any treadmill → false and a Notice. Teleport onto a treadmill → true and `Training == "Treadmill"`. After 3 s, `training.speed` rose by 0.15 (± 0.05).
  - Walk 10 studs away → within 1.5 s the session ended (`Training == nil`) and the stat stops changing.
  - Sandbag → `training.power` rises.
  - With `training.speed = 10`, pick up a personal Top Egg → `WalkSpeed == 26 × 0.8 = 20.8`. `StartTraining` → refused with the carrying Notice. Deliver, or `Drop` → `WalkSpeed == 26`.
  - While training, pick up an egg nearby (spawn one on the treadmill) → the session ends on the next tick.
  - Respawn (Health 0) → `WalkSpeed == 26` again on the new character.
- [ ] **Step 4:** Commit `feat: treadmill and sandbag training with walk speed`.

### Task 3: Rebirth on the server

**Files:**
- Modify: `src/server/Services/ProgressionService.luau`

**Interfaces:**
- Consumes `RebirthRules` (Task 1), `Config/Progression`, `ApplyWalkSpeed` (Task 2), `AnnounceService`.
- Produces `ProgressionService:Rebirth(player): boolean`, called by the `Rebirth` remote. With data, if `RebirthRules.canRebirth(data.money, data.rebirths, Progression)` passes: `StopTraining`, `DataService:Update` each of the four keys from `RebirthRules.apply(data)`, `ApplyWalkSpeed`, Notice `"Rebirth " .. newRebirths .. "! Income +50%, damage +25% for good."` (numbers from `Progression`), and an announcement to all: `"<name> reached rebirth <n>!"` (rarity `"Epic"`). If it fails: Notice `"Rebirth costs $<cost>."` (`Format.number`), and nothing changes.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (in-memory data: money 1,000,000, rebirths 0, training {10, 5}, characters `c1` level 4 placed in slot 1, eggs 2, armor/weapons set):
  - `Rebirth` → true; money 0, rebirths 1, training {0, 0}, `c1` level 1 still in slot 1, eggs/armor/weapons unchanged, `WalkSpeed == 16`, Notice + announcement. The placed stand's label shows Lv 1 (StandService refresh).
  - Money 4,999,999 at rebirths 1 → false, Notice `"Rebirth costs $5M."`, and nothing changed.
  - Carrying a Top Egg with `training.speed = 10` (walk 20.8), money 5,000,000 → rebirth → carry speed 12.8, still carrying after 2 s of walking per-frame at 12 studs/s (no `"speed"` drop).
  - Income per second after the rebirth uses the ×1.5 multiplier (`EconomyService:IncomePerSecond`).
- [ ] **Step 4:** Commit `feat: rebirth resets money, training and stand levels`.

### Task 4: Training prompts, status and the rebirth panel

**Files:**
- Create: `src/client/Controllers/TrainingController.luau`, `src/client/Controllers/RebirthController.luau`

**Interfaces:**
- Consumes the `Train` and `Rebirth` remotes, the player attribute `Training`, `DataController` (`training`, `money`, `rebirths`), `Config/Training`, `Config/Progression`, `Config/Combat.powerDamageFactor`, `Widgets`, `Format`.
- `TrainingController`:
  - On start, add a local `ProximityPrompt` to every part tagged `Treadmill`/`Sandbag`, including ones streamed in later (`CollectionService:GetInstanceAddedSignal`). `ActionText` is `"Train speed"` / `"Train power"`, `MaxActivationDistance` is `Training.trainRange`, and `HoldDuration` is 0.
  - Triggered → `Train(kind, true)`, or `Train(kind, false)` if `Training == kind` already. While training, that station's prompt reads `"Stop"`.
  - The status label (decision 7) is shown only while `Training` is set and refreshed every 0.2 s from `DataController`. It shows walk speed via the same formula as `TrainingRules.walkSpeed`, duplicated on the client, and power as `math.floor(power × powerDamageFactor × 100)` % extra damage.
- `RebirthController`:
  - Adds the HUD button (decision 7), which toggles a panel registered as `"Rebirth"` (380 × 320, centred).
  - The panel shows: the current rebirths; the cost (`Format.number`) coloured green when affordable; "You keep: stands, eggs, boss moves, armor, weapons"; "You reset: money, training, stand levels"; and "Next: income +50%, damage +25%", plus "+1 team slot" if the next rebirth count is in `extraTeamSlotAtRebirths`.
  - The button reads `Rebirth` and switches to `Confirm` for 3 s after a click; a click on `Confirm` fires `Rebirth`.
  - It rebuilds on `money`/`rebirths` changes.

- [ ] **Step 1:** Implement both controllers.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (`screen_capture`; client `execute_luau` to open panels; the server side uses in-memory data with `DataChanged` pushes to the client):
  - Near a treadmill the `Train speed` prompt appears. After `Training = "Treadmill"`, the status label shows the speed and walk values.
  - The Rebirth button sits under Stands without overlapping. The panel shows a cost of $1M, the keep/reset lists and the next bonuses. One click shows `Confirm`; after 3 s it reverts to `Rebirth`.
  - Console has no errors.
- [ ] **Step 4:** Commit `feat: training prompts and rebirth panel`.

### Task 5: Docs and status

**Files:**
- Modify: `CLAUDE.md` (Status), `Steal a boss fight/planning/decisions.md` (one line for decisions 2, 3, 5 and 6)

- [ ] **Step 1:** Update Status: step 10 built on `feat/training-rebirth` (from `feat/gogo-attacks`). Next: step 11 (playtest and exploit review, Opus high) after the user's tests and merges. Note the training and rebirth numbers are placeholders, and that the dev profile's test power is wiped by a real rebirth.
- [ ] **Step 2:** Commit `docs: update status after training and rebirth`.

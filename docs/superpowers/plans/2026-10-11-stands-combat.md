# Stands in Combat Implementation Plan (build step 8)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players pick a stand team (3 slots, more by rebirth) in the Stands panel. While a player stands in the boss arena during a fight, the server deals their team's damage to the boss once per tick, counted in that player's damage ledger. Every client draws the fighting stands next to their owner.

**Architecture:** Two pure modules decide everything: `TeamRules` (slot count, team validation) and `StandDamage` (damage per tick). `StandService` gains the `SetTeam` handler and the damage tick, and publishes two player attributes, `StandTeam` (character ids) and `StandsFighting` (bool). A new client `StandCombatController` draws placeholder stands from those attributes (visual only). `StandsController` gets a Team toggle per stand.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP.

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (section 6 `standTeam`, section 7 `SetTeam`, section 8 "Stands in combat", section 9 step 2, section 12 performance), with [the strip map spec](../../specs/2026-10-11-strip-map-and-egg-chase-design.md) for carrying. `CLAUDE.md`: step 8 must skip players where `CarryService:IsCarrying` / `CarryingEgg`.

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/stands-combat`, cut from `feat/boss-chase` (the stacked branches are unmerged). Do not merge.
2. **Tick:** every `Combat.standTickSeconds = 1` s. Damage per tick = Σ over the team's stands of `basePower × Economy.standLevelPowerGrowth^(level − 1)`, × the rebirth damage multiplier `(1 + rebirths × Progression.damageMultiplierPerRebirth)`, × `Combat.standDamageFactor = 1`. The rebirth multiplier applies to stands too: the spec calls it a "permanent damage multiplier".
3. **When a team fights:** the owner is alive, inside the arena of a boss (`BossService:IsInArena`), not carrying any egg, and that boss is in a fight state (not `Dead`, not `Guard`, not dormant). Otherwise nothing is dealt and `StandsFighting` is false. Stand damage goes through `BossService:DamageBoss`, so it joins the owner's ledger and makes them a participant.
4. **Stale team entries** (a uid no longer in `characters`) are skipped at tick time; the saved list is not rewritten.
5. **Visuals:** every client draws every fighting player's team (spectacle). Placeholders are a 3 × 5 × 2 block per stand, coloured by rarity, in a row 6 studs behind the owner and 4 studs apart. Each tick they lunge 3 studs toward the boss and back over 0.3 s. These are client-only, anchored parts with no collision or query, so the server stays light (spec section 12). With the `fewerEffects` setting on, other players' stands don't lunge.
6. **Stand damage numbers** go only to the owner, in cyan `(90, 220, 255)`, so they read differently from the player's own hits.
7. **The Team toggle** lives on each Stands panel row. The panel header shows `Team n/slots`. A full team gives a toast `"Team is full (n). Remove a stand first."` without sending anything.

## Global Constraints

- The server decides team validity and all damage. The client sends `SetTeam(list)` and draws visuals only.
- Validate `SetTeam` fully on the server: a sequential list of strings, each an owned character uid, no duplicates, length ≤ team slots. On rejection, send the Notice `"Couldn't set that team."` and change nothing.
- Pure modules (`server/Logic`) never call `game:GetService`.
- Every number lives in `Config/Combat`, `Config/Economy`, `Config/Progression` or `Config/Characters`.
- Heartbeat bodies run in `xpcall`; errors log `[StandService] ...`.
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending with the session's attribution line.
- MCP play-tests: temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`; `execute_luau`'s own `require` gets a separate module copy, so call services only from such Scripts). Log into a `StringValue` in `ServerStorage`. Patch `DataService.Get/Update` with an in-memory table, so the real dev profile is never touched.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (205 passing at the start).

## Review Focus

1. **An exploiter sends `SetTeam` with someone else's uids, duplicates, a dictionary, 50 entries or numbers:** it is rejected with the Notice and the saved team is unchanged. Tested in Task 1 (`TeamRules.validate` cases) and play-checked in Task 2.
2. **A carrier stands in the arena:** their stands deal nothing and `StandsFighting` is false; after delivery they fight again. Play-checked in Task 2.
3. **The boss is dead, enraged (Guard) or dormant at night:** no stand damage, no damage numbers, no ledger entries. Play-checked in Task 2.
4. **A team member is upgraded mid-fight:** the next tick uses the new level, because damage is read from data each tick. Tested in Task 1 (level scaling) and play-checked in Task 2.
5. **A player leaves while fighting:** no errors, and their client-side stands disappear for everyone. Play-checked in Task 3 (destroy the attributes / leave).

---

### Task 1: Config and pure team and damage rules

**Files:**
- Create: `src/server/Logic/TeamRules.luau`, `src/server/Logic/StandDamage.luau`, `tests/specs/TeamRules.spec.luau`, `tests/specs/StandDamage.spec.luau`
- Modify: `src/shared/Config/Combat.luau`, `tests/specs/Config.spec.luau`

**Interfaces:**
- `Config/Combat` gains `standTickSeconds = 1`, `standDamageFactor = 1`.
- Produces `TeamRules.slots(rebirths: number, Progression): number` = `baseTeamSlots` + the count of `extraTeamSlotAtRebirths` entries ≤ `rebirths`.
- Produces `TeamRules.validate(list: any, characters: { [string]: any }, rebirths: number, Progression): (boolean, string?)`. Reasons, checked in this order: `"not a list"` (not a table, has non-integer or non-sequential keys, or a non-string value), `"too many"`, `"unknown stand"`, `"duplicate"`. An empty list is valid.
- Produces `StandDamage.perTick(team: { string }, characters, rebirths: number, Characters, Economy, Progression, Combat): number`, using decision 2. Uids not in `characters` and repeated uids count once or not at all; unknown character ids count 0.

- [ ] **Step 1: Write the failing tests.**
  - `TeamRules.spec`: `slots grow with rebirths` (0 → 3, 4 → 3, 5 → 4, 14 → 4, 15 → 5, 30 → 6, 100 → 6); `a valid team passes` (`{"c1","c2"}` with both owned); `empty team passes`; `not a list` (`"c1"`, `{ a = "c1" }`, `{ [1] = "c1", [3] = "c2" }`, `{ 5 }`); `too many` (4 owned uids at 0 rebirths → `"too many"`; the same at 5 rebirths → true); `unknown stand` (`{"c9"}`); `duplicate` (`{"c1","c1"}`).
  - `StandDamage.spec` (real `Config/Characters`, `Economy`, `Progression`, `Combat`): `one level-1 Lofy deals 1`; `level scaling` (Zoru level 3 → `6 × 1.3^2 = 10.14`, near 1e-6); `team sums` (Lofy L1 + Zoru L1 → 7); `rebirths multiply` (Lofy L1 at 2 rebirths → 1.5); `missing, duplicate and unknown entries` (team `{"c1","c1","gone"}` where `c1` is Lofy L1 → 1; a stand with id `"Nope"` → 0); `empty team deals 0`.
  - `Config.spec`: `stand tick values` (`standTickSeconds == 1`, `standDamageFactor == 1`).
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement the config values, `TeamRules`, `StandDamage`.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: team rules and stand damage per tick`.

### Task 2: SetTeam and the server damage tick

**Files:**
- Modify: `src/server/Services/StandService.luau`

**Interfaces:**
- Consumes `TeamRules`, `StandDamage`, `Config/Combat.standTickSeconds` (Task 1); `BossService:GetBosses / IsInArena / DamageBoss`; `CarryService:IsCarrying`; `DataService:Get / Update`.
- Produces `StandService:SetTeam(player: Player, list: any): boolean`: `TeamRules.validate(list, data.characters, data.rebirths, Progression)`. When it passes, `DataService:Update(player, "standTeam", function() return table.clone(list) end)` and return true. Otherwise send the Notice from Global Constraints and return false. The `SetTeam` remote handler only calls this (play-tests call it directly, because the Studio `FireRemote` hook can't send a table).
- Player attribute `StandTeam: string` = character ids of the team in order, joined with `","` (`""` when empty), skipping stale uids. Set on `DataService.Loaded` and whenever `standTeam` or `characters` changes.
- Player attribute `StandsFighting: boolean`, set only when it changes.
- Tick: a Heartbeat accumulator in `xpcall`. Each `standTickSeconds`, for every player with data:
  - `boss` = the first boss whose `IsInArena(boss, root.Position)` holds.
  - `fighting` = alive root, `boss` found, `boss.brain.state` is not `"Dead"` and not `"Guard"`, not `boss.dormant`, not `CarryService:IsCarrying(player)`, and `#data.standTeam > 0`.
  - If fighting: `dealt = BossService:DamageBoss(boss, player, StandDamage.perTick(...))`. When `dealt > 0`, fire `DamageNumbers` to that player with `{ amount = dealt, x, y, z (boss.pos + (0, 8, 0)), stand = true }`.
  - Set `StandsFighting = fighting`.
- `CarryService` is required lazily inside the tick (`require(script.Parent.CarryService)`), to avoid a load cycle.

- [ ] **Step 1:** Implement the handler, the attributes and the tick.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (temporary Script, in-memory data `{ characters = { c1 = { id = "Zoru_Base", level = 1 }, c2 = { id = "Lofy_Base", level = 1 } }, standTeam = {}, rebirths = 0, eggs = {}, baseSlots = 4 }`; call `StandService:SetTeam` directly):
  - Valid team `{"c1","c2"}` → `standTeam` saved, `StandTeam == "Zoru_Base,Lofy_Base"`.
  - Invalid inputs (`{"zz"}`, `{"c1","c1"}`, 4 entries, `{ a = "c1" }`) → Notice each time, team unchanged.
  - Teleport into the arena: within 2 s `StandsFighting == true`, boss HP drops by 7 per second, and the ledger shows the player's damage.
  - Pick up a field egg in the arena → `StandsFighting == false` and boss HP stops dropping. Drop it → fighting again.
  - Upgrade `c1` to level 3 in the fake data → the next ticks deal `10.14 + 1`.
  - Kill the boss → no stand damage while `Dead` or `Guard` (`Hp` stays at max during Guard), and `StandsFighting == false`. `SetDormant(true)` → still false.
  - Leave the arena → false.
- [ ] **Step 4:** Commit `feat: stand team deals damage in the boss arena`.

### Task 3: Team toggle and stand visuals

**Files:**
- Create: `src/client/Controllers/StandCombatController.luau`
- Modify: `src/client/Controllers/StandsController.luau`, `src/client/Controllers/CombatController.luau`, `src/client/Fx/CombatFx.luau`

**Interfaces:**
- Consumes the attributes `StandTeam` / `StandsFighting` (Task 2), `Config/Characters`, `Config/Rarities.byName[r].color`, `Config/Combat.standTickSeconds`, and the player setting `settings.fewerEffects` (from `DataController`).
- `StandsController`: on each row, a `Team` / `Team ✓` button (80 × 22 at `Position UDim2.new(1, -166, 0, 28)`). It fires `SetTeam(newList)` with the uid added or removed, keeping order. A full team shows the toast (decision 7). The header shows `Team n/slots`, using `TeamRules.slots` logic duplicated on the client as `baseTeamSlots + #extra ≤ rebirths` (pure, the same numbers).
- `CombatFx.damageNumber(position, amount, staggered, color: Color3?)`: optional colour; the `DamageNumbers` handler passes cyan `(90, 220, 255)` when `info.stand`.
- `StandCombatController`: every 0.1 s, for every player whose `StandsFighting` is true and `StandTeam ~= ""`, keep one placeholder per id (decision 5) in a client folder `workspace.CurrentCamera.StandFx`. Place them each frame (RenderStepped) at `root.CFrame * CFrame.new((i − (n + 1) / 2) × 4, 0, 6)`. Every `standTickSeconds`, lunge toward the nearest model in `workspace.Bosses`. Remove a player's placeholders when they stop fighting, lose their character, or leave (`Players.PlayerRemoving`).

- [ ] **Step 1:** Implement the toggle, the damage number colour and `StandCombatController`.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check:**
  - Open the Stands panel (`screen_capture`): every row shows `Team`, and the header reads `Team 0/3`. A server-side `StandService:SetTeam(player, {uid})` updates it to `Team ✓` and `Team 1/3` after the data change.
  - In the arena with a 2-stand team: `screen_capture` shows two coloured blocks behind the character, cyan damage numbers appear, and the blocks lunge about once a second.
  - Set `StandsFighting = false` server-side → the blocks disappear within 0.2 s.
  - Console has no errors.
- [ ] **Step 4:** Commit `feat: stand team toggle and client stand visuals`.

### Task 4: Docs and status

**Files:**
- Modify: `CLAUDE.md` (Status), `Steal a boss fight/planning/decisions.md` (section 19 "Stand team": one line for decisions 2, 3 and 5)

- [ ] **Step 1:** Update Status: step 8 built on `feat/stands-combat` (from `feat/boss-chase`); Next: step 9 (drops and weapon shop) after the user's tests and merges. Add one line saying stand damage is tuned by `Combat.standDamageFactor`; balance against player damage in the playtest (step 11).
- [ ] **Step 2:** Commit `docs: update status after stands in combat`.

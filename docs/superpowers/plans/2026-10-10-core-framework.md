# Core Framework Implementation Plan (Build Step 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The foundation every later system plugs into: a Studio test runner, number formatting, all config modules, egg-roll logic, a validated networking layer, two-phase service/controller boot, and saving with ProfileStore.

**Architecture:** Plain ModuleScript services (server) and controllers (client) booted in two phases (`Init`, then `Start`). Pure logic lives in `src/server/Logic` and `src/shared/Util` and takes config as arguments, so it can be unit-tested in Studio. Only DataService writes player data.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`), ProfileStore (vendored).

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (sections 3–7, 15–17)

## Plan series

This is plan 1 of the V1 series; later plans are written after this one ships, one per build step in `CLAUDE.md`: 4 graybox map, 5 combat core, 6 eggs/hatching/stands earning, 7 giant egg, 8 stands in combat, 9 drops and weapon shop, 10 training/rebirth/upgrades/offline earnings.

## Global Constraints

- Rojo manages only `src/` and `tests/`; never put map, lighting or `Assets` into Rojo.
- Pure logic modules never reference `game` services or `ReplicatedStorage` paths; they receive config and RNG as arguments.
- The server owns every outcome; clients send intents only.
- DataStore names: `PlayerData_Dev` in Studio (`RunService:IsStudio()`), `PlayerData_Live` otherwise.
- Never play on empty data: profile load failure kicks with `"Couldn't load your data, please rejoin."`
- No `require(assetId)`, no `loadstring`, no unaudited toolbox scripts.
- One task = one commit. Commit author `Johan Gerold <johangerold385@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Studio instance: get the id with `list_roblox_studios` (it changes when Studio restarts).

**Test command (used by every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected on success: output ends with `FAIL 0`. (Cloning defeats `require` caching so Rojo's latest code is always tested.)

## Review Focus

1. **Bad remote arguments** (nil, NaN, ±inf, 10 000-char strings, tables where numbers expected) → dropped, never reach handlers. Test in Task 5.
2. **Remote spam** beyond the rate limit → extra calls dropped, limit recovers after the window. Test in Task 5.
3. **Old saves missing newer fields** → defaults filled in without overwriting existing values. Test in Task 7.
4. **Player leaves while their profile is still loading** → session ends cleanly, no data kept in memory, no error. Play-test check in Task 8.
5. **Money display extremes** (0, negatives, decimals, 1e300, inf) → readable string, never an error. Test in Task 2.

---

### Task 1: Test runner and Rojo mapping

**Files:**
- Modify: `default.project.json` (add `ServerStorage.Tests` → `tests`)
- Create: `tests/Runner.luau`, `tests/specs/Runner.spec.luau`
- Delete: `src/shared/Hello.luau`

**Interfaces:**
- Produces: `Runner.run(): string`. Spec files are ModuleScripts in `tests/specs/` named `*.spec`, each returning `{ [testName: string]: (expect: Expect, mods: Mods) -> () }`.
- `Expect`: `eq(actual, expected, msg?)`, `near(actual, expected, tol, msg?)`, `truthy(value, msg?)`, `errors(fn, msg?)`.
- `Mods`: `{ Shared: Folder, Logic: Folder }`, fresh clones of `ReplicatedStorage.Shared` and `ServerScriptService.Server.Logic` (use `mods.Logic.X` with `require`).

- [ ] **Step 1:** Add to `default.project.json` tree: `"ServerStorage": { "Tests": { "$path": "tests" } }`. Create `src/server/Logic/Placeholder.luau` returning `{}` (Rojo needs the folder to exist; Task 4 deletes it).
- [ ] **Step 2: Write `tests/specs/Runner.spec.luau`** with tests `eq passes on equal values`, `eq fails on different values` (uses `expect.errors(function() expect.eq(1, 2) end)`), `near tolerates small difference` (`expect.near(1.0, 1.05, 0.1)`).
- [ ] **Step 3: Implement `tests/Runner.luau`.** `run()` clones `Shared` and `Logic` into a temp Folder, requires each `*.spec` clone, runs every test in `pcall`, collects `"FAIL <spec>/<test>: <error>"` lines, returns `"PASS <n>\n<failures>\nFAIL <m>"`, destroys the temp folder.
- [ ] **Step 4:** Make sure `rojo serve` is running and Studio is connected; run the test command. Expected: `PASS 3` … `FAIL 0`.
- [ ] **Step 5: Commit** `test: add Studio test runner and tests mapping`.

### Task 2: Number formatting

**Files:**
- Create: `src/shared/Util/Format.luau`, `tests/specs/Format.spec.luau`

**Interfaces:**
- Produces: `Format.number(n: number): string`

- [ ] **Step 1: Write the failing tests:**

```lua
expect.eq(Format.number(0), "0")
expect.eq(Format.number(999), "999")
expect.eq(Format.number(1200), "1.2K")
expect.eq(Format.number(1000), "1K")
expect.eq(Format.number(1530000), "1.53M")
expect.eq(Format.number(2.5e9), "2.5B")
expect.eq(Format.number(7e12), "7T")
expect.eq(Format.number(-1500), "-1.5K")
expect.eq(Format.number(12.7), "12")       -- floor below 1000
expect.eq(Format.number(1e300), "1e+300")  -- beyond suffix table: scientific
expect.eq(Format.number(math.huge), "∞")
```

- [ ] **Step 2:** Run test command. Expected: FAIL (module missing).
- [ ] **Step 3: Implement.** Suffixes `{"", "K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}`; up to 3 significant digits, trailing zeros stripped; values past `Dc` use `string.format("%.0e")`-style output matching the test; NaN returns `"0"`.
- [ ] **Step 4:** Run test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add number formatting`.

### Task 3: Config modules and integrity tests

**Files:**
- Create in `src/shared/Config/`: `Rarities.luau`, `Characters.luau`, `Eggs.luau`, `Bosses.luau`, `Weapons.luau`, `Armor.luau`, `Economy.luau`, `Combat.luau`, `Training.luau`, `Progression.luau`, `Keybinds.luau`
- Test: `tests/specs/Config.spec.luau`

**Interfaces:**
- Produces (shapes used by every later plan):
  - `Rarities.order: {string}` (12 names, Common → Absolute); `Rarities.byName[name] = { index: number, color: Color3, aura: "None"|"Static"|"Animated", auraIntensity: number }`
  - `Characters[id] = { displayName, rarity, family, model, walkAnim, baseIncome, basePower }`
  - `Eggs[id] = { hatchSeconds: number, odds: { [rarity]: weight } }`
  - `Bosses[id]`, `Weapons[id]`, `Armor[id]` with fields exactly as listed in spec §5
  - `Combat` numbers from spec §5/§8: `parryWindow = 0.20`, `perfectDodgeWindow = 0.15`, `dodgeIFrames = 0.30`, `counterWindow = 1.5`, `claimMaxAge = 0.30`, `claimFutureTolerance = 0.05`, `minDamageShare = 0.05`
  - `Economy.offlineCapSeconds = 8 * 3600`, `Economy.offlineRate = 0.5`, `Economy.inventoryCap = 200`
  - `Keybinds.defaults = { Attack = "MouseButton1", Parry = "MouseButton2", Dodge = "LeftShift", Ability1 = "One", Ability2 = "Two", Ability3 = "Three", Ability4 = "Four", Interact = "E", ToggleCombatMode = "LeftControl", OpenMenu = "Tab" }`

Rarity colors (hex): Common `#9CA3AF`, Uncommon `#22C55E`, Rare `#3B82F6`, Epic `#A855F7`, Legendary `#F59E0B`, Mythic `#F43F5E`, Celestial `#67E8F9`, Divine `#FCD34D`, Transcendent `#F472B6`, Primordial `#C4B5FD`, Omniversal `#E879F9`, Absolute `#F87171`. Aura: None for indexes 1–5, Static for 6, Animated for 7–12 with `auraIntensity = index - 6`.

V1 placeholder characters (models named identically under `Assets.Characters`): `Lofy_Base` Common, `Zoru_Base` Rare, `Narto_Base` Epic, `Gokku_Base` Legendary, `Gokku_Red` Mythic, `Gokku_Blue` Celestial (family `Gokku` for the last three). Eggs: `Stage1_Normal` (Common 60, Rare 25, Epic 12, Legendary 3), `Stage1_Top` (Mythic 90, Celestial 10), `Stage1_Giant` (Legendary 40, Mythic 45, Celestial 15). Boss: `Boss_Lofy` (Stage, `stageId = "Stage1"`, `staggerSeconds = 5`, two attacks, one `unparryable`, `playerMoves` of 4 move ids, `armorChance = 0.35`, `moveCopyChance = 0.05`). Weapons: `Fists` (price 0), `Stick`, `Katana`.

- [ ] **Step 1: Write the failing tests:** `12 rarities in order`; `every character rarity exists`; `every egg odds key is a rarity with weight > 0`; `Stage1_Top only rolls Mythic or higher` (every key's index ≥ 6); `Stage1_Normal only rolls Legendary or lower` (index ≤ 5); `every egg rarity has at least one character`; `every boss playerMoves has 1 to 4 entries`; `keybind defaults cover all 10 actions`.
- [ ] **Step 2:** Run test command. Expected: FAIL.
- [ ] **Step 3:** Write the config modules with the values above.
- [ ] **Step 4:** Run test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add V1 config modules`.

### Task 4: Weighted rolls and egg rolls

**Files:**
- Create: `src/server/Logic/Odds.luau`, `src/server/Logic/EggRoll.luau`; delete `src/server/Logic/Placeholder.luau`
- Test: `tests/specs/EggRoll.spec.luau`

**Interfaces:**
- Produces: `Odds.pick(weights: {[string]: number}, rng: Random): string`; `EggRoll.roll(egg, characters, rng: Random): string` (returns a character id).

- [ ] **Step 1: Write the failing tests:** `pick with a single key always returns it`; `pick errors on empty or all-zero weights`; `pick distribution within 2% over 100k rolls` (weights `{a=75, b=25}`, `Random.new(42)`); `egg roll returns a character of an allowed rarity` (Stage1_Top over 1 000 rolls: every result's rarity index ≥ 6); `egg roll skips rarities with no characters` (egg `{Common=50, Divine=50}` with only Common characters → always a Common character); `egg roll errors when no rarity has characters`.
- [ ] **Step 2:** Run test command. Expected: FAIL.
- [ ] **Step 3: Implement.** `Odds.pick`: iterate keys in **sorted order** (deterministic for a given seed), cumulative weights, `rng:NextNumber(0, total)`. `EggRoll.roll`: drop rarities with no characters, `Odds.pick` a rarity, then pick uniformly among that rarity's characters sorted by id.
- [ ] **Step 4:** Run test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add weighted and egg roll logic`.

### Task 5: Networking

**Files:**
- Create: `src/shared/NetSchema.luau` (pure), `src/shared/Util/RateLimiter.luau` (pure), `src/shared/Net.luau` (Roblox wiring)
- Test: `tests/specs/Net.spec.luau`

**Interfaces:**
- Produces:
  - `NetSchema.definitions[name] = { dir: "c2s"|"s2c", args: {string}, rate: number?, unreliable: boolean? }` for every message in spec §7.
  - Arg type names: `"number"`, `"int"`, `"string"`, `"boolean"`, `"table"`, `"any"`, with `"?"` suffix for optional (e.g. `"string?"`).
  - `NetSchema.validate(name: string, args: {any}): (boolean, string?)`. Numbers must be finite (not NaN/±inf); strings ≤ 200 chars; extra args rejected.
  - `RateLimiter.new(maxPerWindow: number, windowSeconds: number)` → `:allow(key: any, now: number): boolean`
  - `Net.Server(name)` → `:On(handler(player, ...))`, `:Fire(player, ...)`, `:FireAll(...)`; `Net.Client(name)` → `:On(handler(...))`, `:Fire(...)`. Server creates remotes in `ReplicatedStorage.Remotes` during `Net.InitServer()`; clients `WaitForChild` them. Invalid or rate-limited calls are dropped and `warn`ed once per player per message per minute.
- Rates: `Attack` 10/s, `UseAbility` 5/s, `Defend` 6/s, `Counter` 2/s, everything else 4/s.

- [ ] **Step 1: Write the failing tests:** `valid Attack passes` (`{2, "Fists"}`); `NaN rejected`; `inf rejected`; `wrong type rejected` (`{"2", "Fists"}`); `missing arg rejected`; `extra arg rejected`; `long string rejected` (201 chars); `optional arg may be nil`; `unknown message rejected`; `limiter allows up to max then blocks`; `limiter recovers after window`; `limiter keys are independent`.
- [ ] **Step 2:** Run test command. Expected: FAIL.
- [ ] **Step 3:** Implement the three modules.
- [ ] **Step 4:** Run test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add validated networking layer`.

### Task 6: Two-phase boot

**Files:**
- Modify: `src/server/init.server.luau`, `src/client/init.client.luau`
- Create: `src/server/Services/` and `src/client/Controllers/` (first members arrive in Task 8)

**Interfaces:**
- Produces: any ModuleScript in `Services/` or `Controllers/` returning a table with optional `Init(self)` and `Start(self)`. Boot requires all, calls every `Init` (in name order), then every `Start` in its own `task.spawn` wrapped in `xpcall` with `debug.traceback`. Server calls `Net.InitServer()` before any `Init`. Prints `[Boot] server: N services started` / `[Boot] client: N controllers started`.

- [ ] **Step 1:** Implement both boot scripts; remove the hello-world prints.
- [ ] **Step 2: Play test:** `start_stop_play(true)`, `get_console_output`. Expected: `[Boot] server: 0 services started` and `[Boot] client: 0 controllers started`, no errors. `start_stop_play(false)`.
- [ ] **Step 3: Commit** `feat: add two-phase service and controller boot`.

### Task 7: Save template and migrations

**Files:**
- Create: `src/server/Logic/DataTemplate.luau`, `src/server/Logic/Migrations.luau`
- Test: `tests/specs/Data.spec.luau`

**Interfaces:**
- Produces: `DataTemplate.new(): table` (fresh copy of spec §6 layout with `version = 1`, `money = 0`, `baseSlots = 4`, `weapons = { owned = {"Fists"}, equipped = "Fists" }`, empty `characters`, `eggs`, `bossMoves`, `standTeam`, `settings = { fewerEffects = false, keybinds = {} }`); `Migrations.run(data: table): table` (fills missing keys recursively from the template without overwriting existing values, applies version steps, sets `version` to current).

- [ ] **Step 1: Write the failing tests:** `new returns independent copies` (mutating one doesn't change another); `missing keys filled` (`{version=1, money=50}` → money stays 50, `settings.keybinds` exists); `nested missing keys filled` (`settings = {fewerEffects=true}` → `fewerEffects` stays true, `keybinds` added); `existing values never overwritten`; `version set to current`.
- [ ] **Step 2:** Run test command. Expected: FAIL.
- [ ] **Step 3:** Implement both modules.
- [ ] **Step 4:** Run test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add save template and migrations`.

### Task 8: DataService, DataController and ProfileStore

**Files:**
- Create: `src/server/Packages/ProfileStore.luau` (vendored), `src/server/Services/DataService.luau`, `src/client/Controllers/DataController.luau`
- Modify: `src/shared/NetSchema.luau` only if `DataInit`/`DataChanged` aren't already defined

**Interfaces:**
- Consumes: `Net`, `DataTemplate`, `Migrations`.
- Produces:
  - `DataService:Get(player): table?` (read-only use), `DataService:Update(player, key: string, fn: (old: any) -> any)` (sets `data[key] = fn(old)`, fires `DataChanged(key, value)` to that player), `DataService.Loaded: Signal(player)`.
  - Client: `DataController:Get(key): any`, `DataController.Changed: Signal(key, value)`, `DataController:WaitForData()`.
  - `Util/Signal.luau`: `Signal.new()` → `:Connect(fn)` returns `{ Disconnect }`, `:Fire(...)`.

- [ ] **Step 1: Ask the user** before downloading ProfileStore from its official GitHub repo (MadStudioRoblox/ProfileStore): state file, source and size; confirm the license allows use; read the whole file before adding it.
- [ ] **Step 2: User setup (guide them):** publish the place privately (File → Publish to Roblox) and turn on Game Settings → Security → "Enable Studio Access to API Services".
- [ ] **Step 3:** Implement `Signal`, `DataService` (store name per Global Constraints; `StartSessionAsync` with cancel when the player leaves; `Migrations.run` on load; kick message on failure; end session on leave; send `DataInit(data)` once loaded), and `DataController`.
- [ ] **Step 4: Play test:** start play; expected console: `[Boot] server: 1 services started`, `[Data] loaded <UserId>`, `[Boot] client: 1 controllers started`; then `execute_luau` in `Client`: `return require(game.Players.LocalPlayer.PlayerScripts.Client.Controllers.DataController):Get("money")` → `0`. In `Server`: call `DataService:Update(player, "money", function(m) return m + 100 end)`; client `Get("money")` → `100`. Stop play, start again: money still `100` (saved to `PlayerData_Dev`). Stop play.
- [ ] **Step 5: Review Focus check:** in `Server` during play, simulate leaving during load by kicking the player immediately after join (temporary test line, removed afterwards); expected: no errors, `[Data] session ended <UserId>`.
- [ ] **Step 6:** Run test command (unit tests still pass). Expected: `FAIL 0`.
- [ ] **Step 7: Commit** `feat: add saving with ProfileStore`.

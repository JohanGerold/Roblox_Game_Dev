# Gogo Attacks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the stage 1 boss into Gogo with four parryable attacks (Slam, Sweep, Ground Fire on a random player, Flame Wave sweeping the arena), per-attack parry windows and cooldowns, readable warnings (markers, timing rings, PARRY prompt, danger kanji), and asset slots for Astra's model, effects and animations.

**Architecture:** Attack behaviour stays data in `Config/Bosses` (`targeting`, `parryWindow`, `cooldown`, `danger`, `vfx`, `anim`, wave fields). The pure logic is split three ways: `BossBrain` picks eligible attacks and tracks cooldowns, `Hitbox` gains a `Circle` shape, and a shared `WaveTiming` computes the ring radius and per-player arrival. `BossService` locks Ground Fire centres and turns a Flame Wave into one impact per player, all through the existing `Impact` → `CombatService` judging path, with each attack's own parry window. Clients draw every warning from `BossAttack` plus a new optional payload table.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP.

**Spec:** [docs/specs/2026-10-11-gogo-attacks-design.md](../../specs/2026-10-11-gogo-attacks-design.md). Asset contract: [ASSETS.md](../../../ASSETS.md) section 2a. Handoff sent: [handoffs/2026-10-11-claude-gogo-milestone1.md](../../../handoffs/2026-10-11-claude-gogo-milestone1.md).

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/gogo-attacks`, cut from `feat/drops-shop` (the stacked branches are unmerged). Do not merge.
2. **`WaveTiming` lives in `src/shared/Util/`**, because the client needs the same arrival maths for drawing and for the Studio auto-parry hook.
3. **`BossBrain.update(b, now, dt, targetInRange, rng, anyInArena: boolean?)`**: the new input goes last and defaults to `targetInRange`, so existing call sites and tests keep working.
4. **The Ground Fire payload includes `targetUserId`**, so only the targeted client shows the danger warning.
5. **A Flame Wave player's impact time is their exact arrival time** (`WaveTiming.arrival`), not the server frame time, so parry judging matches what the client drew.
6. **Boss animations play on the server** through the model's `Animator`, since server-played animations replicate. With no id or no `Animator`, nothing plays and nothing warns.
7. **`DefenseJudge.judge` gets an optional 5th argument `parryWindow`**; when it's nil, it uses `Combat.parryWindow`.

## Global Constraints

- The server decides targets, impacts and damage; clients only draw.
- Pure modules (`server/Logic`, `shared/Util`) never call `game:GetService`; randomness comes in as a `Random` argument.
- Every number lives in `Config/Bosses`, `Config/Combat` or `Config/Map`.
- Heartbeat bodies run in `xpcall` (the existing loops).
- Every Gogo attack has `unparryable = false`.
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending with the session's attribution line.
- MCP play-tests: temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`; `execute_luau`'s own `require` is a separate module copy). Log into a `StringValue` in `ServerStorage`. Patch `DataService.Get/Update` with an in-memory table if data is touched. Make the test character survive with `MaxHealth = Health = 1e9` when counting hits.
- Write files with the editor tools, not shell heredocs (long heredocs have broken in this shell).

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (243 passing at the start).

## Review Focus

1. **A player jumps or stands on a rock inside the Ground Fire circle:** they are still hit, because the `Circle` height is 10. Tested in Task 1 (`Circle` at dy 6 is inside, dy 11 is outside).
2. **A Flame Wave reaches a player who is parrying at their own arrival time, while another player farther out parries at the same wall-clock moment:** the near player is blocked, and the far player is judged at their own later time (blocked only if they parry then). Play-checked in Task 3 with the auto-parry hook using personal arrival times.
3. **The boss is staggered by parries in the middle of a Flame Wave:** no further impacts from that wave. Play-checked in Task 3.
4. **Nobody is in the arena, or everyone is out of melee range:** no `Self` attack starts out of range, and no ranged attack starts with an empty arena. Tested in Task 2.
5. **Reduced effects on:** markers, timing rings, PARRY prompt and danger warning still show; only `Impact` effects are skipped. Play-checked in Task 4.

---

### Task 1: Config, Circle hitbox, WaveTiming and per-attack parry window

**Files:**
- Create: `src/shared/Util/WaveTiming.luau`, `tests/specs/WaveTiming.spec.luau`
- Modify: `src/shared/Config/Bosses.luau`, `src/server/Logic/Hitbox.luau`, `src/server/Logic/DefenseJudge.luau`, `src/shared/NetSchema.luau`, `tests/specs/Hitbox.spec.luau`, `tests/specs/DefenseJudge.spec.luau`, `tests/specs/Config.spec.luau`

**Interfaces:**
- `Config/Bosses.Boss_Lofy` (spec section 2):
  - **Boss:** `displayName = "Gogo"`, `model = "Boss_Gogo"`, `vfxFolder = "Gogo"`, `animations = {}` (ids filled later).
  - **Slam:** `targeting = "Self"`, `parryWindow = 0.20`, `cooldown = 0`, `danger = false`, `vfx = "Slam"`.
  - **Sweep:** the same fields with `vfx = "Sweep"`, plus `unparryable = false` and `poiseOnParry = 25`.
  - **New `GroundFire`:** `{ id = "GroundFire", targeting = "Player", windup = 1.5, activeWindow = 0.2, recovery = 0.6, damage = 30, hitbox = { shape = "Circle", radius = 7, height = 10 }, parryWindow = 0.35, cooldown = 6, poiseOnParry = 15, unparryable = false, danger = true, vfx = "GroundFire" }`.
  - **New `FlameWave`:** `{ id = "FlameWave", targeting = "Wave", windup = 2.0, activeWindow = 2.2, recovery = 1.0, damage = 25, hitbox = { shape = "Circle", radius = 70, height = 10 }, waveSpeed = 30, waveStartRadius = 8, parryWindow = 0.35, cooldown = 15, poiseOnParry = 20, unparryable = false, danger = true, vfx = "FlameWave" }`. Its hitbox only exists for config checks; impacts come from `WaveTiming`.
  - Every attack may carry `anim` (nil for now).
- `Hitbox.contains` handles `Circle`: flat XZ distance from `origin.Position` ≤ `radius` and `|point.Y − origin.Y| ≤ height`.
- Produces `WaveTiming.radiusAt(t: number, waveStart: number, attack, maxRadius: number): number` = `min(maxRadius, attack.waveStartRadius + attack.waveSpeed × max(0, t − waveStart))`.
- Produces `WaveTiming.arrival(distance: number, waveStart: number, attack): number` = `waveStart + max(0, distance − attack.waveStartRadius) / attack.waveSpeed`.
- `DefenseJudge.judge(history, impactTime, unparryable, Combat, parryWindow: number?)`.
- `NetSchema.BossAttack.args = { "string", "string", "number", "table?" }`.

- [ ] **Step 1: Write the failing tests.**
  - `Hitbox.spec`: `circle uses flat distance and height` (origin `CFrame.new(0, 0, 0)`, radius 7, height 10: `(6, 6, 0)` true, `(0, 11, 0)` false, `(5, 0, 5)` false (flat 7.07), `(4.9, -9, 4.9)` true).
  - `WaveTiming.spec` (attack `{ waveStartRadius = 8, waveSpeed = 30 }`): `radius grows from the start radius` (t = waveStart → 8; +1 s → 38; +5 s capped at max 70); `before the start it is the start radius` (t = waveStart − 1 → 8); `arrival inside the start radius is immediate` (distance 5 → waveStart); `arrival further out` (distance 68 → waveStart + 2).
  - `DefenseJudge.spec`: `per-attack window` (parry 0.3 s before impact: window nil → `"Hit"`, window 0.35 → `"Parried"`).
  - `Config.spec`: `every attack has the new fields` (`targeting` ∈ Self/Player/Wave, `parryWindow > 0`, `cooldown ≥ 0`, `vfx` a non-empty string, `type(danger) == "boolean"`); `every Gogo attack is parryable` (`unparryable == false` for all of `Boss_Lofy.attacks`); `wave attacks have speed and start radius` (> 0); `gogo is the stage 1 boss` (`displayName == "Gogo"`, `model == "Boss_Gogo"`, `vfxFolder == "Gogo"`).
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement the config, `Hitbox` `Circle`, `WaveTiming`, the `DefenseJudge` argument and the schema change. Pass `attack.parryWindow` from `CombatService.judgeVictim` (one-line change).
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`. Start play once: no boot warnings beyond the expected `no asset Assets.Bosses.Boss_Gogo` placeholder notice.
- [ ] **Step 5:** Commit `feat: gogo attack config, circle hitbox and wave timing`.

### Task 2: Attack choice and cooldowns in BossBrain

**Files:**
- Modify: `src/server/Logic/BossBrain.luau`, `tests/specs/BossBrain.spec.luau`

**Interfaces:**
- `BossBrain.update(b, now, dt, targetInRange, rng, anyInArena?)` (decision 3). In `Idle`, once `now ≥ stateEndsAt`, it builds the eligible list in `cfg.attacks` order:
  - `Self` attacks when `targetInRange`;
  - other attacks when `anyInArena` and `now ≥ (b.readyAt[id] or 0)`.

  If the list is not empty, it picks `eligible[rng:NextInteger(1, #eligible)]`, sets `b.readyAt[id] = now + (attack.cooldown or 0)` and enters `Windup` as today.
- `init` resets `b.readyAt = {}` (so `reset` and `enterGuard` clear cooldowns).

- [ ] **Step 1: Write the failing tests** (use a cfg copy whose `attacks` you control, built from the real Boss_Lofy cfg with `table.clone`):
  - `melee only in range`: `targetInRange = false`, `anyInArena = true`, only `Self` attacks in the list → no Windup.
  - `ranged with anyone in the arena`: `targetInRange = false`, `anyInArena = true`, attacks `{ GroundFire }` → Windup with `b.attack.id == "GroundFire"`.
  - `empty arena casts nothing`: `targetInRange = false`, `anyInArena = false` → no Windup.
  - `cooldown blocks a repeat`: attacks `{ GroundFire }` (cooldown 6). Run a full cycle to `Idle` (windup 1.5 + active 0.2 + recovery 0.6, plus idle), then try again before 6 s after the first windup → no Windup; at ≥ 6 s → Windup.
  - `reset clears cooldowns`: after a GroundFire, `reset` → GroundFire is eligible at once.
  - `anyInArena defaults to targetInRange`: the existing 5-argument call with `targetInRange = true` still starts a Windup.
  - Existing BossBrain tests stay green.
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: boss picks eligible attacks with cooldowns`.

### Task 3: Ground Fire targeting, Flame Wave impacts and server animations

**Files:**
- Modify: `src/server/Services/BossService.luau`, `src/client/Controllers/StudioTestController.luau`

**Interfaces:**
- Consumes Task 1 (`Hitbox` `Circle`, `WaveTiming`, config fields) and Task 2 (`BossBrain.update` with `anyInArena`).
- In `step`: `anyInArena` = some living player inside the arena (`ArenaCheck.inside(rec.center, Map.arenaRadius, root.Position, 0)`), passed to `BossBrain.update`.
- On `"Windup"`:
  - `Self`: as today; the payload is nil.
  - `Player`: pick a uniformly random living player inside the arena (`rng`), and store `rec.lockedCenter = Vector3.new(root.X, rec.groundY, root.Z)`. Face them. Payload `{ x, z, radius = hitbox.radius, targetUserId }`.
  - `Wave`: payload `{ x = rec.pos.X, z = rec.pos.Z, speed = waveSpeed, startRadius = waveStartRadius, maxRadius = Map.arenaRadius }`.
  - Then `bossAttackRemote:FireAll(rec.id, attack.id, impactTime, payload)`.
- On `"Impact"`:
  - `Self`: as today.
  - `Player`: victims = arena candidates whose root is inside `Hitbox.contains(hitbox, CFrame.new(rec.lockedCenter), root.Position)`. Fire `Impact` with them at `impactTime`, then clear `rec.lockedCenter`.
  - `Wave`: start `rec.wave = { start = impactTime, center = rec.pos, attack = attack, reached = {} }`. Fire nothing yet.
- Every step while `brain.state == "Active"` and `rec.wave` is set, for each living candidate inside the arena not in `reached`:
  - when `WaveTiming.radiusAt(t, …, Map.arenaRadius) ≥ flat distance(center, root)`, mark them reached;
  - then fire `BossService.Impact:Fire(rec, attack, { player }, WaveTiming.arrival(distance, start, attack))`.
- Clear `rec.wave` whenever the state is not `Active`. That covers recovery, stagger, death, Guard, reset and dormant.
- Animations (decision 6): `playAnimation(rec, id: string?)` loads through the model's `Animator` (found with `FindFirstChildWhichIsA("Animator", true)`), caching tracks by id. Calls:
  - on `Windup`, `attack.anim`;
  - on entering `Staggered`, `animations.stagger`;
  - on `Dead`, `animations.death`;
  - looping `animations.idle` / `animations.move`, switched by whether the boss moved this step.

  With a nil id or no `Animator`, do nothing.
- `StudioTestController` `AutoDefend`:
  - takes the 4th payload argument;
  - for a `Wave`, it computes the local player's arrival with `WaveTiming.arrival(flat distance(root, payload centre), impactTime, { waveStartRadius = payload.startRadius, waveSpeed = payload.speed })` and defends 0.05 s before that;
  - for a `Player` attack, it defends only if its root is within `radius` of the payload centre;
  - `unparryable` stays respected.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (temporary Scripts; force one attack at a time by setting `boss.cfg.attacks` to a single-attack list, same table instance, then restore; the character survives with high health):
  - **Ground Fire, no defence:** the character is hit once (log `HitResult` via a hook on `BossService.Impact`, or watch Health). `lockedCenter` is under the character at windup start.
  - **Ground Fire, character teleported 15 studs away right after windup:** no hit.
  - **Ground Fire, `AutoDefend = "Parry"`:** result `Parried`, and the boss poise drops by 15.
  - **Flame Wave, no defence:** one hit per wave. Character at distance 38 → the impact time logged is `waveStart + 1.0 ± 0.05`.
  - **Flame Wave, `AutoDefend = "Parry"`:** `Parried`.
  - **Flame Wave with poise forced to 15 before the wave reaches the character, and `AutoDefend = "Parry"` on a first nearby fake hit:** simplest version: call `BossService:Parry(boss, 100)` while `rec.wave` is active → `rec.wave` becomes nil, and the character is never hit.
  - **Slam and Sweep still work, and Sweep is now parryable** (`AutoDefend = "Parry"` → `Parried`).
  - **Normal mix:** with the full attack list for 30 s, out of melee range, only GroundFire and FlameWave are cast, and never the same ranged attack again inside its cooldown.
  - Console has no errors.
- [ ] **Step 4:** Commit `feat: ground fire targets a player and flame wave sweeps the arena`.

### Task 4: Client warnings and Astra asset slots

**Files:**
- Create: `src/client/Controllers/BossWarningController.luau`
- Modify: `src/client/Fx/CombatFx.luau`, `src/client/Controllers/CombatController.luau`

**Interfaces:**
- Consumes the `BossAttack` payload (Task 3), `Config/Bosses` (`vfxFolder`, attack fields), `WaveTiming`, `DataController` (`settings.fewerEffects`, `settings.keybinds`), `Config/Keybinds.defaults.Parry`.
- `CombatFx.telegraph(attack, bossModel: Model, impactTime: number, payload: { [string]: any }?, vfxFolder: string?)` replaces the old signature (only `CombatController.onBossAttack` calls it). It draws:
  - **Marker:** Slam circle and Sweep cone as today, but at the boss's ground position; the Ground Fire circle at the payload centre; the Flame Wave ring as a flat cylinder whose diameter follows `2 × WaveTiming.radiusAt(now, impactTime, …)` every frame until it reaches `maxRadius`. If `ReplicatedStorage.Assets.VFX[vfxFolder][attack.vfx].Marker` exists, clone that instead of the placeholder part and scale it per ASSETS.md 2a (1 × 1 base).
  - **Timing ring:** for Self and Player attacks, a thin ring that starts at 2× the marker size and shrinks to the marker edge exactly at `impactTime`.
  - **Impact:** at `impactTime` (for the wave, at each frame along the ring), clone `…Impact` if it exists and `fewerEffects` is false; enable its `ParticleEmitter`s and `Debris` it after 2 s.
  - **Cleanup:** everything is removed at impact (the wave when it ends), or early when the boss's `State` becomes `Staggered`, `Dead` or `Guard`.
- `BossWarningController` (listens to `BossAttack`, local player only):
  - **Personal impact time:** `impactTime` for Self/Player; `WaveTiming.arrival(…)` for Wave.
  - **"In the area":** Self → the boss hitbox, with origin at the boss's ground pivot; Player → within `radius` of the centre; Wave → inside the arena.
  - **Danger warning:** if `attack.danger` and (Wave, or Player with `payload.targetUserId == LocalPlayer.UserId`), show `"危 !"` (red, TextSize 64, centre-top at `UDim2.fromScale(0.5, 0.22)`) for 1 s from the start of the warning.
  - **PARRY prompt:** from `personalImpact − attack.parryWindow` until `personalImpact`, if still in the area, show `"PARRY  [" .. key .. "]"` (white on dark, TextSize 36, `UDim2.fromScale(0.5, 0.62)`). `key` is the bound Parry input's short name: `MouseButton2` → `"RMB"`, `MouseButton1` → `"LMB"`, otherwise the KeyCode name.
  - Both always show, including with `fewerEffects`.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (`screen_capture` during play; force single attacks as in Task 3):
  - **Ground Fire:** a red circle under the character with a shrinking ring, `危 !` at the start, and `PARRY [RMB]` just before impact.
  - **Flame Wave:** a ring growing from Gogo, `危 !`, and `PARRY [RMB]` at the character's own arrival.
  - **Slam/Sweep:** marker and ring, no `危`.
  - **Reduced effects** (set `settings.fewerEffects` true in the client's data copy via a server `DataChanged` push): markers, rings and prompts still show.
  - **Asset slot:** create a test folder `Assets.VFX.Gogo.GroundFire` with a 1 × 1 yellow `Marker` part and an `Impact` model with a `ParticleEmitter`. The marker becomes yellow and 14 × 14; the emitter plays at impact. Remove the test folder afterwards.
  - **Missing assets:** with the folder removed, placeholders show and there are no errors.
- [ ] **Step 4:** Commit `feat: gogo attack warnings and vfx asset slots`.

### Task 5: Docs, status and handoff reply

**Files:**
- Modify: `CLAUDE.md` (Status), `handoffs/2026-10-11-claude-gogo-milestone1.md` (append "Status: the code slots are in on `feat/gogo-attacks`; assets placed at those paths show up with no code change")

- [ ] **Step 1:** Update Status: Gogo attacks built on `feat/gogo-attacks` (from `feat/drops-shop`); Next: integrate Astra's milestone 1 assets when her handoff arrives; merges still wait on the user's tests.
- [ ] **Step 2:** Commit `docs: update status after gogo attacks`.

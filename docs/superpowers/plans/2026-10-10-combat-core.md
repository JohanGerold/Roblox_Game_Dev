# Combat Core Implementation Plan (Build Step 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player can walk into the arena and fight `Boss_Lofy`: a punch/kick combo, dodge with i-frames, perfect dodge into a counter, parry that breaks poise into a 2× damage stagger, and a boss that chases, telegraphs, hits, dies and respawns.

**Architecture:** All rules live in pure, unit-tested `server/Logic` modules (`Hitbox`, `DamageCalc`, `DefenseJudge`, `ComboCheck`, `BossBrain`). `BossService` runs the boss (movement, state machine, telegraph broadcast) and fires an `Impact` signal; `CombatService` owns player input (attacks, defend claims, counters), judges impacts and applies damage both ways. Dependencies are one-way: `CombatService` requires `BossService`, never the reverse. The client (`InputController`, `CameraController`, `CombatController`, `BossHudController`) only sends intents and draws effects.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`, `user_keyboard_input`).

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (section 7 networking, section 8 combat, section 9 steps 1–2 and 5, section 13 input and camera, section 16 boss errors). Design: [combat.md](../../../Steal%20a%20boss%20fight/design/combat.md), decision 9.

## Decisions this plan makes (not in the spec)

1. **Judge delay.** A defend claim pressed just before impact reaches the server up to `claimMaxAge` later. The server snapshots who is in the hitbox at `impactTime`, then judges at `impactTime + judgeDelay` (0.30 s). The client shows the hit when `HitResult` arrives.
2. **One hit check per attack**, at impact. `activeWindow` is only the length of the Active state.
3. **Boss state replicates through attributes** on the boss model (`Hp`, `MaxHp`, `Poise`, `MaxPoise`, `State`, `BossId`), not a `BossState` remote: Roblox replicates them for free and MCP can read them in tests. `BossState` is removed from `NetSchema`; `BossAttack` gains a `bossId` first argument.
4. **Counter is Attack pressed during the counter window** (no extra key). The client sends `Counter` instead of `Attack` while its counter window is open.
5. **Boss HP grows per participant:** `maxHp + hpPerExtraPlayer × (participants − 1)`; a new participant adds the increment to both max and current HP.
6. **Boss resets** to full HP, full poise and an empty ledger after `emptyResetSeconds` with no living player in the arena.
7. **Input uses ContextActionService** (the spec's fallback): it gives phone touch buttons and gamepad support with no UI work. Input Action System can be revisited in polish (step 12).
8. **Missing boss asset:** if `ReplicatedStorage.Assets.Bosses[cfg.model]` doesn't exist, BossService builds a gray placeholder (8×12×8 part named `Root` plus a small "face" part on its front) and warns once. No place-file change is needed for this step.
9. **Not in this step:** abilities / `UseAbility` (moves come from drops, build step 9), stands' damage (step 8), loot and eggs on death (step 6/9: this step only fires `BossService.Defeated`), animations and polished effects (step 12).

## Global Constraints

- The server decides every outcome; every RemoteEvent argument is validated (NetSchema) and checked again in the handler (equipped weapon, range, cooldown, timing).
- Pure modules in `server/Logic` never call `game:GetService`. Roblox datatypes (`CFrame`, `Vector3`) are fine.
- Every value below is tuning and lives in config, never as a literal in a service.
- Both sides use `workspace:GetServerTimeNow()` for all combat times.
- Each service loop body runs inside `xpcall`; an error logs `[BossService] ...` and resets the boss to Idle at full HP (spec section 16).
- `StudioTestController` does nothing unless `RunService:IsStudio()`.
- One task = one commit. Commit author `Johan Gerold <johangerold385@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Studio instance id from `list_roblox_studios`. MCP `execute_luau` runs in its own Lua environment: to call service functions during play, parent a temporary `Script` under `ServerScriptService` that `require`s the service module, and destroy it afterwards.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (71 passing now; each task adds to that).

## Review Focus

1. **Lag spike or forged time on a defend claim** (`pressTime` older than `claimMaxAge`, or in the future beyond `claimFutureTolerance`) → claim ignored, the hit lands. Tests in Task 2.
2. **Attack spam or a forged combo** (wrong `weaponId`, skipping combo steps, faster than `minInterval × attackIntervalTolerance`, out of range) → no damage, no error. Tests in Task 2 (`ComboCheck`) and Task 5 (range).
3. **Damage after death, or two killing blows in the same frame** → `Defeated` fires exactly once; extra damage returns 0. Test in Task 3.
4. **Poise breaks during a windup** → the attack is cancelled, no impact, the boss kneels. Test in Task 3.
5. **Victim dies or leaves between impact and judging** → skipped silently, no error. Check in Task 5 play-test.

---

### Task 1: Config additions, Hitbox and DamageCalc

**Files:**
- Modify: `src/shared/Config/Combat.luau`, `src/shared/Config/Bosses.luau`
- Create: `src/server/Logic/Hitbox.luau`, `src/server/Logic/DamageCalc.luau`, `tests/specs/Hitbox.spec.luau`, `tests/specs/DamageCalc.spec.luau`

**Interfaces:**
- Produces new `Config/Combat` fields (exact values): `judgeDelay = 0.30`, `comboResetSeconds = 1.0`, `attackIntervalTolerance = 0.8`, `powerDamageFactor = 0.01`, `counterRange = 14`, `claimHistorySize = 4`, `dodgeDashSpeed = 60`, `dodgeDashSeconds = 0.2`.
- Produces new `Config/Bosses.Boss_Lofy` fields: `bodyRadius = 5`, `moveSpeed = 10`, `engageRange = 12`, `idleSeconds = 1.0`, `emptyResetSeconds = 30`; each attack gains `recovery` (`Slam = 0.8`, `Sweep = 1.0`).
- Produces `Hitbox.contains(hitbox, origin: CFrame, point: Vector3): boolean`:
  - `Sphere { radius }`: 3D distance from `origin.Position` ≤ radius.
  - `Cone { range, angle }`: 3D distance ≤ range **and** the XZ angle between `origin.LookVector` and the direction to the point ≤ `angle / 2` degrees. A point at the origin counts as inside.
  - `Box { size: Vector3 }`: the point in `origin`'s object space lies within ±size/2 on every axis.
  - Unknown shape → error.
- Produces `DamageCalc.armorBonus(equipped: { [string]: string }, Armor): number` (sum of `powerBonus`, unknown ids ignored) and `DamageCalc.playerDamage(base: number, stats: { power: number, rebirths: number, armorBonus: number, staggered: boolean }, Combat, Progression): number` = `base × (1 + power × powerDamageFactor) × (1 + armorBonus) × (1 + rebirths × damageMultiplierPerRebirth) × (staggerDamageMultiplier if staggered else 1)`.

- [ ] **Step 1: Write the tests.** `Hitbox.spec`: origin `CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))`.
  - `sphere`: radius 14 contains `(0,3,-13)`, not `(0,0,-15)`.
  - `cone in front`: `{range=22, angle=120}` contains `(0,0,-20)` and `(10,0,-10)` (45°), not `(0,0,20)` (behind), not `(20,0,-5)` (76° > 60°), not `(0,0,-23)`.
  - `box`: `size (10,10,10)` contains `(4,4,-4)`, not `(6,0,0)`.
  - `unknown shape errors`: `expect.errors`.
  `DamageCalc.spec`:
  - `base damage unchanged with no stats`: `playerDamage(10, {power=0, rebirths=0, armorBonus=0, staggered=false}, ...) == 10`.
  - `all multipliers stack`: power 100, rebirths 2, armorBonus 0.05, staggered → `10 × 2 × 1.05 × 1.5 × 2` = 63 (`expect.near`, tol 1e-6).
  - `armor bonus sums and ignores unknown ids`: `armorBonus({ head = "Lofy_Hat", body = "Nope" }, Armor) == 0.05`.
- [ ] **Step 2:** Run the test command. Expected: the new specs FAIL (modules missing).
- [ ] **Step 3:** Add the config fields and implement both modules.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add hitbox shapes and damage formula`.

### Task 2: DefenseJudge and ComboCheck

**Files:**
- Create: `src/server/Logic/DefenseJudge.luau`, `src/server/Logic/ComboCheck.luau`, `tests/specs/DefenseJudge.spec.luau`, `tests/specs/ComboCheck.spec.luau`

**Interfaces:**
- Produces `DefenseJudge.newHistory(): { Dodge: { number }, Parry: { number } }` (accepted press times, newest last, at most `claimHistorySize` each).
- Produces `DefenseJudge.accept(history, kind: "Dodge" | "Parry", pressTime: number, receivedAt: number, Combat): boolean`. Accept only if `receivedAt - pressTime <= claimMaxAge`, `pressTime <= receivedAt + claimFutureTolerance`, and `pressTime - last accepted pressTime of that kind >= dodgeCooldown / parryCooldown`. On accept, append and trim to `claimHistorySize`.
- Produces `DefenseJudge.judge(history, impactTime: number, unparryable: boolean, Combat): "Parried" | "PerfectDodge" | "Dodged" | "Hit"`. With `d = impactTime - t` for each claim (only `d >= 0` counts), first match wins: a Parry with `d <= parryWindow` and not unparryable → `Parried`; a Dodge with `d <= perfectDodgeWindow` → `PerfectDodge`; a Dodge with `d <= dodgeIFrames` → `Dodged`; else `Hit`.
- Produces `ComboCheck.newState(): { lastIndex: number?, lastTime: number? }` and `ComboCheck.accept(state, comboIndex: number, combo: { { minInterval: number } }, now: number, Combat): boolean`. Rules: index must be in `1..#combo`; if `lastTime` is nil or `now - lastTime > comboResetSeconds`, only index 1 is valid and there is no interval check; otherwise the index must be `lastIndex % #combo + 1` or `1`, and `now - lastTime >= combo[comboIndex].minInterval × attackIntervalTolerance`. On accept, update `lastIndex` and `lastTime`. Range and weapon checks are CombatService's job.

- [ ] **Step 1: Write the tests** (use `Combat = require(mods.Shared.Config.Combat)`; impact at `t = 100`):
  - `accept rejects stale claims`: `accept(h, "Parry", 99.6, 100.0)` is false (age 0.4).
  - `accept rejects future claims`: `accept(h, "Parry", 100.1, 100.0)` is false.
  - `accept enforces cooldown`: Dodge at 99.0 accepted, Dodge at 99.5 (received 99.6) rejected, Dodge at 99.9 (received 100.0) accepted.
  - `history is trimmed`: accept 6 parries 1 s apart → `#h.Parry == 4`.
  - `parry inside window parries`: Parry at 99.85 → `Parried`.
  - `parry on unparryable attack is a hit`: Parry at 99.85, `unparryable = true` → `Hit`.
  - `perfect dodge`: Dodge at 99.9 → `PerfectDodge`; Dodge at 99.75 → `Dodged`; Dodge at 99.65 → `Hit`.
  - `claims after impact do not count`: Dodge at 100.05 → `Hit`.
  - Judge tests each use a fresh history, claims received 0.05 s after `pressTime`.
  - `combo sequence`: indexes 1, 2, 3, 1 at 0.45 s apart on Fists → all true.
  - `combo skip rejected`: 1 then 3 → false.
  - `combo too fast rejected`: 1 at t=10, 2 at t=10.1 → false.
  - `combo resets after pause`: 1 at 10, 2 at 10.45, then 3 at 12 → false, 1 at 12 → true.
  - `combo index out of range rejected`: index 4 on Fists → false.
- [ ] **Step 2:** Run the test command. Expected: new specs FAIL.
- [ ] **Step 3:** Implement both modules.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add defense judging and combo validation`.

### Task 3: BossBrain (pure boss state machine)

**Files:**
- Create: `src/server/Logic/BossBrain.luau`, `tests/specs/BossBrain.spec.luau`

**Interfaces:**
- Produces `BossBrain.new(cfg, now: number): Brain` where `Brain = { cfg, state: "Idle"|"Windup"|"Active"|"Recovery"|"Staggered"|"Dead", stateEndsAt: number, attack: table?, impactTime: number?, hp, maxHp, poise, lastPoiseHitAt: number, participants: { [number]: boolean }, participantCount: number, ledger: { [number]: number } }`. Starts Idle with `stateEndsAt = now + cfg.idleSeconds`, full HP and poise.
- Produces `BossBrain.update(b, now: number, dt: number, targetInRange: boolean, rng: Random): { string }` returning the events of this step, in order:
  - Idle, `now >= stateEndsAt` and `targetInRange` → pick a random attack, Windup, `impactTime = now + attack.windup` → event `"Windup"`.
  - Windup, `now >= impactTime` → Active until `impactTime + activeWindow` → event `"Impact"`.
  - Active ends → Recovery for `attack.recovery`; Recovery ends → Idle for `idleSeconds` (no events).
  - Staggered ends → Idle, poise = maxPoise → event `"StaggerEnded"`.
  - Poise regen in any living state except Staggered: if `now - lastPoiseHitAt >= poiseRegenDelay`, `poise = min(maxPoise, poise + poiseRegen × dt)`.
  - Dead → no events.
- Produces `BossBrain.addParticipant(b, userId: number)`: first time per userId, increments `participantCount`; from the second participant on, adds `hpPerExtraPlayer` to `maxHp` and `hp`.
- Produces `BossBrain.applyDamage(b, userId: number, amount: number): (number, boolean)`: returns `(dealt, killed)`. Dead → `(0, false)`. Otherwise `dealt = min(amount, hp)`, add to `ledger[userId]`, `killed = hp reaches 0` (state Dead).
- Produces `BossBrain.applyParry(b, poiseDamage: number, now: number): boolean`: returns true if this parry broke poise. Ignored (false) when Dead or Staggered. Poise reaching 0 → Staggered until `now + staggerSeconds`, current attack and `impactTime` cleared.
- Produces `BossBrain.reset(b, now)`: back to the `new` state (keeps `cfg`).

- [ ] **Step 1: Write the tests** (cfg = `Bosses.Boss_Lofy`, `rng = Random.new(1)`):
  - `starts idle at full hp`: hp 5000, poise 100.
  - `idle waits for target`: update at now+5 with `targetInRange = false` → no events, still Idle.
  - `full attack cycle`: update past idle with target → `{"Windup"}`; update at `impactTime` → `{"Impact"}`; past active and recovery → Idle.
  - `hp scales per participant`: add users 1, 2, 2 → maxHp 6500, participantCount 2.
  - `damage after death returns zero`: applyDamage 99999 → `(5000, true)`; again → `(0, false)` (Review Focus 3).
  - `ledger sums damage`: user 1 deals 10 then 15 → `ledger[1] == 25`.
  - `poise break cancels windup`: enter Windup, apply parries totalling 100 → returns true on the last, state Staggered, `attack == nil`; update at the old impactTime → no `"Impact"` (Review Focus 4).
  - `stagger ends with full poise`: update at break time + 5 → `{"StaggerEnded"}`, Idle, poise 100.
  - `poise regenerates after delay`: parry 25 at t, update at t+2 → poise 75; update at t+5 with dt 1 → poise 80.
  - `reset restores full state`: after damage and parry, reset → hp 5000, poise 100, empty ledger, participantCount 0.
- [ ] **Step 2:** Run the test command. Expected: BossBrain FAILs.
- [ ] **Step 3:** Implement `BossBrain`.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add boss state machine`.

### Task 4: BossService (spawn, chase, telegraph, die, respawn)

**Files:**
- Create: `src/server/Services/BossService.luau`
- Modify: `src/shared/NetSchema.luau` (remove `BossState`; `BossAttack.args = { "string", "string", "number" }`), `tests/specs/Net.spec.luau` only if it references `BossState`, spec sections 7 and 8 (decisions 1–3 above)

**Interfaces:**
- Consumes: `BossBrain`, `Hitbox`, `Config/Bosses`, `Config/Map` (`arenaRadius`), `Signal`, `Net`.
- Produces `BossService`:
  - `BossService.Impact: Signal` → `Fire(boss: BossRecord, attack, victims: { Player }, impactTime: number)`
  - `BossService.Defeated: Signal` → `Fire(bossId: string, ledger: { [number]: number })`
  - `BossService:GetBosses(): { BossRecord }`, where `BossRecord = { id: string, cfg, brain: Brain, model: Model, arena: Model }`
  - `BossService:IsStaggered(boss): boolean`
  - `BossService:DamageBoss(boss, player: Player, amount: number): number` (adds participant, applies damage, updates attributes, fires `Defeated` when killed; returns dealt)
  - `BossService:Parry(boss, poiseDamage: number)`
  - `BossService:DistanceToBody(boss, position: Vector3): number` = XZ distance to the boss root minus `bodyRadius`, min 0
- Behaviour:
  - `Init`: create `Workspace.Bosses` folder. For each `BossArena`-tagged model and each `Bosses` entry with `kind == "Stage"` and matching `stageId`, spawn one boss at the arena's `BossSpawn` (root raised by half its height). Model from `ReplicatedStorage.Assets.Bosses[cfg.model]` or the placeholder (decision 8); all parts anchored. Set attributes `BossId`, `Hp`, `MaxHp`, `Poise`, `MaxPoise`, `State`.
  - `Start`: `RunService.Heartbeat` loop per boss inside `xpcall`. Target = nearest living player whose root is within `arenaRadius` (XZ) of the arena pivot. While Idle and the target is beyond `engageRange + bodyRadius`, move toward it at `moveSpeed` (studs/s), facing it, clamped to `arenaRadius - bodyRadius` from the arena centre. While Idle with no target, walk back toward `BossSpawn`. The boss never moves outside Idle.
  - Events: `"Windup"` → face the target, `Net.Server("BossAttack"):FireAll(id, attack.id, impactTime)`. `"Impact"` → collect living players whose `HumanoidRootPart.Position` is inside `Hitbox.contains(attack.hitbox, root CFrame, pos)`, fire `Impact`.
  - Attributes refresh at most 10 times per second, and immediately on a state change.
  - Killed → state Dead, model parts become transparent and non-collidable, `print("[BossService] " .. id .. " defeated")`, fire `Defeated` once, then after `respawnSeconds` call `BossBrain.reset` and restore the model at `BossSpawn`.
  - No living player in the arena for `emptyResetSeconds` → `BossBrain.reset` (decision 6).
  - Loop error → `warn("[BossService] " .. err)`, `BossBrain.reset`, model back to `BossSpawn`.

- [ ] **Step 1:** Update `NetSchema` and the spec text (sections 7 and 8: attributes instead of `BossState`, `BossAttack(bossId, attackId, impactTime)`, judge delay). Run the test command; expected `FAIL 0`.
- [ ] **Step 2:** Implement `BossService`.
- [ ] **Step 3: Play-test.** `start_stop_play` (start); `get_console_output` shows no `[Boot]` or `[BossService]` errors. `execute_luau` (server): `workspace.Bosses.Boss_Lofy` exists, `Hp == 5000`, within 10 studs (XZ) of `BossSpawn`.
- [ ] **Step 4: Chase check.** `execute_luau`: pivot the player's character to 40 studs from the arena centre, inside the arena. Sample the boss's `State` attribute every 0.2 s for 6 s and return the distinct states seen. Expected: the boss moved toward the player, and `Windup`, `Active` and `Recovery` all appear. Move the player back to their base, wait `emptyResetSeconds + 2`: boss back near `BossSpawn` (it walked home). Stop play.
- [ ] **Step 5: Commit** `feat: add BossService with chase, telegraphs and respawn`.

### Task 5: CombatService (server combat rules)

**Files:**
- Create: `src/server/Services/CombatService.luau`

**Interfaces:**
- Consumes: `BossService` (Task 4), `DataService:Get`, `DefenseJudge`, `ComboCheck`, `DamageCalc`, `Config/Combat`, `Config/Weapons`, `Config/Armor`, `Config/Progression`, `Net`.
- Produces handlers and messages:
  - `Defend(kind, pressTime)`: `DefenseJudge.accept` with `receivedAt = workspace:GetServerTimeNow()`.
  - `Attack(comboIndex, weaponId)`: drop unless data is loaded, `weaponId == data.weapons.equipped`, the weapon exists in `Config/Weapons`, `ComboCheck.accept` passes, and some living boss has `DistanceToBody(root) <= hit.range + rangeTolerance`. Damage = `DamageCalc.playerDamage(hit.damage, { power = data.training.power, rebirths = data.rebirths, armorBonus = DamageCalc.armorBonus(data.armor.equipped, Armor), staggered = BossService:IsStaggered(boss) }, ...)`, applied with `BossService:DamageBoss`.
  - `Counter()`: allowed once if `now <= counterUntil[player]` and the boss is within `counterRange` (`DistanceToBody`); damage = `playerDamage(counterDamage, ...)`; clears `counterUntil`.
  - `BossService.Impact` → `task.delay(judgeDelay, ...)`, then for each victim still in the game with a living Humanoid: `DefenseJudge.judge(history, impactTime, attack.unparryable, Combat)`. `Parried` → `BossService:Parry(boss, attack.poiseOnParry)`. `PerfectDodge` → `counterUntil = now + counterWindow`. `Hit` → `Humanoid:TakeDamage(attack.damage)`. Each victim gets `HitResult:Fire(player, { result = <string>, damage = <number taken, 0 if none>, attackId = attack.id })`.
  - Every damaging player hit sends `DamageNumbers:Fire(player, { amount = dealt, x, y, z, staggered = bool })` (position = boss root + 6 up).
  - `Init`: set `StarterPlayer.EnableMouseLockOption = false` (spec 13: Roblox Shift Lock disabled).
  - `PlayerRemoving`: clear that player's history, combo state and counter.

- [ ] **Step 1:** Implement `CombatService`.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0` (nothing new; checks it still loads cleanly).
- [ ] **Step 3: Play-test, boss hits player.** Start play; put the character next to the boss; wait until a `"Slam"` or `"Sweep"` impact passes (≈4 s). Expected: `Humanoid.Health < 100`, no errors in the console.
- [ ] **Step 4: Play-test, damage path.** Parent a temporary Script that sets `require(ReplicatedStorage.Shared.Config.Bosses).Boss_Lofy.respawnSeconds = 5` (runtime only, the file is unchanged), requires `BossService`, calls `DamageBoss(boss, player, 999999)` twice, then destroys itself. Expected: console shows `[BossService] Boss_Lofy defeated` exactly once, `State == "Dead"`, and about 5 s later the boss is back with `Hp == 5000`.
- [ ] **Step 5: Victim leaves (Review Focus 5).** Put the character in a Slam hitbox, and right after the `Windup` state starts, `character:Destroy()` from `execute_luau`. Expected: no error in the console after the judge delay. Stop play.
- [ ] **Step 6: Commit** `feat: add CombatService attacks, defense and counters`.

### Task 6: InputController and CameraController

**Files:**
- Create: `src/client/Controllers/InputController.luau`, `src/client/Controllers/CameraController.luau`
- Modify: spec section 13 (decision 4 and 7: Counter via Attack, ContextActionService)

**Interfaces:**
- Consumes: `Config/Keybinds.defaults`, `DataController` (`settings.keybinds` overrides; rebinding on `DataController.Changed` with key `settings`), `Signal`.
- Produces `InputController.Action: Signal` → `Fire(action: string)` on input Begin only, and `InputController:Bind()` (re-binds every action). Each action binds with `ContextActionService:BindAction("Input_" .. action, handler, touchButton, Enum.KeyCode[...] or Enum.UserInputType[...])`; a bind name that is neither is skipped with a warn. Touch buttons only for `Attack`, `Parry`, `Dodge` (titles "Hit", "Parry", "Dodge"). Gamepad defaults: `ButtonX` Attack, `ButtonL1` Parry, `ButtonB` Dodge. Handlers return `Enum.ContextActionResult.Pass` so movement and the camera keep working.
- Produces `CameraController.combatMode: boolean` and `CameraController:SetCombatMode(on: boolean)`. On `ToggleCombatMode`: when on, each `RenderStepped` sets `UserInputService.MouseBehavior = LockCenter`, `Humanoid.AutoRotate = false`, and turns the root to the camera's yaw; when off, restores `Default` and `AutoRotate = true`. Mode resets to off on respawn.

- [ ] **Step 1:** Implement both controllers; update the spec.
- [ ] **Step 2:** Run the test command (`FAIL 0`), start play, check the console for no `[Boot]` errors. Stop play.
- [ ] **Step 3: User check.** Ask the user to press Play, press Ctrl, and confirm the cursor locks and the character turns with the camera, then press Ctrl again to free it. Wait for their answer.
- [ ] **Step 4: Commit** `feat: add rebindable input and combat camera mode`.

### Task 7: CombatController, boss HUD, test hooks, end-to-end play-test

**Files:**
- Create: `src/client/Controllers/CombatController.luau`, `src/client/Controllers/BossHudController.luau`, `src/client/Controllers/StudioTestController.luau`, `src/client/Fx/CombatFx.luau`
- Modify: `CLAUDE.md` (Status)

**Interfaces:**
- Consumes: `InputController.Action`, `DataController` (`weapons.equipped`), `Config/Weapons`, `Config/Combat`, `Config/Bosses`, `Net` (`Attack`, `Defend`, `Counter` out; `BossAttack`, `HitResult`, `DamageNumbers` in).
- Produces `CombatController:Attack()`, `CombatController:Defend(kind: "Dodge" | "Parry", noDash: boolean?)`, `CombatController.counterUntil: number`:
  - `Attack()`: if `counterUntil >= now`, fire `Counter` and clear it. Otherwise use the same combo rules as `ComboCheck` locally (reset after `comboResetSeconds`, wait `minInterval`), fire `Attack(index, equipped)`, play `CombatFx.swing(character)`.
  - `Defend(kind)`: local cooldown (`dodgeCooldown` / `parryCooldown`), fire `Defend(kind, workspace:GetServerTimeNow())`. Dodge dashes the root along `Humanoid.MoveDirection` (or `LookVector` if still) at `dodgeDashSpeed` for `dodgeDashSeconds`, and makes the character half-transparent for `dodgeIFrames`. Parry flashes a white `Highlight` for `parryWindow`.
  - `HitResult` → `CombatFx.popup(text, color)`: `"PARRY!"` white, `"PERFECT DODGE! Attack to counter"` cyan (also sets `counterUntil = now + counterWindow`), `"Dodged"` gray, `"-<damage>"` red.
  - `BossAttack(bossId, attackId, impactTime)` → `CombatFx.telegraph(attack.hitbox, bossRoot.CFrame, impactTime)`: a red translucent, non-collidable, anchored part shaped like the hitbox (sphere ball, cone as a wedge/cylinder slice, box) that fills in until `impactTime`, then is removed. Removed early if the boss's `State` attribute becomes `Staggered`.
  - `DamageNumbers` → `CombatFx.damageNumber(position, amount, staggered)` (BillboardGui rising 3 studs over 0.8 s; yellow when staggered).
- Produces `BossHudController`: a ScreenGui with the boss name, an HP bar and a poise bar, shown while the player is within `arenaRadius + 30` of a boss, driven by the boss model's attributes. Shows `"STAGGERED"` while `State == "Staggered"`.
- Produces `StudioTestController` (Studio only): reads the local player's attributes. `AutoAttack = true` → calls `CombatController:Attack()` every 0.45 s. `AutoDefend = "Parry" | "Dodge"` → on each `BossAttack`, calls `CombatController:Defend(kind, true)` (no dash, so the player stays in range) at `impactTime - 0.05`; with `"Parry"`, unparryable attacks are dodged instead so the test player survives; with `"Dodge"`, a perfect dodge is followed by `CombatController:Attack()` (the counter).

- [ ] **Step 1:** Implement the four client modules.
- [ ] **Step 2:** Run the test command (`FAIL 0`). Start play; no console errors.
- [ ] **Step 3: Attack path.** Put the character 6 studs in front of the boss and set the player attribute `AutoAttack = true` (server `execute_luau`; attributes replicate). After 5 s, `Hp < 5000`. Set it back to false.
- [ ] **Step 4: Parry → stagger.** Set `AutoDefend = "Parry"`; only `Slam` is parryable (25 poise), so poll up to 40 s for `State == "Staggered"`. Expected: it appears, the player's `Health` did not drop on the parried slams, and `screen_capture` shows the HUD with `STAGGERED`.
- [ ] **Step 5: Perfect dodge → counter.** Set `AutoDefend = "Dodge"`, `AutoAttack = false`. Within 15 s, `Hp` drops by at least `counterDamage` (80) between two samples and the player's health is unchanged.
- [ ] **Step 6: User feel check.** Clear the attributes. Ask the user to play for a minute: click to punch, right-click to parry the slam, Shift to dodge, and say whether the timing feels fair. Tuning changes go in config only.
- [ ] **Step 7:** Update `CLAUDE.md` Status: build step 5 done on `feat/combat-core`; next is plan 4 (build step 6: eggs, hatching, stands earning money).
- [ ] **Step 8: Commit** `feat: add client combat, boss HUD and Studio test hooks`.

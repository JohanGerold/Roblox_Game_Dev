# Boss Chase Implementation Plan (Plan C)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After the boss dies it revives 3 s later enraged (can't be damaged) and, for 60 s, chases the nearest egg carrier outside the home area. A catch costs 20 HP (never lethal) and sends the egg back to its arena spot. A sign at the domain gate shows the boss's chase speed and the walk speed needed to outrun it with each egg.

**Architecture:** `BossBrain` gains a `Guard` state (immune, never attacks). `BossService` drives the phases `Fight → Dead (reviveSeconds) → Guard (guardSeconds) → Fight`. In `Guard` it picks a target from `CarryService` carriers outside `HomeZone` and moves along a corridor-aware path from a new pure `ChaseNav`. `CarryService:ReturnToSpawn` handles the catch. A pure `SpeedRule` computes the sign values, and a small `SpeedSignService` writes them onto the `SpeedSign` part.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`).

**Spec:** [docs/specs/2026-10-11-strip-map-and-egg-chase-design.md](../../specs/2026-10-11-strip-map-and-egg-chase-design.md) (D4, D5, D6, D15; section 3 "Boss phases", "Catch"; section 4 boss config). Builds on [Plan B](2026-10-11-round-cycle.md) (branch `feat/round-cycle`, unmerged).

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/boss-chase`, cut from `feat/round-cycle`. Do not merge.
2. **Entering Guard resets the fight:** full HP, empty ledger, no participants (a new fight starts after Guard). HP shows full; the HUD says `ENRAGED` instead of `STAGGERED`. A red `Highlight` on the boss model marks it.
3. **Catch distance** is measured to the boss's body surface (`BossService:DistanceToBody ≤ catchRange`), like attacks.
4. **Which carriers are chased:** every carrier of any egg kind whose root is outside `HomeZone`, nearest first (flat distance). The target is re-picked every step, so after a catch (the victim no longer carries) the boss moves on (D4).
5. **The boss never enters home:** its position is clamped to the corridor ∪ domain boxes, shrunk by `bodyRadius`. It walks straight in open space, but routes through the gate point `(domain.minX, 0, 0)` when moving between the domain and the corridor, so it never cuts through walls.
6. **With no target**, the Guard boss walks back toward `home` (its arena spawn) along the same route and waits there. When Guard ends, `resetBoss` puts it at home in `Idle` (Fight).
7. **Catch telegraph:** `BossAttack` fires with attack id `"Catch"` and `impactTime = now`. The client draws a sphere of radius `catchRange + bodyRadius` around the boss with the existing `CombatFx.telegraph`. Clients ignore unknown attack ids today, so `StudioTestController` needs no change.
8. **Speed sign lists every egg in `Config/Eggs`**, sorted by needed speed, then name. `needed = ceil(chaseSpeed / carryFactor − 1e-9)`; the epsilon keeps `20 / 0.8` at 25. With the starting values: Field Egg 22, Egg 23, Shiny Egg 24, Top Egg 25, Giant Egg 34 (the spec's 23 / 25 / 34 hold).
9. Night (D15) needs no new code: `SetDormant(true)` already resets the boss and stops `step`.

## Global Constraints

- The server decides chase targets, catches, damage and egg returns.
- Pure modules (`server/Logic`) never call `game:GetService`.
- Every number lives in `Config/Bosses` or `Config/Map`, never as a literal in a service (except the 1e-9 epsilon in `SpeedRule`).
- Heartbeat bodies run in `xpcall` (existing loops); errors log `[BossService] ...`.
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending with the session's attribution line.
- MCP play-tests: temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`), log into a `StringValue` in `ServerStorage`. Patch `DataService.Get/Update` with an in-memory table so the real dev profile is never touched. Move characters with per-frame steps at or below their carry speed.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (188 passing at the start).

## Review Focus

1. **A carrier reaches home with the boss right behind:** the boss stops at the home edge (`x ≥ home.maxX + bodyRadius`), never catches inside home, and turns back. Tested in Task 1 (`ChaseNav.clamp` keeps home out) and play-checked in Task 2.
2. **A carrier is in a domain corner, far from the gate line:** the boss reaches them without leaving the domain box, and on the way home routes through the gate rather than through a wall. Tested in Task 1 (`ChaseNav.goal` routes via the gate).
3. **A carrier with 1–20 HP is caught:** they are left at 1 HP, never killed (so they don't also get the death drop). Play-checked in Task 2 with `Health = 15`.
4. **Nightfall during Guard:** the boss snaps home dormant at full HP, and at sunrise it is in Fight, not Guard. Play-checked in Task 2.
5. **Players attack the enraged boss:** no damage, no damage numbers, no ledger entries, and the next kill's ranks only count damage after Guard. Tested in Task 1 (`applyDamage` in Guard returns 0) and play-checked in Task 2.

---

### Task 1: Config, Guard state and pure chase rules

**Files:**
- Create: `src/server/Logic/ChaseNav.luau`, `src/server/Logic/SpeedRule.luau`, `tests/specs/ChaseNav.spec.luau`, `tests/specs/SpeedRule.spec.luau`
- Modify: `src/shared/Config/Bosses.luau`, `src/server/Logic/BossBrain.luau`, `tests/specs/BossBrain.spec.luau`, `tests/specs/Config.spec.luau`

**Interfaces:**
- `Config/Bosses.Boss_Lofy`: add `chaseSpeed = 20`, `catchRange = 6`, `catchDamage = 20`, `reviveSeconds = 3`, `guardSeconds = 60`; remove `respawnSeconds`. (`BossService` still reads `respawnSeconds` until Task 2; for this commit, change that one read to `cfg.reviveSeconds` so the game keeps booting.)
- Produces `BossBrain.enterGuard(b, now: number)`: re-initialises like `reset`, then `state = "Guard"`, `stateEndsAt = now + cfg.guardSeconds`.
- `BossBrain.update` returns `{}` and changes nothing while `state == "Guard"` (no poise regen, no attacks).
- `BossBrain.applyDamage` returns `0, false` and `BossBrain.applyParry` returns `false` while `state == "Guard"`. `BossBrain.addParticipant` does nothing in Guard.
- Produces `ChaseNav.clamp(pos: Vector3, map, margin: number): Vector3`: projects `pos` (Y kept) onto the allowed region = corridor box `X ∈ [corridor.minX + margin, domain.minX + margin], |z| ≤ corridor.halfWidth − margin` ∪ domain box `X ∈ [domain.minX + margin, domain.maxX − margin], |z| ≤ domain.halfWidth − margin` (the two overlap at the gate, so there is no gap). Never inside home: X is at least `corridor.minX + margin`. A point already inside either shrunk box is returned unchanged. Otherwise return the nearer of its projections onto the two boxes.
- Produces `ChaseNav.goal(from: Vector3, to: Vector3, map, margin: number): Vector3`: the point to walk toward this step. It is `gate = Vector3.new(map.domain.minX, from.Y, 0)` when one of `from`/`to` has `X ≥ domain.minX` and the other has `X < domain.minX`, and `from` is more than `corridor.halfWidth − margin` off the centre line or further than `margin` from the gate on X. Otherwise it is `to`. The result is always `clamp`ed.
- Produces `SpeedRule.needed(chaseSpeed: number, carryFactor: number): number` = `math.ceil(chaseSpeed / carryFactor − 1e-9)`.
- Produces `SpeedRule.lines(chaseSpeed: number, eggs): { string }`: line 1 `"BOSS CHASE SPEED " .. chaseSpeed`, then one line per egg `"<displayName>: <needed>"`, sorted by needed speed, then displayName.

- [ ] **Step 1: Write the failing tests.**
  - `BossBrain.spec`: `guard is immune and never attacks` (enterGuard at t = 0: state `Guard`, hp = maxHp, `applyDamage → 0, false`, `applyParry → false`, `update(b, 5, 0.1, true, rng)` returns 0 events and stays `Guard`); `guard clears the ledger and participants` (damage from user 1, kill, enterGuard → `ledger` empty, `participantCount == 0`, `maxHp == cfg.maxHp`); `reset after guard is a normal fight` (enterGuard, reset → `Idle`, applyDamage works).
  - `ChaseNav.spec` (use `require(Config.Map)`, margin 5): `home is never allowed` (clamp `(200, 0, 0)` → X == 245); `inside the corridor is unchanged` (`(500, 0, 10)`); `outside the corridor wall is pulled in` (`(500, 0, 30)` → Z == 15); `inside the domain is unchanged` (`(850, 0, 80)`); `domain corner is pulled in` (`(950, 0, 120)` → `(915, 0, 85)`); `from a domain corner to the corridor goes via the gate` (goal from `(880, 0, 70)` to `(500, 0, 0)` == `(740, 0, 0)` after clamp, i.e. X 740, Z 0); `once at the gate it goes straight` (goal from `(741, 0, 0)` to `(500, 0, 0)` == `(500, 0, 0)`); `inside the domain it goes straight` (from `(800, 0, 0)` to `(880, 0, 70)` == `(880, 0, 70)`); `from the corridor to a domain corner goes via the gate` (from `(600, 0, 0)` to `(880, 0, 70)` == `(740, 0, 0)`); `a target inside home is clamped to the home edge` (from `(300, 0, 0)` to `(100, 0, 0)` → X == 245).
  - `SpeedRule.spec`: `needed speeds match the spec` (`needed(20, 0.9) == 23`, `needed(20, 0.8) == 25`, `needed(20, 0.6) == 34`, `needed(20, 0.95) == 22`, `needed(20, 0.85) == 24`, `needed(20, 1) == 20`); `lines are sorted by needed speed` (with `Config/Eggs`: line 1 `"BOSS CHASE SPEED 20"`, then `"Field Egg: 22"`, `"Egg: 23"`, `"Shiny Egg: 24"`, `"Top Egg: 25"`, `"Giant Egg: 34"`; 6 lines).
  - `Config.spec`: `boss chase values match the spec` (Boss_Lofy: 20, 6, 20, 3, 60; `respawnSeconds == nil`); `catch damage leaves room to survive` (`catchDamage < 100`, the default max health).
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement the config change, `BossBrain` Guard, `ChaseNav`, `SpeedRule`, and the one `BossService` read (`respawnSeconds → reviveSeconds`).
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: guard state and chase rules for the enraged boss`.

### Task 2: Enraged chase, catch and egg return

**Files:**
- Modify: `src/server/Services/BossService.luau`, `src/server/Services/CarryService.luau`, `src/client/Controllers/BossHudController.luau`, `src/client/Controllers/CombatController.luau`

**Interfaces:**
- Consumes `BossBrain.enterGuard`, `ChaseNav.goal/clamp`, `Config/Bosses` chase values (Task 1); `ZoneCheck.inside` (Plan B).
- Produces `CarryService:GetCarriers(): { Player }` (players currently carrying any egg).
- Produces `CarryService:ReturnToSpawn(player: Player, reason: string): boolean`. If the player carries an egg: drop it the normal way, then move its part to `egg.spawnPos` (anchored, prompt on) and set `regrabUntil = now + Carry.regrabCooldown` for that player. Returns true. Returns false if they carry nothing. Giant-kind eggs broadcast `"Returned"` then `"Free"`.
- `BossService` step, by state:
  - `Dead` and `t − diedAt ≥ reviveSeconds` → `BossBrain.enterGuard(brain, t)`, model attribute `Enraged = true`, red `Highlight` (FillColor `(255, 40, 40)`, FillTransparency 0.6) parented to the model, `setAttributes`.
  - `Guard` and `t ≥ brain.stateEndsAt` → remove the highlight, `Enraged = nil`, `resetBoss(rec)`.
  - `Guard` otherwise: `target` = nearest (flat) carrier from `CarryService:GetCarriers()` with a living root outside `HomeZone` (`ZoneCheck`; no `HomeZone` part means nobody is home). Goal = `ChaseNav.goal(rec.pos, target and target.root.Position or rec.home, Map, cfg.bodyRadius)`. Move toward the goal by `cfg.chaseSpeed × dt` (not past it), clamp with `ChaseNav.clamp`, and `place` facing the goal. Then, if `target` and `DistanceToBody(rec, target.root.Position) ≤ cfg.catchRange`: `humanoid.Health = math.max(1, humanoid.Health − cfg.catchDamage)`, `CarryService:ReturnToSpawn(player, "caught")`, `AnnounceService:All("The boss took back " .. player.DisplayName .. "'s egg!", "Legendary")`, `bossAttackRemote:FireAll(rec.id, "Catch", t)`. Skip all Fight logic (arena clamp, emptySince reset, `BossBrain.update`) in Guard.
  - `resetBoss` also clears `Enraged` and destroys the highlight (it runs on Guard end, `SetDormant`, empty-arena reset and errors).
- `BossService` requires `CarryService` lazily inside `step` (`require(script.Parent.CarryService)` on first use), because `CarryService` already requires `BossService` at load.
- `BossHudController`: the `stagger` label shows `"ENRAGED"` in red `(255, 70, 70)` when `Enraged` is true, `"STAGGERED"` in its current colour when `State == "Staggered"`, and is hidden otherwise.
- `CombatController.onBossAttack`: when `attackId == "Catch"`, call `CombatFx.telegraph({ shape = "Sphere", radius = cfg.catchRange + cfg.bodyRadius }, model, impactTime)` and return.

- [ ] **Step 1:** Implement the `CarryService` additions, the `BossService` Guard step and the two client changes.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (temporary Scripts, in-memory data):
  - Kill the boss → `State == "Dead"`; 3 s later `State == "Guard"`, `Enraged == true`, `Hp == MaxHp`; `DamageBoss(boss, player, 100)` returns 0. `screen_capture` near the boss shows `ENRAGED` on the HUD.
  - No carriers: the boss stays at/near `home` for 5 s (position within 1 stud).
  - Spawn a field egg in the domain, carry it toward home per-frame at 0.95 × 16 = 15.2 studs/s → the boss (20 studs/s) catches up. After the catch: `Health == 100 − 20`, the player no longer carries, the egg is back at its spawn position, and an announcement fires. Repeat with `Health = 15` before the catch → `Health == 1`.
  - Carry an egg into home first (spawn it at x ≈ 250, walk to x = 200), then let Guard run: the boss stops with `pos.X ≥ home.maxX + bodyRadius` and never catches. When the carrier leaves home again, it resumes the chase.
  - Carrier in a domain corner `(880, y, 70)` while the boss is at home: the boss reaches them without leaving the domain box.
  - Set `brain.stateEndsAt = now` → the boss returns to home, `State == "Idle"`, `Enraged == nil`, and takes damage again.
  - Nightfall during Guard (`RoundService:SkipPhase()` to Night) → `Dormant == true`, `Enraged == nil`, full HP at home; `SkipPhase()` to Day → `State == "Idle"`.
  - Console has no errors.
- [ ] **Step 4:** Commit `feat: enraged boss chases egg carriers and takes eggs back`.

### Task 3: Speed sign

**Files:**
- Create: `src/server/Services/SpeedSignService.luau`

**Interfaces:**
- Consumes `SpeedRule.lines` (Task 1), `Config/Bosses`, `Config/Eggs`, `Config/Map.stageId`.
- `SpeedSignService:Start()`: find the Stage boss whose `stageId == Map.stageId` (first by id if several), take `SpeedRule.lines(boss.chaseSpeed, Eggs)`, joined with `"\n"`. Write the text into every `TextLabel` under every part tagged `SpeedSign`. No `SpeedSign` part → warn `[SpeedSignService] no SpeedSign on the map` once. No stage boss → leave the sign as is and warn.
- The sign part is 30 × 8 studs. Set `TextScaled = true` on those labels (already true from the builder) so 6 lines fit.

- [ ] **Step 1:** Implement `SpeedSignService`.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check:** start play, teleport the character to `(720, 4, 0)` facing +X, `screen_capture`: the gate beam shows `BOSS CHASE SPEED 20` and the five egg lines, readable. The label text equals the joined `SpeedRule.lines` output.
- [ ] **Step 4:** Commit `feat: speed sign at the domain gate`.

### Task 4: Docs and status

**Files:**
- Modify: `CLAUDE.md` (Status), `Steal a boss fight/planning/decisions.md` (section 21: one line for this plan's decisions 2, 4, 5 and 8)

- [ ] **Step 1:** Update Status: Plan C built on `feat/boss-chase` (from `feat/round-cycle`); all three branches wait on the user's tests; Next: merge after tests, then plan 6 (build step 8).
- [ ] **Step 2:** Commit `docs: update status after boss chase`.

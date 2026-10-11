# CLAUDE.md — Steal a Boss Fight

Read at the start of every session, before any work.

## Part A — How to work with this user

### Model & effort

The full protocol is in the global `~/.claude/CLAUDE.md` (MODEL CHECK before every build-order step and every distinct task outside it; stop and wait for "go"). Recommended settings per step are in the Build order table below. The user can only switch with the model/effort picker; never start a step before they confirm.

### Keep the user updated

- Before each step: one line saying what you're about to do (e.g. "**Step 2/4:** writing X").
- After each step: one line saying what happened and whether it worked.
- Never do several silent steps in a row. Never skip announcing installs, downloads, git commits or changes to the Studio place.
- The user is a beginner (zero Roblox/Luau/3D experience as of 2026-10-09): explain new Roblox concepts in one plain sentence the first time they appear.

### Token-saving habits (from the user's optimization guide)

- Answer directly: no preamble, filler or padding. Tight bullets, short code blocks.
- No web search unless the task needs current information.
- If a task is trivial, say once: "Haiku recommended for this task."
- When a session passes about 15 messages or a milestone is done, suggest once: update the vault and this file's Status, then start a fresh session.
- When the user asks for a correction, remind once that editing their previous message is cheaper than a follow-up.
- Read only the parts of files you need.

## Part B — Project brief

### The game

Anime boss-raid game on the Steal An Egg loop. Full design: [Obsidian vault](Steal%20a%20boss%20fight/INDEX.md). Read `INDEX.md` and `planning/decisions.md` before design work. Don't re-argue settled decisions (e.g. renamed anime characters).

Core: fight stage bosses alongside auto-fighting stands → everyone gets a personal egg → one giant egg is contested and stealable on the way home → eggs hatch into stands that fight and earn money → bosses drop armor (medium chance) and moveset copies (low chance, one move each) → buy weapons, train speed, rebirth → godly raid boss every 45 min for the whole server.

### Scope for V1

8-player servers, 8 plots (bases), 1 stage, 1 boss, about 6 characters, giant egg, punch/kick + a few weapons, dodge (i-frames + perfect-dodge counter), parry + poise break, saving, treadmill, rebirth. Assets are **placeholders** (the user is making real ones).

**Not in V1** (remind the user if they ask casually): raids, PvP, more stages, trading, monetization before the core loop works.

### Stack

- Luau, Roblox Studio
- Rojo 7.7.1 (pinned in `rokit.toml`) syncs `src/` into Studio; the map is built in Studio
- Roblox Studio MCP (built-in) for building the map, play-testing and reading output
- git, branch `main`

### Folder layout (until the architecture spec changes it)

- `src/server` → ServerScriptService.Server
- `src/client` → StarterPlayerScripts.Client
- `src/shared` → ReplicatedStorage.Shared
- `Steal a boss fight/` → Obsidian vault (design notes)

### Commands

```
install tools:  rokit install
sync to Studio: rojo serve      (then Studio: Plugins → Rojo → Connect)
```

### Engineering rules

- **The server decides everything that matters**: money, inventory, eggs, drops, damage, who holds the giant egg. The client sends inputs and shows effects.
- Validate every RemoteEvent argument on the server (type, range, distance, cooldown). Assume exploiters.
- Dodge/parry timing is judged on the client for responsiveness, then checked for plausibility on the server.
- **Data-driven content**: bosses, characters, weapons, drops and rarities live in config modules. Adding a boss should mean adding data, not new systems.
- Save data with session locking and retries; never lose a player's progress.
- Never use toolbox models with unaudited scripts; never `require(assetId)` or `loadstring`.
- Test in Studio play mode (via MCP) before saying something works.
- One feature per commit, with a clear message.

### Build order

| # | Step | Model / effort |
|---|---|---|
| 1 | Architecture spec (brainstorming → written spec) | Opus high |
| 2 | Implementation plan | Opus medium |
| 3 | Core framework: config modules, networking, saving | Sonnet high |
| 4 | Graybox map via MCP: home with 8 plots, corridor, cursed domain with the arena | Sonnet medium |
| 5 | Combat core: combo, dodge/i-frames, parry/poise, boss AI | Sonnet high (Opus high if it fights back twice) |
| 6 | Eggs, hatching, stands earning money | Sonnet high |
| 7 | Giant egg: carry, steal, deliver | Sonnet high |
| 8 | Stands fighting in combat | Sonnet medium |
| 9 | Drops (armor, moveset copies) and weapon shop | Sonnet high |
| 10 | Treadmill and rebirth | Sonnet medium |
| 11 | Playtest and exploit review | Opus high |
| 12 | Spectacle polish: effects, sounds, number popups | Sonnet medium |
| 13 | Monetization | Sonnet high |
| 14 | Security and code review before launch | Opus high |

## Status

- **Done:** design vault; Rojo + git (2026-10-10); architecture spec approved; plan 1 (core framework, build step 3) and plan 2 (graybox map + BaseService, build step 4) merged into `main`; plan 3 (build step 5: combat core) built on branch `feat/combat-core`: pure `Hitbox`, `DamageCalc`, `DefenseJudge`, `ComboCheck`, `BossBrain`; `BossService` (chase, telegraph, die, respawn; boss HP/poise/state replicate as model attributes), `CombatService`; client `InputController`, `CameraController`, `CombatController`, `BossHudController`, Studio-only `StudioTestController` (player attributes `AutoAttack`, `AutoDefend` drive play-tests). 112 unit tests pass; play-tested attack, parry-stagger, perfect-dodge counter, death and respawn. Plan 4 (build step 6: eggs, hatching, stands earning money) built on branch `feat/eggs-stands`: pure `Uid`, `LootRank`, `EggRules`, `StandPlace`, shared `Income`, `OddsDisplay`; services `AnnounceService`, `EggService`, `LootService`, `StandService`, `EconomyService`, `UpgradeService`; client `Ui/Widgets`, `HudController`, `EggsController`, `StandsController`; Studio test hook `FireRemote` attribute ("Name|arg#nonce"). 141 unit tests pass; play-tested kill -> rank egg, hatch, placement, income, offline earnings, upgrades, saving, UI screenshots. Plan 5 (build step 7: giant egg) built on branch `feat/giant-egg`: pure `GiantEggRules`, `CarryCheck`, `Config/GiantEgg`; `GiantEggService` (spawn after boss kill, ProximityPrompt pickup, carry, drops, return/despawn, delivery), `CombatService` hits on the carrier, client `GiantEggController` banner. 157 unit tests pass; play-tested spawn, pickup, delivery, storage-full, speed drop, fall-off, death, timeouts, no dash while carrying. Not yet tested with 2 real players. Plan A (strip map and carried eggs, design `docs/specs/2026-10-11-strip-map-and-egg-chase-design.md`) built on branch `feat/strip-map`: strip map (8 plots, 500-stud corridor, cursed domain; `HomeZone`, `SpeedSign`, `FieldEggSpawn` already in the map), `Config/Carry`, `CarryRules` (was `GiantEggRules`), `CarryService` (was `GiantEggService`: giant and personal eggs through one record), `EggPromptController`; carry speed = walk speed x egg `carryFactor`; boss kills now drop personal rank eggs in the arena that only their owner can carry home. 173 unit tests pass; play-tested personal and giant pickup, speeds, owner-only, death/respawn drops, expiry, delivery, storage-full, trained walker.
- **Also done:** Plan B (round cycle) built on branch `feat/round-cycle` (from `feat/strip-map`): `Config/Rounds`, pure `RoundRules`, `FieldEggRoll`, `ZoneCheck`; `RoundService` (4 min day / 45 s night, lighting tween, `RoundPhase`/`RoundEndsAt` attributes, field eggs at sunrise, nightfall teleport home), `CarryService:SpawnField/Nightfall/ResetCheck`, `BossService:SetDormant`, client `RoundController` countdown. 188 unit tests pass; play-tested day/night transitions, carried egg counted at nightfall, full storage, dead at nightfall (with an in-memory DataService, because the dev profile was session-locked). Both `feat/strip-map` and `feat/round-cycle` wait for the user's 2-player tests; nothing is merged.
- **Also done:** Plan C (boss chase) built on branch `feat/boss-chase` (from `feat/round-cycle`): config `chaseSpeed/catchRange/catchDamage/reviveSeconds/guardSeconds`, `BossBrain` Guard state, pure `ChaseNav` and `SpeedRule`; `BossService` revives the boss enraged and immune for 60 s, it chases the nearest carrier outside `HomeZone`, a catch costs 20 HP (never lethal) and `CarryService:ReturnToSpawn` sends the egg back; `SpeedSignService` writes the gate sign; HUD shows ENRAGED. 205 unit tests pass; play-tested revive, catch, low-health catch, corner, guard end, nightfall during guard. `feat/strip-map`, `feat/round-cycle` and `feat/boss-chase` are stacked and unmerged, waiting for the user's tests.
- **Also done:** build step 8 (stands in combat) built on branch `feat/stands-combat` (from `feat/boss-chase`): pure `TeamRules` (3 slots + extras by rebirth) and `StandDamage`; `StandService:SetTeam` (strict server validation) and a 1 s damage tick (owner alive, in the arena, not carrying, boss in a normal fight; counted in the damage ledger; tuned by `Combat.standDamageFactor`, balance in the playtest step 11); player attributes `StandTeam` / `StandsFighting`; client `StandCombatController` (placeholder blocks, lunge each tick), Team toggle in the Stands panel, cyan stand damage numbers. 219 unit tests pass; play-tested team validation, carry/dead/guard/dormant/outside-arena stop, upgrade scaling. Four stacked branches (strip-map, round-cycle, boss-chase, stands-combat) are unmerged, waiting for the user's tests.
- **Also done:** build step 9 (drops and weapon shop) built on branch `feat/drops-shop` (from `feat/stands-combat`): `Config/Moves`; pure `DropRoll`, `ShopRules`, `AbilityRules`; `LootService` rolls armor (35%, only unowned pieces, auto-equips an empty slot) and moveset copies (5%, one move each) for every ranked participant; `WeaponService` (`BuyWeapon`, `Equip`: ownership, money and 15-stud shop distance checked on the server); `CombatService` `UseAbility` (copied moves on keys 1-4, server cooldowns, a miss still spends the cooldown); client `ShopController` (local Shop prompt and panel) and `AbilityBarController`. 243 unit tests pass; play-tested drops, buying, equipping, ability damage and cooldowns, and both panels. Move and weapon numbers are placeholders for the playtest (step 11). Five stacked branches (strip-map, round-cycle, boss-chase, stands-combat, drops-shop) are unmerged, waiting for the user's tests.
- **Also done:** Gogo attacks (stage 1 boss, spec `docs/specs/2026-10-11-gogo-attacks-design.md`) built on branch `feat/gogo-attacks` (from `feat/drops-shop`): boss `Boss_Lofy` is now Gogo (id kept for saves); attack data fields `targeting`/`parryWindow`/`cooldown`/`danger`/`vfx`/`anim`; pure `Circle` hitbox, shared `WaveTiming`, `BossBrain` eligibility and cooldowns; `BossService` Ground Fire (circle locked under a random arena player), Flame Wave (one impact per player at their own arrival time), server-played boss animations (ids in config, none yet); client placeholder markers, timing rings, `BossWarningController` (danger kanji, PARRY prompt) and Astra's asset slots (`Assets.VFX.Gogo.<vfx>.Marker/Impact`). 260 unit tests pass; play-tested every attack hit/dodge/parry/stagger-cancel on the server. Client checks done too: Flame Wave ring grows at its true speed, reduced effects skip only Impact (markers, rings, danger and PARRY stay), placeholder fallback for Slam/Sweep/Wave, Astra's GroundFire Marker and Impact play. Not yet tested: boss animation playback (no ids yet). Six stacked branches are unmerged, waiting for the user's tests.
- **Also done:** Gogo integration (animation ids in `Config/Bosses`, root-only anchoring, feet measured from the model pivot, death animation before the body hides, arena entrance wall removed in the builder and the place) and Astra's second pass (FlameWave/Slam impacts, Slam marker, corridor/gate/domain/home scenery; exports to `assets/` still the user's job). Build step 10 (training and rebirth) built on branch `feat/training-rebirth` (from `feat/gogo-attacks`): pure `TrainingRules` and `RebirthRules`; `ProgressionService` (treadmill/sandbag sessions re-checked every second, walk speed = 16 + speed points capped at 60, rebirth costs 1M x 5^n and resets money, training and stand levels), `CarryService:SetBaseSpeed` (carry speed = walk speed x egg slowdown even when walk speed changes), client `TrainingController` and `RebirthController`. 271 unit tests pass; play-tested training gains, leaving a station, carrying, rebirth (also while carrying) and both UIs (the Confirm click itself was not clicked). Numbers are placeholders for the playtest. Seven stacked branches are unmerged, waiting for the user's tests.
- **Next:** the user's 2-player tests and merging the stacked branches in order (strip-map, round-cycle, boss-chase, stands-combat, drops-shop, gogo-attacks, training-rebirth); then build step 11 (playtest and exploit review, Opus high). Open items: Astra's Sweep impact art and live review of her new effects, JJK roster rename for the stands, Sweep/other VFX hooks, `ASSETS.md` is current. The 8-player cap is a Studio Game Settings value (Places > Max Players = 8). The dev profile still has test power 1,000,000; a real rebirth wipes it. Studio sometimes sticks on Play (see Gotchas).
- **Known deferred minors** (from the final review): handler-less remotes unvalidated, Format.number(nil), Loaded-before-DataInit order, loadPlayer pcall, version downgrade, Net small leaks, Update key/NaN checks, DataService boot failure not kicking.
- **Gotchas:** never delete a folder Rojo watches (crashes Rojo 7.7.1: restart `rojo serve`, user reconnects the plugin); MCP `execute_luau` runs in a separate Lua environment from game scripts, so test game services with temporary Scripts parented at runtime during play; Studio instance id changes when Studio restarts (`list_roblox_studios`); Rojo can leave a file stale after a reconnect: check with `Source:find(...)` and make a tiny real edit to resync; the play start can stick ("Start play hasn't finished yet"): the user must look at the Studio window.

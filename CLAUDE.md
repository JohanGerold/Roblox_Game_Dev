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

16-player servers, 16 bases, 1 stage, 1 boss, about 6 characters, giant egg, punch/kick + a few weapons, dodge (i-frames + perfect-dodge counter), parry + poise break, saving, treadmill, rebirth. Assets are **placeholders** (the user is making real ones).

**Not in V1** (remind the user if they ask casually): raids, day/night, PvP, more stages, trading, monetization before the core loop works.

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
| 4 | Graybox map via MCP: hub, 16 bases, boss arena | Sonnet medium |
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

- **Done:** design vault; Rojo + git (2026-10-10); architecture spec approved; plan 1 (core framework, build step 3) and plan 2 (graybox map + BaseService, build step 4) merged into `main`; plan 3 (build step 5: combat core) built on branch `feat/combat-core`: pure `Hitbox`, `DamageCalc`, `DefenseJudge`, `ComboCheck`, `BossBrain`; `BossService` (chase, telegraph, die, respawn; boss HP/poise/state replicate as model attributes), `CombatService`; client `InputController`, `CameraController`, `CombatController`, `BossHudController`, Studio-only `StudioTestController` (player attributes `AutoAttack`, `AutoDefend` drive play-tests). 112 unit tests pass; play-tested attack, parry-stagger, perfect-dodge counter, death and respawn.
- **Next:** user hand-tests the fight feel (click to punch, right-click parry, Shift dodge, Ctrl combat mode) and merges `feat/combat-core` into `main`; then write plan 4 (build step 6: eggs, hatching, stands earning money) with Opus medium, build with Sonnet high.
- **Known deferred minors** (from the final review): handler-less remotes unvalidated, Format.number(nil), Loaded-before-DataInit order, loadPlayer pcall, version downgrade, Net small leaks, Update key/NaN checks, DataService boot failure not kicking.
- **Gotchas:** never delete a folder Rojo watches (crashes Rojo 7.7.1: restart `rojo serve`, user reconnects the plugin); MCP `execute_luau` runs in a separate Lua environment from game scripts, so test game services with temporary Scripts parented at runtime during play; Studio instance id changes when Studio restarts (`list_roblox_studios`).

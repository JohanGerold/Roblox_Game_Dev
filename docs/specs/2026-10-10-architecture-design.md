# Steal a Boss Fight — Architecture Design (V1)

- **Date:** 2026-10-10
- **Status:** awaiting user review
- **Design source:** [Obsidian vault](../../Steal%20a%20boss%20fight/INDEX.md), decisions 1–20 in [decisions.md](../../Steal%20a%20boss%20fight/planning/decisions.md)

## 1. Goal and success criteria

Build V1 of an anime boss-raid game on the Steal An Egg loop: fight a stage boss with auto-fighting stands, get a personal egg ranked by damage, contest a stealable giant egg, hatch stands that earn money at your base, train, upgrade, rebirth.

The architecture succeeds if:

1. **Content is data.** A new boss, character, weapon or egg is added by editing config modules and dropping a model into `Assets`, with no new systems.
2. **The server owns every outcome** (money, inventory, drops, damage, giant egg), and every client message is validated.
3. **Combat feels fair on a laggy phone:** dodge/parry timing is judged on the client and checked for plausibility on the server.
4. **Saves are never lost or duplicated** (session locking; never play on empty data).
5. **V1 can be built and tested step by step**, each step play-testable in Studio.

## 2. Scope

**V1:** 16-player servers with 16 bases; 1 stage and 1 boss; about 6 characters; personal rank eggs; giant egg; punch/kick plus a few weapons; boss armor and moveset-copy drops; dodge (i-frames, perfect-dodge counter), parry and poise break; stand team of 3; stands earning at base; stand upgrades; treadmill (speed) and sandbags (power); rebirth; offline earnings; rebindable controls and combat mode; saving. All assets are placeholders.

**Designed for, not built in V1:** raid bosses every 45 minutes (BossService supports `kind = "Raid"`), ascension (character families exist in config), mutations and sizes (save `version` allows adding them), more stages, day/night, PvP beyond hitting the giant-egg carrier, monetization, stealing stands from bases.

## 3. Tooling and repository

| Tool | Role |
|---|---|
| Rojo 7.7.1 (pinned in `rokit.toml`) | Syncs `src/` into Studio live |
| Roblox Studio MCP | Builds the map, runs play tests, reads output |
| git (`main`) | History; one feature per commit |

```
src/
├─ server/                    → ServerScriptService.Server
│  ├─ init.server.luau        boots services
│  ├─ Packages/ProfileStore   vendored saving library (license checked before adding)
│  ├─ Services/               one module per service (section 4)
│  └─ Logic/                  pure functions, no Roblox instances (testable)
├─ client/                    → StarterPlayerScripts.Client
│  ├─ init.client.luau        boots controllers
│  └─ Controllers/
├─ shared/                    → ReplicatedStorage.Shared
│  ├─ Config/                 all content and tuning (section 5)
│  ├─ Net.luau                every remote + its validation rules (section 7)
│  └─ Util/                   number formatting, Signal, table helpers
tests/                        → ServerStorage.Tests (Studio-only test runner + specs)
docs/specs/                   design specs
Steal a boss fight/           Obsidian design vault
```

The **map is not in Rojo**. It is built in Studio and saved to Roblox. Rojo only manages the folders above, so it never overwrites the map, lighting or `Assets`.

## 4. Runtime structure

### Boot

`init.server.luau` requires every module in `Services/`, calls `Init()` on all (set up state, connect nothing cross-service), then `Start()` on all (begin loops, connect events). `init.client.luau` does the same for `Controllers/`. Services reference each other by `require` and only call each other after `Init`.

### Server services

| Service | Responsibility |
|---|---|
| DataService | Load/save profiles (ProfileStore, session locked), migrations, replicate a player's data to that player, `Get(player)`, `Update(player, fn)` |
| BaseService | Assign one of 16 bases on join, release on leave; base ownership lookups; delivery pad per base |
| EconomyService | 1-second income tick, offline earnings on join, spending money (`TrySpend`) |
| CombatService | Validate player attacks, abilities, dodge/parry claims, counters; compute and apply damage; carrier hits |
| BossService | Spawn bosses from config, AI state machine, HP and poise, stagger, respawn, damage ledger per participant |
| LootService | On boss death: rank participants, grant rank eggs, roll armor and moveset copies |
| EggService | Store personal eggs, hatch timers, server-side character rolls, announcements |
| GiantEggService | Giant egg spawn, head start, pickup, carry rules, drop, return/despawn, delivery |
| StandService | Spawn placed stands at bases (shadowbox), stand team, server-side stand damage ticks |
| UpgradeService | Stand level upgrades (cost and scaling from config) |
| WeaponService | Weapon shop purchases, equipping weapons and armor |
| ProgressionService | Treadmill and sandbag training sessions, rebirth |
| AnnounceService | Server-wide announcements (hatches, giant egg, drops) |

### Client controllers

| Controller | Responsibility |
|---|---|
| InputController | Rebindable actions (keyboard, mouse, gamepad, touch buttons); loads binds from player data |
| CameraController | Combat mode (Ctrl toggle: cursor locked, camera follows mouse, character faces camera) vs cursor mode; Roblox Shift Lock disabled |
| CombatController | Instant combo animations, dodge/parry timing and i-frame visuals, sends claims with server time |
| StandController | Draws your team's stands and their attacks (visual only) |
| EffectsController | Auras by rarity, impact frames, damage numbers, screen shake; respects `fewerEffects` |
| UIController | Money HUD, eggs and hatching, stand management, shop, keybind menu, announcements, odds display |

### Map contract (tags)

Code finds map pieces through CollectionService tags, never by name or position:

| Tag | Used by |
|---|---|
| `Base` (with attribute `BaseIndex` 1–16) | BaseService |
| `StandSlot` (child of a base, attribute `SlotIndex`) | StandService |
| `EggDeliveryPad` (child of a base) | GiantEggService |
| `BaseSpawn` (child of a base, where the owner spawns) | BaseService |
| `BaseSign` (child of a base, part with a SurfaceGui TextLabel showing the owner) | BaseService |
| `BossArena` (attribute `StageId`) | BossService |
| `BossSpawn`, `GiantEggSpawn` (inside arena) | BossService, GiantEggService |
| `Treadmill`, `Sandbag` | ProgressionService |
| `WeaponShop` | WeaponService |

### Assets contract

`ReplicatedStorage.Assets` (Studio-managed) holds models and animations referenced by name from config, for example `Assets.Characters.Goku_Red`, `Assets.Bosses.Boss_Lofy`. V1 ships placeholder models with the final names; real assets replace them with no code change.

## 5. Config modules (`shared/Config`)

All values below are initial tuning, expected to change.

- **Rarities:** ordered list of 12 tiers (Common → Absolute) with `color` and `aura = "None" | "Static" | "Animated"` and `auraIntensity`. Static from Mythic, Animated from Celestial.
- **Characters:** `id`, `displayName`, `rarity`, `family` (for ascension later), `model`, `walkAnim`, `baseIncome`, `basePower`.
- **Eggs:** `id`, `hatchSeconds`, `odds` (rarity → weight, then character pick within rarity). V1 eggs: `Stage1_Top` (Mythic+, mostly Mythic), `Stage1_Normal` (Legendary and below), `Stage1_Giant` (best top-tier odds).
- **Bosses:** `id`, `kind = "Stage" | "Raid"`, `stageId`, `model`, `maxHp` (plus per-player scaling), `maxPoise`, `poiseRegen`, `staggerSeconds` (Stage ≈ 5, Raid ≈ 2.5), `respawnSeconds`, `attacks` (list: `id`, `windup`, `activeWindow`, `damage`, `hitbox`, `poiseOnParry`, `unparryable`), `playerMoves` (up to 4, unlocked one per copy), `drops` (`armorChance` medium, `armorPieces`, `moveCopyChance` low).
- **Weapons:** `id`, `price`, `kind = "Physical" | "Magic"`, `model`, `combo` (hits: `damage`, `range`, `minInterval`), `abilities`. V1 includes `Fists` (default) plus a few placeholder weapons.
- **Armor:** `id`, `slot`, `powerBonus`.
- **Economy:** stand upgrade cost and income/power scaling per level, base slot costs, offline cap (8 h) and rate (0.5), rebirth requirement and bonuses.
- **Combat:** parry window 0.20 s, perfect-dodge window 0.15 s, dodge i-frames 0.30 s, counter window 1.5 s, counter damage, claim max age 0.30 s, cooldowns, minimum damage share for rewards.
- **Training:** speed and power gained per second on treadmill and sandbag, walk-speed cap.
- **Progression:** rebirth resets money, training and stand levels; keeps stands, eggs, boss moves, armor and weapons; grants a permanent income and damage multiplier and unlocks extra stand-team and boss-set slots at set rebirth counts.
- **Keybinds:** default action → input map.

## 6. Player data (ProfileStore)

```lua
{
  version = 1,
  money = 0,
  rebirths = 0,
  lastSeen = 0,                         -- unix time, for offline earnings
  training = { speed = 0, power = 0 },
  characters = {                        -- every stand, unique id each
    ["c_8f2a"] = { id = "Goku_Red", level = 4, slot = 3 },  -- slot nil = storage
  },
  baseSlots = 4,
  standTeam = { "c_8f2a" },             -- up to teamSlots (3 + rebirth unlocks)
  eggs = { ["e_0c11"] = { eggId = "Stage1_Normal", readyAt = 1760100000 } },
  bossMoves = { ["Boss_Lofy"] = 3 },    -- copies = moves unlocked
  equippedBossSet = "Boss_Lofy",
  armor = { owned = { "Lofy_Hat" }, equipped = { head = "Lofy_Hat" } },
  weapons = { owned = { "Fists" }, equipped = "Fists" },
  settings = { fewerEffects = false, keybinds = {} },  -- empty = defaults
}
```

- Saves store ids only; stats come from config.
- Inventory capped at 200 stands.
- `version` plus migration functions in DataService for future fields.
- Studio uses DataStore name `PlayerData_Dev`; live uses `PlayerData_Live`.
- Only DataService writes data, through `Update(player, fn)`, which then sends the change to that player's client (read-only copy).

## 7. Networking (`shared/Net.luau`)

Every remote is declared once with a validator (argument types, ranges) and a per-player rate limit. Invalid or over-limit messages are dropped and logged. Repeated extreme abuse kicks the player. Cosmetic high-frequency messages use `UnreliableRemoteEvent`.

**Client → server**

| Message | Args |
|---|---|
| `Attack` | `comboIndex`, `weaponId` |
| `UseAbility` | `slot` (1–4) |
| `Defend` | `kind` (`"Dodge"` / `"Parry"`), `pressTime` (server clock) |
| `Counter` | — |
| `HatchEgg` | `eggUid` |
| `PlaceStand` / `SetTeam` | `charUid`, `slot` / list of `charUid` |
| `UpgradeStand` | `charUid` |
| `BuyWeapon` / `Equip` | `weaponId` / `kind`, `id` |
| `Train` | `kind` (`"Treadmill"` / `"Sandbag"`), `active` |
| `Rebirth` | — |
| `SetKeybinds` / `SetSetting` | map / `key`, `value` |

Giant-egg pickup uses a server-side ProximityPrompt (no remote).

**Server → client**

| Message | Purpose |
|---|---|
| `DataInit`, `DataChanged` | Player's own data copy |
| `BossState` | HP, poise, state (Idle, Windup, Active, Recovery, Staggered, Dead) |
| `BossAttack` | `attackId`, `impactTime` (server clock) for synced telegraphs |
| `HitResult` | Damage taken, parried, dodged, perfect dodge |
| `DamageNumbers` (unreliable) | Floating numbers |
| `GiantEggState` | Spawned, head start, carried by, dropped, delivered |
| `Announce` | Text and rarity color |

Clock: both sides use `workspace:GetServerTimeNow()`.

## 8. Combat

### Boss AI (server)

State machine: `Idle → Windup → Active → Recovery → Idle`, with `Staggered` (poise 0) and `Dead`. On Windup the server broadcasts `BossAttack(attackId, impactTime)`. At impact it finds players inside the attack's hitbox (simple shapes: sphere, box, cone) and judges each one.

### Judging defense (server)

Each player has a short history of `Defend` claims. A claim is accepted only if `now - pressTime ≤ 0.30 s`, `pressTime ≤ now + 0.05 s`, and the action was off cooldown. For a player in the hitbox at impact:

| Latest accepted claim relative to impact | Result |
|---|---|
| Parry, 0–0.20 s before (and attack parryable) | No damage; boss poise −= `poiseOnParry` |
| Dodge, 0–0.15 s before | No damage; perfect dodge: counter available 1.5 s |
| Dodge, within i-frame duration (0.30 s) | No damage |
| Otherwise | Damage applied |

### Poise and stagger

Poise regenerates after a delay with no parries. At 0 the boss enters `Staggered` for `staggerSeconds`: kneels, cannot attack, takes 2× damage, then poise refills.

### Player damage (server)

`Attack` is accepted if the combo step follows the weapon's `minInterval` and the player is within `range` (+ tolerance) of the boss. Damage:

`move damage × (1 + power × k) × armor multiplier × rebirth multiplier × (2 if staggered)`

Abilities use the same checks with ability cooldowns; only unlocked moves of the equipped boss set are allowed. Player attacks damage other players **only** if the target is carrying the giant egg; any such hit makes the carrier drop it.

### Stands in combat

Your stand team is drawn on clients by StandController. StandService ticks damage for each team stand while its owner is in an active boss arena: `basePower × level scaling` per tick. Bosses never target stands.

## 9. Boss fight lifecycle and rewards

1. BossService spawns the stage boss in its arena; HP scales with players present.
2. BossService keeps a damage ledger per player (their hits plus their stands).
3. On death, LootService:
   - drops players below the minimum damage share,
   - ranks the rest by damage: ranks 1–3 get `Stage1_Top`, rank 4 to last get `Stage1_Normal`,
   - rolls armor (medium chance) and a moveset copy (low chance) for each participant.
4. GiantEggService spawns the giant egg (section 10).
5. Boss respawns after `respawnSeconds`.
6. Raid bosses (post-V1): if not defeated within their time limit, they leave and nobody gets rewards.

## 10. Giant egg

- Spawns at `GiantEggSpawn` after a 3 s countdown with an announcement. Top 3 damage dealers have a 2 s exclusive pickup window.
- **Pickup:** ProximityPrompt (hold E / tap); server checks distance.
- **Carrying:** fixed carry walk speed (training ignored), stand team disabled, highlight visible through walls.
- **Drop:** on any hit from another player, death, leaving or falling off the map. The previous carrier can't re-grab for 1 s.
- **Anti-cheat:** carrier position checked each heartbeat; movement faster than carry speed plus tolerance forces a drop at the last valid position.
- **Timeouts:** undelivered after 3 min, it returns to the arena once; it despawns at 5 min total.
- **Delivery:** carrier touches their own base's `EggDeliveryPad`; `Stage1_Giant` is added to their eggs with an announcement.

## 11. Eggs, hatching and stands

- Eggs live in player data with `readyAt`. When ready, `HatchEgg` makes the server roll rarity, then character, from the egg's odds and add a new character entry.
- Mythic+ hatches trigger a server-wide announcement. The UI shows each egg's odds.
- Placed stands spawn on their base's `StandSlot`s and play a shadowbox idle.
- The stand team is chosen separately; a stand may be both placed and on the team.

## 12. Economy and progression

- **Income tick (1 s):** sum over placed stands of `baseIncome × level scaling`, times rebirth multiplier.
- **Offline earnings on join:** `min(now − lastSeen, 8 h) × income per second × 0.5`, shown in a "welcome back" popup. `lastSeen` is saved on leave and with autosaves.
- **Upgrades:** UpgradeService raises a stand's level (cost from config); income and power scale with level.
- **Training:** while a `Train` session is active and the player is on a `Treadmill`/`Sandbag` (server checks position), speed or power grows per second. Speed raises walk speed up to a cap; power multiplies damage.
- **Rebirth:** rules in Config/Progression (section 5).

## 13. Input and camera

- Actions: Attack, Parry, Dodge, Counter, Ability1–4, Interact, ToggleCombatMode, OpenMenu. All rebindable to keyboard keys, mouse buttons 1–3 and gamepad buttons; saved in `settings.keybinds`.
- Defaults: left-click attack, right-click parry, Left Shift dodge, 1–4 abilities, E interact, Ctrl combat mode.
- Mouse side buttons are not detected by Roblox (tested 2026-10-10). Players remap them to keys in mouse software.
- Phones: on-screen buttons, movable and saved.
- Implementation checks Roblox's Input Action System first; falls back to UserInputService/ContextActionService if it doesn't fit.

## 14. Effects and performance

- Auras by rarity (none / static / animated with impact frames, intensity rising per tier) are rendered client-side.
- `fewerEffects` halves particle counts and disables impact frames for other players' stands.
- Targets: 16 players, 48 team stands, 1 boss, steady frame rate on mid-range phones. Stand visuals are client-only to keep the server light.

## 15. Security

- Every outcome is computed on the server; clients only send intents (section 7).
- Net validators plus rate limits on every remote.
- Range checks on attacks, position checks on training and delivery, speed checks on the giant-egg carrier.
- No toolbox scripts without audit; no `require(assetId)` or `loadstring`.
- Purchases (post-V1) through `ProcessReceipt`, idempotent via the profile.

## 16. Error handling

- **Profile fails to load:** kick with "Couldn't load your data, please rejoin"; never play on empty data.
- **Each service loop** runs in a protected call; errors are logged and the loop continues.
- **Player leaves:** drop giant egg, remove stands, release base, end training, save.
- **Boss errors:** reset the boss to Idle at full HP rather than leaving it stuck.

## 17. Testing

- **Unit tests** for `server/Logic` pure functions: loot ranking and rank eggs, odds rolls (statistical check), damage formula, defense judging, offline earnings, upgrade costs, rebirth reset. A small in-house runner in `tests/` runs them in Studio through MCP; it fails loudly on any error.
- **Play tests** through MCP: start play, drive the scenario, read console output.
- **Multiplayer tests** in Studio's local server with 2–4 clients for giant-egg stealing and boss participation.
- **Data tests** against `PlayerData_Dev` only (requires a published private place and "Enable Studio Access to API Services").
- **Exploit review** in build step 11: try fake claims, spam, speed and teleport.

## 18. Numbers to tune during building

All timing windows, drop chances, egg odds, income and upgrade curves, training rates, rebirth thresholds and boss stats are first guesses in config and will be tuned through play tests.

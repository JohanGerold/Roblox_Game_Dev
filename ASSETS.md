# ASSETS.md: art handoff contract

For whoever makes the visuals (models, animations, effects, stage art). The code side reads this too. If a rule here has to change, change it here first.

## 1. Where things live

| What | Where | Notes |
|---|---|---|
| Code | `src/` (Rojo syncs it into Studio) | Art never goes here. |
| Map, models, animations | The Studio place only | **Not in git.** Save the place often (File > Save). |
| Finished art backup | `assets/` (export as `.rbxm`) | Create the folder when the first asset is done; one file per model. |
| Design notes | `Steal a boss fight/` (Obsidian vault) | Latest design: `docs/specs/2026-10-11-strip-map-and-egg-chase-design.md`. Older notes may still say 16 players. |

## 2. Models the code loads by name

Names must match the config exactly. A missing model is not an error: the game draws a placeholder block and warns once in the output.

| Model | Put it at | Name comes from |
|---|---|---|
| Boss | `ReplicatedStorage.Assets.Bosses.<model>` | `Config/Bosses` field `model` (now `Boss_Lofy`) |
| Stand (character) | `ReplicatedStorage.Assets.Characters.<model>` | `Config/Characters` field `model` (equals the id; the 16 stage 1 stands are listed in `handoffs/2026-10-12-claude-to-astra-stage1-roster.md`) |

Rules for these models:
- One `Model` with a `PrimaryPart`. Bosses should stand on y = 0 at their origin.
- The code anchors parts, turns off collision on stands and sets their labels, so don't script that yourself.
- Stands are shown at a base slot (about 5 x 5 studs of floor). Keep them roughly 3 x 5 x 2 studs, like the placeholder.
- **No Scripts, LocalScripts or ModuleScripts inside any model.** Remove them from toolbox and generated models. Never `require(assetId)` or `loadstring`.

**No asset slot yet** (the code needs a small hook first; ask before building these): eggs and the giant egg, stands drawn during combat, weapons (`Config/Weapons.model`: `Fists`, `Stick`, `Katana`), armor (`Gogo_AshCrown`), effects other than boss attacks (2a), sounds, icons. Plan the art, but tell the code side the model name and where it goes.

## 2a. Boss attack effects and animations

Design: `docs/specs/2026-10-11-gogo-attacks-design.md`.

- **Boss model:** `ReplicatedStorage.Assets.Bosses.Boss_Gogo` (stage 1 boss Gogo; the config `model` field). About 12 studs tall, feet at y = 0, facing −Z, with an `Animator` inside a `Humanoid` or `AnimationController`.
- **Effects:** `ReplicatedStorage.Assets.VFX.<vfxFolder>.<vfx>`: Gogo uses `vfxFolder = "Gogo"`, with `vfx` names `Slam`, `Sweep`, `GroundFire`, `FlameWave`. Each is a `Folder` that may contain:
  - `Marker`: a flat `BasePart` (or `Model` with `PrimaryPart`) exactly **1 × 1 stud in X and Z**, top face up. The code scales it to the attack area on the ground and fades it out at impact.
  - `Impact`: a `Model` with parts and `ParticleEmitter`s, cloned at the impact point, emitters enabled, removed after 2 s.
- **Never put gameplay information only in `Impact`.** Reduced effects hide `Impact`; markers, timing rings, the PARRY prompt and the danger warning are always drawn by the code.
- **Animations:** asset ids go in `Config/Bosses` (`animations = { idle, move, stagger, death }`, plus `anim` on each attack). The hit moment of an attack animation must line up with the end of that attack's warning (`windup`).
- Missing pieces fall back to placeholder shapes, so deliver them one at a time.

**Where an `Impact` is placed and which way it faces:**
- Slam and Sweep (attacks around the boss): at the boss's ground position, rotated with the boss's facing. Forward is the model's **-Z**, so a Sweep swipe effect should point toward -Z of its PrimaryPart and be about 22 studs long.
- Ground Fire: at the locked circle centre, no rotation (it is a point on the ground).
- Flame Wave: once at the boss's position when the wave is released, no rotation. The expanding ring is drawn by the code.
- All Impact emitters are enabled by the code and the clone is removed after 2 s.

**Delivered so far (Gogo):** `Assets.Bosses.Boss_Gogo`; `Assets.VFX.Gogo.GroundFire` (Marker, Impact), `.Slam` (Marker, Impact), `.FlameWave` (Impact), `.Sweep` (Impact only; the code keeps drawing the cone marker).

**Stage scenery (all under `Workspace.Scenery`, script-free, anchored, no collision):** `GogoArena`, `Corridor`, `Gate`, `DomainOutskirts`, `Home`. Add new areas as new child folders and list them here.

## 3. Animations

Upload each animation under the project's account, then give the code side the asset ID and which action it is for. The ID goes into config, never into a script. Character animation names already planned: `walkAnim` in `Config/Characters` (`Walk_Default`, `Walk_Serious`).

## 4. The map: what art must not break

`Workspace.Map` is rebuilt from code by `tools/BuildGraybox.luau`, which **deletes the whole folder and builds it again**. So:
- **Do not hand-build art inside `Workspace.Map`.** Put stage art in its own folder, for example `Workspace.Scenery`, anchored, around and above the map parts.
- Anything you change inside `Workspace.Map` is lost the next time the builder runs. If the graybox should be retired in favour of a real map, say so and the builder gets removed and a map check takes its place.

### Parts the game finds by tag

Art may sit around, over or on these, but they must keep existing with the same tag, attributes and rough position. Do not delete, rename, retag or move them far.

| Tag | Count | What it is | Extra attributes |
|---|---|---|---|
| `Base` | 8 | One model per plot | `BaseIndex` 1..8 |
| `EggDeliveryPad` | 1 per base | Where eggs are delivered | |
| `BaseSpawn` | 1 per base | Where the owner spawns | |
| `BaseSign` | 1 per base | Owner name sign (text is written by the code) | |
| `StandSlot` | 16 per base | Where placed stands stand | `SlotIndex` 1..16 |
| `BossArena` | 1 | The arena model | `StageId = "Stage1"` |
| `BossSpawn` | 1 (in the arena) | Boss home | |
| `GiantEggSpawn` | 1 (in the arena) | Giant egg and personal egg ring centre | |
| `FieldEggSpawn` | 12 | Field egg points inside the arena | |
| `HomeZone` | 1 | Invisible box: the safe area at home | keep `CanCollide`/`CanTouch`/`CanQuery` off |
| `SpeedSign` | 1 | Beam at the domain gate; the code writes text onto its `TextLabel`s | |
| `Treadmill` | 4+ | Speed training | |
| `Sandbag` | 4+ | Power training | |
| `WeaponShop` | 1 | The weapon stall (the Shop prompt is attached to it) | |

If a tagged part is missing, the game logs a map-contract problem or a warning. The checker is `src/server/Logic/MapContract.luau`.

### Layout facts (studs, from `Config/Map`)

- The strip runs along +X: home x 0 to 240 (120 wide), corridor x 240 to 740 (40 wide), cursed domain x 740 to 920 (180 wide), arena centre x 830, radius 70.
- Home has 8 plots in two rows of 4 facing a 24-wide path. The home end (x under 60) holds the spawn, shop, treadmills, sandbags and the reserved fuse-machine spot.
- Invisible walls (60 high) keep players in. Keep gaps closed: the boss and players rely on them.
- The boss never enters home. Keep the corridor and gate clear enough to run through.

## 5. Lighting

`RoundService` owns lighting: it tweens `Lighting` (ClockTime, Ambient, OutdoorAmbient) and its single `Atmosphere` between the day and night presets in `Config/Rounds`. Don't set those by hand in the place (they get overwritten); to change the look, change the presets. Fine to add Sky, Bloom, ColorCorrection and similar effects.

## 6. Scope and performance

- V1 scope is in `CLAUDE.md`: 1 stage, 1 boss, about 6 stands, a few weapons, placeholder-quality art is fine to start. Cutscenes, lots of sounds and clothing are beyond V1; ask before spending time there.
- Target: 8 players, steady frame rate on mid-range phones. Keep parts, particles and lights modest; stand fighting visuals are drawn on each client, so many heavy effects add up.

## 7. Handoff checklist (per asset)

1. Model or animation finished, named exactly as in section 2.
2. Contains no scripts.
3. Exported to `assets/<name>.rbxm` (models) and the place saved.
4. Tell the code side: name, where it goes, and the animation IDs.

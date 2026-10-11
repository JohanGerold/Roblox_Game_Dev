# Gogo Attacks: Design (2026-10-11)

Stage 1's boss becomes **Gogo, the Mountain Head Yokai** ([decision 22](../../Steal%20a%20boss%20fight/planning/decisions.md)). This spec covers his first attack set and the attack system changes it needs: player-targeted and expanding-wave attacks, per-attack parry windows, attack cooldowns, readable warnings, and asset slots for the art made by Astra ([ASSETS.md](../../ASSETS.md)). It changes the [architecture spec](2026-10-10-architecture-design.md) section 8 (boss attacks, defense) where they disagree.

## 1. Goal and success

- Players in the arena can see **where** and **when** each attack lands, on a phone.
- Every attack can be parried in its own window; dodging works as today; stepping out of a Ground Fire circle avoids it.
- Each ground marker matches the real damage area exactly.
- The fight works with placeholder visuals; Astra's models, effects and animations drop in by name with no code change.
- Adding attacks for future bosses stays data in `Config/Bosses` (project rule: content is data).

## 2. Boss config

`Boss_Lofy` keeps its id (saved data references it). Changes: `displayName = "Gogo"`, `model = "Boss_Gogo"`.

| Attack | `targeting` | Area | `windup` | `parryWindow` | `cooldown` | `damage` | `poiseOnParry` | `danger` |
|---|---|---|---|---|---|---|---|---|
| `Slam` | `Self` | `Sphere` r 14 around Gogo | 1.2 | 0.20 | 0 | 20 | 25 | no |
| `Sweep` | `Self` | `Cone` 22 studs, 120° | 1.6 | 0.20 | 0 | 35 | 25 (was 0) | no |
| `GroundFire` | `Player` | `Circle` r 7, height 10 | 1.5 | 0.35 | 6 | 30 | 15 | yes |
| `FlameWave` | `Wave` | ring from `waveStartRadius` 8 to the arena wall at `waveSpeed` 30 | 2.0 | 0.35 | 15 | 25 | 20 | yes |

- `Sweep` becomes parryable (`unparryable = false`): every Gogo attack can be parried.
- `FlameWave.activeWindow = 2.2` (long enough for the ring to reach the wall: (70 − 8) / 30 ≈ 2.07 s). Others keep their current `activeWindow` and `recovery`; GroundFire `activeWindow = 0.2`, `recovery = 0.6`; FlameWave `recovery = 1.0`.
- New attack fields: `targeting` (`"Self" | "Player" | "Wave"`), `parryWindow`, `cooldown`, `danger` (boolean), `vfx` (asset name: `"Slam"`, `"Sweep"`, `"GroundFire"`, `"FlameWave"`), `anim` (animation asset id or nil); Wave only: `waveSpeed`, `waveStartRadius`.
- New boss fields: `vfxFolder = "Gogo"`, `animations = { idle, move, stagger, death }` (asset ids or nil).
- New hitbox shape `Circle`: `{ shape = "Circle", radius, height }`: flat (XZ) distance ≤ radius and |dy| ≤ height. Jumping does not escape it.
- All numbers are first guesses for the playtest.

## 3. Choosing an attack

When Gogo is idle and his idle time has passed, the eligible attacks are:

- `Self` attacks: only while a target is within melee range (`bodyRadius + engageRange`, as today);
- `Player` and `Wave` attacks: while any living player is inside the arena and that attack's cooldown is over.

He picks one uniformly at random from the eligible list. The brain stores a ready time per attack id; starting an attack sets `readyAt = windupStart + cooldown`. Up close he mixes melee and ranged attacks; at range he only casts ranged ones.

## 4. Timing and judging (server)

- **Ground Fire:** when the warning starts, pick a uniformly random living player inside the arena; lock the centre on the ground under their root. The centre never moves. At impact, everyone whose root is inside the `Circle` at that centre is a victim and is judged at the attack's impact time.
- **Flame Wave:** the ring starts when the windup ends (`waveStart = impactTime`), radius `r(t) = waveStartRadius + waveSpeed × (t − waveStart)`, capped at the arena radius. Every server step during `Active`, each living player inside the arena who has not been reached yet is reached when `r(t) ≥` their flat distance from Gogo; that moment is their personal impact time and they are judged then. Each player is judged at most once per wave. Players outside the arena are not hit.
- **Judging:** both feed the existing pipeline (`BossService.Impact` → `CombatService` judges after `judgeDelay`): Ground Fire fires one impact with all victims, Flame Wave one per player at their own time. `DefenseJudge.judge` takes the attack's `parryWindow` (fallback `Combat.parryWindow`). Dodge i-frames and the perfect-dodge counter are unchanged. A parry applies the attack's `poiseOnParry`.
- **Brain:** `BossBrain.update` gains an input "any living player in the arena" and the per-attack ready times; the Windup → Active → Recovery cycle is unchanged.
- **Clients:** `BossAttack` gains an optional 4th argument, a table: Ground Fire `{ x, z, radius }`; Flame Wave `{ x, z, speed, startRadius, maxRadius }`. Clients compute their own wave arrival time to draw the warning.

## 5. Warnings (client, display only)

- **Where:** a ground marker matching the damage area: Slam circle, Sweep cone, Ground Fire locked circle, Flame Wave ring drawn at its true radius `r(t)`.
- **When:** for Slam, Sweep and Ground Fire an outer ring shrinks onto the marker edge, reaching it exactly at impact. For Flame Wave the approaching ring is the timing cue.
- **PARRY prompt:** during the last `parryWindow` seconds before the local player's own impact (Flame Wave: their arrival time), and only if they are in the area, show "PARRY" and their bound Parry input (default right mouse) centred on screen.
- **Danger warning:** for `danger` attacks, show 危 with a "!" symbol at warning start: to everyone in the arena for Flame Wave; to the targeted player only for Ground Fire. It means "big attack", never "can't parry".
- **Reduced effects** (`settings.fewerEffects`): skip decorative effects (Astra's `Impact` assets, debris); markers, rings, the PARRY prompt and the danger warning always show.

## 6. Asset contract (added to ASSETS.md)

- Boss model: `ReplicatedStorage.Assets.Bosses.Boss_Gogo`, about 12 studs tall, feet at y = 0, one `Model` with `PrimaryPart`, no scripts. Animations need an `Animator` (inside a `Humanoid` or `AnimationController`).
- Effects: `ReplicatedStorage.Assets.VFX.Gogo.<vfx>` (a `Folder` per attack), each optionally containing:
  - `Marker`: a flat `BasePart` (or `Model` with `PrimaryPart`); the code scales it to the attack area, places it on the ground and fades it out at impact.
  - `Impact`: a `Model` with emitters/parts; the code clones it at the impact point (Flame Wave: around the ring), enables its `ParticleEmitter`s, and removes it after 2 s.
- Animation ids go in `Config/Bosses` (`animations`, per-attack `anim`); the code plays them when present.
- Anything missing falls back to placeholder neon shapes; the fight never waits for art.

## 7. Edge cases

- Ground Fire target leaves the arena or dies during the warning: the circle stays; whoever is inside at impact is judged.
- No living player in the arena: no `Player`/`Wave` attack is eligible.
- Stagger during windup or during a Flame Wave: the attack ends (existing behaviour clears the attack); no further impacts; clients remove markers when `State` becomes `Staggered`.
- Boss death, Guard (enraged) or night (dormant): no attack starts; a wave in flight stops.
- Egg carriers are hit like anyone; boss hits do not drop eggs. Stands are never targeted.
- A player who joins mid-attack gets no warning for it; Flame Wave only judges players it has not reached.

## 8. Testing

- Unit tests (pure): `Hitbox` `Circle`; `WaveTiming.radiusAt(t, waveStart, cfg)` and `WaveTiming.arrival(distance, waveStart, cfg)`; `BossBrain` eligibility (melee only in range, ranged with anyone in the arena, cooldowns, random pick); `DefenseJudge` per-attack window; Config checks (valid `targeting`, `parryWindow > 0`, Wave fields present, `vfx` set, every attack parryable).
- Play-checks: each attack hits with no defence; parry inside each window blocks it (the Studio auto-parry hook, updated to use personal wave arrival times); leaving the Ground Fire circle avoids it; dodge works; markers match the damage areas; a stagger cancels a wave; screenshots of the warnings.

## 9. Not in this spec

Meteor, the hand clap, the domain phase and its cinematic, player versions of Gogo's moves, new armor rewards, Astra's real models/effects/animations (only the slots), renaming saved ids.

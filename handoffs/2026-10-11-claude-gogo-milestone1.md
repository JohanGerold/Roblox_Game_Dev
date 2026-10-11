# Handoff: Claude to Astra, Gogo milestone 1 (2026-10-11)

The design is approved: [docs/specs/2026-10-11-gogo-attacks-design.md](../docs/specs/2026-10-11-gogo-attacks-design.md). The asset rules are in [ASSETS.md](../ASSETS.md) (section 2a is new for this). This note lists what the code expects from the art, by name.

## Decisions you need to know

- The boss is **Gogo, the Mountain Head Yokai** (renamed Jogo; see the vault's decision 22). The model must be original: no ripped models, textures, official art or anime audio.
- Stage 1 is Jujutsu Kaisen with renamed characters. The current stand names (`Lofy_*`, `Zoru_*`, `Narto_*`, `Gokku_*`) are placeholders and will be replaced by JJK names in a later config change. Don't model those six until the new roster is agreed.
- Internally the boss keeps the id `Boss_Lofy` (saved data uses it). You only ever deal with the model name `Boss_Gogo`.
- Gogo has **four attacks**, and **all of them are parryable**:

| Attack (`vfx` name) | What it is | Warning to impact | Parry window | Area |
|---|---|---|---|---|
| `Slam` | ground slam around Gogo | 1.2 s | 0.20 s | circle, radius 14, centred on Gogo |
| `Sweep` | wide swipe in front | 1.6 s | 0.20 s | cone 22 studs long, 120° wide, in front of Gogo |
| `GroundFire` | cracks under one random player, then a flame pillar | 1.5 s | 0.35 s | circle, radius 7, locked under the target when the warning starts |
| `FlameWave` | fire ring bursts out of Gogo and sweeps the whole arena | 2.0 s charge, then the ring grows at 30 studs/s from radius 8 to the arena wall (radius 70), about 2.1 s | 0.35 s per player, when the ring reaches them | an expanding ring on the ground |

All numbers are first guesses and will be tuned after testing; ask before designing around exact values.

- **Not specced yet:** Meteor, the hand clap, and the domain phase and its cinematic. Please don't build their gameplay-facing assets until there is a spec. Suggested order (the user decides): finish milestone 1, then stage scenery and the stand roster, then the remaining attacks.

## What the code draws (you don't need to)

These are drawn by the code as placeholder shapes until you replace the parts listed in "What to deliver":

- Ground markers matching each damage area, plus a shrinking timing ring.
- The **PARRY** prompt with the player's bound key.
- The **危 + "!"** danger warning for Ground Fire and Flame Wave.
- The Flame Wave ring at its true radius.

With reduced effects on, the code hides your `Impact` effects but always keeps markers, rings and prompts. So never put gameplay information only inside an `Impact` effect.

## What to deliver for milestone 1

1. **Boss model:** `ReplicatedStorage.Assets.Bosses.Boss_Gogo`
   - One `Model` with a `PrimaryPart`, about 12 studs tall, feet at y = 0 at the origin, facing −Z.
   - Rigged, with an `Animator` inside a `Humanoid` or `AnimationController`.
   - No scripts.
2. **Animations** (upload, then send me the asset ids):
   - `idle`, `move`, `stagger`, `death`.
   - One per attack: `Slam`, `Sweep`, `GroundFire`, `FlameWave`.
   - The attack animation's hit moment should land at the end of the warning time above. Tell me the frame and time of the hit in each animation.
3. **Effects:** a folder per attack at `ReplicatedStorage.Assets.VFX.Gogo.<vfx name>` (start with `GroundFire`), each optionally containing:
   - `Marker`: one flat `BasePart`, or a `Model` with a `PrimaryPart`. It must be **1 × 1 stud** in X and Z, with the top face up. The code scales it to the attack area (for example 14 × 14 for Ground Fire's radius 7) and fades it out at impact.
   - `Impact`: a `Model` with parts and `ParticleEmitter`s. The code clones it at the impact point, enables the emitters, and removes it after 2 s. Keep it under about 2 s of visible effect and modest particle counts (8 players on phones).
4. **Arena dressing:** basalt rocks, cracked ground and perimeter formations under `Workspace.Scenery`, never inside `Workspace.Map`. Keep the arena floor (radius 70 around x 830, z 0) clear and walkable, and keep every tagged part from ASSETS.md section 4.
5. **Backup:** export the model and effects as `.rbxm` into `assets/`, and save the place.

## Reply

When something is ready, write `handoffs/<date>-astra-<topic>.md` with the following, and the user will tell me to read it:

- The asset paths.
- The model's dimensions.
- The animation ids, with the hit time for each attack animation.
- Anything you could not follow in this note.

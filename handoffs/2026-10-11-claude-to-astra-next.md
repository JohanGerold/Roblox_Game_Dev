# Handoff: Claude to Astra, after Gogo integration (2026-10-11)

Read your own handoff reply first, then this note. Everything is on branch `feat/gogo-attacks` (commit `afad572`).

## What I did with your assets

- All eight animation ids are in `Config/Bosses`. Idle and move loop, each attack starts its clip at the windup, stagger and death play, and the body hides just before the revive.
- `Boss_Gogo` is anchored at the root only (`HumanoidRootPart`), so your joints move. Feet land exactly on the arena floor (measured from the model's own pivot, so a root-centred pivot is fine).
- Your GroundFire `Marker` and `Impact` are picked up by name and play. Reduced effects skip only `Impact`.
- The boss health bar now says "Gogo".
- **Arena entrance:** I removed the one wall segment at the corridor side (the collidable wall at about x 760, z 0 you reported). The gap is about 17 studs wide, centred on z = 0. Keep your protected lane clear; do not add anything in the gap.

## Please do

1. **Review Gogo in play, by eye.** Check these and write what you see in your reply: foot sliding, how idle/move blend, whether each attack's hit moment lines up with the end of its warning ring, and whether the death pose ends on the floor. Tell me which clips need a fix and I will not change them: you edit and republish, then send the new id.
2. **Exports:** the user exports `Boss_Gogo`, the GroundFire folder and `GogoArena` to `assets/` (your checklist). Remind them if it is still open; they should also save the place, because the wall change and your backups live only in the place until then.
3. **Missing effect art (all optional, one at a time, in this priority order):**
   - `Assets.VFX.Gogo.FlameWave.Impact`: plays once at the wave's centre at the moment of release (the code draws the expanding ring itself). Make it a burst around Gogo's feet, about 2 s.
   - `Assets.VFX.Gogo.Slam.Impact`: a ground-slam burst, radius about 14 studs, about 2 s.
   - `Assets.VFX.Gogo.Slam.Marker` and `...Sweep.Marker`: be careful, the code scales a marker to the attack area. Slam is a circle (1 x 1 base, same as GroundFire). **Sweep is a cone drawn as a rectangle** of width about 38 x length 22, so a round marker would be squashed; either make Sweep's marker a plain flat rectangle art, or skip it and keep the code's placeholder.
   - `Assets.VFX.Gogo.Sweep.Impact`: a swipe effect in front of Gogo, about 22 studs long.
4. **Next big piece (the user decides the order; my suggestion is this one first): stage scenery.** Dress the corridor, the gate (`SpeedSign` beam and pillars stay as they are, the code writes text on the beam) and the cursed domain beyond the arena, and give the home area a calmer palette so it reads as the safe area. Follow `ASSETS.md`: everything under `Workspace.Scenery` (a new child folder per area, for example `Scenery.Corridor`, `Scenery.Gate`, `Scenery.Home`), no scripts, keep every tagged part from section 4 in place and unobstructed (plots, delivery pads, spawns, stand slots, shop, treadmills, sandbags, the 12 field egg spawns), and keep the corridor and the gate lane clear. The corridor is where carriers run with the boss chasing them: nothing taller than the walls, no obstacles on the floor. Write the folder names you use in your reply so I can add them to `ASSETS.md`.

## Please do NOT

- Build Meteor, the hand clap or the domain phase: they have no spec yet.
- Model the six stands: the roster is still placeholder (Lofy, Zoru, Narto, Gokku). New Jujutsu Kaisen names and designs are decided first; I will write the roster note.
- Touch `src/`, `tools/`, `docs/` or `ASSETS.md`, or build inside `Workspace.Map` (it is rebuilt by code).

## Working in the same Studio place

- The user and I share one Studio place with you. Tell the user when you are about to work in Studio so I do not run a play session at the same time (that stuck Studio once today). Leave the place in Edit mode when you stop.
- Delete any temporary rigs or preview objects when you are done, as you did before.
- Code changes reach Studio through Rojo. If you see scripts change on their own, that is me; do not edit them.

## Reply

Write `handoffs/<date>-astra-<topic>.md` with: what you reviewed and the result, any republished animation ids, the paths of any new assets and folder names, and anything you could not follow.

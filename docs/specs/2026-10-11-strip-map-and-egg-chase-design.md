# Strip Map and Egg Chase: Design (2026-10-11)

Changes to the [architecture spec](2026-10-10-architecture-design.md). Where they disagree, this file wins. Reference images: the "Steal an Egg" style layout (home plots → corridor → zones) with stage 1 restyled as a cursed domain.

## 1. Decisions

| # | Decision | Replaces |
|---|---|---|
| D1 | The map is a straight **strip**: home area with 16 plots → 500-stud corridor → cursed domain (stage 1) with the boss arena. | 16 bases in a ring around the arena |
| D2 | **Every egg is carried home**: personal rank eggs and the giant egg both drop as objects in the arena and count only when delivered to your plot's pad. | Personal eggs going straight to inventory |
| D3 | **Carry speed = your walk speed × the egg's slowdown** (`Normal 0.9`, `Top 0.8`, `Giant 0.6`). Training speed now matters while carrying. | Fixed carry speed; "carrying equalizes players" |
| D4 | **The boss guards its eggs.** 3 s after dying it revives **enraged** (can't be damaged) and chases the nearest egg carrier who is outside the home area. If it catches them: 20 damage (never lethal), the egg goes back to its spot in the arena, the boss picks a new target. | Boss simply respawning after 60 s |
| D5 | **The home area is safe.** The boss never enters it; reaching home means you can't be caught. Plot distance inside home doesn't matter for the chase. | (new) |
| D6 | A **sign at the domain gate** shows the boss's chase speed and the walk speed needed to outrun it with each egg (`chaseSpeed ÷ slowdown`, rounded up). With the starting values: Egg 23, Top Egg 25, Giant Egg 34 (boss 20 studs/s; players start at 16). | (new) |
| D7 | **One egg at a time.** To grab another, drop or deliver the one you hold. | (new) |
| D8 | **Personal eggs** can only be picked up by their owner and can't be stolen by players. An undelivered personal egg waits where it lies and vanishes after 5 min. The giant egg keeps its rules (anyone grabs, one player hit drops it, return at 3 min, gone at 5 min). | (new) |
| D9 | **No locked-zone teasers** in V1: the corridor ends at the domain. | (new) |
| D10 | **Round cycle:** Day = 4 min hunt, Night = 45 s rest. At nightfall everyone outside the home area is teleported home (carriers keep their egg and it counts as delivered), every egg left in the field vanishes, the boss resets to full HP. A countdown shows the time to the next phase. | Boss fights with no time structure |
| D11 | **Day/night is lighting on the round timer** (red-orange day, dark night). Allowed into V1 because it is a timer plus lighting, not a gameplay system. | "Day/night" in the not-in-V1 list |
| D12 | **Two egg sources per day.** (a) Boss kill: every ranked participant gets a personal egg (guaranteed reward). (b) **Field eggs** spawned in the domain at sunrise from a drop table: small eggs (count = players + 2), a 10 % chance per small egg slot to be shiny instead, a 25 % chance of an extra giant egg. Field eggs are first come, first served: anyone can grab them and a player hit makes the carrier drop them. Total eggs per day always exceed the player count. | Eggs only from boss kills |
| D13 | **8 players per server** (8 plots, 2 rows of 4). | 16-player servers, 16 bases |
| D14 | **Cross-server raids** (portal to a shared raid arena via TeleportService reserved servers and a cross-server queue) are **post-V1**; the raid boss design already supports `kind = "Raid"`. | (unchanged scope, recorded) |
| D15 | **The chase stops at night** (D10 teleports carriers home with their egg). | (new) |

## 2. Map layout (Config/Map, graybox)

Axis: the strip runs along +X. All sizes are first guesses.

- **Home area** (x 0 → 240): central path 24 studs wide; 2 rows of 4 fenced plots facing it (plot 44 × 44, 4 × 4 stand slots, `EggDeliveryPad` at the plot's path side). Spawn, weapon shop, treadmills, sandbags and a reserved spot for the fuse machine sit at the home end (x < 60). The home area is one tagged part `HomeZone` (safe zone, D5).
- **Corridor** (x 240 → 740): 500 studs, 40 wide, walled; stage gate at the far end.
- **Domain** (x 740 → 920): dark red ground, lava cracks, the arena (radius 70) with `BossSpawn` and `GiantEggSpawn`, backdrop space for the pagoda. `SpeedSign` part at the gate (D6).
- Tags stay as in the map contract, plus `HomeZone` and `SpeedSign`. `MapContract` checks them.
- Look: red sky, fog, dark ground and lava glow via Lighting/Atmosphere/materials; props from Roblox's generator (Cube) using the user's reference images. Placeholder quality, replaced later.

## 3. Eggs and the chase

- **Day / night** (new RoundService): `Day` 240 s, `Night` 45 s, from `Config/Rounds`. Sunrise spawns field eggs (D12) on tagged `FieldEggSpawn` points in the domain; nightfall does D10. Round phase and end time replicate as workspace attributes `RoundPhase`, `RoundEndsAt`.
- **Field eggs** (`Config/Eggs`): `Field_Small` (slowdown 0.95, normal-like odds), `Field_Shiny` (0.85, better odds, glowing), giant as before. Drop table in `Config/Rounds`.
- **On boss death** (LootService): each ranked participant gets a personal egg object (`Stage1_Top` or `Stage1_Normal`) placed on a ring around `GiantEggSpawn`, labelled with the owner's name; the giant egg drops after its 3 s countdown as now.
- **Carrying** (one service for all eggs, generalised from GiantEggService): ProximityPrompt pickup, weld above the head, highlight, `CarryingEgg` player attribute. Speed check uses the carrier's own allowed carry speed (walk speed × slowdown).
- **Delivery**: the owner's plot pad (giant egg: the carrier's plot). Then `EggService:Grant`. Full storage → keep carrying (as now).
- **Boss phases** (BossBrain): `Fight → Dead (3 s) → Guard`. In `Guard` the boss is invulnerable, moves at `chaseSpeed`, chases the nearest carrier outside `HomeZone`, otherwise walks back and idles in the arena. `Guard` lasts `guardSeconds` (60, the old respawn time); then the boss returns to the arena at full HP in `Fight`. Carriers are only chased during `Guard`.
- **Catch**: boss within `catchRange` (6) of a carrier → `catchDamage` (20, HP never below 1) → egg returns to its arena spot → telegraph + announcement "The boss took back <name>'s egg!".

## 4. Config additions

- `Bosses.Boss_Lofy`: `chaseSpeed = 20`, `catchRange = 6`, `catchDamage = 20`, `reviveSeconds = 3`, `guardSeconds = 60` (replaces `respawnSeconds`).
- `Eggs.*`: `carryFactor` (Normal 0.9, Top 0.8, Giant 0.6).
- `Eggs`/`GiantEgg`: `personalExpireSeconds = 300`.
- `Training.carryWalkSpeed` is removed (D3).

## 5. Not in this change

Locked zones, more stages, the fuse system and the Robux shop (separate designs), cross-server raids (D14), real art assets.

## 5a. Build split

1. **Plan A:** strip map for 8 plots, carry speed by egg size, personal eggs carried home.
2. **Plan B:** round cycle (day/night lighting, field eggs, nightfall reset).
3. **Plan C:** enraged boss chase, catch, speed sign.

## 6. Open risks

- 8 players and egg counts: tune `players + 2` small eggs and the shiny/giant chances in play tests.
- Players can wait out the 60 s guard window to carry safely. Acceptable for V1: waiting costs time and someone else may kill the boss again (a new guard window). Tune `guardSeconds` in play tests.
- 16 players carrying at once: the boss chases one at a time, so a crowd mostly escapes. Fine for V1; raid bosses can get faster chasers later.

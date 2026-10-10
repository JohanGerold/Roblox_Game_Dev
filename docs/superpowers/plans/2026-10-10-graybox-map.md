# Graybox Map Implementation Plan (Build Step 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable gray-box map (boss arena, hub plaza, 16 bases) that follows the tag contract, built by a repeatable script, plus a BaseService that gives each player a base and spawns them there.

**Architecture:** Map numbers live in `Config/Map`. A pure `MapLayout` module turns them into CFrames, and a pure `MapContract` module checks any map against the tag contract. A builder script in `tools/` (not synced by Rojo) runs once through MCP `execute_luau` and creates `Workspace.Map` from `MapLayout`. BaseService reads the map only through tags.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP (`execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`).

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (section 3 "map is not in Rojo", section 4 "Map contract (tags)" and BaseService, section 10 giant egg distances)

## Layout (top view, not to scale)

```
            boundary wall (square, ±370)
   ┌─────────────────────────────────────────┐
   │      B  B  B        16 bases on a ring  │
   │   B      hub plaza (r=140):         B   │
   │  B    Shop   Treadmills x4           B  │
   │  B       ( ARENA r=70 )              B  │
   │  B    Spawn   Sandbags x4            B  │
   │   B                                 B   │
   │      B  B  B   ring r=300, 60x60 each   │
   └─────────────────────────────────────────┘
Each base: front (-Z, LookVector) faces the arena. Delivery pad + spawn + sign at the front,
4x4 stand slots at the back, low walls on back and sides.
```

The arena border is a 3-stud wall anyone can jump over, so the egg carrier can leave in any direction and every base is the same distance from the egg (fair). The carry distance from arena edge to delivery pad is about 200 studs, roughly 15 s at `carryWalkSpeed` 14.

## Global Constraints

- The map lives in the Studio place, never in Rojo. `tools/` is **not** added to `default.project.json`.
- Code finds map pieces only through CollectionService tags plus attributes, never by name or position (spec section 4).
- Pure logic modules (`MapLayout`, `MapContract`, `BaseAssign`) never call `game:GetService`. Roblox datatypes (`CFrame`, `Vector3`) and passed-in Instances are fine.
- Every map part is `Anchored = true`. Markers (`BossSpawn`, `GiantEggSpawn`, `BaseSpawn`) are `CanCollide = false`, `Transparency = 0.6`.
- Never delete a folder Rojo watches. `Workspace.Map` is not watched, so the builder may replace it.
- One task = one commit. Commit author `Johan Gerold <johangerold385@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Studio instance: get the id with `list_roblox_studios` (it changes when Studio restarts). MCP `execute_luau` runs in its own Lua environment, so play-tests inspect Instances and attributes, not service tables.

**Test command (used by every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected on success: output ends with `FAIL 0` (currently 56 passing; each task adds to that).

## Review Focus

1. **A 17th player, or no free base** → kicked with `"This server is full, please join another one."`, no error, no base given out twice. Test in Task 4 (`BaseAssign` returns nil when full).
2. **A player leaves and another joins** → the freed base goes to the newcomer, sign and `OwnerUserId` are cleared on leave. Test in Task 4 (release then assign) plus a play-test check.
3. **Character dies or resets** → respawns at their own base, not the hub. Play-test check in Task 4.
4. **Builder run twice** → no duplicate parts, contract still reports 0 problems. Check in Task 3.
5. **The user later hand-edits the map** (replacing placeholders, forgetting a tag) → BaseService prints every contract problem as a warning and keeps running. A base missing `BaseSpawn` falls back to the hub spawn. Tests in Task 2, fallback in Task 4.

---

### Task 1: Map config and layout math

**Files:**
- Create: `src/shared/Config/Map.luau`, `src/server/Logic/MapLayout.luau`, `tests/specs/MapLayout.spec.luau`

**Interfaces:**
- Produces `Config/Map` (exact values):

```lua
return {
	stageId = "Stage1",
	baseCount = 16,
	baseRingRadius = 300,
	baseSize = 60,          -- square footprint, studs
	slotGrid = 4,           -- 4x4 = Economy.maxBaseSlots
	slotSpacing = 10,
	slotSize = 5,
	slotRowStart = 5,       -- local +Z of the first slot row (back half)
	deliveryPadOffset = 22, -- local -Z from base centre (toward arena)
	deliveryPadSize = 10,
	arenaRadius = 70,
	arenaWallHeight = 3,
	stationRadius = 140,
	stationAngles = { WeaponShop = 56.25, Treadmill = 146.25, Sandbag = 236.25, HubSpawn = 326.25 }, -- degrees
	treadmillCount = 4,
	sandbagCount = 4,
	boundaryHalfSize = 370,
}
```

- Produces `MapLayout.baseCFrames(map): { CFrame }`: base `i` sits at angle `(i-1) * 360/baseCount` degrees, radius `baseRingRadius`, Y = 0, built with `CFrame.lookAt(pos, Vector3.zero)` so `LookVector` points at the arena.
- Produces `MapLayout.slotOffsets(map): { Vector3 }`: `slotGrid^2` local offsets, index = row-major order, rows at `z = slotRowStart + (row-1)*slotSpacing`, columns centred on x = 0.
- Produces `MapLayout.stationCFrames(map): { WeaponShop: CFrame, HubSpawn: CFrame, Treadmill: { CFrame }, Sandbag: { CFrame } }`: each group centred at `stationAngles[name]`, radius `stationRadius`, facing the arena. Treadmills and sandbags are spread 8 studs apart sideways.

- [ ] **Step 1: Write `tests/specs/MapLayout.spec.luau`** with these tests (all use `require(mods.Shared.Config.Map)` and `require(mods.Logic.MapLayout)`):
  - `16 bases on the ring`: `#bases == 16`; for each, `Vector3.new(p.X, 0, p.Z).Magnitude` near 300 (tol 0.01) and `p.Y == 0`.
  - `bases face the arena`: `cf.LookVector:Dot((-cf.Position).Unit) > 0.999`.
  - `bases never overlap`: the distance between neighbours `i` and `i % 16 + 1` is `>= baseSize * math.sqrt(2)`.
  - `bases inside boundary`: `math.abs(x)` and `math.abs(z)` plus `baseSize * 0.75 <= boundaryHalfSize`.
  - `slot grid matches max slots`: `#slotOffsets == require(mods.Shared.Config.Economy).maxBaseSlots`; all offsets distinct; each `math.abs(x) + slotSize/2 <= baseSize/2`, `z - slotSize/2 >= 0` (back half), `z + slotSize/2 <= baseSize/2`.
  - `stations sit in the plaza`: every station CFrame has XZ distance from the origin `> arenaRadius + 10` and `< baseRingRadius - baseSize`; `#Treadmill == 4`, `#Sandbag == 4`.
- [ ] **Step 2:** Run the test command. Expected: the MapLayout tests FAIL (module missing).
- [ ] **Step 3:** Create `Config/Map.luau` (values above) and implement `MapLayout.luau`.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add map config and layout math`.

### Task 2: Map contract checker

**Files:**
- Create: `src/server/Logic/MapContract.luau`, `tests/specs/MapContract.spec.luau`
- Modify: `docs/specs/2026-10-10-architecture-design.md` (map contract table: add the two new tags)

**Interfaces:**
- Consumes: `Config/Map` (`baseCount`, `slotGrid`, `stageId`).
- Produces `MapContract.check(root: Instance, map): { string }`: returns a sorted list of problems, empty when valid. It walks `root:GetDescendants()` and uses `inst:HasTag(tag)`, not `GetTagged`, so it works on any folder. Rules:
  - exactly `baseCount` `Base` Models, `BaseIndex` integers `1..baseCount`, unique
  - each Base contains exactly 1 `EggDeliveryPad`, 1 `BaseSpawn`, 1 `BaseSign` (BaseParts), and `StandSlot` BaseParts with `SlotIndex` `1..slotGrid^2`, unique
  - exactly 1 `BossArena` Model with string `StageId == map.stageId`, containing exactly 1 `BossSpawn` and 1 `GiantEggSpawn`
  - at least 1 `Treadmill`, at least 1 `Sandbag`, exactly 1 `WeaponShop`
- Problem text format: `"<where>: <what>"`, for example `"Base 3: missing EggDeliveryPad"`, `"Base: duplicate BaseIndex 2"`, `"BossArena: missing GiantEggSpawn"`, `"Map: expected 1 WeaponShop, found 0"`.
- New tags (add to the spec table): `BaseSpawn` (child of a base, used by BaseService), `BaseSign` (child of a base, a part with a SurfaceGui TextLabel, used by BaseService).

- [ ] **Step 1: Write `tests/specs/MapContract.spec.luau`.** Use a local helper `makeMap(map)` that builds a minimal valid map in a new Folder: `baseCount` tagged Models, each with tagged pad, spawn, sign and `slotGrid^2` slots, plus an arena with both spawns, 1 treadmill, 1 sandbag and 1 shop. Use a test config `{ stageId = "Stage1", baseCount = 2, slotGrid = 2 }`. Destroy the folder at the end of each test. Tests:
  - `valid map has no problems`: `#check(...) == 0`
  - `missing delivery pad is reported`: destroy one pad, the problems contain `"Base 1: missing EggDeliveryPad"`
  - `duplicate base index is reported`: set base 2's `BaseIndex = 1`, the problems contain `"Base: duplicate BaseIndex 1"`
  - `missing giant egg spawn is reported`: the problems contain `"BossArena: missing GiantEggSpawn"`
  - `wrong slot count is reported`: destroy one slot, the problems contain a string starting `"Base 1: "` and mentioning `SlotIndex`
  - `missing shop is reported`: the problems contain `"Map: expected 1 WeaponShop, found 0"`
- [ ] **Step 2:** Run the test command. Expected: the MapContract tests FAIL.
- [ ] **Step 3:** Implement `MapContract.check`, then add `BaseSpawn` and `BaseSign` rows to the spec's map contract table.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Commit** `feat: add map contract checker`.

### Task 3: Build the graybox map through MCP

**Files:**
- Create: `tools/BuildGraybox.luau` (run with MCP `execute_luau`, Edit datamodel; never synced)

**Interfaces:**
- Consumes: `MapLayout.*`, `Config/Map`, `MapContract.check` (each required as `:Clone()` of the synced module, so the latest code is used).
- Produces `Workspace.Map` (Folder) with:
  - `Ground`: 740×1×740 part, top at Y = 0, Grass material, plus 4 invisible boundary walls 60 studs tall at `±boundaryHalfSize`
  - `Arena`: Model tagged `BossArena`, `StageId = "Stage1"`. It holds a dark floor disc (cylinder part, radius 70, top at Y = 0.2), a ring of 3-stud wall segments (24 segments), a `BossSpawn` marker (red, at the arena centre) and a `GiantEggSpawn` marker (yellow, 15 studs from the centre)
  - `Hub`: a `SpawnLocation` named `HubSpawn` at `stationCFrames.HubSpawn` (neutral, `Duration = 0`, the only SpawnLocation in the place). Also a `WeaponShop` part (12×8×6, tagged, with a SurfaceGui saying "WEAPONS"), 4 `Treadmill` parts (4×1×8) and 4 `Sandbag` parts (cylinder, 3×6×3), all tagged
  - `Base_01`…`Base_16`: Models tagged `Base` with `BaseIndex`. Each is pivoted to `baseCFrames[i]` and holds a 60×1×60 floor, low walls (3 studs) on the back and sides, 16 tagged `StandSlot` parts (`SlotIndex`, light blue), an `EggDeliveryPad` (green Neon, at local `(0, 0.6, -deliveryPadOffset)`), a `BaseSpawn` marker at local `(0, 3, -10)` and a `BaseSign` (14×6×1 at the front edge, with a SurfaceGui TextLabel `Text = "Free base"` facing the arena)
- At the start the builder destroys any existing `Workspace.Map`, plus `Workspace.Baseplate` and `Workspace.SpawnLocation` from the Studio template. It returns `MapContract.check(workspace.Map, map)`.

- [ ] **Step 1:** Write `tools/BuildGraybox.luau`.
- [ ] **Step 2:** Run it through MCP `execute_luau`, passing the file contents as code. Expected: it returns an empty problems list.
- [ ] **Step 3:** Run it **a second time**. Expected: still an empty list, and `#workspace.Map:GetDescendants()` is the same as after the first run (Review Focus 4).
- [ ] **Step 4:** Use `screen_capture` for a top-down view (set `workspace.CurrentCamera.CFrame` to `CFrame.lookAt(Vector3.new(0, 600, 1), Vector3.zero)` first) and show it to the user.
- [ ] **Step 5: User action:** in Studio, File → Save to Roblox (Ctrl+S); if the place has never been published, use File → Publish to Roblox. Wait for the user to confirm. The map only exists in the place file.
- [ ] **Step 6: Commit** `feat: add graybox map builder script`.

### Task 4: BaseService (assign, spawn at base, release)

**Files:**
- Create: `src/server/Logic/BaseAssign.luau`, `tests/specs/BaseAssign.spec.luau`, `src/server/Services/BaseService.luau`
- Modify: `CLAUDE.md` (Status section)

**Interfaces:**
- Consumes: `MapContract.check`, `Config/Map`, `Signal`.
- Produces `BaseAssign.lowestFree(owners: { [number]: any }, count: number): number?`, the lowest index in `1..count` with no owner, or nil.
- Produces `BaseService` (spec section 4):
  - `BaseService.Assigned: Signal`: `Fire(player, base: Model)`
  - `BaseService:GetBase(player: Player): Model?`
  - `BaseService:GetOwner(baseIndex: number): Player?`
  - `BaseService:GetSpawnCFrame(player: Player): CFrame`: the base's `BaseSpawn` CFrame + `Vector3.new(0, 3, 0)`, or the hub `SpawnLocation` CFrame if missing
  - `Init`: index `CollectionService:GetTagged("Base")` by `BaseIndex`. If `workspace:FindFirstChild("Map")` exists, `warn` each `MapContract.check` problem with the prefix `[BaseService] map: `. Never error.
  - `Start`: handle `Players.PlayerAdded` and the players already present. Assign with `lowestFree`; if nil, `player:Kick("This server is full, please join another one.")`. On assign: set the base attribute `OwnerUserId = player.UserId`, set the sign text to `player.DisplayName .. "'s base"`, fire `Assigned`, then `print("[BaseService] " .. player.Name .. " -> base " .. i)`. On `CharacterAdded` (and the current character), wait for `HumanoidRootPart` and `character:PivotTo(GetSpawnCFrame(player))`. On `PlayerRemoving`: clear the owner, set `OwnerUserId = nil`, set the sign to `"Free base"`.

- [ ] **Step 1: Write `tests/specs/BaseAssign.spec.luau`:**

```lua
expect.eq(BaseAssign.lowestFree({}, 16), 1)
expect.eq(BaseAssign.lowestFree({ [1] = true, [2] = true }, 16), 3)
expect.eq(BaseAssign.lowestFree({ [1] = true, [3] = true }, 16), 2) -- freed base is reused
local full = {}
for i = 1, 16 do full[i] = true end
expect.eq(BaseAssign.lowestFree(full, 16), nil)
```

- [ ] **Step 2:** Run the test command. Expected: the BaseAssign tests FAIL.
- [ ] **Step 3:** Implement `BaseAssign.lowestFree`, then `BaseService`.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5: Play-test.** `start_stop_play` (start), then `get_console_output`. Expected: `[BaseService] <name> -> base 1`, no `[BaseService] map:` warnings, no `[Boot]` failures. Then use `execute_luau` (server datamodel) to check that base 1 has `OwnerUserId == player.UserId`, the sign text ends with `'s base`, and the character's `HumanoidRootPart` is within 10 studs of base 1's `BaseSpawn`.
- [ ] **Step 6: Respawn check (Review Focus 3).** Use `execute_luau` to set the character's `Humanoid.Health = 0`, wait 7 s, and check it again: within 10 studs of base 1's `BaseSpawn`. Stop play.
- [ ] **Step 7: User action (optional, needs a published place):** Creator Hub → this place → Configure → set max players to 16, so Roblox itself stops a 17th join.
- [ ] **Step 8:** Update `CLAUDE.md` Status: build step 4 done on `feat/graybox-map`. Next is plan 3 (combat core, Opus medium to plan, Sonnet high to build).
- [ ] **Step 9: Commit** `feat: add BaseService base assignment and spawning`.

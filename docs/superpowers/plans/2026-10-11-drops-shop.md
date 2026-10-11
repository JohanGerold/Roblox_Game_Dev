# Drops and Weapon Shop Implementation Plan (build step 9)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boss kills can drop armor (medium chance) and moveset copies (low chance, one move each). Copied moves become usable abilities on keys 1–4. A weapon shop at home sells weapons for money, and players equip weapons and armor they own.

**Architecture:** The decisions live in three pure modules: `DropRoll` (what a participant gets), `ShopRules` (buy and equip checks) and `AbilityRules` (whether an ability may fire). `LootService` rolls drops next to the rank eggs. A new `WeaponService` handles `BuyWeapon` and `Equip`, and `CombatService` handles `UseAbility`. Move stats live in a new `Config/Moves`. On the client, a `ShopController` adds a local shop prompt and panel, and an `AbilityBarController` shows the four move slots with cooldowns.

**Tech Stack:** Luau, Roblox Studio, Rojo 7.7.1, Roblox Studio MCP.

**Spec:** [docs/specs/2026-10-10-architecture-design.md](../../specs/2026-10-10-architecture-design.md) (section 5 Bosses `drops`/`playerMoves`, Weapons, Armor; section 6 `bossMoves`, `equippedBossSet`, `armor`, `weapons`; section 7 `UseAbility`, `BuyWeapon`, `Equip`; section 8 damage formula and "Abilities"; section 9 step 3; the services table: `WeaponService`). Design notes in the vault: `Steal a boss fight/planning/decisions.md`.

## Decisions this plan makes (not in the spec)

1. **Branch:** `feat/drops-shop`, cut from `feat/stands-combat` (the stacked branches are unmerged). Do not merge.
2. **Who rolls:** every ranked participant (`LootRank.rank` output, so above the minimum damage share) rolls once for armor and once for a move copy, independently.
3. **Armor drop:** with `drops.armorChance`, a uniformly random piece from `drops.armorPieces` **that the player doesn't own** is granted. If they own every piece, nothing drops. It auto-equips when that slot is empty. Notice `"Armor drop: <displayName>!"`.
4. **Move copy:** with `drops.moveCopyChance`, `bossMoves[bossId] += 1`, unless the player already has `#playerMoves` copies (then nothing). The first copy also sets `equippedBossSet = bossId` when it is nil. Notice `"You copied <move displayName>!"`. Boss-set slots by rebirth (`extraBossSetSlotAtRebirths`) are not used in V1: there is one boss, so the set is fixed. Equipping sets comes with more bosses.
5. **Moves** (new `Config/Moves`, placeholder tuning): `Lofy_Punch` (displayName "Rubber Punch", damage 80, range 12, cooldown 4), `Lofy_Stretch` ("Stretch Strike", 60, 24, 6), `Lofy_Barrage` ("Gatling Barrage", 200, 12, 12), `Lofy_Ultimate` ("Giant Fist", 600, 16, 30). An ability hits the boss in reach like a weapon hit, through the same damage formula (`strike`). It can't hit egg carriers.
6. **Ability cooldowns** are server-checked per player per slot with `Combat.abilityCooldownTolerance = 0.2` s of slack for latency. A rejected press is silent.
7. **Shop access:** the client draws its own `ProximityPrompt` on the `WeaponShop` part (`"Shop"`, `"Weapons"`, MaxActivationDistance 10) to open the panel. The server still requires the buyer to be within `Combat.shopRange = 15` studs of the `WeaponShop` part.
8. **Equip:** `Equip("weapon", id)` and `Equip("armor", id)` need ownership. Armor goes into its own slot, replacing what's there. There is no unequip in V1.
9. **Buying** never auto-equips. The panel offers Equip right after a purchase.

## Global Constraints

- The server decides drops, purchases, equips, cooldowns and damage. Validate every argument (type, ownership, money, distance, cooldown).
- Money only changes through `EconomyService:TrySpend`; data only through `DataService:Update`.
- Pure modules (`server/Logic`) never call `game:GetService`; randomness comes in as a `Random` argument.
- Every number lives in config (`Config/Bosses`, `Config/Moves`, `Config/Weapons`, `Config/Armor`, `Config/Combat`).
- One task = one commit. Commit with `git -c user.name="Johan Gerold" -c user.email="johangerold385@gmail.com" commit`, message ending with the session's attribution line.
- MCP play-tests: temporary `Script` under `ServerScriptService` (Source in `[==[ ... ]==]`; `execute_luau`'s own `require` is a separate module copy). Log into a `StringValue` in `ServerStorage`. Patch `DataService.Get/Update` with an in-memory table, and fire `DataService.Changed` from the patch, so the real dev profile is never touched.

**Test command (every task):** MCP `execute_luau`, datamodel `Edit`:

```lua
local r = game.ServerStorage.Tests.Runner:Clone()
return require(r).run()
```

Expected: ends with `FAIL 0` (219 passing at the start).

## Review Focus

1. **An exploiter fires `BuyWeapon` from across the map, for an unknown id, an owned weapon, or without money:** refused with a Notice, and money and inventory are unchanged. Tested in Task 1 (`ShopRules.canBuy` reasons) and play-checked in Task 3 (far away).
2. **An exploiter spams `UseAbility` on a locked slot or during cooldown:** no damage. Tested in Task 1 (`AbilityRules.canUse`) and play-checked in Task 4 (two presses 1 s apart on a 4 s move → one hit).
3. **A player who already owns every armor piece or has all four copies:** no duplicate grants and no errors. Tested in Task 1 (`DropRoll` with full ownership).
4. **Money is exactly the price:** the purchase succeeds and leaves 0. One less than the price is refused. Tested in Task 1.
5. **A player leaves during the drop roll** (the boss dies while they disconnect): no error; they are skipped like the rank egg. Play-checked in Task 2 by rolling for a userId that isn't in the server.

---

### Task 1: Moves config and pure rules

**Files:**
- Create: `src/shared/Config/Moves.luau`, `src/server/Logic/DropRoll.luau`, `src/server/Logic/ShopRules.luau`, `src/server/Logic/AbilityRules.luau`, `tests/specs/DropRoll.spec.luau`, `tests/specs/ShopRules.spec.luau`, `tests/specs/AbilityRules.spec.luau`
- Modify: `src/shared/Config/Combat.luau`, `src/shared/Config/Armor.luau`, `tests/specs/Config.spec.luau`

**Interfaces:**
- `Config/Moves`: the four moves of decision 5, each `{ displayName, damage, range, cooldown }`.
- `Config/Armor.Lofy_Hat` gains `displayName = "Straw Hat"`. `Config/Weapons` entries gain `displayName` (`"Fists"`, `"Stick"`, `"Katana"`).
- `Config/Combat` gains `abilityCooldownTolerance = 0.2`, `shopRange = 15`.
- Produces `DropRoll.roll(drops, ownedArmor: { string }, copies: number, moveCount: number, rng: Random): { armorId: string?, moveCopy: boolean }`. Draw order is fixed for reproducible tests: first `rng:NextNumber()` against `armorChance`; on success pick `candidates[rng:NextInteger(1, #candidates)]` from the unowned pieces in `armorPieces` order. Then `rng:NextNumber()` against `moveCopyChance`. `moveCopy` is false when `copies ≥ moveCount`.
- Produces `ShopRules.canBuy(weaponId: string, owned: { string }, money: number, distance: number, Weapons, Combat): (boolean, string?)`. Reasons in order: `"unknown weapon"`, `"owned"`, `"too far"` (`distance > Combat.shopRange`), `"poor"` (`money < price`).
- Produces `ShopRules.canEquip(kind: string, id: string, data, Weapons, Armor): (boolean, string?)`. Reasons: `"bad kind"` (not `"weapon"`/`"armor"`), `"unknown"` (not in that config), `"not owned"`.
- Produces `AbilityRules.canUse(slot: number, setId: string?, copies: number, lastUsedAt: number?, now: number, Bosses, Moves, Combat): (boolean, string?, string?)`. Returns `true, nil, moveId` or `false, reason`. Reasons in order: `"no set"` (setId nil or not in Bosses), `"locked"` (`slot > copies`, or slot out of 1..#playerMoves), `"unknown move"` (not in Moves), `"cooldown"` (`lastUsedAt` and `now − lastUsedAt < cooldown − abilityCooldownTolerance`).

- [ ] **Step 1: Write the failing tests.**
  - `DropRoll.spec` (use a fake rng table `{ NextNumber = ..., NextInteger = ... }` returning queued values, plus one run with `Random.new(1)` for the shape): `armor drops below the chance` (NextNumber 0.1 < 0.35, NextInteger 1 → `armorId == "Lofy_Hat"`); `no armor above the chance` (0.9 → nil); `owned pieces are never dropped` (owned `{"Lofy_Hat"}`, chance roll 0.0 → nil, and NextInteger is never called); `move copy below the chance` (armor roll 0.9, move roll 0.01 < 0.05 → true); `no copy when all moves are copied` (copies 4 of 4, roll 0.0 → false); `no copy above the chance` (0.5 → false). Use the real `Bosses.Boss_Lofy.drops`.
  - `ShopRules.spec`: `buys an affordable weapon` (`Stick`, owned `{"Fists"}`, money 500, distance 5 → true); `exactly the price is enough` (500 → true; 499 → `"poor"`); `unknown weapon`; `already owned` (`Fists`); `too far` (distance 16 → `"too far"`, 15 → true); `equip owned weapon` (true); `equip unowned weapon` (`"not owned"`); `equip owned armor` (data `{ armor = { owned = {"Lofy_Hat"} } }` → true); `bad kind` (`"pet"`); `unknown id` (`"weapon", "Laser"` → `"unknown"`).
  - `AbilityRules.spec` (real `Bosses`, `Moves`, `Combat`): `no set` (nil → `"no set"`); `locked slot` (copies 1, slot 2 → `"locked"`; slot 5 → `"locked"`); `first use passes and names the move` (slot 1, copies 1, never used → true, nil, `"Lofy_Punch"`); `cooldown with tolerance` (cooldown 4: used at 10, now 13.7 → `"cooldown"`; now 13.8 → true).
  - `Config.spec`: `every boss move has stats` (each `playerMoves` id exists in `Moves` with damage > 0, range > 0, cooldown > 0); `every drop armor piece exists` (each `drops.armorPieces` id is in `Armor` with a slot and displayName); `every weapon has a display name and a price ≥ 0`; `Fists are free`.
- [ ] **Step 2:** Run the test command. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement the config and the three modules.
- [ ] **Step 4:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 5:** Commit `feat: drop, shop and ability rules`.

### Task 2: Boss drops

**Files:**
- Modify: `src/server/Services/LootService.luau`

**Interfaces:**
- Consumes `DropRoll.roll` (Task 1), `Config/Armor`, `Config/Moves`.
- In `onDefeated`, after each ranked player's egg, call `DropRoll.roll(cfg.drops, data.armor.owned, data.bossMoves[bossId] or 0, #cfg.playerMoves, rng)` (`rng` = one `Random.new()` per server). Players not in the server or without data are skipped.
  - `armorId` → `DataService:Update(player, "armor", ...)`: append it to `owned`, and set `equipped[slot] = armorId` if that slot is empty. Then Notice (decision 3).
  - `moveCopy` → `DataService:Update(player, "bossMoves", ...)` adds 1. If `equippedBossSet` is nil, also `DataService:Update(player, "equippedBossSet", function() return bossId end)`. Notice with the newly unlocked move's displayName (`Moves[cfg.playerMoves[newCopies]].displayName`).
- A boss config without `drops` rolls nothing.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (in-memory data; set `Bosses.Boss_Lofy.drops.armorChance = 1` and `moveCopyChance = 1` from the test Script, same module instance, and restore them afterwards):
  - Kill the boss → `armor.owned == {"Lofy_Hat"}`, `armor.equipped.head == "Lofy_Hat"`, `bossMoves.Boss_Lofy == 1`, `equippedBossSet == "Boss_Lofy"`, and both Notices fire.
  - Let Guard end, then kill again → no second hat, `bossMoves == 2`, Notice `"You copied Stretch Strike!"`.
  - Set copies to 4, kill → still 4, no copy Notice.
  - Set both chances to 0 → nothing granted.
  - Call `onDefeated` through `BossService.Defeated:Fire("Boss_Lofy", { [1] = 100, [player.UserId] = 100 })` (userId 1 isn't in the server) → no errors.
- [ ] **Step 4:** Commit `feat: boss kills drop armor and moveset copies`.

### Task 3: WeaponService (buy and equip)

**Files:**
- Create: `src/server/Services/WeaponService.luau`

**Interfaces:**
- Consumes `ShopRules` (Task 1), `EconomyService:TrySpend`, `DataService`, `AnnounceService:Notice`.
- `BuyWeapon(weaponId)` handler: `distance` = the root's distance to the part tagged `WeaponShop` (`math.huge` if either is missing). On `ShopRules.canBuy` success: `TrySpend(player, price)`, and only if that returns true, `Update("weapons")` to append to `owned`. Notice `"Bought <displayName>!"`. On failure, Notice per reason: `"unknown weapon"`/`"owned"` → `"You can't buy that."`, `"too far"` → `"Walk up to the weapon shop."`, `"poor"` → `"Not enough money."`.
- `Equip(kind, id)` handler: on `ShopRules.canEquip` success, `Update("weapons")` sets `equipped = id`, or `Update("armor")` sets `equipped[Armor[id].slot] = id`. Failure → Notice `"You can't equip that."`.
- Produces `WeaponService:Buy(player, weaponId): boolean` and `WeaponService:Equip(player, kind, id): boolean` (the remote handlers call these, and play-tests call them directly).

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (in-memory data with `money = 600`, weapons `{ owned = {"Fists"}, equipped = "Fists" }`):
  - Far from the shop: `Buy("Stick")` → false, `"Walk up to the weapon shop."`, money 600.
  - Teleport next to the `WeaponShop` part: `Buy("Stick")` → true, money 100, owned includes Stick. `Buy("Stick")` again → `"You can't buy that."`. `Buy("Katana")` → `"Not enough money."`. `Buy("Laser")` → `"You can't buy that."`.
  - `Equip("weapon", "Stick")` → equipped Stick. A real attack with `Attack(1, "Stick")` through the `FireRemote` hook (`"Attack|1|Stick#n"`) next to the boss deals Stick damage (18 × multipliers). `Equip("weapon", "Katana")` → refused. `Equip("armor", "Lofy_Hat")` without owning it → refused; after granting it in the fake data → equipped.
- [ ] **Step 4:** Commit `feat: weapon shop purchases and equipping`.

### Task 4: Abilities

**Files:**
- Modify: `src/server/Services/CombatService.luau`

**Interfaces:**
- Consumes `AbilityRules.canUse`, `Config/Moves` (Task 1); the existing `strike`, `bossInReach`, `aliveRoot`, `now`.
- `UseAbility(slot)` handler: `lastUsed[player][slot]` (cleared on `PlayerRemoving`). Call `AbilityRules.canUse(slot, data.equippedBossSet, data.bossMoves[set] or 0, lastUsed, now(), Bosses, Moves, Combat)`. On success, record `lastUsed = now()` **before** the reach check (a missed swing still costs the cooldown). Then if `bossInReach(root.Position, move.range + Combat.rangeTolerance)`, call `strike(player, boss, move.damage, data)`. Silent on failure.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (in-memory data with `equippedBossSet = "Boss_Lofy"`, `bossMoves = { Boss_Lofy = 1 }`, `training.power = 0`, no armor, 0 rebirths; drive the remote through the `FireRemote` hook `"UseAbility|1#n"`):
  - Next to the boss: slot 1 → boss HP −80. Slot 1 again after 1 s → no damage. Again after 4 s → −80.
  - Slot 2 (locked) → no damage.
  - Out of reach (30 studs away): slot 1 → no damage, and the cooldown is spent (a press 1 s later next to the boss → nothing).
- [ ] **Step 4:** Commit `feat: copied boss moves as abilities`.

### Task 5: Shop panel and ability bar

**Files:**
- Create: `src/client/Controllers/ShopController.luau`, `src/client/Controllers/AbilityBarController.luau`

**Interfaces:**
- Consumes the remotes `BuyWeapon`, `Equip`, `UseAbility`; `DataController` (`money`, `weapons`, `armor`, `bossMoves`, `equippedBossSet`); `InputController.Action` (`"Ability1"`…`"Ability4"`); `Widgets` (`frame`, `label`, `button`, `list`, `registerPanel`).
- `ShopController`: on start, find the part tagged `WeaponShop` (`CollectionService`, waiting for it). Create a local `ProximityPrompt` (decision 7) whose `Triggered` opens the panel registered as `"Shop"`. The panel is 380 × 360 and centred. It has one row per weapon (sorted by price): name, price, and a button that reads `Buy $<price>` (green when affordable, grey otherwise), `Equip`, or `Equipped` (disabled), plus a section `Armor` with one row per owned piece and an `Equip` / `Equipped` button. Buttons fire the remotes. The panel rebuilds when `money`, `weapons` or `armor` change.
- `AbilityBarController`: bottom-centre, 4 slots of 64 × 64 at `Position UDim2.new(0.5, (i − 2.5) × 72, 1, −80)` with `AnchorPoint (0.5, 0)`. Each slot shows its key number and the move's displayName; a locked slot shows `"Locked"` greyed out. On `Ability<i>` it fires `UseAbility(i)` when unlocked and not on local cooldown, then shows a dark overlay shrinking over `Moves[id].cooldown`. Hidden while `equippedBossSet` is nil.

- [ ] **Step 1:** Implement both controllers.
- [ ] **Step 2:** Run the test command. Expected: `FAIL 0`.
- [ ] **Step 3: Play-check** (client datamodel `execute_luau` to open panels; `screen_capture`):
  - Standing at the shop, the prompt `Shop` appears. Opening the panel shows Fists `Equipped`, Stick `Buy $500`, Katana `Buy $25,000`, coloured by your money.
  - The ability bar is hidden with no copies. After a server-side copy grant (real profile untouched: use the in-memory patch, then fire `DataChanged` for `bossMoves` and `equippedBossSet` to that client), it shows `1 Rubber Punch` and three `Locked` slots without overlapping the money HUD or the stands buttons.
  - Console has no errors.
- [ ] **Step 4:** Commit `feat: weapon shop panel and ability bar`.

### Task 6: Docs and status

**Files:**
- Modify: `CLAUDE.md` (Status), `Steal a boss fight/planning/decisions.md` (one line for decisions 2–5 and 7)

- [ ] **Step 1:** Update Status: step 9 built on `feat/drops-shop` (from `feat/stands-combat`); Next: step 10 (treadmill and rebirth; carriers' `WalkSpeed = newSpeed × carryFactor`) after the user's tests and merges. Note that move and weapon numbers are placeholders for the playtest (step 11).
- [ ] **Step 2:** Commit `docs: update status after drops and shop`.

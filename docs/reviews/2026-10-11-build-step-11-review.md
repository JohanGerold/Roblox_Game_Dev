# Build step 11: playtest and exploit review (2026-10-11)

Scope: the whole stacked branch (`feat/strip-map` through `feat/training-rebirth`, reviewed on `feat/review`). I read every client-to-server entry point (`NetSchema` c2s messages and their handlers, the egg pickup prompts) and the server loops behind them. I checked the suspected holes in Studio with temporary test scripts, and worked out the balance from the config numbers. Findings are ranked by what a player or an exploiter can actually do.

## Severity summary

| # | Finding | Severity | Status |
|---|---|---|---|
| 1 | Teleport to your pad right after grabbing an egg delivers it instantly | **Critical** | Reproduced in Studio |
| 2 | Teleport to your pad between two speed samples delivers it | **High** | Found in the code; not reproduced with a server-side simulation |
| 3 | Small servers: every participant gets the Mythic-heavy top egg on every kill | **High (balance)** | From config |
| 4 | Stand damage dwarfs the boss: one Mythic stand kills it in about 3 s | **High (balance)** | From config |
| 5 | No movement checks for players who are not carrying (speed and teleport hacks) | Medium | From code |
| 6 | Players cannot change settings (reduced effects, keybinds): the remotes have no handler | Medium (missing feature) | From code |
| 7 | Auto-parry and auto-dodge bots are possible (timing is judged on the client) | Low (accepted by design) | From code |
| 8 | Egg carriers can be hit and robbed inside the home area | Question | Design |
| 9 | Known deferred minors from the core-framework review are still open | Low | Listed in `CLAUDE.md` |

## Details

### 1. Grace-period teleport delivers any egg instantly (Critical)

`CarryCheck.step` skips the speed check during the first `speedGraceSeconds` (0.5 s) after a pickup and only records positions. `CarryService.stepCarrier` checks the delivery pad on every frame. An exploiter grabs an egg in the arena and teleports to their own pad within 0.5 s, and the egg is granted.

- **Reproduced:** a Top Egg was picked up at x 800, the character was moved to the plot 1 pad on the next frame, and the egg was granted 0.4 s later.
- **Impact:** it skips the whole carry, chase and steal loop, for personal eggs, field eggs and the giant egg.
- **Fix:** during the grace period, still run the speed check, but with an extra allowance (`Carry.speedGraceSlack = 10` studs) instead of skipping it.

### 2. One-frame teleport between speed samples (High)

`CarryCheck.step` returns `true` without checking whenever less than `speedSampleSeconds` (0.25 s) passed since the last sample. The pad check runs right after it on the same frame. A teleport to the pad that lands between two samples is therefore accepted and delivered. My server-side simulation was dropped by the speed check instead (it likely landed on sample frames, and the client owns the character's physics), so this one is from reading the code.

- **Fix:** on every frame, check the distance from the last sample against `(speed + tolerance) × elapsed + slack`. Only the update of the sample itself waits for `speedSampleSeconds`.
- **Tests:** "a teleport between samples is caught" and "a teleport during the grace period is caught" in `CarryCheck.spec`.

### 3. Top eggs for everyone in small servers (High, balance)

`LootRank` gives `Stage1_Top` (90% Mythic, 10% Celestial) to ranks 1–3. With 1–3 players every participant is always top 3, so every kill hands everyone a Mythic or better stand. With 8 players, 3 of 8 get one.

- **Options (for you to decide):**
  - Give top eggs only to a fraction of the participants (for example the top 30%, at least 1).
  - Or make the top egg's odds depend on rank.
  - Or require a minimum damage share for a top egg.

### 4. Stand damage overwhelms the boss (High, balance)

Boss HP is 5,000 (+1,500 per extra player).

| Damage source | Damage per second | Solo kill time |
|---|---|---|
| Stand, Common | 1 | — |
| Stand, Rare | 6 | — |
| Stand, Epic | 30 | — |
| Stand, Legendary | 180 | about 28 s |
| Stand, Mythic | 1,500 | about 3 s |
| Stand, Celestial | 15,000 | about 0.3 s |
| A fresh player with Fists | about 33 | about 150 s |
| Katana | about 200 | about 25 s |

With finding 3, the first kill gives a Mythic, and from then on every fight is a few seconds long. The 60 s enraged guard becomes the only real time gate.

- **Options:**
  - Lower `Combat.standDamageFactor` (for example 0.05 makes a Mythic 75 DPS, close to a Katana).
  - Or scale boss HP with the participants' total stand power.
  - Or both.

  These are config changes; the playtest numbers should decide.

### 5. No movement checks outside carrying (Medium)

Characters' physics belong to the client, so a cheater can change their own speed or teleport. Carriers are protected by `CarryCheck`. Everyone else can:
- reach field eggs first;
- teleport next to a carrier to hit them and drop their egg;
- teleport into training or shop range.

They cannot gain money, eggs or stands directly. A light server-side movement check for everyone (the same speed rule as `CarryCheck`, with a generous allowance, and a teleport back on violation) would close most of this. I'd suggest it as a follow-up task.

### 6. Settings cannot be changed (Medium, missing feature)

`SetSetting` and `SetKeybinds` are validated, but no service handles them, and there is no settings UI. Reduced effects (`settings.fewerEffects`) and rebindable keys are read by the client but can never be changed. The V1 scope lists rebindable controls. This needs a small `SettingsService` (validate the key, value and action names) and a settings panel.

### 7. Auto-parry and auto-dodge bots (Low, accepted)

By design, parry and dodge timing are claimed by the client and only checked for plausibility (freshness, cooldowns). `BossAttack` tells every client the impact time, so a script can parry every attack perfectly. A later mitigation could flag accounts with near-100% parry success. No change is proposed now.

### 8. Robbing carriers at home (Question)

The boss never enters home, but player hits on egg carriers work everywhere, so a carrier can be hit and robbed next to their own pad. Decide whether home should also be safe from player hits. If yes, `CombatService` should skip carriers inside `HomeZone`.

### 9. Deferred minors still open (Low)

From the core-framework review:
- handler-less remotes unvalidated;
- `Format.number(nil)`;
- `Loaded` firing before `DataInit` (order);
- `loadPlayer` not wrapped in pcall;
- save-version downgrade;
- small `Net` leaks;
- `Update` key and NaN checks;
- a `DataService` boot failure not kicking.

None of these is exploitable for gain. They should be cleaned up before launch (step 14).

## Checked and fine

| Handler | Checks |
|---|---|
| `Attack` | combo order and pace, equipped weapon, reach; damage from server data |
| `UseAbility` | unlock, cooldown with slack, reach |
| `Counter` | needs a server-recorded perfect dodge |
| `Defend` | claim age, future tolerance, cooldown |
| `HatchEgg` | own egg, ready time, inventory cap |
| `PlaceStand` | own stand, slot in range and unlocked |
| `UpgradeStand` | own stand, max level, money via `TrySpend` |
| `SetTeam` | list shape, ownership, duplicates, slot count |
| `BuyWeapon` / `Equip` | price, ownership, 15-stud shop distance |
| `Train` | station distance re-checked every second, not while carrying |
| `Rebirth` | money |
| Egg pickup prompts | server-side distance re-check, owner check for personal eggs, one egg at a time |

- **Malformed and spam calls:** all c2s messages are type-checked by `NetSchema`, rate-limited, and 50 malformed calls in 10 s kick the player.
- **Money:** it only moves through the income tick, `TrySpend` and rebirth. Offline earnings use server time.
- **Test hooks:** the Studio-only ones do nothing in live servers, and `RoundService:SkipPhase` is server-only.

## Proposed fix pass

1. Fix findings 1 and 2 in `CarryCheck` with failing tests first (Sonnet high).
2. Balance (3, 4): you choose the options, then I change config and tests.
3. Follow-ups as their own tasks: movement checks (5), settings (6), the home-safety decision (8), and the minors (9) in step 14.

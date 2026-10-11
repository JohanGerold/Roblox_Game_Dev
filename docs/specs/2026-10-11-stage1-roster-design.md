# Stage 1 Roster: Design (2026-10-11)

Stage 1 (the cursed domain, boss **Gogo**) uses Jujutsu Kaisen characters with changed names ([decision 1](../../Steal%20a%20boss%20fight/planning/decisions.md), [decision 22](../../Steal%20a%20boss%20fight/planning/decisions.md)). This note fixes the stand roster for stage 1 and records the agreed plan for later stages. It replaces the placeholder roster (`Lofy`, `Zoru`, `Narto`, `Gokku`).

## 1. Stage 1 stands (16)

| Rarity | Stand (renamed) | Original | Id | Role |
|---|---|---|---|---|
| Common | Yuju Itadore | Yuji | `Yuju_Base` | damage |
| Common | Kasumo Miwo | Miwa | `Miwo_Base` | damage |
| Rare | Nobaru Kugisake | Nobara | `Nobaru_Base` | damage |
| Rare | Momo Nishimiye | Momo | `Momo_Base` | damage |
| Rare | Pando | Panda | `Pando_Base` | damage |
| Epic | Megumu Fushigoro | Megumi | `Megumu_Base` | damage |
| Epic | Mai Zenim | Mai | `Mai_Base` | damage |
| Epic | Noritoshe Kamo | Kamo | `Kamo_Base` | damage |
| Epic | Togi Inumako | Inumaki | `Inumako_Base` | damage |
| Legendary | Mechamaro | Mechamaru | `Mechamaro_Base` | damage |
| Legendary | Masamachi Yago | Yaga | `Yago_Base` | damage |
| Legendary | Utahame Iori | Utahime | `Utahame_Base` | **team buffer** |
| Legendary | Hanamo | Hanami (flower cursed spirit) | `Hanamo_Base` | **healer** |
| Mythic | Aoi Toudo | Todo | `Toudo_Base` | damage |
| Mythic | Gakugonji | Gakuganji | `Gakugonji_Base` | damage |
| Celestial | Satoro Gojou (blindfolded) | Gojo | `Gojou_Blindfold` | damage |

- **Family** (for ascension later) is the character's name (for example `Gojou`). Gojo's eyes-revealed form is a later family member, not in stage 1.
- **Stats** stay per rarity, as today: income / power per second at level 1:

| Rarity | Income | Power |
|---|---|---|
| Common | 1 | 1 |
| Rare | 8 | 6 |
| Epic | 40 | 30 |
| Legendary | 250 | 180 |
| Mythic | 2,000 | 1,500 |
| Celestial | 20,000 | 15,000 |

  Stand damage is scaled by `Combat.standDamageFactor` (0.05). The egg odds and the "every egg rarity has a stand" rule are unchanged.
- **Roles:** Utahime (buffer) and Hanami (healer) deal normal stand damage until their role mechanics are designed. That gets its own spec: what the buff does, how healing works, and how both scale with level and copies.
- **Not in stage 1:** Gojo with his eyes revealed, Sukuna, Hakari and Yuta (final stage).
- **Placeholder models:** each stand is a placeholder block until Astra delivers `Assets.Characters.<model>`. The model name equals the id.

## 2. Saves: renaming the old ids

Saved stands store ids, so the placeholder ids are migrated once, by rarity, when a save loads. `DataTemplate.CURRENT_VERSION` goes from 1 to 2, with a migration in `Logic/Migrations`.

| Old id | New id |
|---|---|
| `Lofy_Base` (Common) | `Yuju_Base` |
| `Zoru_Base` (Rare) | `Nobaru_Base` |
| `Narto_Base` (Epic) | `Megumu_Base` |
| `Gokku_Base` (Legendary) | `Mechamaro_Base` |
| `Gokku_Red` (Mythic) | `Toudo_Base` |
| `Gokku_Blue` (Celestial) | `Gojou_Blindfold` |

Level, slot and team membership are kept. Unknown ids are left as they are, and the game already ignores stands whose id is not in config.

## 3. Other One Piece leftovers to rename (same follow-up)

- **Boss moves** copied from Gogo still have One Piece names: `Lofy_Punch` "Rubber Punch", `Lofy_Stretch`, `Lofy_Barrage`, `Lofy_Ultimate` "Giant Fist". They become Gogo-themed volcanic moves. Names are to be agreed; saved copies are counted per boss, so no save change is needed beyond the move ids in config.
- **Armor:** `Lofy_Hat` "Straw Hat" becomes a Gogo piece. Its id is saved in `armor.owned` and `armor.equipped`, so it is part of the same migration.

## 4. Later stages (roadmap, not V1)

Decided in principle; each stage gets its own design when its time comes.

- **Progression:** a set number of rebirths moves the player to a new **dimension**. They start over in the next stage, with new bosses, new stands and stronger versions of stands. What carries over between dimensions is open.
- **Stage 2:** boss **Mahito**, with the **Shibuya** cast.
- **Stage 3 (final):** boss **Sukuna**, with the final-form cast, including **Hakari** (with the copy-based luck passive below) and **Yuta**.
- **Hakari's luck passive (stage 3):** one copy gives a passive that randomly auto-dodges one boss attack. Max copies guarantee 3 dodges and 1 revive. "Copies", the per-fight versus per-life reset, and the numbers are designed with stage 3.

## 5. Asset handoff (for Astra)

Model the stage 1 stands at `ReplicatedStorage.Assets.Characters.<id>`, one per row in section 1, following `ASSETS.md` section 2. About 3 × 5 × 2 studs, script-free, original designs (no ripped art). Start with one stand as the size and rig reference. Utahime and Hanami need no special effects until their role spec exists.

## 6. Open points

1. **Gogo's move names and the armor piece** (section 3).
2. **Role mechanics** for Utahime and Hanami (own spec).

# Handoff: Claude to Astra, stage 1 roster (2026-10-12)

Stage 1 stands are decided and now in config (`src/shared/Config/Characters.luau`). Full design: `docs/specs/2026-10-11-stage1-roster-design.md`. Theme: Jujutsu Kaisen with **renamed** characters (same approach as Gogo): original designs that read as the character's archetype, no ripped art, no official logos.

## What to build

16 stands. Each is one `Model` at `ReplicatedStorage.Assets.Characters.<Model name>` (rules in `ASSETS.md` section 2: `PrimaryPart`, script-free, about 3 x 5 x 2 studs).

| Rarity | Model name | Stand | Archetype to read as |
|---|---|---|---|
| Common | `Yuju_Base` | Yuju Itadore | spiky-haired school fighter, dark uniform |
| Common | `Miwo_Base` | Kasumo Miwo | shy girl in school uniform, sword on her belt |
| Rare | `Nobaru_Base` | Nobaru Kugisake | short-haired girl, hammer and nails |
| Rare | `Momo_Base` | Momo Nishimiye | witch on a broom, long ponytail |
| Rare | `Pando_Base` | Pando | tall, round panda-like fighter (original design, not a plush) |
| Epic | `Megumu_Base` | Megumu Fushigoro | dark spiky hair, calm, hands in a summoning pose |
| Epic | `Mai_Base` | Mai Zenim | glasses, side ponytail, holds a pistol |
| Epic | `Kamo_Base` | Noritoshe Kamo | noble in dark robes, long hair, blood-red accents |
| Epic | `Inumako_Base` | Togi Inumako | high collar covering the mouth, pale hair, snake-eye marks |
| Legendary | `Mechamaro_Base` | Mechamaro | sleek puppet-body robot |
| Legendary | `Yago_Base` | Masamachi Yago | stern older teacher, sunglasses, puppet-maker |
| Legendary | `Utahame_Base` | Utahame Iori | teacher in a kimono, support / **team buffer** |
| Legendary | `Hanamo_Base` | Hanamo | flower-headed cursed spirit, **healer** |
| Mythic | `Toudo_Base` | Aoi Toudo | huge, muscular, bandaged, clapping pose |
| Mythic | `Gakugonji_Base` | Gakugonji | elderly principal, imposing, guitar |
| Celestial | `Gojou_Blindfold` | Satoro Gojou | tall, white hair, black blindfold, confident pose |

Higher rarities can look more impressive (more detail, aura-ready), but rarity effects and auras come from code, not from the model. Celestial/Mythic models are the ones the player will brag about, so spend polish there.

## How to start

1. **One stand first**, as the size and rig reference: build `Yuju_Base`, export it, and tell me. I will check it in play (placement on the base slot, scale, the lunge when it fights) before you do the other 15.
2. Then the rest in rarity order, a few at a time. Missing models are fine: the game draws a placeholder block and warns once, so deliver them one by one.
3. Walk animations: `Walk_Default` for Common to Legendary, `Walk_Serious` for Mythic and Celestial are already named in config. Make them later if you have time; they are not needed for the first pass.

## Not needed now

- No special effects for Utahame or Hanamo yet. Their buff and heal mechanics need their own spec. A model is enough.
- No eyes-revealed Gojou, Sukuna, Hakari or Yuta: those are later stages.

## Gogo-side renames (code only, FYI)

Gogo's four copyable moves are now `Magma Fist`, `Ember Lash`, `Cinder Barrage`, `Eruption`, and the armor drop is the `Ash Crown` (head slot). There is no art slot for them yet; if you want to make an Ash Crown model, tell me and I will add the hook.

## Reminder

Export each model to `assets/<Model name>.rbxm` and save the place (the user does this), then tell me the model names that are done.

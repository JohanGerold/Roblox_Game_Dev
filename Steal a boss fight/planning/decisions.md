---
title: Decisions Log
date: 2026-10-09
tags: [planning, decisions]
---

# Decisions Log

## 1. Anime characters with changed names

- **Decision (2026-10-09):** use anime characters with altered names (e.g. "Lofy" for Luffy), as many Roblox games do.
- **Reasoning:** Blox Fruits has dominated for years without a lawsuit.
- **Risk noted:** still copyright infringement under the Roblox Terms. Risk grows with success; a takedown would remove the game and its earnings. Blox Fruits is *inspired by* One Piece but uses its own characters, which is safer than renamed lookalikes.
- **Rules to follow:** never use ripped models, official art, logos or anime audio. Make all models and sounds ourselves or license them.

## 2. Spell Heist rejected

- **Decision (2026-10-09):** don't build the Perplexity report's "Spell Heist".
- **Reasoning:** the audience is kids who want big numbers, cool powers and flashy effects; spellbooks and complex systems don't deliver that.

## 3. Shared normal eggs + one giant stealable egg

- **Decision (2026-10-09):** every fighter gets a personal egg that can't be stolen; one giant egg with the best odds is contested.
- **Reasoning:** avoids power creep at the boss, keeps the steal hook. See [The Big Egg](../design/big-egg.md).

## 4. Abilities from copies instead of playing as the boss

- **Decision (2026-10-09):** copies unlock the boss's abilities on your own character. See [Boss Abilities and Copies](../design/boss-abilities-and-copies.md).
- **Reasoning:** much cheaper to build; full-mastery aura keeps the fantasy.

## 5. One boss ability set equipped at a time

- **Decision (2026-10-09):** more slots via rebirth or a game pass.

## 6. Combat starts simple — superseded

- **Decision (2026-10-09):** V1 has one generous dodge; parry and perfect-dodge come later.
- **Superseded 2026-10-10** by decision 9.

## 7. Rojo + git for code

- **Decision (2026-10-10):** code lives in files in `src/`, synced into Studio by Rojo, versioned with git. The map is built in Studio.
- **Reasoning:** full history and rollback, especially with an AI making large changes.

## 8. Drops: armor medium, moveset low, one move per copy; weapons bought

- **Decision (2026-10-10):** normal bosses drop armor/clothing (medium chance, power boost) and moveset copies (low chance, one move each). Players start with punch/kick and buy weapons (physical and magical, unique movesets) so unlucky players still progress. See [Weapons and Gear](../design/weapons-and-gear.md).

## 9. Dodge and parry are core

- **Decision (2026-10-10):** perfect dodge gives i-frames and a counter; parry builds poise; poise break makes the boss kneel, stop attacking and take 2× damage (normal bosses recover medium, raid bosses fast). See [Combat](../design/combat.md).

## 10. Raid bosses are 16-player server fights

- **Decision (2026-10-10):** major-villain raid bosses every 45 min, built for about 16 players.

## 11. 16-player servers, raids in the same server

- **Decision (2026-10-10):** every server holds 16 players with 16 bases; raids happen in that same server.
- **Reasoning:** one place and one map, easy to test in Studio; no cross-server matchmaking or teleports.

## 12. Code structure: services and controllers

- **Decision (2026-10-10):** plain ModuleScript services (server) and controllers (client), content in config modules, ProfileStore for saving, a small `Net` module for remotes. Knit and ECS rejected.

## 13. 12 rarity tiers with auras from Mythic

- **Decision (2026-10-10):** Common → Absolute; still aura at Mythic, animated aura + impact frames above. See [Rarities and Auras](../design/rarities-and-auras.md).

## 14. Forms are separate characters; original final forms where needed

- **Decision (2026-10-10):** each form is its own fixed-rarity character linked as a family (ascension later). Characters with one canon final form get original final forms.

## 15. Training and stand upgrades

- **Decision (2026-10-10):** treadmill = speed, sandbags = power; stands shadowbox at base to earn and can be upgraded for more money and power.

## 16. Offline earnings in V1

- **Decision (2026-10-10):** players earn money while offline: money/s × time away, capped (~8 h) at a reduced rate (~50%). Return reason for players who play after school/college.

## 17. Rebindable controls and combat mode

- **Decision (2026-10-10):** every action rebindable (keyboard, mouse, controller), saved in player data; movable phone buttons. Defaults: left-click attack, right-click parry, Left Shift dodge, 1–4 abilities, **Ctrl toggles combat mode** (cursor locked + camera follows mouse) vs cursor mode (free cursor for UI). Roblox Shift Lock disabled.
- **Tested 2026-10-10:** Roblox does not detect mouse side buttons (Mouse 4/5). Workaround: remap the side button to a key in mouse software.

## 18. Rank-based personal eggs

- **Decision (2026-10-10):** after a boss dies, participants are ranked by damage (including their stands). **Ranks 1–3** get an egg that rolls **Mythic or higher**; **rank 4 to last** get an egg that rolls **Legendary or lower**. Minimum damage share required to count as a participant.
- Mythic must stay common within the top egg and higher tiers very rare, or Mythic+ inflates. The giant egg remains every player's chance at top tiers regardless of rank.

## 19. Stand team: 3 slots, more by rebirth

- **Decision (2026-10-10):** up to 3 stands fight beside you; rebirth unlocks more slots. Server computes stand damage; stands are drawn on each client and can't be hit.

- **Build step 8 choices (2026-10-11):** stands deal damage once a second only while their owner is in the arena, alive and not carrying an egg, and only while the boss is in a normal fight; rebirth damage bonus applies to stands; every player sees every fighting team (placeholder blocks).

- **Build step 9 choices (2026-10-11):** every ranked participant rolls for armor (never a piece they own) and for a moveset copy; copied moves are abilities on keys 1-4 with server-checked cooldowns; the weapon shop needs you within 15 studs; buying never auto-equips; boss-set slots by rebirth wait for a second boss.

## 20. Raid rewards only on kill

- **Decision (2026-10-10):** if the raid boss isn't defeated, nobody gets any reward.

## 21. Strip map and egg chase (2026-10-11)

Full table in the [design spec](../../docs/specs/2026-10-11-strip-map-and-egg-chase-design.md); where it disagrees with earlier decisions, the spec wins.

- **D1** Straight strip map: home with plots, 500-stud corridor, cursed domain with the arena.
- **D2** Every egg is carried home, personal rank eggs included (delivered to your plot's pad).
- **D3** Carry speed = your walk speed x the egg's slowdown (Normal 0.9, Top 0.8, Giant 0.6).
- **D4** The boss revives enraged 3 s after dying and chases the nearest carrier outside home; a catch costs 20 HP (never lethal) and sends the egg back (Plan C).
- **Plan C choices:** the revived boss starts a fresh fight after its 60 s guard (full HP, empty damage list); every carrier outside home is chased, nearest first; the boss never enters home and routes through the gate; the gate sign lists every egg (Field 22, Egg 23, Shiny 24, Top 25, Giant 34).
- **D5** The home area is safe; the boss never enters.
- **D6** A sign at the domain gate shows the speed needed to outrun the boss with each egg (Plan C).
- **D7** One egg at a time.
- **D8** Personal eggs: only the owner picks them up, can't be stolen, vanish after 5 min. The giant egg keeps its steal rules.
- **D9** No locked-zone teasers in V1.
- **D10** Round cycle: 4 min day, 45 s night; nightfall teleports everyone home, field eggs vanish, boss resets (Plan B).
- **Plan B choices:** at nightfall a carrier whose storage is full keeps the egg at home; uncarried eggs lying outside home vanish (inside home they stay); the boss is dormant (full HP, no attacks, no damage) at night; field giant eggs have no countdown or banner.
- **D11** Day/night is lighting on the round timer, allowed into V1.
- **D12** Two egg sources a day: boss-kill personal eggs and field eggs (Plan B).
- **D13** 8 players per server, 8 plots.
- **D14** Cross-server raids are post-V1.
- **D15** The chase stops at night.

## 22. Stage 1 is Jujutsu Kaisen, boss Gogo

- **Decision (2026-10-11):** stage 1 (the cursed domain) uses Jujutsu Kaisen characters with changed names, per decision 1. The boss is **Gogo, the Mountain Head Yokai** (renamed Jogo): volcanic, single-eye design, original model.
- The current placeholder names (`Boss_Lofy`, `Lofy_*`, `Zoru_*`, `Narto_*`, `Gokku_*`) were only examples from decision 1 and get replaced by stage 1 names. Saved ids stay stable: the boss keeps id `Boss_Lofy` until a data migration renames it; only `model`, `displayName` and moves change.
- Visual production is done by a second AI (Astra) following [ASSETS.md](../../ASSETS.md); code by Claude.

Related: [Open Questions](open-questions.md), [Game Concept](../design/game-concept.md)

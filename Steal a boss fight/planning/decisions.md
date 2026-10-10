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

Related: [Open Questions](open-questions.md), [Game Concept](../design/game-concept.md)

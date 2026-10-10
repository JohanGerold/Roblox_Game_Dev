---
title: Rarities and Auras
date: 2026-10-10
tags: [design, collectibles, visuals]
aliases: [Rarity Tiers]
---

# Rarities and Auras

## 12 tiers (colors from the user's reference)

| # | Tier | Color | Aura |
|---|---|---|---|
| 1 | Common | grey | none |
| 2 | Uncommon | green | none |
| 3 | Rare | blue | none |
| 4 | Epic | purple | none |
| 5 | Legendary | orange | none |
| 6 | Mythic | pink-red | still aura in the tier color |
| 7 | Celestial | cyan | animated aura + impact frames |
| 8 | Divine | gold | animated, stronger |
| 9 | Transcendent | pink | animated, stronger |
| 10 | Primordial | lavender | animated, stronger |
| 11 | Omniversal | magenta | animated, stronger |
| 12 | Absolute | red | strongest animated aura + impact frames |

From Mythic up, the name color "becomes" the aura. Exact hex values live in `Config/Rarities`.

## Forms (decided: option A)

- **Each form is its own character with a fixed rarity.** Example: Goku (Red) = Mythic, Goku (Blue) = Celestial, Goku (MUI) = Absolute, each with its own model, aura, walk animation and impact-frame moveset.
- Forms are linked as a **family** in config so **ascension** (evolving one form into the next) can be added later.
- **Characters with only one final form in their anime get original, non-anime final forms** designed by us.
- High-tier characters look serious and in final forms: animated hair, special walk animation, impact-frame moves.

## Performance

Every player gets a "fewer effects" setting; 16 players' animated auras must not lag phones.

Related: [Stands](stands.md), [Spectacle and YouTube](spectacle-and-youtube.md), [Decisions Log](../planning/decisions.md)

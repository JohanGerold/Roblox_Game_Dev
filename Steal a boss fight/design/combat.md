---
title: Combat
date: 2026-10-10
tags: [design, combat]
---

# Combat

You fight **alongside** your [stands](stands.md): they auto-fight the boss while you attack, dodge and parry.

## Your attacks

- **Start:** a basic punch-and-kick combo.
- **Weapons** bought with money: from a stick up to OP anime weapons, physical and magical. See [Weapons and Gear](weapons-and-gear.md). Each weapon has its own moveset, so a player with bad drop luck still has strong options.
- **Boss moves** unlocked from boss moveset drops, one move per copy. See [Boss Abilities and Copies](boss-abilities-and-copies.md).

## Dodge (Wuthering Waves style)

- Dodging gives **i-frames** (brief invulnerability).
- A **perfect dodge** (dodging right as an attack lands) triggers a **cool counter move** that does moderate damage. This rewards dodging instead of tanking.

## Parry (Sekiro style)

- Parrying attacks builds **poise damage** on the boss.
- When poise breaks, the boss enters a **vulnerable state**:
  - it stops attacking and kneels on one leg,
  - it takes **2× damage**,
  - it won't attack until it recovers.
- **Recovery time:** normal bosses medium, raid bosses quick.

## Netcode reality

Most players are on phones and have lag. Tight timing windows feel unfair over the network, so dodge and parry windows are judged on the player's own client and the server checks they're plausible (timing and distance) before applying results. See the architecture spec for details.

## Later

- PvP (planned after launch).

Related: [Weapons and Gear](weapons-and-gear.md), [Boss Abilities and Copies](boss-abilities-and-copies.md), [Raids and Events](raids-and-events.md), [Decisions Log](../planning/decisions.md)

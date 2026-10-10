---
title: Combat
date: 2026-10-09
tags: [design, combat]
---

# Combat

## Vision

- Stands fight for you; you dodge, parry and use boss abilities.
- Dodge inspired by Wuthering Waves (perfect-dodge feel), parry inspired by Sekiro.

## Reality check

- Most Roblox players are kids on phones.
- Network lag makes tight timing windows feel unfair; good parry needs client-side prediction with server validation. That's weeks of work for one mechanic, and hard for a first project.

## Plan

| Phase | Combat |
|---|---|
| V1 | Stands auto-fight. Player has **one dodge with a generous window** and equipped boss abilities. |
| Later | Perfect-dodge bonus (slow-mo, counter) in the Wuthering Waves style. |
| Later | Sekiro-style parry. |
| Later | PvP arena. |

## Server authority

The server decides damage, drops and who holds the [giant egg](big-egg.md). The client only sends inputs and shows effects. Exploiters target these games heavily.

Related: [Boss Abilities and Copies](boss-abilities-and-copies.md), [Stands](stands.md), [V1 Scope and Build Order](../planning/v1-scope.md)

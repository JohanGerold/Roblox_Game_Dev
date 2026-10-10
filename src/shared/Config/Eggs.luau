-- odds: rarity -> weight. Stage1_Top is the rank 1-3 egg, Stage1_Normal is rank 4+,
-- Stage1_Giant is the stealable giant egg.
return {
	Stage1_Normal = { hatchSeconds = 30, odds = { Common = 60, Rare = 25, Epic = 12, Legendary = 3 } },
	Stage1_Top = { hatchSeconds = 60, odds = { Mythic = 90, Celestial = 10 } },
	Stage1_Giant = { hatchSeconds = 120, odds = { Legendary = 40, Mythic = 45, Celestial = 15 } },
}

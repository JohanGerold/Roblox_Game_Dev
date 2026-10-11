-- odds: rarity -> weight. Stage1_Top is the rank 1-3 egg, Stage1_Normal is rank 4+,
-- Stage1_Giant is the stealable giant egg.
-- carryFactor: carrying speed = walk speed x carryFactor. color: the egg object and carry highlight.
return {
	Stage1_Normal = {
		displayName = "Egg",
		hatchSeconds = 30,
		carryFactor = 0.9,
		color = Color3.fromRGB(235, 235, 235),
		odds = { Common = 60, Rare = 25, Epic = 12, Legendary = 3 },
	},
	Stage1_Top = {
		displayName = "Top Egg",
		hatchSeconds = 60,
		carryFactor = 0.8,
		color = Color3.fromRGB(170, 90, 255),
		odds = { Mythic = 90, Celestial = 10 },
	},
	Stage1_Giant = {
		displayName = "Giant Egg",
		hatchSeconds = 120,
		carryFactor = 0.6,
		color = Color3.fromRGB(255, 205, 60),
		odds = { Legendary = 40, Mythic = 45, Celestial = 15 },
	},
}

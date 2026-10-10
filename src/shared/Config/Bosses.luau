-- Boss attacks: windup/activeWindow in seconds. Moves unlock one per copy (playerMoves order).
return {
	Boss_Lofy = {
		kind = "Stage",
		stageId = "Stage1",
		model = "Boss_Lofy",
		maxHp = 5000,
		hpPerExtraPlayer = 1500,
		maxPoise = 100,
		poiseRegen = 5,
		poiseRegenDelay = 4,
		staggerSeconds = 5,
		bodyRadius = 5,
		moveSpeed = 10,
		engageRange = 12,
		idleSeconds = 1.0,
		emptyResetSeconds = 30,
		respawnSeconds = 60,
		attacks = {
			{ id = "Slam", windup = 1.2, activeWindow = 0.2, damage = 20, hitbox = { shape = "Sphere", radius = 14 }, poiseOnParry = 25, unparryable = false, recovery = 0.8 },
			{ id = "Sweep", windup = 1.6, activeWindow = 0.3, damage = 35, hitbox = { shape = "Cone", range = 22, angle = 120 }, poiseOnParry = 0, unparryable = true, recovery = 1.0 },
		},
		playerMoves = { "Lofy_Punch", "Lofy_Stretch", "Lofy_Barrage", "Lofy_Ultimate" },
		drops = { armorChance = 0.35, armorPieces = { "Lofy_Hat" }, moveCopyChance = 0.05 },
	},
}

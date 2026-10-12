-- Boss attacks: windup/activeWindow in seconds. Moves unlock one per copy (playerMoves order).
-- Attack fields: targeting (Self = shape around the boss, Player = circle locked under a random arena player,
-- Wave = ring growing from the boss), parryWindow (s), cooldown (s before it can be chosen again), danger (show
-- the big-attack warning), vfx (asset name under Assets.VFX.<vfxFolder>), anim (animation asset id or nil).
-- Wave only: waveSpeed (studs/s) and waveStartRadius (studs). Boss_Lofy is Gogo, the stage 1 boss (the id stays
-- because saves reference it).
return {
	Boss_Lofy = {
		kind = "Stage",
		stageId = "Stage1",
		displayName = "Gogo",
		model = "Boss_Gogo",
		vfxFolder = "Gogo",
		animations = { idle = 108978809514872, move = 114241903539291, stagger = 101874204015161, death = 124931594858775 }, -- published by Astra
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
		chaseSpeed = 20, -- enraged Guard phase: studs/s while chasing a carrier
		catchRange = 6, -- studs from the body surface
		catchDamage = 20, -- never lethal (HP stays at 1 or more)
		reviveSeconds = 3, -- dead -> enraged Guard
		guardSeconds = 60, -- length of the Guard phase
		attacks = {
			{ id = "Slam", targeting = "Self", windup = 1.2, activeWindow = 0.2, damage = 20, hitbox = { shape = "Sphere", radius = 14 }, parryWindow = 0.20, cooldown = 0, poiseOnParry = 25, unparryable = false, danger = false, vfx = "Slam", anim = 117319311380375, recovery = 0.8 },
			{ id = "Sweep", targeting = "Self", windup = 1.6, activeWindow = 0.3, damage = 35, hitbox = { shape = "Cone", range = 22, angle = 120 }, parryWindow = 0.20, cooldown = 0, poiseOnParry = 25, unparryable = false, danger = false, vfx = "Sweep", anim = 109594147926968, recovery = 1.0 },
			{ id = "GroundFire", targeting = "Player", windup = 1.5, activeWindow = 0.2, damage = 30, hitbox = { shape = "Circle", radius = 7, height = 10 }, parryWindow = 0.35, cooldown = 6, poiseOnParry = 15, unparryable = false, danger = true, vfx = "GroundFire", anim = 107992856701130, recovery = 0.6 },
			{ id = "FlameWave", targeting = "Wave", windup = 2.0, activeWindow = 2.2, damage = 25, hitbox = { shape = "Circle", radius = 70, height = 10 }, waveSpeed = 30, waveStartRadius = 8, parryWindow = 0.35, cooldown = 15, poiseOnParry = 20, unparryable = false, danger = true, vfx = "FlameWave", anim = 108385541643382, recovery = 1.0 },
		},
		rankEggs = { top = "Stage1_Top", normal = "Stage1_Normal", topCount = 3, topFraction = 0.3 },
		playerMoves = { "Gogo_MagmaFist", "Gogo_EmberLash", "Gogo_CinderBarrage", "Gogo_Eruption" },
		drops = { armorChance = 0.35, armorPieces = { "Gogo_AshCrown" }, moveCopyChance = 0.05 },
	},
}

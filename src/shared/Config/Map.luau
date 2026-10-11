-- Map sizes in studs. The strip runs along +X: home (plots + stations) -> corridor -> cursed domain.
-- Base local axes: -Z faces the path (front, delivery pad side), +Z is the back.
return {
	stageId = "Stage1",
	baseCount = 8, -- plots, 2 rows of plotsPerRow
	plotsPerRow = 4,
	baseSize = 44, -- square footprint
	plotFirstX = 82.5, -- X of the first plot in each row
	plotSpacing = 45, -- X gap between plot centres
	plotRowOffset = 36, -- |Z| of the plot rows
	slotGrid = 4, -- 4x4 = Economy.maxBaseSlots
	slotSpacing = 6,
	slotSize = 5,
	slotRowStart = 0, -- local +Z of the first slot row
	deliveryPadOffset = 15, -- local -Z from base centre (toward the path)
	deliveryPadSize = 10,
	pathWidth = 24,
	home = { minX = 0, maxX = 240, halfWidth = 60 },
	corridor = { minX = 240, maxX = 740, halfWidth = 20 },
	domain = { minX = 740, maxX = 920, halfWidth = 90 },
	arenaCenter = Vector3.new(830, 0, 0),
	arenaRadius = 70,
	arenaWallHeight = 3,
	giantEggOffset = Vector3.new(-30, 0, 0), -- from the arena centre
	fieldEggRingRadius = 50,
	fieldEggSpawnCount = 12,
	stations = {
		HubSpawn = Vector3.new(16, 0, 0),
		WeaponShop = Vector3.new(40, 0, -34),
		FuseMachine = Vector3.new(14, 0, -34),
		Treadmill = Vector3.new(40, 0, 34),
		Sandbag = Vector3.new(14, 0, 34),
	},
	stationSpread = 6, -- X gap between treadmills / sandbags
	treadmillCount = 4,
	sandbagCount = 4,
	wallHeight = 60,
}

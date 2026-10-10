-- Map sizes in studs. Base local axes: -Z faces the arena (front), +Z is the back.
return {
	stageId = "Stage1",
	baseCount = 16,
	baseRingRadius = 300,
	baseSize = 60, -- square footprint
	slotGrid = 4, -- 4x4 = Economy.maxBaseSlots
	slotSpacing = 7,
	slotSize = 5,
	slotRowStart = 5, -- local +Z of the first slot row (back half)
	deliveryPadOffset = 22, -- local -Z from base centre (toward the arena)
	deliveryPadSize = 10,
	arenaRadius = 70,
	arenaWallHeight = 3,
	stationRadius = 140,
	stationAngles = { WeaponShop = 56.25, Treadmill = 146.25, Sandbag = 236.25, HubSpawn = 326.25 }, -- degrees
	stationSpread = 8, -- sideways gap between treadmills / sandbags
	treadmillCount = 4,
	sandbagCount = 4,
	boundaryHalfSize = 370,
}

-- Pure layout math for the graybox map. Takes the Config/Map table, returns CFrames.
local MapLayout = {}

-- Face the path (the X axis) from a point.
local function facingPath(pos: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(pos.X, 0, 0))
end

function MapLayout.plotCFrames(map): { CFrame }
	local result = {}
	for i = 1, map.baseCount do
		local col = (i - 1) % map.plotsPerRow
		local z = if i <= map.plotsPerRow then -map.plotRowOffset else map.plotRowOffset
		result[i] = facingPath(Vector3.new(map.plotFirstX + col * map.plotSpacing, 0, z))
	end
	return result
end

-- Local offsets from a base's centre, row-major (SlotIndex order).
function MapLayout.slotOffsets(map): { Vector3 }
	local result = {}
	local n = map.slotGrid
	for row = 1, n do
		for col = 1, n do
			local x = (col - (n + 1) / 2) * map.slotSpacing
			local z = map.slotRowStart + (row - 1) * map.slotSpacing
			table.insert(result, Vector3.new(x, 0, z))
		end
	end
	return result
end

-- A station on the centre line (|z| < 1) faces +X; the others face the path.
local function stationCFrame(pos: Vector3): CFrame
	if math.abs(pos.Z) < 1 then
		return CFrame.lookAt(pos, pos + Vector3.xAxis)
	end
	return facingPath(pos)
end

local function row(center: CFrame, count: number, spread: number): { CFrame }
	local result = {}
	for i = 1, count do
		result[i] = center * CFrame.new((i - (count + 1) / 2) * spread, 0, 0)
	end
	return result
end

function MapLayout.stationCFrames(map)
	local s = map.stations
	return {
		HubSpawn = stationCFrame(s.HubSpawn),
		WeaponShop = stationCFrame(s.WeaponShop),
		FuseMachine = stationCFrame(s.FuseMachine),
		Treadmill = row(stationCFrame(s.Treadmill), map.treadmillCount, map.stationSpread),
		Sandbag = row(stationCFrame(s.Sandbag), map.sandbagCount, map.stationSpread),
	}
end

-- Evenly spaced points on a circle around the arena centre, first at angle 0.
function MapLayout.fieldEggSpawns(map): { Vector3 }
	local result = {}
	local n = map.fieldEggSpawnCount
	for i = 1, n do
		local a = (i - 1) * 2 * math.pi / n
		table.insert(result, map.arenaCenter + Vector3.new(map.fieldEggRingRadius * math.cos(a), 0, map.fieldEggRingRadius * math.sin(a)))
	end
	return result
end

return MapLayout

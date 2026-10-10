-- Pure layout math for the graybox map. Takes the Config/Map table, returns CFrames.
local MapLayout = {}

local function onRing(radius: number, degrees: number): CFrame
	local rad = math.rad(degrees)
	local pos = Vector3.new(radius * math.cos(rad), 0, radius * math.sin(rad))
	return CFrame.lookAt(pos, Vector3.zero)
end

function MapLayout.baseCFrames(map): { CFrame }
	local result = {}
	for i = 1, map.baseCount do
		result[i] = onRing(map.baseRingRadius, (i - 1) * 360 / map.baseCount)
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

local function row(center: CFrame, count: number, spread: number): { CFrame }
	local result = {}
	for i = 1, count do
		result[i] = center * CFrame.new((i - (count + 1) / 2) * spread, 0, 0)
	end
	return result
end

function MapLayout.stationCFrames(map)
	local a, r = map.stationAngles, map.stationRadius
	return {
		WeaponShop = onRing(r, a.WeaponShop),
		HubSpawn = onRing(r, a.HubSpawn),
		Treadmill = row(onRing(r, a.Treadmill), map.treadmillCount, map.stationSpread),
		Sandbag = row(onRing(r, a.Sandbag), map.sandbagCount, map.stationSpread),
	}
end

return MapLayout

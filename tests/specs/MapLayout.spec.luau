local function load(mods)
	return require(mods.Shared.Config.Map), require(mods.Logic.MapLayout)
end

local function flat(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

return {
	["16 bases on the ring"] = function(expect, mods)
		local map, Layout = load(mods)
		local bases = Layout.baseCFrames(map)
		expect.eq(#bases, 16)
		for i, cf in bases do
			expect.near(flat(cf.Position), 300, 0.01, "base " .. i)
			expect.eq(cf.Position.Y, 0, "base " .. i)
		end
	end,
	["bases face the arena"] = function(expect, mods)
		local map, Layout = load(mods)
		for i, cf in Layout.baseCFrames(map) do
			expect.truthy(cf.LookVector:Dot((-cf.Position).Unit) > 0.999, "base " .. i)
		end
	end,
	["bases never overlap"] = function(expect, mods)
		local map, Layout = load(mods)
		local bases = Layout.baseCFrames(map)
		for i = 1, #bases do
			local nextBase = bases[i % #bases + 1]
			local gap = (bases[i].Position - nextBase.Position).Magnitude
			expect.truthy(gap >= map.baseSize * math.sqrt(2), "base " .. i .. " too close to its neighbour")
		end
	end,
	["bases inside boundary"] = function(expect, mods)
		local map, Layout = load(mods)
		for i, cf in Layout.baseCFrames(map) do
			expect.truthy(math.abs(cf.Position.X) + map.baseSize * 0.75 <= map.boundaryHalfSize, "base " .. i .. " X")
			expect.truthy(math.abs(cf.Position.Z) + map.baseSize * 0.75 <= map.boundaryHalfSize, "base " .. i .. " Z")
		end
	end,
	["slot grid matches max slots"] = function(expect, mods)
		local map, Layout = load(mods)
		local offsets = Layout.slotOffsets(map)
		expect.eq(#offsets, require(mods.Shared.Config.Economy).maxBaseSlots)
		local seen = {}
		for i, o in offsets do
			local key = o.X .. "," .. o.Z
			expect.truthy(not seen[key], "slot " .. i .. " duplicates another")
			seen[key] = true
			expect.truthy(math.abs(o.X) + map.slotSize / 2 <= map.baseSize / 2, "slot " .. i .. " sideways")
			expect.truthy(o.Z - map.slotSize / 2 >= 0, "slot " .. i .. " not in back half")
			expect.truthy(o.Z + map.slotSize / 2 <= map.baseSize / 2, "slot " .. i .. " past back edge")
		end
	end,
	["stations sit in the plaza"] = function(expect, mods)
		local map, Layout = load(mods)
		local st = Layout.stationCFrames(map)
		local function inPlaza(cf, name)
			local d = flat(cf.Position)
			expect.truthy(d > map.arenaRadius + 10, name .. " too close to the arena")
			expect.truthy(d < map.baseRingRadius - map.baseSize, name .. " too close to the bases")
		end
		inPlaza(st.WeaponShop, "WeaponShop")
		inPlaza(st.HubSpawn, "HubSpawn")
		expect.eq(#st.Treadmill, 4)
		expect.eq(#st.Sandbag, 4)
		for i, cf in st.Treadmill do
			inPlaza(cf, "Treadmill " .. i)
		end
		for i, cf in st.Sandbag do
			inPlaza(cf, "Sandbag " .. i)
		end
	end,
}

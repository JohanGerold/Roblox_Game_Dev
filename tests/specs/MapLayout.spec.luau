local function load(mods)
	return require(mods.Shared.Config.Map), require(mods.Logic.MapLayout)
end

local function flat(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

return {
	["8 plots in two rows facing the path"] = function(expect, mods)
		local map, Layout = load(mods)
		local plots = Layout.plotCFrames(map)
		expect.eq(#plots, 8)
		for i, cf in plots do
			local z = cf.Position.Z
			expect.near(z, i <= 4 and -36 or 36, 0.01, "plot " .. i .. " row")
			expect.eq(cf.Position.Y, 0, "plot " .. i)
			expect.truthy(cf.LookVector:Dot(Vector3.new(0, 0, -math.sign(z))) > 0.999, "plot " .. i .. " facing")
		end
	end,
	["plots inside home and clear of the path"] = function(expect, mods)
		local map, Layout = load(mods)
		for i, cf in Layout.plotCFrames(map) do
			local half = map.baseSize / 2
			local x, z = cf.Position.X, math.abs(cf.Position.Z)
			expect.truthy(x - half >= map.home.minX and x + half <= map.home.maxX, "plot " .. i .. " X")
			expect.truthy(z + half <= map.home.halfWidth, "plot " .. i .. " outer edge")
			expect.truthy(z - half >= map.pathWidth / 2, "plot " .. i .. " path edge")
		end
	end,
	["plots never overlap"] = function(expect, mods)
		local map, Layout = load(mods)
		local plots = Layout.plotCFrames(map)
		for _, first in { 1, 5 } do
			for i = first, first + 2 do
				local gap = plots[i + 1].Position.X - plots[i].Position.X
				expect.truthy(gap >= map.baseSize, "plot " .. i .. " too close to its neighbour")
			end
		end
	end,
	["slot grid fits behind the pad"] = function(expect, mods)
		local map, Layout = load(mods)
		local offsets = Layout.slotOffsets(map)
		expect.eq(#offsets, require(mods.Shared.Config.Economy).maxBaseSlots)
		local seen = {}
		for i, o in offsets do
			local key = o.X .. "," .. o.Z
			expect.truthy(not seen[key], "slot " .. i .. " duplicates another")
			seen[key] = true
			expect.truthy(math.abs(o.X) + map.slotSize / 2 <= map.baseSize / 2, "slot " .. i .. " sideways")
			expect.truthy(o.Z + map.slotSize / 2 <= map.baseSize / 2, "slot " .. i .. " past back edge")
			expect.truthy(o.Z - map.slotSize / 2 > -map.deliveryPadOffset + map.deliveryPadSize / 2, "slot " .. i .. " on the pad")
		end
	end,
	["stations sit at the home end"] = function(expect, mods)
		local map, Layout = load(mods)
		local st = Layout.stationCFrames(map)
		local function atHomeEnd(cf, name)
			local p = cf.Position
			expect.truthy(p.X < map.plotFirstX - map.baseSize / 2, name .. " too close to the plots")
			expect.truthy(p.X >= map.home.minX, name .. " outside home")
			expect.truthy(math.abs(p.Z) < map.home.halfWidth, name .. " outside home width")
		end
		atHomeEnd(st.WeaponShop, "WeaponShop")
		atHomeEnd(st.HubSpawn, "HubSpawn")
		atHomeEnd(st.FuseMachine, "FuseMachine")
		expect.eq(#st.Treadmill, 4)
		expect.eq(#st.Sandbag, 4)
		for i, cf in st.Treadmill do
			atHomeEnd(cf, "Treadmill " .. i)
		end
		for i, cf in st.Sandbag do
			atHomeEnd(cf, "Sandbag " .. i)
		end
		expect.truthy(st.HubSpawn.LookVector:Dot(Vector3.xAxis) > 0.99, "HubSpawn faces +X")
	end,
	["arena inside the domain"] = function(expect, mods)
		local map = load(mods)
		expect.truthy(map.arenaCenter.X - map.arenaRadius >= map.domain.minX, "arena west edge")
		expect.truthy(map.arenaCenter.X + map.arenaRadius <= map.domain.maxX, "arena east edge")
		expect.truthy(map.arenaRadius <= map.domain.halfWidth, "arena width")
	end,
	["field egg spawns inside the arena, clear of spawns"] = function(expect, mods)
		local map, Layout = load(mods)
		local spawns = Layout.fieldEggSpawns(map)
		expect.eq(#spawns, 12)
		local giant = map.arenaCenter + map.giantEggOffset
		for i, p in spawns do
			expect.truthy(flat(p - map.arenaCenter) <= map.arenaRadius - 5, "spawn " .. i .. " too near the wall")
			expect.truthy(flat(p - map.arenaCenter) >= 10, "spawn " .. i .. " too close to the boss")
			expect.truthy(flat(p - giant) >= 10, "spawn " .. i .. " too close to the giant egg")
		end
	end,
	["zones line up"] = function(expect, mods)
		local map = load(mods)
		expect.eq(map.home.maxX, map.corridor.minX)
		expect.eq(map.corridor.maxX, map.domain.minX)
		expect.eq(map.corridor.maxX - map.corridor.minX, 500)
	end,
}

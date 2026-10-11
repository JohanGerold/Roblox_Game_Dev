local ATTACK = { waveStartRadius = 8, waveSpeed = 30 }

local function load(mods)
	return require(mods.Shared.Util.WaveTiming)
end

return {
	["radius grows from the start radius"] = function(expect, mods)
		local Wave = load(mods)
		expect.near(Wave.radiusAt(10, 10, ATTACK, 70), 8, 1e-9)
		expect.near(Wave.radiusAt(11, 10, ATTACK, 70), 38, 1e-9)
		expect.near(Wave.radiusAt(15, 10, ATTACK, 70), 70, 1e-9, "capped at the arena wall")
	end,
	["before the start it is the start radius"] = function(expect, mods)
		local Wave = load(mods)
		expect.near(Wave.radiusAt(9, 10, ATTACK, 70), 8, 1e-9)
	end,
	["arrival inside the start radius is immediate"] = function(expect, mods)
		local Wave = load(mods)
		expect.near(Wave.arrival(5, 10, ATTACK), 10, 1e-9)
	end,
	["arrival further out"] = function(expect, mods)
		local Wave = load(mods)
		expect.near(Wave.arrival(68, 10, ATTACK), 12, 1e-9)
	end,
}

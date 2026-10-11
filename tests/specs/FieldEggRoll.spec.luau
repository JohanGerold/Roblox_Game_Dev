local function load(mods)
	return require(mods.Logic.FieldEggRoll), require(mods.Shared.Config.Rounds).fieldEggs
end

local function with(cfg, overrides)
	local c = table.clone(cfg)
	for k, v in overrides do
		c[k] = v
	end
	return c
end

local function count(list, eggId)
	local n = 0
	for _, e in list do
		if e.eggId == eggId then
			n += 1
		end
	end
	return n
end

return {
	["3 players, no giant, no shiny"] = function(expect, mods)
		local Roll, cfg = load(mods)
		local result = Roll.roll(3, 12, with(cfg, { giantChance = 0, shinyChance = 0 }), Random.new(1))
		expect.eq(#result, 5)
		expect.eq(count(result, "Field_Small"), 5)
	end,
	["giant rolled comes first"] = function(expect, mods)
		local Roll, cfg = load(mods)
		local result = Roll.roll(3, 12, with(cfg, { giantChance = 1, shinyChance = 0 }), Random.new(1))
		expect.eq(#result, 6)
		expect.eq(result[1].eggId, "Stage1_Giant")
		expect.eq(count(result, "Field_Small"), 5)
	end,
	["all shiny"] = function(expect, mods)
		local Roll, cfg = load(mods)
		local result = Roll.roll(3, 12, with(cfg, { giantChance = 0, shinyChance = 1 }), Random.new(1))
		expect.eq(count(result, "Field_Shiny"), 5)
	end,
	["capped by spawn points"] = function(expect, mods)
		local Roll, cfg = load(mods)
		expect.eq(#Roll.roll(8, 12, with(cfg, { giantChance = 1 }), Random.new(1)), 11)
		expect.eq(#Roll.roll(14, 12, with(cfg, { giantChance = 1 }), Random.new(1)), 12)
		expect.eq(#Roll.roll(8, 6, with(cfg, { giantChance = 0 }), Random.new(1)), 6)
	end,
	["unique spawn indices in range"] = function(expect, mods)
		local Roll, cfg = load(mods)
		for seed = 1, 20 do
			local seen = {}
			for _, e in Roll.roll(8, 12, cfg, Random.new(seed)) do
				expect.truthy(e.spawnIndex >= 1 and e.spawnIndex <= 12, "seed " .. seed .. " range")
				expect.truthy(not seen[e.spawnIndex], "seed " .. seed .. " duplicate index")
				seen[e.spawnIndex] = true
			end
		end
	end,
	["no spawn points"] = function(expect, mods)
		local Roll, cfg = load(mods)
		expect.eq(#Roll.roll(3, 0, with(cfg, { giantChance = 1 }), Random.new(1)), 0)
	end,
	["zero players still spawns the extras"] = function(expect, mods)
		local Roll, cfg = load(mods)
		expect.eq(#Roll.roll(0, 12, with(cfg, { giantChance = 0 }), Random.new(1)), 2)
	end,
}

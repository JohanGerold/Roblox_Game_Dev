local function load(mods)
	return require(mods.Logic.EggRules), require(mods.Shared.Config.Economy)
end

return {
	["canReceive allows up to the cap"] = function(expect, mods)
		local EggRules, Economy = load(mods)
		expect.truthy(EggRules.canReceive(49, Economy))
		expect.eq(EggRules.canReceive(50, Economy), false)
	end,
	["canHatch rejects a missing egg"] = function(expect, mods)
		local EggRules, Economy = load(mods)
		local ok, reason = EggRules.canHatch(nil, 100, 0, Economy)
		expect.eq(ok, false)
		expect.eq(reason, "no egg")
	end,
	["canHatch rejects an egg that is not ready"] = function(expect, mods)
		local EggRules, Economy = load(mods)
		local ok, reason = EggRules.canHatch({ readyAt = 100 }, 99, 0, Economy)
		expect.eq(ok, false)
		expect.eq(reason, "not ready")
	end,
	["canHatch rejects a full inventory"] = function(expect, mods)
		local EggRules, Economy = load(mods)
		local ok, reason = EggRules.canHatch({ readyAt = 100 }, 100, 200, Economy)
		expect.eq(ok, false)
		expect.eq(reason, "inventory full")
	end,
	["canHatch accepts a ready egg with room"] = function(expect, mods)
		local EggRules, Economy = load(mods)
		local ok = EggRules.canHatch({ readyAt = 100 }, 100, 199, Economy)
		expect.truthy(ok)
	end,
}

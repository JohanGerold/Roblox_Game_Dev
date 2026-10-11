local function load(mods)
	return require(mods.Logic.RoundRules), require(mods.Shared.Config.Rounds)
end

return {
	["phases alternate"] = function(expect, mods)
		local Rules = load(mods)
		expect.eq(Rules.nextPhase("Day"), "Night")
		expect.eq(Rules.nextPhase("Night"), "Day")
	end,
	["durations come from the config"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.duration("Day", cfg), 240)
		expect.eq(Rules.duration("Night", cfg), 45)
	end,
	["an unknown phase errors"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq((pcall(Rules.nextPhase, "Dusk")), false)
		expect.eq((pcall(Rules.duration, "Dusk", cfg)), false)
	end,
}

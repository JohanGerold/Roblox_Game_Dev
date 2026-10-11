local function load(mods)
	return require(mods.Logic.TrainingRules), require(mods.Shared.Config.Training)
end

return {
	["walk speed starts at base"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.walkSpeed(0, cfg), 16)
	end,
	["one point is one stud per second"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.walkSpeed(10, cfg), 26)
	end,
	["walk speed is capped"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.walkSpeed(500, cfg), 60)
	end,
	["a negative stat counts as zero"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.walkSpeed(-5, cfg), 16)
	end,
	["canTrain gives the first failing reason"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local _, kind = Rules.canTrain("Bench", 1, false, true, cfg)
		expect.eq(kind, "bad kind")
		local _, dead = Rules.canTrain("Treadmill", 1, false, false, cfg)
		expect.eq(dead, "dead")
		local _, carrying = Rules.canTrain("Treadmill", 1, true, true, cfg)
		expect.eq(carrying, "carrying")
		local _, far = Rules.canTrain("Treadmill", 7, false, true, cfg)
		expect.eq(far, "too far")
		expect.eq((Rules.canTrain("Treadmill", 6, false, true, cfg)), true)
		expect.eq((Rules.canTrain("Sandbag", 0, false, true, cfg)), true)
	end,
	["stat and rate per kind"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.statFor("Treadmill"), "speed")
		expect.eq(Rules.statFor("Sandbag"), "power")
		expect.eq(Rules.rateFor("Treadmill", cfg), 0.05)
		expect.eq(Rules.rateFor("Sandbag", cfg), 0.05)
	end,
}

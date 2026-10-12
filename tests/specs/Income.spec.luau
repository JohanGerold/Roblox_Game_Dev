local function load(mods)
	return require(mods.Shared.Util.Income),
		require(mods.Shared.Config.Characters),
		require(mods.Shared.Config.Economy),
		require(mods.Shared.Config.Progression)
end

return {
	["standIncome scales per level"] = function(expect, mods)
		local Income, Characters, Economy = load(mods)
		expect.near(Income.standIncome("Yuju_Base", 1, Characters, Economy), 1, 1e-9)
		expect.near(Income.standIncome("Yuju_Base", 3, Characters, Economy), 1.8225, 1e-9)
		expect.eq(Income.standIncome("Nope", 1, Characters, Economy), 0)
	end,
	["perSecond counts placed stands only"] = function(expect, mods)
		local Income, Characters, Economy, Progression = load(mods)
		local stands = {
			a = { id = "Yuju_Base", level = 1, slot = 1 },
			b = { id = "Nobaru_Base", level = 2, slot = 2 },
			c = { id = "Megumu_Base", level = 1, slot = nil },
			d = { id = "Unknown", level = 1, slot = 3 },
		}
		expect.near(Income.perSecond(stands, 0, Characters, Economy, Progression), 11.8, 1e-9)
		expect.near(Income.perSecond(stands, 2, Characters, Economy, Progression), 23.6, 1e-9)
	end,
	["offline earnings use the rate and the cap"] = function(expect, mods)
		local Income, _, Economy = load(mods)
		local now = 1000000
		local amount, seconds = Income.offline(10, now, now - 3600, Economy)
		expect.eq(amount, 18000)
		expect.eq(seconds, 3600)
		amount, seconds = Income.offline(10, now, now - 86400, Economy)
		expect.eq(amount, 144000)
		expect.eq(seconds, 28800)
	end,
	["offline earnings ignore first join and future lastSeen"] = function(expect, mods)
		local Income, _, Economy = load(mods)
		local now = 1000000
		local amount, seconds = Income.offline(10, now, 0, Economy)
		expect.eq(amount, 0)
		expect.eq(seconds, 0)
		amount, seconds = Income.offline(10, now, now + 60, Economy)
		expect.eq(amount, 0)
		expect.eq(seconds, 0)
	end,
	["upgradeCost grows with level and income"] = function(expect, mods)
		local Income, Characters, Economy = load(mods)
		expect.eq(Income.upgradeCost("Yuju_Base", 1, Characters, Economy), 100)
		expect.eq(Income.upgradeCost("Yuju_Base", 2, Characters, Economy), 160)
		expect.eq(Income.upgradeCost("Nobaru_Base", 1, Characters, Economy), 800)
	end,
	["upgradeCost is nil at max level or for unknown stands"] = function(expect, mods)
		local Income, Characters, Economy = load(mods)
		expect.eq(Income.upgradeCost("Yuju_Base", Economy.standMaxLevel, Characters, Economy), nil)
		expect.eq(Income.upgradeCost("Nope", 1, Characters, Economy), nil)
	end,
}

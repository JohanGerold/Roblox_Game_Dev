local function load(mods)
	return require(mods.Logic.RebirthRules), require(mods.Shared.Config.Progression)
end

return {
	["cost grows with each rebirth"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq(Rules.cost(0, cfg), 1000000)
		expect.eq(Rules.cost(1, cfg), 5000000)
		expect.eq(Rules.cost(2, cfg), 25000000)
	end,
	["exactly the cost is enough, one less is not"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq((Rules.canRebirth(1000000, 0, cfg)), true)
		local ok, reason = Rules.canRebirth(999999, 0, cfg)
		expect.eq(ok, false)
		expect.eq(reason, "poor")
	end,
	["apply resets only what it should"] = function(expect, mods)
		local Rules = load(mods)
		local data = {
			money = 5000000,
			rebirths = 1,
			training = { speed = 12, power = 3 },
			characters = { c1 = { id = "Nobaru_Base", level = 7, slot = 2 }, c2 = { id = "Yuju_Base", level = 3 } },
		}
		local result = Rules.apply(data)
		expect.eq(result.money, 0)
		expect.eq(result.rebirths, 2)
		expect.eq(result.training.speed, 0)
		expect.eq(result.training.power, 0)
		expect.eq(result.characters.c1.level, 1)
		expect.eq(result.characters.c1.slot, 2)
		expect.eq(result.characters.c1.id, "Nobaru_Base")
		expect.eq(result.characters.c2.level, 1)
		expect.eq(result.characters.c2.slot, nil)
		expect.eq(data.characters.c1.level, 7, "input untouched")
		expect.eq(data.money, 5000000, "input untouched")
	end,
	["apply returns exactly the four reset keys"] = function(expect, mods)
		local Rules = load(mods)
		local result = Rules.apply({ money = 1, rebirths = 0, training = { speed = 1, power = 1 }, characters = {}, eggs = { e = 1 } })
		local keys = {}
		for key in result do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect.eq(table.concat(keys, ","), "characters,money,rebirths,training")
	end,
}

local function load(mods)
	return require(mods.Logic.Odds), require(mods.Logic.EggRoll), require(mods.Shared.Config.Characters),
		require(mods.Shared.Config.Eggs), require(mods.Shared.Config.Rarities)
end

return {
	["pick with a single key always returns it"] = function(expect, mods)
		local Odds = load(mods)
		local rng = Random.new(1)
		for _ = 1, 20 do
			expect.eq(Odds.pick({ only = 5 }, rng), "only")
		end
	end,
	["pick errors on empty or all-zero weights"] = function(expect, mods)
		local Odds = load(mods)
		expect.errors(function() Odds.pick({}, Random.new(1)) end)
		expect.errors(function() Odds.pick({ a = 0, b = 0 }, Random.new(1)) end)
	end,
	["pick distribution is within 2 percent over 100k rolls"] = function(expect, mods)
		local Odds = load(mods)
		local rng, a = Random.new(42), 0
		for _ = 1, 100000 do
			if Odds.pick({ a = 75, b = 25 }, rng) == "a" then a += 1 end
		end
		expect.near(a / 100000, 0.75, 0.02)
	end,
	["pick is deterministic for a given seed"] = function(expect, mods)
		local Odds = load(mods)
		local w = { a = 1, b = 1, c = 1, d = 1 }
		local r1, r2 = Random.new(7), Random.new(7)
		for _ = 1, 50 do
			expect.eq(Odds.pick(w, r1), Odds.pick(w, r2))
		end
	end,
	["egg roll returns a character of an allowed rarity"] = function(expect, mods)
		local _, EggRoll, Characters, Eggs, Rarities = load(mods)
		local rng = Random.new(3)
		for _ = 1, 1000 do
			local id = EggRoll.roll(Eggs.Stage1_Top, Characters, rng)
			expect.truthy(Rarities.byName[Characters[id].rarity].index >= 6, id)
		end
	end,
	["egg roll skips rarities with no characters"] = function(expect, mods)
		local _, EggRoll = load(mods)
		local chars = { A = { rarity = "Common" }, B = { rarity = "Common" } }
		local egg = { odds = { Common = 50, Divine = 50 } }
		local rng = Random.new(5)
		for _ = 1, 200 do
			expect.truthy(chars[EggRoll.roll(egg, chars, rng)])
		end
	end,
	["egg roll errors when no rarity has characters"] = function(expect, mods)
		local _, EggRoll = load(mods)
		expect.errors(function()
			EggRoll.roll({ odds = { Divine = 1 } }, { A = { rarity = "Common" } }, Random.new(1))
		end)
	end,
}

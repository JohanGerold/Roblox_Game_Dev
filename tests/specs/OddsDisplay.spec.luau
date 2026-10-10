local function load(mods)
	return require(mods.Shared.Util.OddsDisplay), require(mods.Shared.Config.Rarities), require(mods.Shared.Config.Eggs)
end

return {
	["rows are sorted by rarity with percents"] = function(expect, mods)
		local OddsDisplay, Rarities, Eggs = load(mods)
		local rows = OddsDisplay.rows(Eggs.Stage1_Normal.odds, Rarities)
		local expected = { { "Common", 60 }, { "Rare", 25 }, { "Epic", 12 }, { "Legendary", 3 } }
		expect.eq(#rows, 4)
		for i, e in expected do
			expect.eq(rows[i].rarity, e[1])
			expect.near(rows[i].percent, e[2], 1e-9)
		end
	end,
	["percents sum to 100 for every egg"] = function(expect, mods)
		local OddsDisplay, Rarities, Eggs = load(mods)
		for id, egg in Eggs do
			local sum = 0
			for _, row in OddsDisplay.rows(egg.odds, Rarities) do
				sum += row.percent
			end
			expect.near(sum, 100, 1e-9, id)
		end
	end,
}

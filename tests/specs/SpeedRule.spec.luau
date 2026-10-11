local function load(mods)
	return require(mods.Logic.SpeedRule), require(mods.Shared.Config.Eggs)
end

return {
	["needed speeds match the spec"] = function(expect, mods)
		local Rule = load(mods)
		expect.eq(Rule.needed(20, 0.9), 23)
		expect.eq(Rule.needed(20, 0.8), 25)
		expect.eq(Rule.needed(20, 0.6), 34)
		expect.eq(Rule.needed(20, 0.95), 22)
		expect.eq(Rule.needed(20, 0.85), 24)
		expect.eq(Rule.needed(20, 1), 20)
	end,
	["lines are sorted by needed speed"] = function(expect, mods)
		local Rule, eggs = load(mods)
		local lines = Rule.lines(20, eggs)
		expect.eq(#lines, 6)
		expect.eq(lines[1], "BOSS CHASE SPEED 20")
		local expected = { "Field Egg: 22", "Egg: 23", "Shiny Egg: 24", "Top Egg: 25", "Giant Egg: 34" }
		for i, text in expected do
			expect.eq(lines[i + 1], text)
		end
	end,
}

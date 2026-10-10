local function load(mods)
	return require(mods.Logic.ComboCheck),
		require(mods.Shared.Config.Combat),
		require(mods.Shared.Config.Weapons).Fists.combo
end

return {
	["combo sequence is accepted"] = function(expect, mods)
		local CC, Combat, combo = load(mods)
		local s = CC.newState()
		local t = 10
		for _, index in { 1, 2, 3, 1 } do
			expect.eq(CC.accept(s, index, combo, t, Combat), true, "index " .. index)
			t += 0.45
		end
	end,
	["skipping a combo step is rejected"] = function(expect, mods)
		local CC, Combat, combo = load(mods)
		local s = CC.newState()
		expect.eq(CC.accept(s, 1, combo, 10, Combat), true)
		expect.eq(CC.accept(s, 3, combo, 10.5, Combat), false)
	end,
	["attacking too fast is rejected"] = function(expect, mods)
		local CC, Combat, combo = load(mods)
		local s = CC.newState()
		expect.eq(CC.accept(s, 1, combo, 10, Combat), true)
		expect.eq(CC.accept(s, 2, combo, 10.1, Combat), false)
	end,
	["combo resets after a pause"] = function(expect, mods)
		local CC, Combat, combo = load(mods)
		local s = CC.newState()
		expect.eq(CC.accept(s, 1, combo, 10, Combat), true)
		expect.eq(CC.accept(s, 2, combo, 10.45, Combat), true)
		expect.eq(CC.accept(s, 3, combo, 12, Combat), false)
		expect.eq(CC.accept(s, 1, combo, 12, Combat), true)
	end,
	["first attack must be step 1"] = function(expect, mods)
		local CC, Combat, combo = load(mods)
		expect.eq(CC.accept(CC.newState(), 2, combo, 10, Combat), false)
	end,
	["index out of range is rejected"] = function(expect, mods)
		local CC, Combat, combo = load(mods)
		expect.eq(CC.accept(CC.newState(), 4, combo, 10, Combat), false)
		expect.eq(CC.accept(CC.newState(), 0, combo, 10, Combat), false)
	end,
}

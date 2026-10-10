local function load(mods)
	return require(mods.Logic.DamageCalc),
		require(mods.Shared.Config.Combat),
		require(mods.Shared.Config.Progression),
		require(mods.Shared.Config.Armor)
end

return {
	["base damage is unchanged with no stats"] = function(expect, mods)
		local DamageCalc, Combat, Progression = load(mods)
		local stats = { power = 0, rebirths = 0, armorBonus = 0, staggered = false }
		expect.near(DamageCalc.playerDamage(10, stats, Combat, Progression), 10, 1e-6)
	end,
	["all multipliers stack"] = function(expect, mods)
		local DamageCalc, Combat, Progression = load(mods)
		local stats = { power = 100, rebirths = 2, armorBonus = 0.05, staggered = true }
		-- 10 * (1 + 100*0.01) * 1.05 * (1 + 2*0.25) * 2
		expect.near(DamageCalc.playerDamage(10, stats, Combat, Progression), 63, 1e-6)
	end,
	["armor bonus sums and ignores unknown ids"] = function(expect, mods)
		local DamageCalc, _, _, Armor = load(mods)
		expect.near(DamageCalc.armorBonus({ head = "Lofy_Hat", body = "Nope" }, Armor), 0.05, 1e-6)
	end,
}

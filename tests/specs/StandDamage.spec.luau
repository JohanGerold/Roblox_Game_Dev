local function load(mods)
	local C = mods.Shared.Config
	return require(mods.Logic.StandDamage), require(C.Characters), require(C.Economy), require(C.Progression), require(C.Combat)
end

local function damage(mods, team, characters, rebirths)
	local SD, Ch, E, P, Co = load(mods)
	return SD.perTick(team, characters, rebirths, Ch, E, P, Co)
end

return {
	["one level-1 Lofy deals 1"] = function(expect, mods)
		expect.near(damage(mods, { "c1" }, { c1 = { id = "Lofy_Base", level = 1 } }, 0), 1, 1e-9)
	end,
	["level scaling"] = function(expect, mods)
		expect.near(damage(mods, { "c1" }, { c1 = { id = "Zoru_Base", level = 3 } }, 0), 6 * 1.3 ^ 2, 1e-6)
	end,
	["team sums"] = function(expect, mods)
		local chars = { c1 = { id = "Lofy_Base", level = 1 }, c2 = { id = "Zoru_Base", level = 1 } }
		expect.near(damage(mods, { "c1", "c2" }, chars, 0), 7, 1e-9)
	end,
	["rebirths multiply"] = function(expect, mods)
		expect.near(damage(mods, { "c1" }, { c1 = { id = "Lofy_Base", level = 1 } }, 2), 1.5, 1e-9)
	end,
	["missing, duplicate and unknown entries"] = function(expect, mods)
		expect.near(damage(mods, { "c1", "c1", "gone" }, { c1 = { id = "Lofy_Base", level = 1 } }, 0), 1, 1e-9)
		expect.eq(damage(mods, { "c1" }, { c1 = { id = "Nope", level = 1 } }, 0), 0)
	end,
	["empty team deals 0"] = function(expect, mods)
		expect.eq(damage(mods, {}, {}, 0), 0)
	end,
}

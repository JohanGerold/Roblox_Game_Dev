local function load(mods)
	return require(mods.Logic.TeamRules), require(mods.Shared.Config.Progression)
end

local CHARS = { c1 = { id = "Lofy_Base", level = 1 }, c2 = { id = "Zoru_Base", level = 1 }, c3 = { id = "Narto_Base", level = 1 }, c4 = { id = "Gokku_Base", level = 1 } }

return {
	["slots grow with rebirths"] = function(expect, mods)
		local Rules, P = load(mods)
		for rebirths, slots in { [0] = 3, [4] = 3, [5] = 4, [14] = 4, [15] = 5, [30] = 6, [100] = 6 } do
			expect.eq(Rules.slots(rebirths, P), slots, rebirths .. " rebirths")
		end
	end,
	["a valid team passes"] = function(expect, mods)
		local Rules, P = load(mods)
		expect.eq((Rules.validate({ "c1", "c2" }, CHARS, 0, P)), true)
	end,
	["empty team passes"] = function(expect, mods)
		local Rules, P = load(mods)
		expect.eq((Rules.validate({}, CHARS, 0, P)), true)
	end,
	["not a list"] = function(expect, mods)
		local Rules, P = load(mods)
		for _, bad in { "c1", { a = "c1" }, { [1] = "c1", [3] = "c2" }, { 5 }, 7, true } do
			local ok, reason = Rules.validate(bad, CHARS, 0, P)
			expect.eq(ok, false)
			expect.eq(reason, "not a list")
		end
	end,
	["too many"] = function(expect, mods)
		local Rules, P = load(mods)
		local ok, reason = Rules.validate({ "c1", "c2", "c3", "c4" }, CHARS, 0, P)
		expect.eq(ok, false)
		expect.eq(reason, "too many")
		expect.eq((Rules.validate({ "c1", "c2", "c3", "c4" }, CHARS, 5, P)), true)
	end,
	["unknown stand"] = function(expect, mods)
		local Rules, P = load(mods)
		local ok, reason = Rules.validate({ "c9" }, CHARS, 0, P)
		expect.eq(ok, false)
		expect.eq(reason, "unknown stand")
	end,
	["duplicate"] = function(expect, mods)
		local Rules, P = load(mods)
		local ok, reason = Rules.validate({ "c1", "c1" }, CHARS, 0, P)
		expect.eq(ok, false)
		expect.eq(reason, "duplicate")
	end,
}

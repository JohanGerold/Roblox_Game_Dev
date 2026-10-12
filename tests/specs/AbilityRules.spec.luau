local function load(mods)
	local C = mods.Shared.Config
	return require(mods.Logic.AbilityRules), require(C.Bosses), require(C.Moves), require(C.Combat)
end

return {
	["no set"] = function(expect, mods)
		local Rules, B, M, Co = load(mods)
		local ok, reason = Rules.canUse(1, nil, 1, nil, 100, B, M, Co)
		expect.eq(ok, false)
		expect.eq(reason, "no set")
		local _, unknown = Rules.canUse(1, "Boss_Nope", 1, nil, 100, B, M, Co)
		expect.eq(unknown, "no set")
	end,
	["locked slot"] = function(expect, mods)
		local Rules, B, M, Co = load(mods)
		local _, locked = Rules.canUse(2, "Boss_Lofy", 1, nil, 100, B, M, Co)
		expect.eq(locked, "locked")
		local _, outOfRange = Rules.canUse(5, "Boss_Lofy", 4, nil, 100, B, M, Co)
		expect.eq(outOfRange, "locked")
	end,
	["first use passes and names the move"] = function(expect, mods)
		local Rules, B, M, Co = load(mods)
		local ok, reason, moveId = Rules.canUse(1, "Boss_Lofy", 1, nil, 100, B, M, Co)
		expect.eq(ok, true)
		expect.eq(reason, nil)
		expect.eq(moveId, "Gogo_MagmaFist")
	end,
	["cooldown with tolerance"] = function(expect, mods)
		local Rules, B, M, Co = load(mods)
		local ok, reason = Rules.canUse(1, "Boss_Lofy", 1, 10, 13.7, B, M, Co)
		expect.eq(ok, false)
		expect.eq(reason, "cooldown")
		expect.eq((Rules.canUse(1, "Boss_Lofy", 1, 10, 13.8, B, M, Co)), true)
	end,
}

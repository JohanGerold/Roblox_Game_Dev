local function load(mods)
	local C = mods.Shared.Config
	return require(mods.Logic.ShopRules), require(C.Weapons), require(C.Armor), require(C.Combat)
end

return {
	["buys an affordable weapon"] = function(expect, mods)
		local Rules, W, _, Co = load(mods)
		expect.eq((Rules.canBuy("Stick", { "Fists" }, 500, 5, W, Co)), true)
	end,
	["exactly the price is enough, one less is not"] = function(expect, mods)
		local Rules, W, _, Co = load(mods)
		expect.eq((Rules.canBuy("Stick", { "Fists" }, 500, 5, W, Co)), true)
		local ok, reason = Rules.canBuy("Stick", { "Fists" }, 499, 5, W, Co)
		expect.eq(ok, false)
		expect.eq(reason, "poor")
	end,
	["unknown weapon"] = function(expect, mods)
		local Rules, W, _, Co = load(mods)
		local _, reason = Rules.canBuy("Laser", { "Fists" }, 1e9, 5, W, Co)
		expect.eq(reason, "unknown weapon")
	end,
	["already owned"] = function(expect, mods)
		local Rules, W, _, Co = load(mods)
		local _, reason = Rules.canBuy("Fists", { "Fists" }, 1e9, 5, W, Co)
		expect.eq(reason, "owned")
	end,
	["too far"] = function(expect, mods)
		local Rules, W, _, Co = load(mods)
		local _, reason = Rules.canBuy("Stick", { "Fists" }, 1e9, 16, W, Co)
		expect.eq(reason, "too far")
		expect.eq((Rules.canBuy("Stick", { "Fists" }, 1e9, 15, W, Co)), true)
	end,
	["equip owned weapon"] = function(expect, mods)
		local Rules, W, A = load(mods)
		expect.eq((Rules.canEquip("weapon", "Stick", { weapons = { owned = { "Fists", "Stick" } }, armor = { owned = {} } }, W, A)), true)
	end,
	["equip unowned weapon"] = function(expect, mods)
		local Rules, W, A = load(mods)
		local _, reason = Rules.canEquip("weapon", "Katana", { weapons = { owned = { "Fists" } }, armor = { owned = {} } }, W, A)
		expect.eq(reason, "not owned")
	end,
	["equip owned armor"] = function(expect, mods)
		local Rules, W, A = load(mods)
		expect.eq((Rules.canEquip("armor", "Gogo_AshCrown", { weapons = { owned = { "Fists" } }, armor = { owned = { "Gogo_AshCrown" } } }, W, A)), true)
	end,
	["bad kind and unknown id"] = function(expect, mods)
		local Rules, W, A = load(mods)
		local data = { weapons = { owned = { "Fists" } }, armor = { owned = {} } }
		local _, kindReason = Rules.canEquip("pet", "Fists", data, W, A)
		expect.eq(kindReason, "bad kind")
		local _, idReason = Rules.canEquip("weapon", "Laser", data, W, A)
		expect.eq(idReason, "unknown")
	end,
}

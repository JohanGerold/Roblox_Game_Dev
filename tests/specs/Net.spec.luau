return {
	["valid Attack passes"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		local ok = S.validate("Attack", { 2, "Fists" })
		expect.eq(ok, true)
	end,
	["NaN rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { 0 / 0, "Fists" })), false)
	end,
	["inf rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { math.huge, "Fists" })), false)
		expect.eq((S.validate("Attack", { -math.huge, "Fists" })), false)
	end,
	["wrong type rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { "2", "Fists" })), false)
		expect.eq((S.validate("Attack", { 2, 5 })), false)
	end,
	["missing arg rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { 2 })), false)
	end,
	["extra arg rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { 2, "Fists", "extra" })), false)
	end,
	["long string rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { 2, string.rep("a", 201) })), false)
		expect.eq((S.validate("Attack", { 2, string.rep("a", 200) })), true)
	end,
	["int rejects fractions"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { 1.5, "Fists" })), false)
	end,
	["optional arg may be nil"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Equip", { "weapon", "Fists" })), true)
		S.definitions.__optTest = { dir = "c2s", args = { "string", "string?" } }
		expect.eq((S.validate("__optTest", { "a" })), true)
		expect.eq((S.validate("__optTest", { "a", 5 })), false)
		S.definitions.__optTest = nil
	end,
	["unknown message rejected"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("NoSuchMessage", {})), false)
	end,
	["every spec message is defined"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		for _, name in { "Attack", "UseAbility", "Defend", "Counter", "HatchEgg", "PlaceStand", "SetTeam", "UpgradeStand",
			"BuyWeapon", "Equip", "Train", "Rebirth", "SetKeybinds", "SetSetting", "RequestData",
			"DataInit", "DataChanged", "BossAttack", "HitResult", "DamageNumbers", "GiantEggState", "Announce" } do
			expect.truthy(S.definitions[name], name)
		end
	end,
	["boss state travels as attributes, attacks carry the boss id"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq(S.definitions.BossState, nil)
		expect.eq(#S.definitions.BossAttack.args, 4)
		expect.eq(S.definitions.BossAttack.args[4], "table?") -- optional payload: locked circle centre or wave data
	end,
	["limiter allows up to max then blocks"] = function(expect, mods)
		local L = require(mods.Shared.Util.RateLimiter).new(3, 1)
		expect.eq(L:allow("p", 0), true)
		expect.eq(L:allow("p", 0.1), true)
		expect.eq(L:allow("p", 0.2), true)
		expect.eq(L:allow("p", 0.3), false)
	end,
	["limiter recovers after window"] = function(expect, mods)
		local L = require(mods.Shared.Util.RateLimiter).new(2, 1)
		L:allow("p", 0)
		L:allow("p", 0.1)
		expect.eq(L:allow("p", 0.5), false)
		expect.eq(L:allow("p", 1.2), true)
	end,
	["limiter keys are independent"] = function(expect, mods)
		local L = require(mods.Shared.Util.RateLimiter).new(1, 1)
		expect.eq(L:allow("a", 0), true)
		expect.eq(L:allow("b", 0), true)
		expect.eq(L:allow("a", 0.1), false)
	end,
	["UseAbility slot must be 1 to 4"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		for _, ok in { 1, 4 } do
			expect.eq((S.validate("UseAbility", { ok })), true, tostring(ok))
		end
		for _, bad in { 0, 5, -1, 1e300 } do
			expect.eq((S.validate("UseAbility", { bad })), false, tostring(bad))
		end
	end,
	["Attack combo index must be 1 to 10"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Attack", { 10, "Fists" })), true)
		expect.eq((S.validate("Attack", { 0, "Fists" })), false)
		expect.eq((S.validate("Attack", { 11, "Fists" })), false)
	end,
	["Defend kind must be Dodge or Parry"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Defend", { "Dodge", 12.5 })), true)
		expect.eq((S.validate("Defend", { "Parry", 12.5 })), true)
		expect.eq((S.validate("Defend", { "Block", 12.5 })), false)
	end,
	["Train kind must be Treadmill or Sandbag"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Train", { "Treadmill", true })), true)
		expect.eq((S.validate("Train", { "Sandbag", false })), true)
		expect.eq((S.validate("Train", { "Swim", true })), false)
	end,
	["Equip kind must be weapon or armor"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("Equip", { "weapon", "Katana" })), true)
		expect.eq((S.validate("Equip", { "armor", "Gogo_AshCrown" })), true)
		expect.eq((S.validate("Equip", { "hat", "x" })), false)
	end,
	["PlaceStand slot must be 1 to 16 when given"] = function(expect, mods)
		local S = require(mods.Shared.NetSchema)
		expect.eq((S.validate("PlaceStand", { "c_1", 16 })), true)
		expect.eq((S.validate("PlaceStand", { "c_1" })), true)
		expect.eq((S.validate("PlaceStand", { "c_1", 0 })), false)
		expect.eq((S.validate("PlaceStand", { "c_1", 17 })), false)
	end,
}

return {
	["new returns independent copies"] = function(expect, mods)
		local T = require(mods.Logic.DataTemplate)
		local a, b = T.new(), T.new()
		a.money = 99
		a.weapons.owned[2] = "Katana"
		a.settings.keybinds.Dodge = "Q"
		expect.eq(b.money, 0)
		expect.eq(#b.weapons.owned, 1)
		expect.eq(b.settings.keybinds.Dodge, nil)
	end,
	["template matches the spec layout"] = function(expect, mods)
		local d = require(mods.Logic.DataTemplate).new()
		expect.eq(d.version, 1)
		expect.eq(d.money, 0)
		expect.eq(d.rebirths, 0)
		expect.eq(d.lastSeen, 0)
		expect.eq(d.baseSlots, 4)
		expect.eq(d.weapons.equipped, "Fists")
		expect.eq(d.settings.fewerEffects, false)
		expect.truthy(type(d.characters) == "table" and type(d.eggs) == "table" and type(d.bossMoves) == "table")
		expect.truthy(type(d.training) == "table" and d.training.speed == 0 and d.training.power == 0)
	end,
	["missing keys filled"] = function(expect, mods)
		local M = require(mods.Logic.Migrations)
		local d = M.run({ version = 1, money = 50 })
		expect.eq(d.money, 50)
		expect.truthy(d.settings and d.settings.keybinds)
		expect.eq(d.baseSlots, 4)
	end,
	["nested missing keys filled without overwriting"] = function(expect, mods)
		local M = require(mods.Logic.Migrations)
		local d = M.run({ version = 1, settings = { fewerEffects = true } })
		expect.eq(d.settings.fewerEffects, true)
		expect.truthy(d.settings.keybinds)
	end,
	["existing values never overwritten"] = function(expect, mods)
		local M = require(mods.Logic.Migrations)
		local d = M.run({
			version = 1,
			money = 7,
			baseSlots = 9,
			characters = { c_1 = { id = "Lofy_Base", level = 3 } },
			weapons = { owned = { "Fists", "Katana" }, equipped = "Katana" },
		})
		expect.eq(d.money, 7)
		expect.eq(d.baseSlots, 9)
		expect.eq(d.characters.c_1.level, 3)
		expect.eq(d.weapons.equipped, "Katana")
		expect.eq(#d.weapons.owned, 2)
	end,
	["version is set to current"] = function(expect, mods)
		local M = require(mods.Logic.Migrations)
		expect.eq(M.run({}).version, 1)
		expect.eq(M.run({ version = 0 }).version, 1)
	end,
}

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
		expect.eq(d.version, 2)
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
			characters = { c_1 = { id = "Yuju_Base", level = 3 } },
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
		expect.eq(M.run({}).version, 2)
		expect.eq(M.run({ version = 0 }).version, 2)
	end,
	["v1 to v2 renames stands and armor, keeps level slot and team"] = function(expect, mods)
		local M = require(mods.Logic.Migrations)
		local d = M.run({
			version = 1,
			characters = {
				a = { id = "Lofy_Base", level = 3, slot = 2 },
				b = { id = "Gokku_Red", level = 1 },
				c = { id = "Gokku_Blue", level = 5, slot = 1 },
				d = { id = "Unknown_Id", level = 1 },
			},
			standTeam = { "a", "c" },
			armor = { owned = { "Lofy_Hat" }, equipped = { head = "Lofy_Hat" } },
		})
		expect.eq(d.characters.a.id, "Yuju_Base")
		expect.eq(d.characters.a.level, 3)
		expect.eq(d.characters.a.slot, 2)
		expect.eq(d.characters.b.id, "Toudo_Base")
		expect.eq(d.characters.c.id, "Gojou_Blindfold")
		expect.eq(d.characters.d.id, "Unknown_Id")
		expect.eq(d.standTeam[2], "c")
		expect.eq(d.armor.owned[1], "Gogo_AshCrown")
		expect.eq(d.armor.equipped.head, "Gogo_AshCrown")
		expect.eq(d.version, 2)
	end,
	["a v2 save is not renamed again"] = function(expect, mods)
		local M = require(mods.Logic.Migrations)
		local d = M.run({ version = 2, characters = { a = { id = "Lofy_Base", level = 1 } } })
		expect.eq(d.characters.a.id, "Lofy_Base")
	end,
	["every renamed stand id exists in config"] = function(expect, mods)
		local C = require(mods.Shared.Config.Characters)
		local d = require(mods.Logic.Migrations).run({
			version = 1,
			characters = {
				a = { id = "Lofy_Base" }, b = { id = "Zoru_Base" }, c = { id = "Narto_Base" },
				d = { id = "Gokku_Base" }, e = { id = "Gokku_Red" }, f = { id = "Gokku_Blue" },
			},
		})
		for uid, stand in d.characters do
			expect.truthy(C[stand.id], uid .. " -> " .. stand.id)
		end
	end,
}

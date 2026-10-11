local function cfg(mods, name)
	return require(mods.Shared.Config[name])
end

return {
	["12 rarities in order"] = function(expect, mods)
		local R = cfg(mods, "Rarities")
		expect.eq(#R.order, 12)
		expect.eq(R.order[1], "Common")
		expect.eq(R.order[6], "Mythic")
		expect.eq(R.order[12], "Absolute")
		for i, name in R.order do
			expect.eq(R.byName[name].index, i, name)
		end
	end,
	["auras start at Mythic and animate from Celestial"] = function(expect, mods)
		local R = cfg(mods, "Rarities")
		expect.eq(R.byName.Legendary.aura, "None")
		expect.eq(R.byName.Mythic.aura, "Static")
		expect.eq(R.byName.Celestial.aura, "Animated")
		expect.eq(R.byName.Absolute.auraIntensity, 6)
	end,
	["every character rarity exists"] = function(expect, mods)
		local R, C = cfg(mods, "Rarities"), cfg(mods, "Characters")
		for id, ch in C do
			expect.truthy(R.byName[ch.rarity], id .. " has unknown rarity " .. tostring(ch.rarity))
		end
	end,
	["every egg odds key is a rarity with weight above zero"] = function(expect, mods)
		local R, E = cfg(mods, "Rarities"), cfg(mods, "Eggs")
		for id, egg in E do
			for rarity, w in egg.odds do
				expect.truthy(R.byName[rarity], id .. " unknown rarity " .. rarity)
				expect.truthy(w > 0, id .. " weight for " .. rarity)
			end
		end
	end,
	["Stage1_Top only rolls Mythic or higher"] = function(expect, mods)
		local R, E = cfg(mods, "Rarities"), cfg(mods, "Eggs")
		for rarity in E.Stage1_Top.odds do
			expect.truthy(R.byName[rarity].index >= 6, rarity)
		end
	end,
	["Stage1_Normal only rolls Legendary or lower"] = function(expect, mods)
		local R, E = cfg(mods, "Rarities"), cfg(mods, "Eggs")
		for rarity in E.Stage1_Normal.odds do
			expect.truthy(R.byName[rarity].index <= 5, rarity)
		end
	end,
	["every egg rarity has at least one character"] = function(expect, mods)
		local C, E = cfg(mods, "Characters"), cfg(mods, "Eggs")
		local have = {}
		for _, ch in C do
			have[ch.rarity] = true
		end
		for id, egg in E do
			for rarity in egg.odds do
				expect.truthy(have[rarity], id .. " has no character of rarity " .. rarity)
			end
		end
	end,
	["every egg has a display name"] = function(expect, mods)
		for id, egg in cfg(mods, "Eggs") do
			expect.truthy(type(egg.displayName) == "string" and #egg.displayName > 0, id)
		end
	end,
	["stage boss rank eggs exist and top count is 3"] = function(expect, mods)
		local E = cfg(mods, "Eggs")
		for id, boss in cfg(mods, "Bosses") do
			if boss.kind == "Stage" then
				expect.truthy(boss.rankEggs, id .. " has no rankEggs")
				expect.truthy(E[boss.rankEggs.top], id .. " top egg missing")
				expect.truthy(E[boss.rankEggs.normal], id .. " normal egg missing")
				expect.eq(boss.rankEggs.topCount, 3)
			end
		end
	end,
	["egg cap is 50"] = function(expect, mods)
		expect.eq(cfg(mods, "Economy").eggCap, 50)
	end,
	["every boss has 1 to 4 player moves"] = function(expect, mods)
		for id, boss in cfg(mods, "Bosses") do
			expect.truthy(#boss.playerMoves >= 1 and #boss.playerMoves <= 4, id)
		end
	end,
	["combat numbers match the spec"] = function(expect, mods)
		local K = cfg(mods, "Combat")
		expect.eq(K.parryWindow, 0.20)
		expect.eq(K.perfectDodgeWindow, 0.15)
		expect.eq(K.dodgeIFrames, 0.30)
		expect.eq(K.counterWindow, 1.5)
		expect.eq(K.claimMaxAge, 0.30)
		expect.eq(K.claimFutureTolerance, 0.05)
	end,
	["economy numbers match the spec"] = function(expect, mods)
		local E = cfg(mods, "Economy")
		expect.eq(E.offlineCapSeconds, 8 * 3600)
		expect.eq(E.offlineRate, 0.5)
		expect.eq(E.inventoryCap, 200)
	end,
	["keybind defaults cover all 10 actions"] = function(expect, mods)
		local K = cfg(mods, "Keybinds").defaults
		local n = 0
		for _ in K do
			n += 1
		end
		expect.eq(n, 10)
		expect.eq(K.Parry, "MouseButton2")
		expect.eq(K.Dodge, "LeftShift")
		expect.eq(K.ToggleCombatMode, "LeftControl")
	end,
	["every egg has a carry factor and a color"] = function(expect, mods)
		for id, egg in cfg(mods, "Eggs") do
			expect.truthy(type(egg.carryFactor) == "number" and egg.carryFactor > 0 and egg.carryFactor <= 1, id .. " carryFactor")
			expect.eq(typeof(egg.color), "Color3", id .. " color")
		end
	end,
	["giant egg config is consistent"] = function(expect, mods)
		local G, E, R = cfg(mods, "GiantEgg"), cfg(mods, "Eggs"), cfg(mods, "Rarities")
		expect.truthy(E[G.eggId], "egg " .. G.eggId)
		expect.truthy(G.returnAfterSeconds < G.despawnAfterSeconds)
		expect.truthy(R.byName[G.announceRarity], "announce rarity")
	end,
	["carry speed lives in the egg, not in training"] = function(expect, mods)
		expect.eq(cfg(mods, "Training").carryWalkSpeed, nil)
	end,
	["personal egg ring clears the boss"] = function(expect, mods)
		local K, M = cfg(mods, "Carry"), cfg(mods, "Map")
		expect.truthy(K.personalRingRadius + K.personalSize < M.giantEggOffset.Magnitude - 5)
	end,
	["rounds config matches the spec"] = function(expect, mods)
		local R, E = cfg(mods, "Rounds"), cfg(mods, "Eggs")
		expect.eq(R.daySeconds, 240)
		expect.eq(R.nightSeconds, 45)
		expect.eq(R.fieldEggs.smallExtra, 2)
		expect.eq(R.fieldEggs.shinyChance, 0.10)
		expect.eq(R.fieldEggs.giantChance, 0.25)
		for _, key in { "small", "shiny", "giant" } do
			expect.truthy(E[R.fieldEggs[key]], "egg for " .. key)
		end
	end,
	["field eggs are lighter than the giant"] = function(expect, mods)
		local E = cfg(mods, "Eggs")
		expect.eq(E.Field_Small.carryFactor, 0.95)
		expect.eq(E.Field_Shiny.carryFactor, 0.85)
	end,
	["both lighting presets set every key"] = function(expect, mods)
		local R = cfg(mods, "Rounds")
		for _, phase in { "Day", "Night" } do
			for _, key in { "ClockTime", "Ambient", "OutdoorAmbient", "Density", "Color", "Decay", "Haze", "Glare" } do
				expect.truthy(R.lighting[phase][key] ~= nil, phase .. " " .. key)
			end
		end
	end,
	["boss chase values match the spec"] = function(expect, mods)
		local b = cfg(mods, "Bosses").Boss_Lofy
		expect.eq(b.chaseSpeed, 20)
		expect.eq(b.catchRange, 6)
		expect.eq(b.catchDamage, 20)
		expect.eq(b.reviveSeconds, 3)
		expect.eq(b.guardSeconds, 60)
		expect.eq(b.respawnSeconds, nil)
	end,
	["catch damage leaves room to survive"] = function(expect, mods)
		expect.truthy(cfg(mods, "Bosses").Boss_Lofy.catchDamage < 100)
	end,
	["stand tick values"] = function(expect, mods)
		local C = cfg(mods, "Combat")
		expect.eq(C.standTickSeconds, 1)
		expect.eq(C.standDamageFactor, 1)
	end,
	["every boss move has stats"] = function(expect, mods)
		local Moves = cfg(mods, "Moves")
		for id, boss in cfg(mods, "Bosses") do
			for _, moveId in boss.playerMoves do
				local move = Moves[moveId]
				expect.truthy(move, id .. " move " .. moveId)
				expect.truthy(move.damage > 0 and move.range > 0 and move.cooldown > 0, moveId)
				expect.truthy(type(move.displayName) == "string", moveId .. " name")
			end
		end
	end,
	["every drop armor piece exists"] = function(expect, mods)
		local Armor = cfg(mods, "Armor")
		for id, boss in cfg(mods, "Bosses") do
			for _, pieceId in boss.drops and boss.drops.armorPieces or {} do
				local piece = Armor[pieceId]
				expect.truthy(piece, id .. " armor " .. pieceId)
				expect.truthy(piece.slot and piece.displayName, pieceId)
			end
		end
	end,
	["every weapon has a name and a price"] = function(expect, mods)
		for id, weapon in cfg(mods, "Weapons") do
			expect.truthy(type(weapon.displayName) == "string", id .. " name")
			expect.truthy(weapon.price >= 0, id .. " price")
		end
	end,
	["fists are free"] = function(expect, mods)
		expect.eq(cfg(mods, "Weapons").Fists.price, 0)
	end,
	["every attack has the new fields"] = function(expect, mods)
		local targeting = { Self = true, Player = true, Wave = true }
		for id, boss in cfg(mods, "Bosses") do
			for _, attack in boss.attacks do
				local name = id .. " " .. attack.id
				expect.truthy(targeting[attack.targeting], name .. " targeting")
				expect.truthy(type(attack.parryWindow) == "number" and attack.parryWindow > 0, name .. " parryWindow")
				expect.truthy(type(attack.cooldown) == "number" and attack.cooldown >= 0, name .. " cooldown")
				expect.truthy(type(attack.vfx) == "string" and #attack.vfx > 0, name .. " vfx")
				expect.eq(type(attack.danger), "boolean", name .. " danger")
			end
		end
	end,
	["every gogo attack is parryable"] = function(expect, mods)
		for _, attack in cfg(mods, "Bosses").Boss_Lofy.attacks do
			expect.eq(attack.unparryable, false, attack.id)
		end
	end,
	["wave attacks have speed and start radius"] = function(expect, mods)
		for _, attack in cfg(mods, "Bosses").Boss_Lofy.attacks do
			if attack.targeting == "Wave" then
				expect.truthy(attack.waveSpeed > 0, attack.id .. " speed")
				expect.truthy(attack.waveStartRadius > 0, attack.id .. " start radius")
			end
		end
	end,
	["gogo is the stage 1 boss"] = function(expect, mods)
		local boss = cfg(mods, "Bosses").Boss_Lofy
		expect.eq(boss.displayName, "Gogo")
		expect.eq(boss.model, "Boss_Gogo")
		expect.eq(boss.vfxFolder, "Gogo")
	end,
}

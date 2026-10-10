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
	["giant egg config is consistent"] = function(expect, mods)
		local G, E, R = cfg(mods, "GiantEgg"), cfg(mods, "Eggs"), cfg(mods, "Rarities")
		expect.truthy(E[G.eggId], "egg " .. G.eggId)
		expect.truthy(G.returnAfterSeconds < G.despawnAfterSeconds)
		expect.truthy(R.byName[G.announceRarity], "announce rarity")
	end,
}

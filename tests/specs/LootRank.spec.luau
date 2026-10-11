local function load(mods)
	return require(mods.Logic.LootRank)
end

return {
	["ranks by damage and drops players under the minimum share"] = function(expect, mods)
		local LootRank = load(mods)
		local result = LootRank.rank({ [1] = 500, [2] = 300, [3] = 100, [4] = 90, [5] = 10 }, 0.05, 3)
		expect.eq(#result, 4)
		for i, userId in { 1, 2, 3, 4 } do
			expect.eq(result[i].userId, userId)
			expect.eq(result[i].rank, i)
		end
		expect.truthy(result[1].top and result[2].top and result[3].top)
		expect.eq(result[4].top, false)
	end,
	["ties are sorted by user id"] = function(expect, mods)
		local LootRank = load(mods)
		local result = LootRank.rank({ [7] = 50, [3] = 50 }, 0.05, 3)
		expect.eq(result[1].userId, 3)
		expect.eq(result[2].userId, 7)
	end,
	["empty ledger gives no ranks"] = function(expect, mods)
		local LootRank = load(mods)
		expect.eq(#LootRank.rank({}, 0.05, 3), 0)
		expect.eq(#LootRank.rank({ [1] = 0 }, 0.05, 3), 0)
	end,
	["solo player is rank 1 and top"] = function(expect, mods)
		local LootRank = load(mods)
		local result = LootRank.rank({ [42] = 10 }, 0.05, 3)
		expect.eq(#result, 1)
		expect.eq(result[1].rank, 1)
		expect.truthy(result[1].top)
	end,
	["top count is a share of the participants, at least one, never above the cap"] = function(expect, mods)
		local LootRank = load(mods)
		for participants, expected in { [1] = 1, [2] = 1, [3] = 1, [4] = 2, [5] = 2, [6] = 2, [7] = 3, [8] = 3, [16] = 3 } do
			expect.eq(LootRank.topCount(participants, 0.3, 3), expected, participants .. " participants")
		end
		expect.eq(LootRank.topCount(0, 0.3, 3), 0, "nobody")
	end,
}

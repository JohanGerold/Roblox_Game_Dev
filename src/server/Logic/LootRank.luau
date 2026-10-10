local LootRank = {}

export type Entry = { userId: number, damage: number, rank: number, top: boolean }

-- Ranks participants by damage (highest first, ties by userId). Players under `minShare` of the
-- total damage are left out. The first `topCount` ranks are `top`.
function LootRank.rank(ledger: { [number]: number }, minShare: number, topCount: number): { Entry }
	local total = 0
	for _, damage in ledger do
		if damage > 0 then
			total += damage
		end
	end
	if total <= 0 then
		return {}
	end

	local entries = {}
	for userId, damage in ledger do
		if damage > 0 and damage / total >= minShare then
			table.insert(entries, { userId = userId, damage = damage, rank = 0, top = false })
		end
	end
	table.sort(entries, function(a, b)
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		return a.userId < b.userId
	end)
	for i, entry in entries do
		entry.rank = i
		entry.top = i <= topCount
	end
	return entries
end

return LootRank

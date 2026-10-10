local OddsDisplay = {}

-- Odds table (rarity -> weight) as rows sorted from the lowest rarity up, with percents.
function OddsDisplay.rows(odds: { [string]: number }, Rarities): { { rarity: string, percent: number } }
	local total = 0
	for _, weight in odds do
		total += weight
	end
	local rows = {}
	for rarity, weight in odds do
		table.insert(rows, { rarity = rarity, percent = weight / total * 100 })
	end
	table.sort(rows, function(a, b)
		return Rarities.byName[a.rarity].index < Rarities.byName[b.rarity].index
	end)
	return rows
end

return OddsDisplay

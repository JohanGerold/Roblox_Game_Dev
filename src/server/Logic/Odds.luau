local Odds = {}

-- Weighted random pick. Keys are visited in sorted order so a seeded Random is deterministic.
function Odds.pick(weights: { [string]: number }, rng: Random): string
	local keys, total = {}, 0
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	if total <= 0 then
		error("Odds.pick: no positive weights")
	end
	table.sort(keys)

	local roll = rng:NextNumber(0, total)
	local running = 0
	for _, key in keys do
		running += weights[key]
		if roll < running then
			return key
		end
	end
	return keys[#keys]
end

return Odds

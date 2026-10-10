local Odds = require(script.Parent.Odds)

local EggRoll = {}

-- Rolls a rarity from the egg's odds (ignoring rarities with no characters), then a
-- character of that rarity. Returns a character id.
function EggRoll.roll(egg: { odds: { [string]: number } }, characters: { [string]: { rarity: string } }, rng: Random): string
	local byRarity: { [string]: { string } } = {}
	for id, character in characters do
		byRarity[character.rarity] = byRarity[character.rarity] or {}
		table.insert(byRarity[character.rarity], id)
	end

	local usable = {}
	for rarity, weight in egg.odds do
		if byRarity[rarity] then
			usable[rarity] = weight
		end
	end
	if next(usable) == nil then
		error("EggRoll.roll: no character exists for any rarity in this egg")
	end

	local rarity = Odds.pick(usable, rng)
	local ids = byRarity[rarity]
	table.sort(ids)
	return ids[rng:NextInteger(1, #ids)]
end

return EggRoll

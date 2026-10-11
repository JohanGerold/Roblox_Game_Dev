-- Decides which field eggs spawn at sunrise and on which spawn point. Pure: randomness comes in as `rng`.
local FieldEggRoll = {}

-- cfg = Config/Rounds.fieldEggs. Returns { { eggId, spawnIndex } }, the giant (if rolled) first.
function FieldEggRoll.roll(playerCount: number, spawnCount: number, cfg, rng: Random): { { eggId: string, spawnIndex: number } }
	local result = {}
	if spawnCount < 1 then
		return result
	end
	local giant = rng:NextNumber() < cfg.giantChance
	local small = math.max(0, math.min(playerCount + cfg.smallExtra, spawnCount - (giant and 1 or 0)))

	local order = {}
	for i = 1, spawnCount do
		order[i] = i
	end
	for i = spawnCount, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end

	local nextIndex = 1
	if giant then
		table.insert(result, { eggId = cfg.giant, spawnIndex = order[nextIndex] })
		nextIndex += 1
	end
	for _ = 1, small do
		local eggId = rng:NextNumber() < cfg.shinyChance and cfg.shiny or cfg.small
		table.insert(result, { eggId = eggId, spawnIndex = order[nextIndex] })
		nextIndex += 1
	end
	return result
end

return FieldEggRoll

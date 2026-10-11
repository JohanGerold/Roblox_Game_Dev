-- What one boss participant gets from the boss's drop table (spec section 9). Pure: randomness is `rng`.
local DropRoll = {}

-- drops = Bosses[id].drops. Returns { armorId = a piece the player doesn't own yet or nil, moveCopy = bool }.
function DropRoll.roll(drops, ownedArmor: { string }, copies: number, moveCount: number, rng): { armorId: string?, moveCopy: boolean }
	local armorId = nil
	if rng:NextNumber() < drops.armorChance then
		local candidates = {}
		for _, id in drops.armorPieces do
			if not table.find(ownedArmor, id) then
				table.insert(candidates, id)
			end
		end
		if #candidates > 0 then
			armorId = candidates[rng:NextInteger(1, #candidates)]
		end
	end
	local moveCopy = rng:NextNumber() < drops.moveCopyChance and copies < moveCount
	return { armorId = armorId, moveCopy = moveCopy }
end

return DropRoll

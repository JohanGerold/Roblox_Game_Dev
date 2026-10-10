local StandPlace = {}

-- Moves a stand to `slot` (nil = storage). Mutates `characters`. Any stand already in that slot
-- goes to storage. Returns true, or false plus "unknown stand" | "slot locked".
function StandPlace.place(characters, uid: string, slot: number?, baseSlots: number): (boolean, string?)
	local stand = characters[uid]
	if not stand then
		return false, "unknown stand"
	end
	if slot ~= nil then
		if slot ~= math.floor(slot) or slot < 1 or slot > baseSlots then
			return false, "slot locked"
		end
		for otherUid, other in characters do
			if otherUid ~= uid and other.slot == slot then
				other.slot = nil
			end
		end
	end
	stand.slot = slot
	return true
end

function StandPlace.firstFreeSlot(characters, baseSlots: number): number?
	local used = {}
	for _, stand in characters do
		if stand.slot then
			used[stand.slot] = true
		end
	end
	for slot = 1, baseSlots do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

return StandPlace

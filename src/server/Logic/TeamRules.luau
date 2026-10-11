-- Stand team size and validation (spec section 6/7). Pure.
local TeamRules = {}

function TeamRules.slots(rebirths: number, Progression): number
	local slots = Progression.baseTeamSlots
	for _, atRebirths in Progression.extraTeamSlotAtRebirths do
		if rebirths >= atRebirths then
			slots += 1
		end
	end
	return slots
end

-- Returns true, or false plus the first failing reason.
function TeamRules.validate(list: any, characters: { [string]: any }, rebirths: number, Progression): (boolean, string?)
	if type(list) ~= "table" then
		return false, "not a list"
	end
	local count = 0
	for key, value in list do
		count += 1
		if type(key) ~= "number" or type(value) ~= "string" then
			return false, "not a list"
		end
	end
	if count ~= #list then
		return false, "not a list"
	end
	if count > TeamRules.slots(rebirths, Progression) then
		return false, "too many"
	end
	local seen = {}
	for _, uid in list do
		if not characters[uid] then
			return false, "unknown stand"
		end
		if seen[uid] then
			return false, "duplicate"
		end
		seen[uid] = true
	end
	return true
end

return TeamRules

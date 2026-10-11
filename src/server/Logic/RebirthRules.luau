-- Rebirth cost and what a rebirth resets (spec sections 5 and 11). Pure.
local RebirthRules = {}

function RebirthRules.cost(rebirths: number, cfg): number
	return cfg.rebirthCostBase * cfg.rebirthCostGrowth ^ rebirths
end

-- Returns true, or false plus the reason.
function RebirthRules.canRebirth(money: number, rebirths: number, cfg): (boolean, string?)
	if money < RebirthRules.cost(rebirths, cfg) then
		return false, "poor"
	end
	return true
end

-- The new values for the four keys a rebirth changes. Stands keep their slot but go back to level 1.
-- The input is not modified.
function RebirthRules.apply(data)
	local characters = {}
	for uid, stand in data.characters do
		local copy = table.clone(stand)
		copy.level = 1
		characters[uid] = copy
	end
	return {
		money = 0,
		rebirths = data.rebirths + 1,
		training = { speed = 0, power = 0 },
		characters = characters,
	}
end

return RebirthRules

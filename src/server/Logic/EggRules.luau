local EggRules = {}

function EggRules.canReceive(eggCount: number, Economy): boolean
	return eggCount < Economy.eggCap
end

-- Returns true, or false plus "no egg" | "not ready" | "inventory full".
function EggRules.canHatch(egg: { readyAt: number }?, now: number, characterCount: number, Economy): (boolean, string?)
	if egg == nil then
		return false, "no egg"
	end
	if now < egg.readyAt then
		return false, "not ready"
	end
	if characterCount >= Economy.inventoryCap then
		return false, "inventory full"
	end
	return true
end

return EggRules

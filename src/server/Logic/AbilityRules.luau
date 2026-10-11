-- Whether a player may fire a copied boss move now (spec section 8, abilities). Pure.
local AbilityRules = {}

-- Returns true, nil, moveId; or false plus the first failing reason.
function AbilityRules.canUse(slot: number, setId: string?, copies: number, lastUsedAt: number?, now: number, Bosses, Moves, Combat): (boolean, string?, string?)
	local boss = setId and Bosses[setId]
	if not boss or not boss.playerMoves then
		return false, "no set"
	end
	if slot < 1 or slot > #boss.playerMoves or slot > copies then
		return false, "locked"
	end
	local moveId = boss.playerMoves[slot]
	local move = Moves[moveId]
	if not move then
		return false, "unknown move"
	end
	if lastUsedAt and now - lastUsedAt < move.cooldown - Combat.abilityCooldownTolerance then
		return false, "cooldown"
	end
	return true, nil, moveId
end

return AbilityRules

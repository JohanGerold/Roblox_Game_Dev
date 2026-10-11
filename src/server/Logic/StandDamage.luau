-- Damage one stand team deals per tick (spec section 8). Pure.
local StandDamage = {}

function StandDamage.perTick(team: { string }, characters, rebirths: number, Characters, Economy, Progression, Combat): number
	local total = 0
	local counted = {}
	for _, uid in team do
		local stand = characters[uid]
		local def = stand and Characters[stand.id]
		if def and not counted[uid] then
			counted[uid] = true
			total += def.basePower * Economy.standLevelPowerGrowth ^ (stand.level - 1)
		end
	end
	return total * (1 + rebirths * Progression.damageMultiplierPerRebirth) * Combat.standDamageFactor
end

return StandDamage

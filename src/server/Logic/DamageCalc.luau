-- Player damage formula (spec section 8). Pure; all tuning comes from the config tables passed in.
local DamageCalc = {}

function DamageCalc.armorBonus(equipped: { [string]: string }, Armor): number
	local total = 0
	for _, id in equipped do
		local piece = Armor[id]
		if piece then
			total += piece.powerBonus
		end
	end
	return total
end

function DamageCalc.playerDamage(base: number, stats, Combat, Progression): number
	local damage = base
		* (1 + stats.power * Combat.powerDamageFactor)
		* (1 + stats.armorBonus)
		* (1 + stats.rebirths * Progression.damageMultiplierPerRebirth)
	if stats.staggered then
		damage *= Combat.staggerDamageMultiplier
	end
	return damage
end

return DamageCalc

-- Money rules shared by the server (pays out) and the client (shows the same numbers).
local Income = {}

function Income.standIncome(charId: string, level: number, Characters, Economy): number
	local character = Characters[charId]
	if not character then
		return 0
	end
	return character.baseIncome * Economy.standLevelIncomeGrowth ^ (level - 1)
end

-- Money per second from placed stands (slot ~= nil), times the rebirth multiplier.
function Income.perSecond(characters, rebirths: number, Characters, Economy, Progression): number
	local total = 0
	for _, stand in characters do
		if stand.slot ~= nil then
			total += Income.standIncome(stand.id, stand.level, Characters, Economy)
		end
	end
	return total * (1 + rebirths * Progression.incomeMultiplierPerRebirth)
end

-- Returns (amount earned, seconds counted). Nothing for a first join or a clock in the future.
function Income.offline(perSecond: number, now: number, lastSeen: number, Economy): (number, number)
	if lastSeen <= 0 or lastSeen > now then
		return 0, 0
	end
	local seconds = math.min(now - lastSeen, Economy.offlineCapSeconds)
	return math.floor(seconds * perSecond * Economy.offlineRate), seconds
end

-- Cost of going from `level` to `level + 1`; nil at max level or for an unknown stand.
function Income.upgradeCost(charId: string, level: number, Characters, Economy): number?
	local character = Characters[charId]
	if not character or level >= Economy.standMaxLevel then
		return nil
	end
	return math.floor(
		character.baseIncome * Economy.standUpgradeCostSeconds * Economy.standUpgradeCostGrowth ^ (level - 1)
	)
end

return Income

-- Validates the order and pace of a player's combo hits. Pure; range and weapon checks live in CombatService.
local ComboCheck = {}

function ComboCheck.newState()
	return { lastIndex = nil :: number?, lastTime = nil :: number? }
end

function ComboCheck.accept(state, comboIndex: number, combo, now: number, Combat): boolean
	if comboIndex < 1 or comboIndex > #combo or comboIndex ~= math.floor(comboIndex) then
		return false
	end
	local fresh = state.lastTime == nil or now - state.lastTime > Combat.comboResetSeconds
	if fresh then
		if comboIndex ~= 1 then
			return false
		end
	else
		-- the next step, one step ahead (a hit lost to lag must not desync the combo), or a restart
		local expected = state.lastIndex % #combo + 1
		if comboIndex ~= expected and comboIndex ~= expected % #combo + 1 and comboIndex ~= 1 then
			return false
		end
		if now - state.lastTime < combo[comboIndex].minInterval * Combat.attackIntervalTolerance then
			return false
		end
	end
	state.lastIndex = comboIndex
	state.lastTime = now
	return true
end

return ComboCheck

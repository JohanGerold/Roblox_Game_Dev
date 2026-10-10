-- Judges dodge/parry claims against a boss impact (spec section 8). Pure; the caller supplies times.
local DefenseJudge = {}

function DefenseJudge.newHistory()
	return { Dodge = {}, Parry = {} }
end

-- Accepts a claim only if it is fresh, not from the future, and off cooldown. Records it when accepted.
function DefenseJudge.accept(history, kind: string, pressTime: number, receivedAt: number, Combat): boolean
	if receivedAt - pressTime > Combat.claimMaxAge then
		return false
	end
	if pressTime > receivedAt + Combat.claimFutureTolerance then
		return false
	end
	local list = history[kind]
	local last = list[#list]
	local cooldown = kind == "Dodge" and Combat.dodgeCooldown or Combat.parryCooldown
	if last and pressTime - last < cooldown then
		return false
	end
	table.insert(list, pressTime)
	while #list > Combat.claimHistorySize do
		table.remove(list, 1)
	end
	return true
end

-- Returns "Parried" | "PerfectDodge" | "Dodged" | "Hit". Only claims made before impact count.
function DefenseJudge.judge(history, impactTime: number, unparryable: boolean, Combat): string
	local parried, perfect, dodged = false, false, false
	for _, t in history.Parry do
		local d = impactTime - t
		if d >= 0 and d <= Combat.parryWindow then
			parried = true
		end
	end
	for _, t in history.Dodge do
		local d = impactTime - t
		if d >= 0 then
			if d <= Combat.perfectDodgeWindow then
				perfect = true
			end
			if d <= Combat.dodgeIFrames then
				dodged = true
			end
		end
	end
	if parried and not unparryable then
		return "Parried"
	elseif perfect then
		return "PerfectDodge"
	elseif dodged then
		return "Dodged"
	end
	return "Hit"
end

return DefenseJudge

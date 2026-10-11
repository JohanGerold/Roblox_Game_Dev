-- Walk speed from training and who may train (spec section 11). Pure.
local TrainingRules = {}

function TrainingRules.walkSpeed(speedStat: number, cfg): number
	return math.min(cfg.maxWalkSpeed, cfg.baseWalkSpeed + math.max(0, speedStat))
end

-- Returns true, or false plus the first failing reason.
function TrainingRules.canTrain(kind: string, distance: number, carrying: boolean, alive: boolean, cfg): (boolean, string?)
	if kind ~= "Treadmill" and kind ~= "Sandbag" then
		return false, "bad kind"
	end
	if not alive then
		return false, "dead"
	end
	if carrying then
		return false, "carrying"
	end
	if distance > cfg.trainRange then
		return false, "too far"
	end
	return true
end

function TrainingRules.statFor(kind: string): string
	return kind == "Treadmill" and "speed" or "power"
end

function TrainingRules.rateFor(kind: string, cfg): number
	return kind == "Treadmill" and cfg.speedPerSecond or cfg.powerPerSecond
end

return TrainingRules

-- Numbers for the gate sign: the walk speed needed to outrun the boss with each egg. Pure.
local SpeedRule = {}

function SpeedRule.needed(chaseSpeed: number, carryFactor: number): number
	return math.ceil(chaseSpeed / carryFactor - 1e-9) -- epsilon: 20 / 0.8 must stay 25
end

-- eggs = Config/Eggs. First line the boss speed, then one line per egg, slowest requirement first.
function SpeedRule.lines(chaseSpeed: number, eggs): { string }
	local rows = {}
	for _, egg in eggs do
		table.insert(rows, { name = egg.displayName, needed = SpeedRule.needed(chaseSpeed, egg.carryFactor) })
	end
	table.sort(rows, function(a, b)
		if a.needed ~= b.needed then
			return a.needed < b.needed
		end
		return a.name < b.name
	end)
	local lines = { "BOSS CHASE SPEED " .. chaseSpeed }
	for _, row in rows do
		table.insert(lines, string.format("%s: %d", row.name, row.needed))
	end
	return lines
end

return SpeedRule

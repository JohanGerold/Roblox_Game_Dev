-- Anti-cheat for the giant egg carrier: horizontal speed check plus the last grounded, valid spot.
local CarryCheck = {}

export type State = { lastPos: Vector3, lastT: number, lastValid: Vector3, graceUntil: number }

function CarryCheck.new(pos: Vector3, t: number, cfg): State
	return { lastPos = pos, lastT = t, lastValid = pos, graceUntil = t + cfg.speedGraceSeconds }
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Returns false when the carrier moved faster than allowed since the last sample (state is left
-- untouched so `lastValid` stays where they were legitimately). The distance is checked on EVERY call,
-- so a teleport between two samples or right after pickup (extra `speedGraceSlack` for that first
-- half second) is caught; only the recorded sample waits for `speedSampleSeconds`. `lastValid` only
-- follows grounded samples.
function CarryCheck.step(state: State, pos: Vector3, t: number, grounded: boolean, speed: number, cfg): boolean
	local elapsed = t - state.lastT
	local allowed = (speed + cfg.speedTolerance) * elapsed + cfg.speedSlack
	if t < state.graceUntil then
		allowed += cfg.speedGraceSlack
	end
	if (flat(pos) - flat(state.lastPos)).Magnitude > allowed then
		return false
	end
	if elapsed < cfg.speedSampleSeconds then
		return true
	end
	state.lastPos = pos
	state.lastT = t
	if grounded then
		state.lastValid = pos
	end
	return true
end

return CarryCheck

-- Expanding fire ring maths shared by the server (who is hit when) and the client (what to draw). Pure.
-- attack = { waveStartRadius, waveSpeed }; times are server time in seconds, distances in studs.
local WaveTiming = {}

-- Ring radius at time `t` for a wave that started at `waveStart`, capped at `maxRadius`.
function WaveTiming.radiusAt(t: number, waveStart: number, attack, maxRadius: number): number
	return math.min(maxRadius, attack.waveStartRadius + attack.waveSpeed * math.max(0, t - waveStart))
end

-- The moment the ring reaches something `distance` studs from the boss's centre.
function WaveTiming.arrival(distance: number, waveStart: number, attack): number
	return waveStart + math.max(0, distance - attack.waveStartRadius) / attack.waveSpeed
end

return WaveTiming

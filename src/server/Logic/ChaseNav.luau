-- Where the enraged boss may walk and which way it heads. Pure. The boss lives in the corridor and the
-- domain (never home); moving between them it passes the gate so it never cuts through a wall.
local ChaseNav = {}

-- The two walkable boxes, shrunk by `margin`: { minX, maxX, halfZ } each.
local function boxes(map, margin: number)
	local c, d = map.corridor, map.domain
	return {
		{ minX = c.minX + margin, maxX = d.minX + margin, halfZ = c.halfWidth - margin },
		{ minX = d.minX + margin, maxX = d.maxX - margin, halfZ = d.halfWidth - margin },
	}
end

local function project(box, pos: Vector3): Vector3
	return Vector3.new(math.clamp(pos.X, box.minX, box.maxX), pos.Y, math.clamp(pos.Z, -box.halfZ, box.halfZ))
end

function ChaseNav.clamp(pos: Vector3, map, margin: number): Vector3
	local best, bestDist
	for _, box in boxes(map, margin) do
		local p = project(box, pos)
		local d = (Vector3.new(p.X - pos.X, 0, p.Z - pos.Z)).Magnitude
		if d == 0 then
			return pos
		end
		if not bestDist or d < bestDist then
			best, bestDist = p, d
		end
	end
	return best
end

function ChaseNav.goal(from: Vector3, to: Vector3, map, margin: number): Vector3
	local gateX = map.domain.minX
	local crossing = (from.X >= gateX) ~= (to.X >= gateX)
	if crossing then
		local atGate = math.abs(from.Z) <= map.corridor.halfWidth - margin and math.abs(from.X - gateX) <= margin
		if not atGate then
			return ChaseNav.clamp(Vector3.new(gateX, from.Y, 0), map, margin)
		end
	end
	return ChaseNav.clamp(to, map, margin)
end

return ChaseNav

-- Is a point inside a circular arena? Ignores height. Pure.
local ArenaCheck = {}

function ArenaCheck.inside(center: Vector3, radius: number, point: Vector3, tolerance: number): boolean
	local dx, dz = point.X - center.X, point.Z - center.Z
	return math.sqrt(dx * dx + dz * dz) <= radius + tolerance
end

return ArenaCheck

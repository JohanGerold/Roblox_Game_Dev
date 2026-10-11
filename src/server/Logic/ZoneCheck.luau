-- Point-in-box test in the zone's own axes (boundary counts as inside). Pure.
local ZoneCheck = {}

function ZoneCheck.inside(zoneCFrame: CFrame, zoneSize: Vector3, pos: Vector3): boolean
	local rel = zoneCFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= zoneSize.X / 2 and math.abs(rel.Y) <= zoneSize.Y / 2 and math.abs(rel.Z) <= zoneSize.Z / 2
end

return ZoneCheck

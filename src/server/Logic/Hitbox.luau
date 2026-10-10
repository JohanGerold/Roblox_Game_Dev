-- Point-in-shape checks for boss attack hitboxes. Pure: the caller supplies the origin CFrame.
local Hitbox = {}

function Hitbox.contains(hitbox, origin: CFrame, point: Vector3): boolean
	local shape = hitbox.shape
	if shape == "Sphere" then
		return (point - origin.Position).Magnitude <= hitbox.radius
	elseif shape == "Cone" then
		local offset = point - origin.Position
		if offset.Magnitude > hitbox.range then
			return false
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < 1e-6 then
			return true
		end
		local look = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z).Unit
		local cosAngle = math.clamp(look:Dot(flat.Unit), -1, 1)
		return math.deg(math.acos(cosAngle)) <= hitbox.angle / 2
	elseif shape == "Box" then
		local local_ = origin:PointToObjectSpace(point)
		local half = hitbox.size / 2
		return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
	end
	error("unknown hitbox shape: " .. tostring(shape))
end

return Hitbox

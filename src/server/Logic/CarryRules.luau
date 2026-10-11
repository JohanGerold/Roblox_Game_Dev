local CarryRules = {}

export type EggState = {
	readyAt: number,
	headStartUntil: number,
	top: { [number]: boolean },
	ownerUserId: number?,
	carrierUserId: number?,
	lastCarrierUserId: number?,
	regrabUntil: number,
	returnAt: number?,
	expireAt: number,
	returned: boolean,
}

local RANGE_SLACK = 2 -- the prompt's distance and the player's root differ by a stud or two

-- Returns true, or false plus the first failing reason.
function CarryRules.canPickUp(egg: EggState, userId: number, carryingOther: boolean, distance: number, now: number, cfg): (boolean, string?)
	if now < egg.readyAt then
		return false, "not ready"
	end
	if egg.ownerUserId and egg.ownerUserId ~= userId then
		return false, "not yours"
	end
	if egg.carrierUserId then
		return false, "carried"
	end
	if carryingOther then
		return false, "already carrying"
	end
	if distance > cfg.pickupRange + RANGE_SLACK then
		return false, "too far"
	end
	if now < egg.headStartUntil and not egg.top[userId] then
		return false, "head start"
	end
	if userId == egg.lastCarrierUserId and now < egg.regrabUntil then
		return false, "cooldown"
	end
	return true
end

-- "despawn" at the hard limit, "return" once at the return time (if the egg has one), otherwise nil.
function CarryRules.timeoutAction(egg: EggState, now: number): ("despawn" | "return")?
	if now >= egg.expireAt then
		return "despawn"
	end
	if egg.returnAt and now >= egg.returnAt and not egg.returned then
		return "return"
	end
	return nil
end

-- True when `pos` is over the pad's footprint, at most `height` studs above its top face.
function CarryRules.onPad(pos: Vector3, padCFrame: CFrame, padSize: Vector3, height: number): boolean
	local rel = padCFrame:PointToObjectSpace(pos)
	local above = rel.Y - padSize.Y / 2
	return math.abs(rel.X) <= padSize.X / 2 and math.abs(rel.Z) <= padSize.Z / 2 and above >= 0 and above <= height
end

-- Carrying speed: the carrier's own walk speed slowed by the egg.
function CarryRules.carrySpeed(walkSpeed: number, carryFactor: number): number
	return walkSpeed * carryFactor
end

-- `count` points on a horizontal circle around `center`, first at angle 0, evenly spaced.
function CarryRules.ringPositions(center: Vector3, radius: number, count: number): { Vector3 }
	local result = {}
	for i = 1, count do
		local a = (i - 1) * 2 * math.pi / count
		result[i] = center + Vector3.new(radius * math.cos(a), 0, radius * math.sin(a))
	end
	return result
end

return CarryRules

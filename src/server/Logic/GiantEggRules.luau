local GiantEggRules = {}

export type EggState = {
	readyAt: number,
	headStartUntil: number,
	top: { [number]: boolean },
	carrierUserId: number?,
	lastCarrierUserId: number?,
	regrabUntil: number,
	returned: boolean,
}

local RANGE_SLACK = 2 -- the prompt's distance and the player's root differ by a stud or two

-- Returns true, or false plus the first failing reason.
function GiantEggRules.canPickUp(egg: EggState, userId: number, carryingOther: boolean, distance: number, now: number, cfg): (boolean, string?)
	if now < egg.readyAt then
		return false, "not ready"
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

-- "despawn" at the hard limit, "return" once at the return limit, otherwise nil.
function GiantEggRules.timeoutAction(egg: EggState, now: number, cfg): ("despawn" | "return")?
	local age = now - egg.readyAt
	if age >= cfg.despawnAfterSeconds then
		return "despawn"
	end
	if age >= cfg.returnAfterSeconds and not egg.returned then
		return "return"
	end
	return nil
end

-- True when `pos` is over the pad's footprint, at most `height` studs above its top face.
function GiantEggRules.onPad(pos: Vector3, padCFrame: CFrame, padSize: Vector3, height: number): boolean
	local rel = padCFrame:PointToObjectSpace(pos)
	local above = rel.Y - padSize.Y / 2
	return math.abs(rel.X) <= padSize.X / 2 and math.abs(rel.Z) <= padSize.Z / 2 and above >= 0 and above <= height
end

return GiantEggRules

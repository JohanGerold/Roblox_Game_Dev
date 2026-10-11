local function load(mods)
	return require(mods.Logic.CarryRules), require(mods.Shared.Config.Carry)
end

local function egg(overrides)
	local e = { readyAt = 100, headStartUntil = 102, top = { [1] = true }, regrabUntil = 0, returned = false, expireAt = 400 }
	for k, v in overrides or {} do
		e[k] = v
	end
	return e
end

return {
	["pickup is refused before the egg lands"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local ok, reason = Rules.canPickUp(egg(), 1, false, 5, 99, cfg)
		expect.eq(ok, false)
		expect.eq(reason, "not ready")
	end,
	["only top players can grab during the head start"] = function(expect, mods)
		local Rules, cfg = load(mods)
		expect.eq((Rules.canPickUp(egg(), 1, false, 5, 101, cfg)), true)
		local ok, reason = Rules.canPickUp(egg(), 2, false, 5, 101, cfg)
		expect.eq(ok, false)
		expect.eq(reason, "head start")
		expect.eq((Rules.canPickUp(egg(), 2, false, 5, 102, cfg)), true)
	end,
	["a carried egg cannot be grabbed"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local _, reason = Rules.canPickUp(egg({ carrierUserId = 1 }), 2, false, 5, 110, cfg)
		expect.eq(reason, "carried")
	end,
	["a carrier cannot grab a second egg"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local _, reason = Rules.canPickUp(egg(), 2, true, 5, 110, cfg)
		expect.eq(reason, "already carrying")
	end,
	["too far away is refused"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local _, reason = Rules.canPickUp(egg(), 2, false, 13, 110, cfg)
		expect.eq(reason, "too far")
		expect.eq((Rules.canPickUp(egg(), 2, false, 12, 110, cfg)), true)
	end,
	["the last carrier waits out the regrab cooldown"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local e = egg({ lastCarrierUserId = 2, regrabUntil = 110 })
		local _, reason = Rules.canPickUp(e, 2, false, 5, 105, cfg)
		expect.eq(reason, "cooldown")
		expect.eq((Rules.canPickUp(e, 3, false, 5, 105, cfg)), true)
		expect.eq((Rules.canPickUp(e, 2, false, 5, 110, cfg)), true)
	end,
	["only the owner can grab a personal egg"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local e = egg({ ownerUserId = 5, headStartUntil = 100 })
		local ok, reason = Rules.canPickUp(e, 6, false, 5, 110, cfg)
		expect.eq(ok, false)
		expect.eq(reason, "not yours")
		expect.eq((Rules.canPickUp(e, 5, false, 5, 110, cfg)), true)
	end,
	["a personal egg that is not ready reports not ready first"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local _, reason = Rules.canPickUp(egg({ ownerUserId = 5 }), 6, false, 5, 99, cfg)
		expect.eq(reason, "not ready")
	end,
	["timeouts return once then despawn"] = function(expect, mods)
		local Rules = load(mods)
		local e = egg({ returnAt = 180, expireAt = 300 })
		expect.eq(Rules.timeoutAction(e, 179), nil)
		expect.eq(Rules.timeoutAction(e, 180), "return")
		e.returned = true
		expect.eq(Rules.timeoutAction(e, 200), nil)
		expect.eq(Rules.timeoutAction(e, 300), "despawn")
	end,
	["an egg with no returnAt never returns"] = function(expect, mods)
		local Rules = load(mods)
		local e = egg({ expireAt = 300 })
		expect.eq(Rules.timeoutAction(e, 250), nil)
		expect.eq(Rules.timeoutAction(e, 300), "despawn")
	end,
	["pad check uses the pad's own axes and height"] = function(expect, mods)
		local Rules = load(mods)
		local size = Vector3.new(10, 1, 10)
		expect.eq(Rules.onPad(Vector3.new(4, 3, -4), CFrame.new(), size, 8), true)
		expect.eq(Rules.onPad(Vector3.new(6, 3, 0), CFrame.new(), size, 8), false)
		expect.eq(Rules.onPad(Vector3.new(0, 10, 0), CFrame.new(), size, 8), false)
		expect.eq(Rules.onPad(Vector3.new(0, -1, 0), CFrame.new(), size, 8), false)
		local rotated = CFrame.Angles(0, math.rad(45), 0)
		expect.eq(Rules.onPad(Vector3.new(6, 3, 0), rotated, size, 8), true)
	end,
	["carry speed is walk speed times the egg factor"] = function(expect, mods)
		local Rules = load(mods)
		expect.near(Rules.carrySpeed(16, 0.6), 9.6, 0.0001)
		expect.near(Rules.carrySpeed(30, 0.9), 27, 0.0001)
	end,
	["ring of one sits at angle zero"] = function(expect, mods)
		local Rules = load(mods)
		local points = Rules.ringPositions(Vector3.new(5, 2, 7), 10, 1)
		expect.eq(#points, 1)
		expect.eq(points[1], Vector3.new(15, 2, 7))
	end,
	["ring of eight is flat, round and spaced out"] = function(expect, mods)
		local Rules = load(mods)
		local center = Vector3.new(5, 2, 7)
		local points = Rules.ringPositions(center, 10, 8)
		expect.eq(#points, 8)
		local minGap = 2 * 10 * math.sin(math.pi / 8) - 0.01
		for i, p in points do
			expect.eq(p.Y, center.Y, "point " .. i .. " height")
			expect.near((p - center).Magnitude, 10, 0.001, "point " .. i .. " radius")
			local nextP = points[i % #points + 1]
			expect.truthy((p - nextP).Magnitude >= minGap, "point " .. i .. " too close to its neighbour")
		end
	end,
	["ring of zero is empty"] = function(expect, mods)
		local Rules = load(mods)
		expect.eq(#Rules.ringPositions(Vector3.zero, 10, 0), 0)
	end,
}

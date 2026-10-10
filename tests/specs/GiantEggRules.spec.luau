local function load(mods)
	return require(mods.Logic.GiantEggRules), require(mods.Shared.Config.GiantEgg)
end

local function egg(overrides)
	local e = { readyAt = 100, headStartUntil = 102, top = { [1] = true }, regrabUntil = 0, returned = false }
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
	["timeouts return once then despawn"] = function(expect, mods)
		local Rules, cfg = load(mods)
		local e = egg({ readyAt = 0 })
		expect.eq(Rules.timeoutAction(e, 179, cfg), nil)
		expect.eq(Rules.timeoutAction(e, 180, cfg), "return")
		e.returned = true
		expect.eq(Rules.timeoutAction(e, 200, cfg), nil)
		expect.eq(Rules.timeoutAction(e, 300, cfg), "despawn")
		expect.eq(Rules.timeoutAction(egg({ readyAt = 0 }), 300, cfg), "despawn")
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
}

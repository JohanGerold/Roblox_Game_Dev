local function load(mods)
	return require(mods.Logic.CarryCheck), require(mods.Shared.Config.Carry)
end

local SPEED = 14

return {
	["walking at carry speed passes"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		local x = 0
		for i = 1, 16 do
			x += 3.5
			expect.eq(Check.step(state, Vector3.new(x, 0, 0), i * 0.25, true, SPEED, cfg), true, "step " .. i)
		end
	end,
	["a teleport after the grace period fails and keeps the last valid spot"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		expect.eq(Check.step(state, Vector3.new(3.5, 0, 0), 1, true, SPEED, cfg), true)
		expect.eq(Check.step(state, Vector3.new(43.5, 0, 0), 1.25, true, SPEED, cfg), false)
		expect.eq(state.lastValid, Vector3.new(3.5, 0, 0))
	end,
	["one lag gap at carry speed passes"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		expect.eq(Check.step(state, Vector3.new(3.5, 0, 0), 1, true, SPEED, cfg), true)
		expect.eq(Check.step(state, Vector3.new(11.9, 0, 0), 1.6, true, SPEED, cfg), true)
	end,
	["the grace period only records"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		expect.eq(Check.step(state, Vector3.new(30, 0, 0), 0.25, true, SPEED, cfg), true)
		expect.eq(state.lastValid, Vector3.new(30, 0, 0))
	end,
	["samples closer together than the sample interval are skipped"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		expect.eq(Check.step(state, Vector3.new(500, 0, 0), 0.1, true, SPEED, cfg), true)
		expect.eq(state.lastValid, Vector3.zero)
	end,
	["airborne samples never become the drop spot"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		expect.eq(Check.step(state, Vector3.new(0, 20, 0), 1, false, SPEED, cfg), true)
		expect.eq(Check.step(state, Vector3.new(0, 70, 0), 1.25, false, SPEED, cfg), true)
		expect.eq(state.lastValid, Vector3.zero)
	end,
	["vertical movement is not checked"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		expect.eq(Check.step(state, Vector3.new(0, -50, 0), 1, true, SPEED, cfg), true)
	end,
	["trained walker passes at 27"] = function(expect, mods)
		local Check, cfg = load(mods)
		local state = Check.new(Vector3.zero, 0, cfg)
		local x = 0
		for t = 1, 5 do
			x += 6.75
			expect.eq(Check.step(state, Vector3.new(x, 0, 0), t * 0.25, true, 27, cfg), true, "step " .. t)
		end
	end,
}

local origin = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))

return {
	["sphere contains points within radius only"] = function(expect, mods)
		local Hitbox = require(mods.Logic.Hitbox)
		local sphere = { shape = "Sphere", radius = 14 }
		expect.truthy(Hitbox.contains(sphere, origin, Vector3.new(0, 3, -13)))
		expect.eq(Hitbox.contains(sphere, origin, Vector3.new(0, 0, -15)), false)
	end,
	["cone contains points in front within range and angle"] = function(expect, mods)
		local Hitbox = require(mods.Logic.Hitbox)
		local cone = { shape = "Cone", range = 22, angle = 120 }
		expect.truthy(Hitbox.contains(cone, origin, Vector3.new(0, 0, -20)))
		expect.truthy(Hitbox.contains(cone, origin, Vector3.new(10, 0, -10)))
		expect.eq(Hitbox.contains(cone, origin, Vector3.new(0, 0, 20)), false, "behind")
		expect.eq(Hitbox.contains(cone, origin, Vector3.new(20, 0, -5)), false, "outside angle")
		expect.eq(Hitbox.contains(cone, origin, Vector3.new(0, 0, -23)), false, "out of range")
	end,
	["cone counts its own origin as inside"] = function(expect, mods)
		local Hitbox = require(mods.Logic.Hitbox)
		expect.truthy(Hitbox.contains({ shape = "Cone", range = 22, angle = 120 }, origin, Vector3.zero))
	end,
	["box contains points inside its size"] = function(expect, mods)
		local Hitbox = require(mods.Logic.Hitbox)
		local box = { shape = "Box", size = Vector3.new(10, 10, 10) }
		expect.truthy(Hitbox.contains(box, origin, Vector3.new(4, 4, -4)))
		expect.eq(Hitbox.contains(box, origin, Vector3.new(6, 0, 0)), false)
	end,
	["unknown shape errors"] = function(expect, mods)
		local Hitbox = require(mods.Logic.Hitbox)
		expect.errors(function()
			Hitbox.contains({ shape = "Triangle" }, origin, Vector3.zero)
		end)
	end,
	["circle uses flat distance and height"] = function(expect, mods)
		local Hitbox = require(mods.Logic.Hitbox)
		local circle = { shape = "Circle", radius = 7, height = 10 }
		expect.truthy(Hitbox.contains(circle, origin, Vector3.new(6, 6, 0)))
		expect.eq(Hitbox.contains(circle, origin, Vector3.new(0, 11, 0)), false, "too high")
		expect.eq(Hitbox.contains(circle, origin, Vector3.new(5, 0, 5)), false, "flat 7.07")
		expect.truthy(Hitbox.contains(circle, origin, Vector3.new(4.9, -9, 4.9)))
	end,
}

return {
	["points within radius plus tolerance are inside"] = function(expect, mods)
		local ArenaCheck = require(mods.Logic.ArenaCheck)
		local center = Vector3.zero
		expect.eq(ArenaCheck.inside(center, 70, Vector3.new(74, 0, 0), 5), true)
		expect.eq(ArenaCheck.inside(center, 70, Vector3.new(0, 0, -69), 0), true)
	end,
	["points past the tolerance are outside"] = function(expect, mods)
		local ArenaCheck = require(mods.Logic.ArenaCheck)
		expect.eq(ArenaCheck.inside(Vector3.zero, 70, Vector3.new(76, 0, 0), 5), false)
		expect.eq(ArenaCheck.inside(Vector3.zero, 70, Vector3.new(0, 0, 71), 0), false)
	end,
	["height is ignored"] = function(expect, mods)
		local ArenaCheck = require(mods.Logic.ArenaCheck)
		expect.eq(ArenaCheck.inside(Vector3.zero, 70, Vector3.new(0, 500, 0), 0), true)
	end,
}

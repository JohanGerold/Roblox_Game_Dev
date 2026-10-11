local function load(mods)
	return require(mods.Logic.ChaseNav), require(mods.Shared.Config.Map)
end

local MARGIN = 5

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

local function near(expect, a: Vector3, b: Vector3, msg: string)
	expect.truthy((a - b).Magnitude < 0.01, msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

return {
	["home is never allowed"] = function(expect, mods)
		local Nav, map = load(mods)
		expect.near(Nav.clamp(v(200, 0, 0), map, MARGIN).X, 245, 0.001)
	end,
	["inside the corridor is unchanged"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.clamp(v(500, 0, 10), map, MARGIN), v(500, 0, 10), "corridor")
	end,
	["outside the corridor wall is pulled in"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.clamp(v(500, 0, 30), map, MARGIN), v(500, 0, 15), "corridor wall")
	end,
	["inside the domain is unchanged"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.clamp(v(850, 0, 80), map, MARGIN), v(850, 0, 80), "domain")
	end,
	["domain corner is pulled in"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.clamp(v(950, 0, 120), map, MARGIN), v(915, 0, 85), "corner")
	end,
	["from a domain corner to the corridor goes via the gate"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.goal(v(880, 0, 70), v(500, 0, 0), map, MARGIN), v(740, 0, 0), "gate")
	end,
	["from the corridor to a domain corner goes via the gate"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.goal(v(600, 0, 0), v(880, 0, 70), map, MARGIN), v(740, 0, 0), "gate")
	end,
	["once at the gate it goes straight"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.goal(v(741, 0, 0), v(500, 0, 0), map, MARGIN), v(500, 0, 0), "straight")
	end,
	["inside the domain it goes straight"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.goal(v(800, 0, 0), v(880, 0, 70), map, MARGIN), v(880, 0, 70), "domain")
	end,
	["a target inside home is clamped to the home edge"] = function(expect, mods)
		local Nav, map = load(mods)
		near(expect, Nav.goal(v(300, 0, 0), v(100, 0, 0), map, MARGIN), v(245, 0, 0), "home edge")
	end,
}

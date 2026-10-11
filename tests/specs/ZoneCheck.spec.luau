local function load(mods)
	return require(mods.Logic.ZoneCheck)
end

return {
	["points inside and outside an axis-aligned zone"] = function(expect, mods)
		local Zone = load(mods)
		local cf, size = CFrame.new(120, 20, 0), Vector3.new(240, 40, 120)
		expect.eq(Zone.inside(cf, size, Vector3.new(10, 3, 0)), true)
		expect.eq(Zone.inside(cf, size, Vector3.new(239.9, 3, 59)), true)
		expect.eq(Zone.inside(cf, size, Vector3.new(241, 3, 0)), false)
		expect.eq(Zone.inside(cf, size, Vector3.new(100, 3, 61)), false)
		expect.eq(Zone.inside(cf, size, Vector3.new(100, 41, 0)), false)
	end,
	["a rotated zone uses its own axes"] = function(expect, mods)
		local Zone = load(mods)
		local cf, size = CFrame.Angles(0, math.rad(90), 0), Vector3.new(10, 4, 2)
		expect.eq(Zone.inside(cf, size, Vector3.new(0, 0, 4)), true)
		expect.eq(Zone.inside(cf, size, Vector3.new(4, 0, 0)), false)
	end,
}

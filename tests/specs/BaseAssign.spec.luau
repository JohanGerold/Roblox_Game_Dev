return {
	["lowest free base is chosen"] = function(expect, mods)
		local BaseAssign = require(mods.Logic.BaseAssign)
		expect.eq(BaseAssign.lowestFree({}, 16), 1)
		expect.eq(BaseAssign.lowestFree({ [1] = true, [2] = true }, 16), 3)
	end,
	["freed base is reused"] = function(expect, mods)
		local BaseAssign = require(mods.Logic.BaseAssign)
		expect.eq(BaseAssign.lowestFree({ [1] = true, [3] = true }, 16), 2)
	end,
	["no free base returns nil"] = function(expect, mods)
		local BaseAssign = require(mods.Logic.BaseAssign)
		local full = {}
		for i = 1, 16 do
			full[i] = true
		end
		expect.eq(BaseAssign.lowestFree(full, 16), nil)
	end,
}

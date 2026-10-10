return {
	["formats small numbers"] = function(expect, mods)
		local Format = require(mods.Shared.Util.Format)
		expect.eq(Format.number(0), "0")
		expect.eq(Format.number(999), "999")
		expect.eq(Format.number(12.7), "12")
	end,
	["formats thousands to trillions"] = function(expect, mods)
		local Format = require(mods.Shared.Util.Format)
		expect.eq(Format.number(1000), "1K")
		expect.eq(Format.number(1200), "1.2K")
		expect.eq(Format.number(1530000), "1.53M")
		expect.eq(Format.number(2.5e9), "2.5B")
		expect.eq(Format.number(7e12), "7T")
	end,
	["formats negatives"] = function(expect, mods)
		local Format = require(mods.Shared.Util.Format)
		expect.eq(Format.number(-1500), "-1.5K")
	end,
	["handles extremes without erroring"] = function(expect, mods)
		local Format = require(mods.Shared.Util.Format)
		expect.eq(Format.number(1e300), "1e+300")
		expect.eq(Format.number(math.huge), "∞")
		expect.eq(Format.number(0 / 0), "0")
	end,
	["rounds up across a suffix boundary"] = function(expect, mods)
		local Format = require(mods.Shared.Util.Format)
		expect.eq(Format.number(999999), "1M")
	end,
}

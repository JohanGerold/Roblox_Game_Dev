return {
	["keeps loading while the player is present and within the timeout"] = function(expect, mods)
		local P = require(mods.Logic.LoadPolicy)
		expect.eq(P.shouldCancel(true, 5, 120), false)
		expect.eq(P.shouldCancel(true, 120, 120), false)
	end,
	["cancels when the player has left"] = function(expect, mods)
		local P = require(mods.Logic.LoadPolicy)
		expect.eq(P.shouldCancel(false, 1, 120), true)
	end,
	["cancels after the timeout so a DataStore outage cannot hang a player forever"] = function(expect, mods)
		local P = require(mods.Logic.LoadPolicy)
		expect.eq(P.shouldCancel(true, 121, 120), true)
	end,
	["default timeout is 120 seconds"] = function(expect, mods)
		expect.eq(require(mods.Logic.LoadPolicy).TIMEOUT_SECONDS, 120)
	end,
}

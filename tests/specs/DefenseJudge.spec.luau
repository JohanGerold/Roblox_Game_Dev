local IMPACT = 100

local function load(mods)
	return require(mods.Logic.DefenseJudge), require(mods.Shared.Config.Combat)
end

-- Accepts a claim as if it reached the server 0.05 s after the press.
local function claim(DJ, Combat, h, kind, pressTime)
	return DJ.accept(h, kind, pressTime, pressTime + 0.05, Combat)
end

return {
	["accept rejects stale claims"] = function(expect, mods)
		local DJ, Combat = load(mods)
		expect.eq(DJ.accept(DJ.newHistory(), "Parry", 99.6, 100.0, Combat), false)
	end,
	["accept rejects future claims"] = function(expect, mods)
		local DJ, Combat = load(mods)
		expect.eq(DJ.accept(DJ.newHistory(), "Parry", 100.1, 100.0, Combat), false)
	end,
	["accept enforces the cooldown"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local h = DJ.newHistory()
		expect.eq(DJ.accept(h, "Dodge", 99.0, 99.05, Combat), true)
		expect.eq(DJ.accept(h, "Dodge", 99.5, 99.6, Combat), false)
		expect.eq(DJ.accept(h, "Dodge", 99.9, 100.0, Combat), true)
	end,
	["history is trimmed to the configured size"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local h = DJ.newHistory()
		for i = 1, 6 do
			expect.eq(claim(DJ, Combat, h, "Parry", 90 + i), true)
		end
		expect.eq(#h.Parry, Combat.claimHistorySize)
	end,
	["parry inside the window parries"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local h = DJ.newHistory()
		claim(DJ, Combat, h, "Parry", 99.85)
		expect.eq(DJ.judge(h, IMPACT, false, Combat), "Parried")
	end,
	["parry on an unparryable attack is a hit"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local h = DJ.newHistory()
		claim(DJ, Combat, h, "Parry", 99.85)
		expect.eq(DJ.judge(h, IMPACT, true, Combat), "Hit")
	end,
	["parry outside the window is a hit"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local h = DJ.newHistory()
		claim(DJ, Combat, h, "Parry", 99.7)
		expect.eq(DJ.judge(h, IMPACT, false, Combat), "Hit")
	end,
	["dodge timing picks perfect, dodged or hit"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local a, b, c = DJ.newHistory(), DJ.newHistory(), DJ.newHistory()
		claim(DJ, Combat, a, "Dodge", 99.9)
		claim(DJ, Combat, b, "Dodge", 99.75)
		claim(DJ, Combat, c, "Dodge", 99.65)
		expect.eq(DJ.judge(a, IMPACT, false, Combat), "PerfectDodge")
		expect.eq(DJ.judge(b, IMPACT, false, Combat), "Dodged")
		expect.eq(DJ.judge(c, IMPACT, false, Combat), "Hit")
	end,
	["claims after impact do not count"] = function(expect, mods)
		local DJ, Combat = load(mods)
		local h = DJ.newHistory()
		DJ.accept(h, "Dodge", 100.05, 100.1, Combat)
		expect.eq(DJ.judge(h, IMPACT, false, Combat), "Hit")
	end,
	["no claims is a hit"] = function(expect, mods)
		local DJ, Combat = load(mods)
		expect.eq(DJ.judge(DJ.newHistory(), IMPACT, false, Combat), "Hit")
	end,
}

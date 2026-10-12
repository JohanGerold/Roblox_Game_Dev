local function load(mods)
	return require(mods.Logic.DropRoll), require(mods.Shared.Config.Bosses).Boss_Lofy.drops
end

-- Replays queued numbers; records whether NextInteger was asked for.
local function fakeRng(numbers, integers)
	local rng = { integerCalls = 0 }
	local n, i = 0, 0
	function rng:NextNumber()
		n += 1
		return numbers[n]
	end
	function rng:NextInteger(lo, hi)
		self.integerCalls += 1
		i += 1
		return integers[i] or lo
	end
	return rng
end

return {
	["armor drops below the chance"] = function(expect, mods)
		local Roll, drops = load(mods)
		local result = Roll.roll(drops, {}, 0, 4, fakeRng({ 0.1, 0.9 }, { 1 }))
		expect.eq(result.armorId, "Gogo_AshCrown")
		expect.eq(result.moveCopy, false)
	end,
	["no armor above the chance"] = function(expect, mods)
		local Roll, drops = load(mods)
		expect.eq(Roll.roll(drops, {}, 0, 4, fakeRng({ 0.9, 0.9 }, {})).armorId, nil)
	end,
	["owned pieces are never dropped"] = function(expect, mods)
		local Roll, drops = load(mods)
		local rng = fakeRng({ 0.0, 0.9 }, {})
		expect.eq(Roll.roll(drops, { "Gogo_AshCrown" }, 0, 4, rng).armorId, nil)
		expect.eq(rng.integerCalls, 0)
	end,
	["move copy below the chance"] = function(expect, mods)
		local Roll, drops = load(mods)
		local result = Roll.roll(drops, {}, 0, 4, fakeRng({ 0.9, 0.01 }, {}))
		expect.eq(result.moveCopy, true)
		expect.eq(result.armorId, nil)
	end,
	["no copy when all moves are copied"] = function(expect, mods)
		local Roll, drops = load(mods)
		expect.eq(Roll.roll(drops, {}, 4, 4, fakeRng({ 0.9, 0.0 }, {})).moveCopy, false)
	end,
	["no copy above the chance"] = function(expect, mods)
		local Roll, drops = load(mods)
		expect.eq(Roll.roll(drops, {}, 0, 4, fakeRng({ 0.9, 0.5 }, {})).moveCopy, false)
	end,
	["a real rng gives the right shape"] = function(expect, mods)
		local Roll, drops = load(mods)
		local result = Roll.roll(drops, {}, 0, 4, Random.new(1))
		expect.truthy(result.armorId == nil or result.armorId == "Gogo_AshCrown")
		expect.eq(type(result.moveCopy), "boolean")
	end,
}

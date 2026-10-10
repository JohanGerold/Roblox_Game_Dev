local function load(mods)
	return require(mods.Logic.StandPlace)
end

local function stands()
	return {
		a = { id = "Lofy_Base", level = 1, slot = nil },
		b = { id = "Zoru_Base", level = 1, slot = 1 },
	}
end

return {
	["placing into an empty slot sets it"] = function(expect, mods)
		local StandPlace = load(mods)
		local s = stands()
		local ok = StandPlace.place(s, "a", 2, 4)
		expect.truthy(ok)
		expect.eq(s.a.slot, 2)
		expect.eq(s.b.slot, 1)
	end,
	["placing into an occupied slot sends the old stand to storage"] = function(expect, mods)
		local StandPlace = load(mods)
		local s = stands()
		expect.truthy(StandPlace.place(s, "a", 1, 4))
		expect.eq(s.a.slot, 1)
		expect.eq(s.b.slot, nil)
	end,
	["nil slot stores the stand"] = function(expect, mods)
		local StandPlace = load(mods)
		local s = stands()
		expect.truthy(StandPlace.place(s, "b", nil, 4))
		expect.eq(s.b.slot, nil)
	end,
	["locked or invalid slots are rejected and change nothing"] = function(expect, mods)
		local StandPlace = load(mods)
		for _, slot in { 5, 0, 1.5, -1 } do
			local s = stands()
			local ok, reason = StandPlace.place(s, "a", slot, 4)
			expect.eq(ok, false, tostring(slot))
			expect.eq(reason, "slot locked")
			expect.eq(s.a.slot, nil)
			expect.eq(s.b.slot, 1)
		end
	end,
	["unknown stand is rejected"] = function(expect, mods)
		local StandPlace = load(mods)
		local ok, reason = StandPlace.place(stands(), "zzz", 1, 4)
		expect.eq(ok, false)
		expect.eq(reason, "unknown stand")
	end,
	["firstFreeSlot finds the lowest free unlocked slot"] = function(expect, mods)
		local StandPlace = load(mods)
		local s = {
			a = { id = "Lofy_Base", level = 1, slot = 1 },
			b = { id = "Lofy_Base", level = 1, slot = 3 },
		}
		expect.eq(StandPlace.firstFreeSlot(s, 4), 2)
		s.c = { id = "Lofy_Base", level = 1, slot = 2 }
		s.d = { id = "Lofy_Base", level = 1, slot = 4 }
		expect.eq(StandPlace.firstFreeSlot(s, 4), nil)
	end,
}

local function load(mods)
	return require(mods.Logic.Uid)
end

return {
	["uid has prefix and 8 hex chars"] = function(expect, mods)
		local Uid = load(mods)
		local uid = Uid.new("c", {}, Random.new(1))
		expect.truthy(uid:match("^c_%x%x%x%x%x%x%x%x$"), uid)
		expect.eq(uid, uid:lower())
	end,
	["same seed gives same uid"] = function(expect, mods)
		local Uid = load(mods)
		expect.eq(Uid.new("e", {}, Random.new(9)), Uid.new("e", {}, Random.new(9)))
	end,
	["taken uid is never returned"] = function(expect, mods)
		local Uid = load(mods)
		local first = Uid.new("c", {}, Random.new(5))
		local second = Uid.new("c", { [first] = true }, Random.new(5))
		expect.truthy(first ~= second, "collision not avoided")
	end,
}

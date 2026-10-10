local CONFIG = { stageId = "Stage1", baseCount = 2, slotGrid = 2 }

local function part(parent: Instance, tag: string?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Parent = parent
	if tag then
		p:AddTag(tag)
	end
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	return p
end

local function makeMap(): Folder
	local root = Instance.new("Folder")
	for i = 1, CONFIG.baseCount do
		local base = Instance.new("Model")
		base:AddTag("Base")
		base:SetAttribute("BaseIndex", i)
		base.Parent = root
		part(base, "EggDeliveryPad")
		part(base, "BaseSpawn")
		part(base, "BaseSign")
		for s = 1, CONFIG.slotGrid ^ 2 do
			part(base, "StandSlot", { SlotIndex = s })
		end
	end
	local arena = Instance.new("Model")
	arena:AddTag("BossArena")
	arena:SetAttribute("StageId", CONFIG.stageId)
	arena.Parent = root
	part(arena, "BossSpawn")
	part(arena, "GiantEggSpawn")
	part(root, "Treadmill")
	part(root, "Sandbag")
	part(root, "WeaponShop")
	return root
end

local function contains(list: { string }, text: string): boolean
	for _, line in list do
		if line == text then
			return true
		end
	end
	return false
end

local function firstTagged(root: Instance, tag: string): Instance
	for _, d in root:GetDescendants() do
		if d:HasTag(tag) then
			return d
		end
	end
	error("no instance tagged " .. tag)
end

return {
	["valid map has no problems"] = function(expect, mods)
		local check = require(mods.Logic.MapContract).check
		local root = makeMap()
		local problems = check(root, CONFIG)
		root:Destroy()
		expect.eq(#problems, 0, table.concat(problems, "; "))
	end,
	["missing delivery pad is reported"] = function(expect, mods)
		local check = require(mods.Logic.MapContract).check
		local root = makeMap()
		firstTagged(root, "EggDeliveryPad"):Destroy()
		local problems = check(root, CONFIG)
		root:Destroy()
		expect.truthy(contains(problems, "Base 1: missing EggDeliveryPad"), table.concat(problems, "; "))
	end,
	["duplicate base index is reported"] = function(expect, mods)
		local check = require(mods.Logic.MapContract).check
		local root = makeMap()
		local bases = {}
		for _, d in root:GetDescendants() do
			if d:HasTag("Base") then
				table.insert(bases, d)
			end
		end
		bases[2]:SetAttribute("BaseIndex", 1)
		local problems = check(root, CONFIG)
		root:Destroy()
		expect.truthy(contains(problems, "Base: duplicate BaseIndex 1"), table.concat(problems, "; "))
	end,
	["missing giant egg spawn is reported"] = function(expect, mods)
		local check = require(mods.Logic.MapContract).check
		local root = makeMap()
		firstTagged(root, "GiantEggSpawn"):Destroy()
		local problems = check(root, CONFIG)
		root:Destroy()
		expect.truthy(contains(problems, "BossArena: missing GiantEggSpawn"), table.concat(problems, "; "))
	end,
	["wrong slot count is reported"] = function(expect, mods)
		local check = require(mods.Logic.MapContract).check
		local root = makeMap()
		firstTagged(root, "StandSlot"):Destroy()
		local problems = check(root, CONFIG)
		root:Destroy()
		local found = false
		for _, line in problems do
			if line:sub(1, 8) == "Base 1: " and line:find("SlotIndex") then
				found = true
			end
		end
		expect.truthy(found, table.concat(problems, "; "))
	end,
	["missing shop is reported"] = function(expect, mods)
		local check = require(mods.Logic.MapContract).check
		local root = makeMap()
		firstTagged(root, "WeaponShop"):Destroy()
		local problems = check(root, CONFIG)
		root:Destroy()
		expect.truthy(contains(problems, "Map: expected 1 WeaponShop, found 0"), table.concat(problems, "; "))
	end,
}

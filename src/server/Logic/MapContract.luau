-- Checks a map folder against the tag contract (spec section 4). Pure: pass any root Instance.
local MapContract = {}

local function tagged(root: Instance, tag: string): { Instance }
	local result = {}
	for _, d in root:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(result, d)
		end
	end
	return result
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v % 1 == 0 and v >= lo and v <= hi
end

-- Exactly one part with this tag inside `owner`; reports `<where>: missing <tag>` or a count problem.
local function expectOne(problems: { string }, owner: Instance, tag: string, where: string)
	local found = tagged(owner, tag)
	if #found == 0 then
		table.insert(problems, string.format("%s: missing %s", where, tag))
	elseif #found > 1 then
		table.insert(problems, string.format("%s: expected 1 %s, found %d", where, tag, #found))
	end
end

local function checkBase(problems: { string }, base: Instance, map)
	local where = "Base " .. tostring(base:GetAttribute("BaseIndex"))
	expectOne(problems, base, "EggDeliveryPad", where)
	expectOne(problems, base, "BaseSpawn", where)
	expectOne(problems, base, "BaseSign", where)

	local slotCount = map.slotGrid ^ 2
	local seen, bad = {}, false
	local slots = tagged(base, "StandSlot")
	for _, slot in slots do
		local idx = slot:GetAttribute("SlotIndex")
		if not isInt(idx, 1, slotCount) or seen[idx] then
			bad = true
		else
			seen[idx] = true
		end
	end
	if bad or #slots ~= slotCount then
		table.insert(problems, string.format("%s: needs %d StandSlot parts with unique SlotIndex 1..%d, found %d", where, slotCount, slotCount, #slots))
	end
end

function MapContract.check(root: Instance, map): { string }
	local problems = {}

	local bases = tagged(root, "Base")
	if #bases ~= map.baseCount then
		table.insert(problems, string.format("Map: expected %d Base, found %d", map.baseCount, #bases))
	end
	local seenIndex = {}
	for _, base in bases do
		local idx = base:GetAttribute("BaseIndex")
		if not isInt(idx, 1, map.baseCount) then
			table.insert(problems, string.format("Base: invalid BaseIndex %s", tostring(idx)))
		elseif seenIndex[idx] then
			table.insert(problems, string.format("Base: duplicate BaseIndex %d", idx))
		else
			seenIndex[idx] = true
		end
		checkBase(problems, base, map)
	end

	local arenas = tagged(root, "BossArena")
	if #arenas ~= 1 then
		table.insert(problems, string.format("Map: expected 1 BossArena, found %d", #arenas))
	end
	for _, arena in arenas do
		if arena:GetAttribute("StageId") ~= map.stageId then
			table.insert(problems, string.format("BossArena: StageId should be %s", map.stageId))
		end
		expectOne(problems, arena, "BossSpawn", "BossArena")
		expectOne(problems, arena, "GiantEggSpawn", "BossArena")
	end

	for _, tag in { "Treadmill", "Sandbag" } do
		local n = #tagged(root, tag)
		if n < 1 then
			table.insert(problems, string.format("Map: expected at least 1 %s, found 0", tag))
		end
	end
	local shops = #tagged(root, "WeaponShop")
	if shops ~= 1 then
		table.insert(problems, string.format("Map: expected 1 WeaponShop, found %d", shops))
	end

	for _, tag in { "HomeZone", "SpeedSign" } do
		local n = #tagged(root, tag)
		if n ~= 1 then
			table.insert(problems, string.format("Map: expected 1 %s, found %d", tag, n))
		end
	end
	if #tagged(root, "FieldEggSpawn") < 1 then
		table.insert(problems, "Map: expected at least 1 FieldEggSpawn, found 0")
	end

	table.sort(problems)
	return problems
end

return MapContract

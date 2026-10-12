local DataTemplate = require(script.Parent.DataTemplate)

local Migrations = {}

-- Stage 1 roster rename (version 1 -> 2): placeholder stand and armor ids become the Jujutsu Kaisen ones.
local STAND_RENAMES = {
	Lofy_Base = "Yuju_Base",
	Zoru_Base = "Nobaru_Base",
	Narto_Base = "Megumu_Base",
	Gokku_Base = "Mechamaro_Base",
	Gokku_Red = "Toudo_Base",
	Gokku_Blue = "Gojou_Blindfold",
}
local ARMOR_RENAMES = {
	Lofy_Hat = "Gogo_AshCrown",
}

-- steps[n] upgrades a save from version n to n + 1 (version 1 is the first layout).
local steps: { [number]: (data: { [string]: any }) -> () } = {
	[1] = function(data)
		if type(data.characters) == "table" then
			for _, stand in data.characters do
				if type(stand) == "table" and STAND_RENAMES[stand.id] then
					stand.id = STAND_RENAMES[stand.id]
				end
			end
		end
		local armor = data.armor
		if type(armor) == "table" then
			if type(armor.owned) == "table" then
				for i, id in armor.owned do
					if ARMOR_RENAMES[id] then
						armor.owned[i] = ARMOR_RENAMES[id]
					end
				end
			end
			if type(armor.equipped) == "table" then
				for slot, id in armor.equipped do
					if ARMOR_RENAMES[id] then
						armor.equipped[slot] = ARMOR_RENAMES[id]
					end
				end
			end
		end
	end,
}

local function isArray(t: { [any]: any }): boolean
	return t[1] ~= nil
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fills keys missing from `data` using `template`. Never overwrites existing values and
-- never merges into arrays or id-keyed maps (those templates are empty or list-shaped).
local function fillMissing(data: { [any]: any }, template: { [any]: any })
	for key, defaultValue in template do
		local current = data[key]
		if current == nil then
			data[key] = deepCopy(defaultValue)
		elseif type(current) == "table" and type(defaultValue) == "table" and not isArray(defaultValue) then
			fillMissing(current, defaultValue)
		end
	end
end

function Migrations.run(data: { [string]: any }): { [string]: any }
	local version = data.version
	if type(version) ~= "number" then
		version = 0
	end
	while version < DataTemplate.CURRENT_VERSION do
		local step = steps[version]
		if step then
			step(data)
		end
		version += 1
	end
	fillMissing(data, DataTemplate.new())
	data.version = DataTemplate.CURRENT_VERSION
	return data
end

return Migrations

local DataTemplate = require(script.Parent.DataTemplate)

local Migrations = {}

-- steps[n] upgrades a save from version n to n + 1. None yet (version 1 is the first layout).
local steps: { [number]: (data: { [string]: any }) -> () } = {}

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

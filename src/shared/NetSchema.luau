-- Every client<->server message and its argument rules (spec section 7). Pure; no Roblox wiring.
-- Arg types: number (finite), int, string (<=200 chars), boolean, table (flat, <=64 entries,
-- primitive values), any (number|string|boolean); a trailing "?" makes an argument optional.
local NetSchema = {}

local MAX_STRING = 200
local MAX_TABLE_ENTRIES = 64

NetSchema.definitions = {
	-- client -> server
	Attack = { dir = "c2s", args = { "int", "string" }, rate = 10 },
	UseAbility = { dir = "c2s", args = { "int" }, rate = 5 },
	Defend = { dir = "c2s", args = { "string", "number" }, rate = 6 },
	Counter = { dir = "c2s", args = {}, rate = 2 },
	HatchEgg = { dir = "c2s", args = { "string" } },
	PlaceStand = { dir = "c2s", args = { "string", "int?" } },
	SetTeam = { dir = "c2s", args = { "table" } },
	UpgradeStand = { dir = "c2s", args = { "string" } },
	BuyWeapon = { dir = "c2s", args = { "string" } },
	Equip = { dir = "c2s", args = { "string", "string" } },
	Train = { dir = "c2s", args = { "string", "boolean" } },
	Rebirth = { dir = "c2s", args = {} },
	SetKeybinds = { dir = "c2s", args = { "table" } },
	SetSetting = { dir = "c2s", args = { "string", "any" } },
	RequestData = { dir = "c2s", args = {} },
	-- server -> client (not validated; the server is trusted)
	DataInit = { dir = "s2c", args = { "table" } },
	DataChanged = { dir = "s2c", args = { "string", "any" } },
	BossState = { dir = "s2c", args = { "table" } },
	BossAttack = { dir = "s2c", args = { "string", "number" } },
	HitResult = { dir = "s2c", args = { "table" } },
	DamageNumbers = { dir = "s2c", args = { "table" }, unreliable = true },
	GiantEggState = { dir = "s2c", args = { "table" } },
	Announce = { dir = "s2c", args = { "string", "string" } },
}

NetSchema.defaultRate = 4

local function finite(v): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function primitive(v): boolean
	local t = type(v)
	return finite(v) or t == "boolean" or (t == "string" and #v <= MAX_STRING)
end

local function checkValue(typeName: string, v): boolean
	if typeName == "number" then
		return finite(v)
	elseif typeName == "int" then
		return finite(v) and v == math.floor(v)
	elseif typeName == "string" then
		return type(v) == "string" and #v <= MAX_STRING
	elseif typeName == "boolean" then
		return type(v) == "boolean"
	elseif typeName == "any" then
		return primitive(v)
	elseif typeName == "table" then
		if type(v) ~= "table" then
			return false
		end
		local count = 0
		for k, value in v do
			count += 1
			if count > MAX_TABLE_ENTRIES then
				return false
			end
			local keyOk = (type(k) == "string" and #k <= MAX_STRING) or (type(k) == "number" and finite(k))
			if not keyOk or not primitive(value) then
				return false
			end
		end
		return true
	end
	return false
end

-- Returns true, or false plus a reason. Only client->server messages can be validated.
function NetSchema.validate(name: string, args: { any }): (boolean, string?)
	local def = NetSchema.definitions[name]
	if not def or def.dir ~= "c2s" then
		return false, "unknown message"
	end
	local given = args.n or #args
	if given > #def.args then
		return false, "too many arguments"
	end
	for i, typeName in def.args do
		local optional = typeName:sub(-1) == "?"
		local base = optional and typeName:sub(1, -2) or typeName
		local value = args[i]
		if value == nil then
			if not optional then
				return false, "missing argument " .. i
			end
		elseif not checkValue(base, value) then
			return false, "bad argument " .. i
		end
	end
	return true
end

return NetSchema

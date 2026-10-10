-- Roblox wiring for NetSchema: creates remotes (server), validates and rate-limits every
-- client->server call, and gives both sides a tiny On/Fire API.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetSchema = require(script.Parent.NetSchema)
local RateLimiter = require(script.Parent.Util.RateLimiter)

local Net = {}

local FOLDER_NAME = "Remotes"
local limiters: { [string]: any } = {}
local lastWarn: { [string]: number } = {}
local violations = RateLimiter.new(50, 10) -- 50 rejected calls in 10 s => kick

local function remoteFolder(): Folder
	if RunService:IsServer() then
		return ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.InitServer()
	assert(RunService:IsServer(), "Net.InitServer is server-only")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for name, def in NetSchema.definitions do
		local remote = Instance.new(def.unreliable and "UnreliableRemoteEvent" or "RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		violations:remove(player.UserId)
		for _, limiter in limiters do
			limiter:remove(player.UserId)
		end
	end)
end

local function reject(player: Player, name: string, reason: string)
	local key = player.UserId .. ":" .. name
	local now = os.clock()
	if not lastWarn[key] or now - lastWarn[key] > 60 then
		lastWarn[key] = now
		warn(string.format("[Net] dropped %s from %s: %s", name, player.Name, reason))
	end
	if not violations:allow(player.UserId, now) then
		player:Kick("Too many invalid requests.")
	end
end

function Net.Server(name: string)
	local def = assert(NetSchema.definitions[name], "unknown message " .. name)
	local remote = remoteFolder():WaitForChild(name) :: RemoteEvent
	local object = {}

	function object:On(handler: (Player, ...any) -> ())
		assert(def.dir == "c2s", name .. " is not a client->server message")
		local limiter = RateLimiter.new(def.rate or NetSchema.defaultRate, 1)
		limiters[name] = limiter
		remote.OnServerEvent:Connect(function(player, ...)
			if not limiter:allow(player.UserId, os.clock()) then
				return reject(player, name, "rate limit")
			end
			local args = table.pack(...)
			local ok, reason = NetSchema.validate(name, args)
			if not ok then
				return reject(player, name, reason or "invalid")
			end
			local success, err = xpcall(handler, debug.traceback, player, ...)
			if not success then
				warn(string.format("[Net] handler error in %s: %s", name, tostring(err)))
			end
		end)
	end

	function object:Fire(player: Player, ...)
		remote:FireClient(player, ...)
	end

	function object:FireAll(...)
		remote:FireAllClients(...)
	end

	return object
end

function Net.Client(name: string)
	local def = assert(NetSchema.definitions[name], "unknown message " .. name)
	local remote = remoteFolder():WaitForChild(name) :: RemoteEvent
	local object = {}

	function object:On(handler: (...any) -> ())
		assert(def.dir == "s2c", name .. " is not a server->client message")
		remote.OnClientEvent:Connect(handler)
	end

	function object:Fire(...)
		assert(def.dir == "c2s", name .. " is not a client->server message")
		remote:FireServer(...)
	end

	return object
end

return Net

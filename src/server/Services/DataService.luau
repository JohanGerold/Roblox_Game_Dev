-- Loads and saves player data with ProfileStore (session locked). The only writer of player data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Server = script.Parent.Parent
local ProfileStore = require(Server.Packages.ProfileStore)
local DataTemplate = require(Server.Logic.DataTemplate)
local Migrations = require(Server.Logic.Migrations)
local LoadPolicy = require(Server.Logic.LoadPolicy)

local STORE_NAME = RunService:IsStudio() and "PlayerData_Dev" or "PlayerData_Live"

local DataService = {}
DataService.Loaded = Signal.new() -- Fire(player) once a player's data is ready

local store = ProfileStore.New(STORE_NAME, DataTemplate.new())
local profiles: { [Player]: any } = {}
local dataInit, dataChanged

-- Read-only use: change data through DataService:Update.
function DataService:Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Sets data[key] = fn(old) and tells that player's client. Returns false if no data is loaded.
function DataService:Update(player: Player, key: string, fn: (any) -> any): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	local value = fn(profile.Data[key])
	profile.Data[key] = value
	dataChanged:Fire(player, key, value)
	return true
end

local function sendInit(player: Player)
	local profile = profiles[player]
	if profile then
		dataInit:Fire(player, profile.Data)
	end
end

local function loadPlayer(player: Player)
	local startedAt = os.clock()
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return LoadPolicy.shouldCancel(player.Parent == Players, os.clock() - startedAt, LoadPolicy.TIMEOUT_SECONDS)
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			player:Kick("Couldn't load your data, please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	Migrations.run(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		print("[Data] session ended", player.UserId)
		if player.Parent == Players then
			player:Kick("Your data session ended, please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	profiles[player] = profile
	print("[Data] loaded", player.UserId)
	DataService.Loaded:Fire(player)
	sendInit(player)
end

function DataService:Init()
	dataInit = Net.Server("DataInit")
	dataChanged = Net.Server("DataChanged")
	Net.Server("RequestData"):On(function(player)
		sendInit(player)
	end)
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService

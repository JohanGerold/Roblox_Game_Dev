-- Money: the 1-second income tick, offline earnings on join, and the only way to spend (TrySpend).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Net = require(ReplicatedStorage.Shared.Net)
local Income = require(ReplicatedStorage.Shared.Util.Income)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

local welcome

local function validAmount(amount: number): boolean
	return type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

function EconomyService:IncomePerSecond(player: Player): number
	local data = DataService:Get(player)
	if not data then
		return 0
	end
	return Income.perSecond(data.characters, data.rebirths, Characters, Economy, Progression)
end

function EconomyService:Add(player: Player, amount: number)
	if not validAmount(amount) then
		return
	end
	DataService:Update(player, "money", function(money)
		return money + amount
	end)
end

-- Takes `amount` if the player can afford it. Money never goes below 0.
function EconomyService:TrySpend(player: Player, amount: number): boolean
	local data = DataService:Get(player)
	if not data or not validAmount(amount) or amount > data.money then
		return false
	end
	return DataService:Update(player, "money", function(money)
		return money - amount
	end)
end

-- Pays what the placed stands earned while the player was away, then restarts the clock.
function EconomyService:ApplyOffline(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local now = os.time()
	local amount, seconds = Income.offline(self:IncomePerSecond(player), now, data.lastSeen, Economy)
	DataService:Update(player, "lastSeen", function()
		return now
	end)
	if amount > 0 then
		self:Add(player, amount)
		welcome:Fire(player, { seconds = seconds, amount = amount })
	end
end

local function tick(player: Player, stamp: boolean)
	if not DataService:Get(player) then
		return
	end
	EconomyService:Add(player, EconomyService:IncomePerSecond(player))
	if stamp then
		DataService:Update(player, "lastSeen", function()
			return os.time()
		end)
	end
end

function EconomyService:Init()
	welcome = Net.Server("Welcome")
end

function EconomyService:Start()
	DataService.Loaded:Connect(function(player)
		-- deferred so the client's DataInit (sent right after Loaded) goes out first
		task.defer(function()
			self:ApplyOffline(player)
		end)
	end)

	task.spawn(function()
		local sinceStamp = 0
		while true do
			task.wait(1)
			sinceStamp += 1
			local stamp = sinceStamp >= Economy.lastSeenStampSeconds
			if stamp then
				sinceStamp = 0
			end
			for _, player in Players:GetPlayers() do
				local ok, err = xpcall(tick, debug.traceback, player, stamp)
				if not ok then
					warn("[EconomyService] " .. tostring(err))
				end
			end
		end
	end)
end

return EconomyService

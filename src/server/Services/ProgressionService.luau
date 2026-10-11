-- Treadmill and sandbag training sessions, and the walk speed of every character (spec section 11).
-- The server checks the player's position on every tick; walk speed goes through CarryService while an
-- egg is carried, so carry speed stays walk speed x the egg's slowdown.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Training = require(ReplicatedStorage.Shared.Config.Training)
local Net = require(ReplicatedStorage.Shared.Net)
local TrainingRules = require(script.Parent.Parent.Logic.TrainingRules)
local AnnounceService = require(script.Parent.AnnounceService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)

local REFUSAL_TEXT = {
	["Treadmill"] = "Stand on a treadmill to train speed.",
	["Sandbag"] = "Stand on a sandbag to train power.",
	["carrying"] = "You can't train while carrying an egg.",
}

local ProgressionService = {}

local sessions: { [Player]: string } = {} -- player -> "Treadmill" | "Sandbag"
local accumulator = 0

local function aliveParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root :: BasePart
	end
	return nil, nil
end

-- Flat distance to the nearest station of this kind (math.huge when the map has none).
local function distanceToStation(root: BasePart, kind: string): number
	local best = math.huge
	for _, station in CollectionService:GetTagged(kind) do
		if station:IsA("BasePart") then
			local d = Vector3.new(root.Position.X - station.Position.X, 0, root.Position.Z - station.Position.Z).Magnitude
			best = math.min(best, d)
		end
	end
	return best
end

local function check(player: Player, kind: string): (boolean, string?)
	local humanoid, root = aliveParts(player)
	local distance = root and distanceToStation(root, kind) or math.huge
	return TrainingRules.canTrain(kind, distance, CarryService:IsCarrying(player), humanoid ~= nil, Training)
end

-- Sets the character's WalkSpeed from trained speed (through CarryService while carrying).
function ProgressionService:ApplyWalkSpeed(player: Player)
	local data = DataService:Get(player)
	local humanoid = aliveParts(player)
	if not data or not humanoid then
		return
	end
	local walk = TrainingRules.walkSpeed(data.training.speed, Training)
	if not CarryService:SetBaseSpeed(player, walk) then
		humanoid.WalkSpeed = walk
	end
end

function ProgressionService:StopTraining(player: Player)
	if sessions[player] then
		sessions[player] = nil
		player:SetAttribute("Training", nil)
	end
end

-- Returns true when a session started (or was already running on this kind).
function ProgressionService:StartTraining(player: Player, kind: string): (boolean, string?)
	if not DataService:Get(player) then
		return false, "no data"
	end
	local ok, reason = check(player, kind)
	if not ok then
		local text = reason == "carrying" and REFUSAL_TEXT.carrying or (reason == "too far" and REFUSAL_TEXT[kind])
		if text then
			AnnounceService:Notice(player, text)
		end
		return false, reason
	end
	sessions[player] = kind
	player:SetAttribute("Training", kind)
	return true
end

local function tick()
	for player, kind in table.clone(sessions) do
		if player.Parent ~= Players or not check(player, kind) then
			ProgressionService:StopTraining(player)
		else
			local stat = TrainingRules.statFor(kind)
			local gain = TrainingRules.rateFor(kind, Training) * Training.tickSeconds
			DataService:Update(player, "training", function(training)
				training[stat] += gain
				return training
			end)
		end
	end
end

function ProgressionService:Init()
	Net.Server("Train"):On(function(player, kind, active)
		if active then
			self:StartTraining(player, kind)
		else
			self:StopTraining(player)
		end
	end)
end

function ProgressionService:Start()
	local function onCharacter(player: Player, character: Model)
		character:WaitForChild("Humanoid")
		self:ApplyWalkSpeed(player)
	end
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			self:StopTraining(player)
			onCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			self:StopTraining(player)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		self:StopTraining(player)
	end)
	DataService.Loaded:Connect(function(player)
		self:ApplyWalkSpeed(player)
	end)
	DataService.Changed:Connect(function(player, key)
		if key == "training" then
			self:ApplyWalkSpeed(player)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Training.tickSeconds then
			return
		end
		accumulator -= Training.tickSeconds
		local ok, err = xpcall(tick, debug.traceback)
		if not ok then
			warn("[ProgressionService] " .. tostring(err))
		end
	end)
end

return ProgressionService

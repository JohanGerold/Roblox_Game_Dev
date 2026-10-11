-- Draws every fighting player's stand team as placeholder blocks behind them and lunges them at the
-- boss once per tick. Visual only: the server deals the damage (StandService) and publishes the
-- StandTeam / StandsFighting player attributes this reads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local DataController = require(script.Parent.DataController)

local STAND_SIZE = Vector3.new(3, 5, 2)
local STAND_SPACING = 4
local STAND_BEHIND = 6
local LUNGE_DISTANCE = 3
local LUNGE_SECONDS = 0.3
local REFRESH_SECONDS = 0.1
local NEON_FROM_RARITY_INDEX = 6 -- Mythic

local StandCombatController = {}

local folder: Folder
local drawn: { [Player]: { team: string, parts: { Part } } } = {}
local lungeStart = 0

local function clear(player: Player)
	local entry = drawn[player]
	if entry then
		for _, part in entry.parts do
			part:Destroy()
		end
		drawn[player] = nil
	end
end

local function makePart(charId: string): Part
	local cfg = Characters[charId]
	local rarity = Rarities.byName[cfg.rarity]
	local part = Instance.new("Part")
	part.Name = charId
	part.Size = STAND_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = rarity.color
	part.Material = rarity.index >= NEON_FROM_RARITY_INDEX and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.Parent = folder
	return part
end

-- Creates, replaces or removes a player's blocks so they match the published attributes.
local function sync(player: Player)
	local team = player:GetAttribute("StandTeam")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if player:GetAttribute("StandsFighting") ~= true or type(team) ~= "string" or team == "" or not root then
		clear(player)
		return
	end
	local entry = drawn[player]
	if entry and entry.team == team then
		return
	end
	clear(player)
	local parts = {}
	for id in string.gmatch(team, "[^,]+") do
		if Characters[id] then
			table.insert(parts, makePart(id))
		end
	end
	drawn[player] = { team = team, parts = parts }
end

local function nearestBoss(from: Vector3): Vector3?
	local bosses = workspace:FindFirstChild("Bosses")
	local best, bestDist
	for _, model in bosses and bosses:GetChildren() or {} do
		local position = model:GetPivot().Position
		local d = (position - from).Magnitude
		if not bestDist or d < bestDist then
			best, bestDist = position, d
		end
	end
	return best
end

local function place()
	local lunge = 0
	local sinceTick = os.clock() - lungeStart
	if sinceTick < LUNGE_SECONDS then
		lunge = math.sin(sinceTick / LUNGE_SECONDS * math.pi) * LUNGE_DISTANCE
	end
	local settings = DataController:Get("settings")
	local fewer = settings ~= nil and settings.fewerEffects == true
	for player, entry in drawn do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local count = #entry.parts
			local boss = nearestBoss(root.Position)
			local push = (player == Players.LocalPlayer or not fewer) and lunge or 0
			for i, part in entry.parts do
				local cf = root.CFrame * CFrame.new((i - (count + 1) / 2) * STAND_SPACING, 0, STAND_BEHIND)
				if boss and push > 0 then
					local toward = Vector3.new(boss.X - cf.Position.X, 0, boss.Z - cf.Position.Z)
					if toward.Magnitude > 0.1 then
						cf += toward.Unit * push
					end
				end
				part.CFrame = cf
			end
		end
	end
end

function StandCombatController:Init()
	folder = Instance.new("Folder")
	folder.Name = "StandFx"
	folder.Parent = workspace.CurrentCamera
end

function StandCombatController:Start()
	lungeStart = os.clock()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				sync(player)
			end
			for player in drawn do
				if player.Parent == nil then
					clear(player)
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Combat.standTickSeconds)
			lungeStart = os.clock()
		end
	end)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(place)
end

return StandCombatController

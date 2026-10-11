-- Day/night round cycle (spec D10-D12). Day: field eggs sit in the domain and the boss can be
-- fought. Night: everyone goes home, carried eggs count as delivered, field eggs vanish and the boss
-- rests. The phase replicates as workspace attributes RoundPhase / RoundEndsAt; clients only display it.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GiantEgg = require(ReplicatedStorage.Shared.Config.GiantEgg)
local Rounds = require(ReplicatedStorage.Shared.Config.Rounds)
local Logic = script.Parent.Parent.Logic
local FieldEggRoll = require(Logic.FieldEggRoll)
local RoundRules = require(Logic.RoundRules)
local ZoneCheck = require(Logic.ZoneCheck)
local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local CarryService = require(script.Parent.CarryService)

local RoundService = {}

local rng = Random.new()
local phase = "Day"
local warnedNoHome = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function taggedParts(tag: string): { BasePart }
	local found = {}
	for _, d in CollectionService:GetTagged(tag) do
		if d:IsA("BasePart") then
			table.insert(found, d)
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	return found
end

local function isHome(position: Vector3): boolean
	local zone = taggedParts("HomeZone")[1]
	if not zone then
		if not warnedNoHome then
			warnedNoHome = true
			warn("[RoundService] no HomeZone on the map: nothing counts as home")
		end
		return false
	end
	return ZoneCheck.inside(zone.CFrame, zone.Size, position)
end

local function tweenLighting(name: string)
	local preset = Rounds.lighting[name]
	local info = TweenInfo.new(Rounds.lightingTweenSeconds)
	TweenService:Create(Lighting, info, {
		ClockTime = preset.ClockTime,
		Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	TweenService:Create(atmosphere, info, {
		Density = preset.Density,
		Color = preset.Color,
		Decay = preset.Decay,
		Haze = preset.Haze,
		Glare = preset.Glare,
	}):Play()
end

local function sunrise(endsAt: number)
	BossService:SetDormant(false)
	local spawns = taggedParts("FieldEggSpawn")
	local giantDropped = false
	for _, entry in FieldEggRoll.roll(#Players:GetPlayers(), #spawns, Rounds.fieldEggs, rng) do
		local spawn = spawns[entry.spawnIndex]
		CarryService:SpawnField(entry.eggId, spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0), endsAt)
		giantDropped = giantDropped or entry.eggId == GiantEgg.eggId
	end
	if giantDropped then
		AnnounceService:All("A Giant Egg appeared in the domain!", GiantEgg.announceRarity)
	end
end

local function nightfall()
	BossService:SetDormant(true)
	CarryService:Nightfall(isHome)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and not isHome(root.Position) then
			character:PivotTo(BaseService:GetSpawnCFrame(player))
			CarryService:ResetCheck(player)
		end
	end
	AnnounceService:All("Night falls. Everyone is home.", "Common")
end

local function enter(name: string)
	phase = name
	local endsAt = now() + RoundRules.duration(name, Rounds)
	workspace:SetAttribute("RoundEndsAt", endsAt)
	workspace:SetAttribute("RoundPhase", name)
	tweenLighting(name)
	if name == "Day" then
		sunrise(endsAt)
	else
		nightfall()
	end
	print(string.format("[RoundService] %s until %.0f", name, endsAt))
end

-- Test hook: ends the current phase at once (called from temporary Studio scripts only).
function RoundService:SkipPhase()
	workspace:SetAttribute("RoundEndsAt", now())
end

-- The cycle starts once the first player is in, so the first sunrise counts them.
local function run()
	local ok, err = xpcall(enter, debug.traceback, "Day")
	if not ok then
		warn("[RoundService] " .. tostring(err))
	end
	RunService.Heartbeat:Connect(function()
		if now() < (workspace:GetAttribute("RoundEndsAt") or 0) then
			return
		end
		local good, problem = xpcall(enter, debug.traceback, RoundRules.nextPhase(phase))
		if not good then
			warn("[RoundService] " .. tostring(problem))
		end
	end)
end

function RoundService:Start()
	if #Players:GetPlayers() > 0 then
		run()
	else
		Players.PlayerAdded:Once(run)
	end
end

return RoundService

-- Stands at bases: the PlaceStand handler, and a static model on each placed stand's base slot.
-- Models are server-side and anchored; the shadowbox animation arrives with real assets (build step 12).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Income = require(ReplicatedStorage.Shared.Util.Income)
local Server = script.Parent.Parent
local StandDamage = require(Server.Logic.StandDamage)
local StandPlace = require(Server.Logic.StandPlace)
local TeamRules = require(Server.Logic.TeamRules)
local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local DataService = require(script.Parent.DataService)

local PLACEHOLDER_SIZE = Vector3.new(3, 5, 2)
local LABEL_HEIGHT = 4
local NEON_FROM_RARITY_INDEX = 6 -- Mythic

local REASON_TEXT = {
	["unknown stand"] = "You don't have that stand.",
	["slot locked"] = "That base slot isn't unlocked.",
}

local StandService = {}

local standsFolder: Folder
local damageNumbers
local tickAccumulator = 0
local warnedPlaceholder: { [string]: boolean } = {}

local function findSlot(base: Model, index: number): BasePart?
	for _, d in base:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag("StandSlot") and d:GetAttribute("SlotIndex") == index then
			return d
		end
	end
	return nil
end

local function addLabel(adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StandLabel"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(160, 50)
	gui.StudsOffset = Vector3.new(0, LABEL_HEIGHT, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
end

local function makeModel(stand): Model
	local cfg = Characters[stand.id]
	local rarity = Rarities.byName[cfg.rarity]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characterAssets = assets and assets:FindFirstChild("Characters")
	local template = characterAssets and characterAssets:FindFirstChild(cfg.model)

	local model: Model
	if template then
		model = template:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
	else
		if not warnedPlaceholder[cfg.model] then
			warnedPlaceholder[cfg.model] = true
			warn("[StandService] no asset Assets.Characters." .. cfg.model .. ", using a placeholder")
		end
		model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = PLACEHOLDER_SIZE
		root.Anchored = true
		root.CanCollide = false
		root.Color = rarity.color
		root.Material = rarity.index >= NEON_FROM_RARITY_INDEX and Enum.Material.Neon or Enum.Material.SmoothPlastic
		root.Parent = model
		model.PrimaryPart = root
	end
	model.Name = stand.id

	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if adornee then
		local income = Income.standIncome(stand.id, stand.level, Characters, Economy)
		addLabel(adornee, string.format("%s\nLv %d  $%s/s", cfg.displayName, stand.level, Format.number(income)), rarity.color)
	end
	return model
end

-- Rebuilds the models for one player's placed stands. No-op until both their base and data exist.
function StandService:Refresh(player: Player)
	local key = tostring(player.UserId)
	local old = standsFolder:FindFirstChild(key)
	if old then
		old:Destroy()
	end
	local base = BaseService:GetBase(player)
	local data = DataService:Get(player)
	if not base or not data then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = key
	for uid, stand in data.characters do
		if stand.slot and Characters[stand.id] then
			local slot = findSlot(base, stand.slot)
			if slot then
				local model = makeModel(stand)
				model.Name = uid
				local height = model:GetExtentsSize().Y
				local rotation = slot.CFrame - slot.Position
				model:PivotTo(CFrame.new(slot.Position + Vector3.new(0, slot.Size.Y / 2 + height / 2, 0)) * rotation)
				model.Parent = folder
			end
		end
	end
	folder.Parent = standsFolder
end

local function place(player: Player, charUid: string, slot: number?)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local failure
	DataService:Update(player, "characters", function(characters)
		local ok, reason = StandPlace.place(characters, charUid, slot, data.baseSlots)
		if not ok then
			failure = reason
		end
		return characters
	end)
	if failure then
		AnnounceService:Notice(player, REASON_TEXT[failure] or "Can't place that stand.")
	end
end

-- Replaces the player's stand team. Returns false (with a Notice) when the list is not valid.
function StandService:SetTeam(player: Player, list: any): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local ok = TeamRules.validate(list, data.characters, data.rebirths, Progression)
	if not ok then
		AnnounceService:Notice(player, "Couldn't set that team.")
		return false
	end
	DataService:Update(player, "standTeam", function()
		return table.clone(list)
	end)
	return true
end

-- Attribute StandTeam = character ids of the team in order (stale uids skipped); clients draw them.
local function publishTeam(player: Player)
	local data = DataService:Get(player)
	local ids = {}
	if data then
		for _, uid in data.standTeam do
			local stand = data.characters[uid]
			if stand and Characters[stand.id] then
				table.insert(ids, stand.id)
			end
		end
	end
	player:SetAttribute("StandTeam", table.concat(ids, ","))
end

-- The boss whose arena the player stands in while that boss can be fought, else nil.
local function fightableBoss(root: BasePart)
	for _, boss in BossService:GetBosses() do
		if BossService:IsInArena(boss, root.Position) then
			local state = boss.brain.state
			if state ~= "Dead" and state ~= "Guard" and not boss.dormant then
				return boss
			end
		end
	end
	return nil
end

local function tick()
	local CarryService = require(script.Parent.CarryService)
	for _, player in Players:GetPlayers() do
		local data = DataService:Get(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local fighting = false
		if data and humanoid and root and humanoid.Health > 0 and #data.standTeam > 0 and not CarryService:IsCarrying(player) then
			local boss = fightableBoss(root)
			if boss then
				fighting = true
				local amount = StandDamage.perTick(data.standTeam, data.characters, data.rebirths, Characters, Economy, Progression, Combat)
				local dealt = BossService:DamageBoss(boss, player, amount)
				if dealt > 0 then
					local p = boss.pos
					damageNumbers:Fire(player, { amount = dealt, x = p.X, y = p.Y + 8, z = p.Z, staggered = false, stand = true })
				end
			end
		end
		if player:GetAttribute("StandsFighting") ~= fighting then
			player:SetAttribute("StandsFighting", fighting)
		end
	end
end

function StandService:Init()
	damageNumbers = Net.Server("DamageNumbers")
	Net.Server("SetTeam"):On(function(player, list)
		self:SetTeam(player, list)
	end)
	standsFolder = Instance.new("Folder")
	standsFolder.Name = "Stands"
	standsFolder.Parent = Workspace
	Net.Server("PlaceStand"):On(place)
end

function StandService:Start()
	DataService.Changed:Connect(function(player, key)
		if key == "characters" or key == "baseSlots" then
			self:Refresh(player)
		end
		if key == "characters" or key == "standTeam" then
			publishTeam(player)
		end
	end)
	DataService.Loaded:Connect(function(player)
		self:Refresh(player)
		publishTeam(player)
	end)
	RunService.Heartbeat:Connect(function(dt)
		tickAccumulator += dt
		if tickAccumulator < Combat.standTickSeconds then
			return
		end
		tickAccumulator -= Combat.standTickSeconds
		local ok, err = xpcall(tick, debug.traceback)
		if not ok then
			warn("[StandService] " .. tostring(err))
		end
	end)
	BaseService.Assigned:Connect(function(player)
		self:Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local folder = standsFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)
end

return StandService

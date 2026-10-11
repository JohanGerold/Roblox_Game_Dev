-- Every carryable egg: the stealable giant egg (spec section 10) and the personal rank eggs that drop
-- in the arena. Eggs are grabbed through a ProximityPrompt, carried slowly (walk speed x the egg's
-- carryFactor), dropped on hits (stealable eggs only), deaths, leaving or speeding, and delivered at
-- the carrier's own base pad. The server decides who holds each egg.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local GiantEgg = require(ReplicatedStorage.Shared.Config.GiantEgg)
local Net = require(ReplicatedStorage.Shared.Net)
local Logic = script.Parent.Parent.Logic
local CarryCheck = require(Logic.CarryCheck)
local CarryRules = require(Logic.CarryRules)
local LootRank = require(Logic.LootRank)
local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local EggService = require(script.Parent.EggService)

local REFUSAL_TEXT = {
	["head start"] = "Top damage dealers grab first!",
	["cooldown"] = "Wait a moment before grabbing it again.",
	["already carrying"] = "You're already carrying an egg.",
	["not yours"] = "That egg belongs to someone else.",
}

local CarryService = {}

local eggs: { [string]: any } = {} -- id -> egg record
local carriers: { [Player]: any } = {} -- player -> carry record
local eggFolder: Folder
local stateRemote
local counter = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function aliveParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root :: BasePart
	end
	return nil, nil
end

-- Giant egg phases are sent to every client; personal eggs only track the phase on the server.
local function broadcast(egg, phase: string, extra: { [string]: any }?)
	egg.phase = phase
	if egg.kind ~= "Giant" then
		return
	end
	local payload = { id = egg.id, phase = phase }
	for k, v in extra or {} do
		payload[k] = v
	end
	stateRemote:FireAll(payload)
end

local function broadcastCarried(egg, player: Player)
	broadcast(egg, "Carried", { carrierName = player.DisplayName, carrierUserId = player.UserId })
end

local function makePart(egg)
	local def = Eggs[egg.eggId]
	local owner = egg.ownerUserId and Players:GetPlayerByUserId(egg.ownerUserId)
	local part = Instance.new("Part")
	part.Name = "Egg_" .. egg.id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * egg.size
	part.Material = Enum.Material.Neon
	part.Color = def.color
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(egg.spawnPos)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, egg.size, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = if egg.kind == "Giant" then "GIANT EGG" else string.format("%s's %s", owner and owner.DisplayName or "Someone", def.displayName)
	label.TextColor3 = def.color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = def.displayName
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Carry.pickupRange
	prompt.RequiresLineOfSight = false
	if egg.ownerUserId then
		prompt:SetAttribute("OwnerUserId", egg.ownerUserId) -- EggPromptController hides it for everyone else
	end
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		CarryService:TryPickUp(player, egg.id)
	end)

	egg.part, egg.prompt = part, prompt
	part.Parent = eggFolder
end

local function findPad(player: Player): BasePart?
	local base = BaseService:GetBase(player)
	if not base then
		return nil
	end
	for _, d in base:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag("EggDeliveryPad") then
			return d
		end
	end
	return nil
end

-- Undoes everything pickup did to the player. Returns the carry record, or nil if not carrying.
local function detach(player: Player)
	local carry = carriers[player]
	if not carry then
		return nil
	end
	carriers[player] = nil
	for _, conn in carry.connections do
		conn:Disconnect()
	end
	carry.weld:Destroy()
	carry.highlight:Destroy()
	if carry.humanoid.Parent then
		carry.humanoid.WalkSpeed = carry.savedSpeed
	end
	player:SetAttribute("CarryingEgg", nil)
	carry.egg.carrier = nil
	carry.egg.carrierUserId = nil
	return carry
end

function CarryService:GetEggs()
	return eggs
end

function CarryService:IsCarrying(player: Player): boolean
	return carriers[player] ~= nil
end

-- Nearest other player carrying a stealable egg within `reach` studs of `position`.
function CarryService:CarrierInReach(attacker: Player, position: Vector3, reach: number): Player?
	local best, bestDist
	for player, carry in carriers do
		if player ~= attacker and carry.egg.stealable then
			local _, root = aliveParts(player)
			if root then
				local d = (root.Position - position).Magnitude
				if d <= reach and (not bestDist or d < bestDist) then
					best, bestDist = player, d
				end
			end
		end
	end
	return best
end

-- Puts the egg on the ground at the carrier's last valid spot and makes it grabbable again.
function CarryService:Drop(player: Player, reason: string)
	local carry = detach(player)
	if not carry then
		return
	end
	local egg = carry.egg
	local t = now()
	egg.lastCarrierUserId = player.UserId
	egg.regrabUntil = t + Carry.regrabCooldown
	egg.part.Anchored = true
	egg.part.CFrame = CFrame.new(carry.check.lastValid)
	egg.prompt.Enabled = true
	print(string.format("[CarryService] %s dropped %s (%s)", player.Name, egg.id, reason))
	broadcast(egg, "Free")
end

function CarryService:TryPickUp(player: Player, eggId: string): (boolean, string?)
	local egg = eggs[eggId]
	local humanoid, root = aliveParts(player)
	if not egg or not egg.part or not humanoid or not root then
		return false, "unavailable"
	end
	local distance = (root.Position - egg.part.Position).Magnitude
	local ok, reason = CarryRules.canPickUp(egg, player.UserId, carriers[player] ~= nil, distance, now(), Carry)
	if not ok then
		if reason and REFUSAL_TEXT[reason] then
			AnnounceService:Notice(player, REFUSAL_TEXT[reason])
		end
		return false, reason
	end

	local def = Eggs[egg.eggId]
	local part = egg.part
	part.Anchored = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0, 3 + egg.size / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, part
	weld.Parent = part
	egg.prompt.Enabled = false

	local highlight = Instance.new("Highlight")
	highlight.FillColor = def.color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = player.Character
	highlight.Parent = player.Character

	local carry = {
		egg = egg,
		humanoid = humanoid,
		weld = weld,
		highlight = highlight,
		savedSpeed = humanoid.WalkSpeed,
		speed = CarryRules.carrySpeed(humanoid.WalkSpeed, def.carryFactor),
		check = CarryCheck.new(root.Position, now(), Carry),
		onPad = false,
		connections = {},
	}
	table.insert(carry.connections, humanoid.Died:Connect(function()
		CarryService:Drop(player, "died")
	end))
	table.insert(carry.connections, player.CharacterRemoving:Connect(function()
		CarryService:Drop(player, "respawned")
	end))
	carriers[player] = carry
	humanoid.WalkSpeed = carry.speed
	egg.carrier = player
	egg.carrierUserId = player.UserId
	player:SetAttribute("CarryingEgg", true)

	if egg.kind == "Giant" then
		AnnounceService:All(player.DisplayName .. " grabbed the Giant Egg!", GiantEgg.announceRarity)
	else
		AnnounceService:Notice(player, string.format("Carry your %s home!", def.displayName))
	end
	broadcastCarried(egg, player)
	return true
end

local function destroyEgg(egg)
	eggs[egg.id] = nil
	if egg.part then
		egg.part:Destroy()
	end
end

local function deliver(player: Player, carry)
	local egg = carry.egg
	if not EggService:Grant(player, egg.eggId) then
		return -- storage full: Grant already sent a Notice, keep carrying
	end
	detach(player)
	if egg.kind == "Giant" then
		AnnounceService:All(player.DisplayName .. " delivered the Giant Egg!", GiantEgg.announceRarity)
		broadcast(egg, "Delivered", { carrierName = player.DisplayName, carrierUserId = player.UserId })
	else
		AnnounceService:Notice(player, string.format("Delivered your %s!", Eggs[egg.eggId].displayName))
	end
	destroyEgg(egg)
end

local function stepCarrier(player: Player, carry)
	local humanoid, root = aliveParts(player)
	if not humanoid or not root then
		return
	end
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if not CarryCheck.step(carry.check, root.Position, now(), grounded, carry.speed, Carry) then
		CarryService:Drop(player, "speed")
		return
	end
	carry.pad = carry.pad or findPad(player)
	local pad = carry.pad
	local onPad = pad ~= nil and CarryRules.onPad(root.Position, pad.CFrame, pad.Size, Carry.padHeight)
	if onPad and not carry.onPad then
		carry.onPad = true
		deliver(player, carry)
	else
		carry.onPad = onPad
	end
end

local function stepEgg(egg)
	local t = now()
	if not egg.part then
		if t >= egg.readyAt then
			makePart(egg)
			broadcast(egg, "HeadStart", { endsAt = egg.headStartUntil })
		end
		return
	end
	if egg.phase == "HeadStart" and t >= egg.headStartUntil then
		broadcast(egg, "Free")
	end
	local action = CarryRules.timeoutAction(egg, t)
	if action == "despawn" then
		if egg.carrier then
			detach(egg.carrier)
		end
		broadcast(egg, "Despawned")
		if egg.kind == "Personal" then
			local owner = Players:GetPlayerByUserId(egg.ownerUserId)
			if owner then
				AnnounceService:Notice(owner, string.format("Your %s crumbled away.", Eggs[egg.eggId].displayName))
			end
		end
		destroyEgg(egg)
	elseif action == "return" then
		if egg.carrier then
			CarryService:Drop(egg.carrier, "returned")
		end
		egg.returned = true
		egg.part.Anchored = true
		egg.part.CFrame = CFrame.new(egg.spawnPos)
		broadcast(egg, "Returned")
		broadcast(egg, "Free")
	end
end

-- A point on the ground at the arena's egg spawn marker (nil, with a warning, when the map has none).
function CarryService:GetArenaEggSpawn(bossId: string): Vector3?
	for _, boss in BossService:GetBosses() do
		if boss.id == bossId and boss.arena then
			for _, d in boss.arena:GetDescendants() do
				if d:IsA("BasePart") and CollectionService:HasTag(d, "GiantEggSpawn") then
					return d.Position + Vector3.new(0, d.Size.Y / 2, 0)
				end
			end
		end
	end
	warn("[CarryService] no GiantEggSpawn for " .. bossId .. (Bosses[bossId] and "" or " (unknown boss)"))
	return nil
end

-- Drops `player`'s personal egg at a ground point; ready at once, only they can grab it, never returns.
-- Returns the egg id, or nil for an unknown eggId.
function CarryService:SpawnPersonal(player: Player, eggId: string, position: Vector3): string?
	if not Eggs[eggId] then
		return nil
	end
	counter += 1
	local t = now()
	local egg = {
		id = "p" .. counter,
		kind = "Personal",
		eggId = eggId,
		ownerUserId = player.UserId,
		stealable = false,
		size = Carry.personalSize,
		spawnPos = position + Vector3.new(0, Carry.personalSize / 2, 0),
		readyAt = t,
		headStartUntil = t,
		top = {},
		regrabUntil = 0,
		returned = false,
		expireAt = t + Carry.personalExpireSeconds,
	}
	eggs[egg.id] = egg
	makePart(egg)
	egg.phase = "Free"
	return egg.id
end

local function onDefeated(bossId: string, ledger: { [number]: number })
	local count = 0
	for _, egg in eggs do
		if egg.kind == "Giant" then
			count += 1
		end
	end
	if count >= GiantEgg.maxActive then
		print("[CarryService] too many giant eggs active, none spawned")
		return
	end
	local ground = CarryService:GetArenaEggSpawn(bossId)
	if not ground then
		return
	end
	local top = {}
	for _, entry in LootRank.rank(ledger, Combat.minDamageShare, GiantEgg.headStartCount) do
		if entry.top then
			top[entry.userId] = true
		end
	end
	counter += 1
	local readyAt = now() + GiantEgg.countdownSeconds
	local egg = {
		id = "g" .. counter,
		kind = "Giant",
		eggId = GiantEgg.eggId,
		stealable = true,
		size = GiantEgg.size,
		spawnPos = ground + Vector3.new(0, GiantEgg.size / 2, 0),
		readyAt = readyAt,
		headStartUntil = readyAt + GiantEgg.headStartSeconds,
		top = top,
		regrabUntil = 0,
		returned = false,
		returnAt = readyAt + GiantEgg.returnAfterSeconds,
		expireAt = readyAt + GiantEgg.despawnAfterSeconds,
	}
	eggs[egg.id] = egg
	AnnounceService:All("A Giant Egg is dropping in the arena!", GiantEgg.announceRarity)
	broadcast(egg, "Countdown", { endsAt = readyAt })
end

function CarryService:Init()
	stateRemote = Net.Server("GiantEggState")
	eggFolder = workspace:FindFirstChild("Eggs") or Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = workspace
end

function CarryService:Start()
	BossService.Defeated:Connect(onDefeated)
	Players.PlayerRemoving:Connect(function(player)
		CarryService:Drop(player, "left")
		for _, egg in table.clone(eggs) do
			if egg.ownerUserId == player.UserId then
				destroyEgg(egg)
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		for _, egg in table.clone(eggs) do
			local ok, err = xpcall(stepEgg, debug.traceback, egg)
			if not ok then
				warn("[CarryService] " .. tostring(err))
			end
		end
		for player, carry in table.clone(carriers) do
			local ok, err = xpcall(stepCarrier, debug.traceback, player, carry)
			if not ok then
				warn("[CarryService] " .. tostring(err))
			end
		end
	end)
end

return CarryService

-- Client side of combat: sends attack/defend/counter intents, plays instant local feedback and shows
-- results the server sends back. The server judges everything (spec section 8).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local CombatFx = require(script.Parent.Parent.Fx.CombatFx)
local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)

local player = Players.LocalPlayer

local CombatController = {}
CombatController.counterUntil = 0

local comboIndex, comboTime = 0, nil :: number?
local lastDefend = { Dodge = -math.huge, Parry = -math.huge }
local attackRemote, defendRemote, counterRemote

local function now(): number
	return workspace:GetServerTimeNow()
end

local function aliveCharacter(): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 and humanoid.RootPart then
		return character, humanoid
	end
	return nil, nil
end

function CombatController:Attack()
	local character = aliveCharacter()
	if not character then
		return
	end
	local t = now()
	CombatFx.swing(character)
	if self.counterUntil >= t then
		self.counterUntil = 0
		counterRemote:Fire()
		return
	end

	local weaponData = DataController:Get("weapons")
	local weapon = weaponData and Weapons[weaponData.equipped]
	if not weapon then
		return
	end
	local combo = weapon.combo
	local index = 1
	if comboTime and t - comboTime <= Combat.comboResetSeconds then
		index = comboIndex % #combo + 1
		-- stricter than the server's tolerance, so a click the server would drop is never sent
		if t - comboTime < combo[index].minInterval then
			return
		end
	end
	comboIndex, comboTime = index, t
	attackRemote:Fire(index, weaponData.equipped)
end

local function dash(humanoid: Humanoid)
	local root = humanoid.RootPart
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local untilTime = os.clock() + Combat.dodgeDashSeconds
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() >= untilTime or not root.Parent then
			connection:Disconnect()
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(
			direction.X * Combat.dodgeDashSpeed,
			root.AssemblyLinearVelocity.Y,
			direction.Z * Combat.dodgeDashSpeed
		)
	end)
end

local function ghost(character: Model, seconds: number)
	local parts = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0.5
			table.insert(parts, d)
		end
	end
	task.delay(seconds, function()
		for _, part in parts do
			part.LocalTransparencyModifier = 0
		end
	end)
end

local function flash(character: Model, seconds: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.3
	highlight.Parent = character
	task.delay(seconds, function()
		highlight:Destroy()
	end)
end

function CombatController:Defend(kind: string, noDash: boolean?)
	local character, humanoid = aliveCharacter()
	if not character or not humanoid then
		return
	end
	local t = now()
	local cooldown = kind == "Dodge" and Combat.dodgeCooldown or Combat.parryCooldown
	if t - lastDefend[kind] < cooldown then
		return
	end
	lastDefend[kind] = t
	defendRemote:Fire(kind, t)
	if kind == "Dodge" then
		ghost(character, Combat.dodgeIFrames)
		if not noDash and not player:GetAttribute("CarryingEgg") then
			dash(humanoid)
		end
	else
		flash(character, Combat.parryWindow)
	end
end

local function onHitResult(info)
	local result = info.result
	if result == "Parried" then
		CombatFx.popup("PARRY!", Color3.new(1, 1, 1))
	elseif result == "PerfectDodge" then
		CombatController.counterUntil = now() + Combat.counterWindow
		CombatFx.popup("PERFECT DODGE! Attack to counter", Color3.fromRGB(80, 230, 255))
	elseif result == "Dodged" then
		CombatFx.popup("Dodged", Color3.fromRGB(200, 200, 200))
	else
		CombatFx.popup("-" .. math.floor(info.damage + 0.5), Color3.fromRGB(255, 70, 70))
	end
end

local function findBossModel(bossId: string): Model?
	local folder = workspace:FindFirstChild("Bosses")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("BossId") == bossId then
			return model :: Model
		end
	end
	return nil
end

local STAND_NUMBER_COLOR = Color3.fromRGB(90, 220, 255)

local function onBossAttack(bossId: string, attackId: string, impactTime: number, payload)
	local cfg = Bosses[bossId]
	local model = findBossModel(bossId)
	if not cfg or not model then
		return
	end
	if attackId == "Catch" then
		local area = { targeting = "Self", hitbox = { shape = "Sphere", radius = cfg.catchRange + cfg.bodyRadius } }
		CombatFx.telegraph(area, model, impactTime, {})
		return
	end
	local settings = DataController:Get("settings")
	for _, attack in cfg.attacks do
		if attack.id == attackId then
			CombatFx.telegraph(attack, model, impactTime, {
				payload = payload,
				vfxFolder = cfg.vfxFolder,
				fewerEffects = settings ~= nil and settings.fewerEffects == true,
			})
			return
		end
	end
end

function CombatController:Init()
	attackRemote = Net.Client("Attack")
	defendRemote = Net.Client("Defend")
	counterRemote = Net.Client("Counter")
end

function CombatController:Start()
	DataController:WaitForData()
	InputController.Action:Connect(function(action)
		if action == "Attack" then
			self:Attack()
		elseif action == "Parry" then
			self:Defend("Parry")
		elseif action == "Dodge" then
			self:Defend("Dodge")
		end
	end)
	Net.Client("HitResult"):On(onHitResult)
	Net.Client("BossAttack"):On(onBossAttack)
	Net.Client("DamageNumbers"):On(function(info)
		CombatFx.damageNumber(Vector3.new(info.x, info.y, info.z), info.amount, info.staggered, info.stand and STAND_NUMBER_COLOR or nil)
	end)
	player.CharacterAdded:Connect(function()
		comboIndex, comboTime = 0, nil
		self.counterUntil = 0
	end)
end

return CombatController

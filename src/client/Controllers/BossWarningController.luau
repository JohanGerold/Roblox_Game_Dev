-- Screen warnings for boss attacks: the danger kanji for big attacks and the PARRY prompt during the last
-- moments before the local player's own impact. Display only; the server decides every outcome. Both always
-- show, including with reduced effects (they carry gameplay information).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Keybinds = require(ReplicatedStorage.Shared.Config.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local WaveTiming = require(ReplicatedStorage.Shared.Util.WaveTiming)
local DataController = require(script.Parent.DataController)

local DANGER_SECONDS = 1
local KEY_NAMES = { MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB" }

local BossWarningController = {}

local danger: TextLabel
local prompt: TextLabel
local activeUntil = 0 -- when the current attack's warnings are over
local current: { [string]: any }? = nil

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function parryKeyName(): string
	local settings = DataController:Get("settings")
	local bound = settings and settings.keybinds and settings.keybinds.Parry or Keybinds.defaults.Parry
	return KEY_NAMES[bound] or tostring(bound)
end

-- Is the local player inside this attack's damage area? Self shapes use the boss's position and facing.
local function inArea(attack, payload, bossPivot: CFrame, position: Vector3): boolean
	if attack.targeting == "Wave" then
		return payload ~= nil and flatDistance(position, Vector3.new(payload.x, 0, payload.z)) <= payload.maxRadius
	elseif attack.targeting == "Player" then
		return payload ~= nil and flatDistance(position, Vector3.new(payload.x, 0, payload.z)) <= payload.radius
	end
	local hitbox = attack.hitbox
	if hitbox.shape == "Sphere" or hitbox.shape == "Circle" then
		return flatDistance(position, bossPivot.Position) <= hitbox.radius
	elseif hitbox.shape == "Cone" then
		local offset = position - bossPivot.Position
		if offset.Magnitude > hitbox.range then
			return false
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < 1e-6 then
			return true
		end
		local look = Vector3.new(bossPivot.LookVector.X, 0, bossPivot.LookVector.Z).Unit
		return math.deg(math.acos(math.clamp(look:Dot(flat.Unit), -1, 1))) <= hitbox.angle / 2
	end
	return true
end

local function onBossAttack(bossId: string, attackId: string, impactTime: number, payload)
	local cfg = Bosses[bossId]
	local attack
	for _, candidate in cfg and cfg.attacks or {} do
		if candidate.id == attackId then
			attack = candidate
		end
	end
	local folder = workspace:FindFirstChild("Bosses")
	local model
	for _, child in folder and folder:GetChildren() or {} do
		if child:GetAttribute("BossId") == bossId then
			model = child
		end
	end
	if not attack or not model then
		return
	end

	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if attack.danger and root then
		local mine = false
		if attack.targeting == "Player" then
			mine = payload ~= nil and payload.targetUserId == me.UserId
		elseif attack.targeting == "Wave" then
			mine = inArea(attack, payload, model:GetPivot(), root.Position)
		end
		if mine then
			danger.Visible = true
			task.delay(DANGER_SECONDS, function()
				danger.Visible = false
			end)
		end
	end

	local waveEnd = 0
	if attack.targeting == "Wave" and payload then
		waveEnd = (payload.maxRadius - payload.startRadius) / payload.speed
	end
	current = { attack = attack, payload = payload, model = model, impactTime = impactTime }
	activeUntil = impactTime + waveEnd + 0.1
end

local function render()
	local now = workspace:GetServerTimeNow()
	local state = current
	if not state or now > activeUntil then
		prompt.Visible = false
		current = nil
		return
	end
	local bossState = state.model:GetAttribute("State")
	if bossState == "Staggered" or bossState == "Dead" or bossState == "Guard" then
		prompt.Visible = false
		current = nil
		return
	end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		prompt.Visible = false
		return
	end
	local attack, payload = state.attack, state.payload
	local personal = state.impactTime
	if attack.targeting == "Wave" and payload then
		local distance = flatDistance(root.Position, Vector3.new(payload.x, 0, payload.z))
		personal = WaveTiming.arrival(distance, state.impactTime, { waveStartRadius = payload.startRadius, waveSpeed = payload.speed })
	end
	local inWindow = now >= personal - attack.parryWindow and now <= personal
	prompt.Visible = inWindow and inArea(attack, payload, state.model:GetPivot(), root.Position)
	if prompt.Visible then
		prompt.Text = "PARRY  [" .. parryKeyName() .. "]"
	end
end

local function makeLabel(name: string, text: string, size: number, position: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.fromOffset(520, size + 16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Visible = false
	return label
end

function BossWarningController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossWarnings"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	danger = makeLabel("Danger", "\u{5371} !", 64, UDim2.fromScale(0.5, 0.3), Color3.fromRGB(255, 50, 50))
	danger.Parent = gui
	prompt = makeLabel("Parry", "PARRY", 36, UDim2.fromScale(0.5, 0.62), Color3.new(1, 1, 1))
	prompt.Parent = gui
end

function BossWarningController:Start()
	Net.Client("BossAttack"):On(onBossAttack)
	RunService.RenderStepped:Connect(render)
end

return BossWarningController

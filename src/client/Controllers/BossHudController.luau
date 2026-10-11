-- Boss HP and poise bars, shown while the player is near a boss. Reads the boss model's attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Map = require(ReplicatedStorage.Shared.Config.Map)

local player = Players.LocalPlayer
local SHOW_RANGE = Map.arenaRadius + 30

local BossHudController = {}

local function makeBar(parent: Instance, y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, y)
	back.Size = UDim2.new(1, 0, 0, height)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	return back
end

function BossHudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 20)
	root.Size = UDim2.new(0.5, 0, 0, 70)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 24)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 20
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Parent = root

	local hpBack = makeBar(root, 26, 22, Color3.fromRGB(200, 40, 40))
	local poiseBack = makeBar(root, 52, 10, Color3.fromRGB(240, 200, 60))
	local hpFill = hpBack.Fill :: Frame
	local poiseFill = poiseBack.Fill :: Frame

	local stagger = Instance.new("TextLabel")
	stagger.Size = UDim2.new(1, 0, 0, 22)
	stagger.Position = UDim2.new(0, 0, 0, 64)
	stagger.BackgroundTransparency = 1
	stagger.Font = Enum.Font.GothamBlack
	stagger.TextSize = 22
	stagger.TextColor3 = Color3.fromRGB(255, 220, 60)
	stagger.TextStrokeTransparency = 0.3
	stagger.Text = "STAGGERED"
	stagger.Visible = false
	stagger.Parent = root

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.1 then
			return
		end
		accumulated = 0

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local folder = workspace:FindFirstChild("Bosses")
		local shown: Model? = nil
		if hrp and folder then
			local best = SHOW_RANGE
			for _, model in folder:GetChildren() do
				local pivot = model:GetPivot().Position
				local d = (Vector3.new(pivot.X, 0, pivot.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
				if model:GetAttribute("BossId") and d <= best then
					best, shown = d, model :: Model
				end
			end
		end
		root.Visible = shown ~= nil
		if not shown then
			return
		end
		local maxHp = math.max(1, shown:GetAttribute("MaxHp") or 1)
		local maxPoise = math.max(1, shown:GetAttribute("MaxPoise") or 1)
		name.Text = tostring(shown:GetAttribute("BossId"))
		hpFill.Size = UDim2.fromScale(math.clamp((shown:GetAttribute("Hp") or 0) / maxHp, 0, 1), 1)
		poiseFill.Size = UDim2.fromScale(math.clamp((shown:GetAttribute("Poise") or 0) / maxPoise, 0, 1), 1)
		local enraged = shown:GetAttribute("Enraged") == true
		stagger.Text = enraged and "ENRAGED" or "STAGGERED"
		stagger.TextColor3 = enraged and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 220, 60)
		stagger.Visible = enraged or shown:GetAttribute("State") == "Staggered"
	end)
end

return BossHudController

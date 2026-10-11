-- Treadmill and sandbag prompts plus a status line while training. Display and requests only: the server
-- checks the position every second and decides every gain (ProgressionService).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Training = require(ReplicatedStorage.Shared.Config.Training)
local Net = require(ReplicatedStorage.Shared.Net)
local DataController = require(script.Parent.DataController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local REFRESH_SECONDS = 0.2

local TrainingController = {}

local label: TextLabel
local prompts: { [ProximityPrompt]: string } = {} -- prompt -> kind

local function trainingKind(): string?
	return Players.LocalPlayer:GetAttribute("Training")
end

local function refreshPrompts()
	local active = trainingKind()
	for prompt, kind in prompts do
		if active == kind then
			prompt.ActionText = "Stop"
		else
			prompt.ActionText = kind == "Treadmill" and "Train speed" or "Train power"
		end
	end
end

local function addPrompt(station: Instance, kind: string)
	if not station:IsA("BasePart") or station:FindFirstChild("TrainPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainPrompt"
	prompt.ObjectText = kind == "Treadmill" and "Treadmill" or "Sandbag"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Training.trainRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = station
	prompts[prompt] = kind
	prompt.Triggered:Connect(function()
		Net.Client("Train"):Fire(kind, trainingKind() ~= kind)
	end)
	refreshPrompts()
end

local function render()
	local kind = trainingKind()
	if not kind then
		label.Visible = false
		return
	end
	local training = DataController:Get("training") or { speed = 0, power = 0 }
	if kind == "Treadmill" then
		local walk = math.min(Training.maxWalkSpeed, Training.baseWalkSpeed + math.max(0, training.speed))
		label.Text = string.format("Training speed: %.1f  (walk %.1f)", training.speed, walk)
	else
		label.Text = string.format("Training power: %.1f  (+%d%% damage)", training.power, math.floor(training.power * Combat.powerDamageFactor * 100))
	end
	label.Visible = true
end

function TrainingController:Init()
	label = Widgets.label({
		Name = "TrainingStatus",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(420, 28),
		Text = "",
		TextSize = 20,
		TextColor3 = Widgets.colors.good,
		TextStrokeTransparency = 0.3,
		Visible = false,
	})
end

function TrainingController:Start()
	DataController:WaitForData()
	for _, kind in { "Treadmill", "Sandbag" } do
		for _, station in CollectionService:GetTagged(kind) do
			addPrompt(station, kind)
		end
		CollectionService:GetInstanceAddedSignal(kind):Connect(function(station)
			addPrompt(station, kind)
		end)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("Training"):Connect(refreshPrompts)
	task.spawn(function()
		while true do
			render()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return TrainingController

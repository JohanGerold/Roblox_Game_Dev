-- Money HUD, panel buttons, toasts (Notice / Announce) and the offline "welcome back" popup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Income = require(ReplicatedStorage.Shared.Util.Income)
local DataController = require(script.Parent.DataController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local MAX_TOASTS = 4
local TOAST_SECONDS = 4

local HudController = {}

local moneyLabel: TextLabel, rateLabel: TextLabel
local toastHolder: Frame
local eggsButton: TextButton, standsButton: TextButton
local toastCounter = 0

function HudController:Toast(text: string, color: Color3?)
	toastCounter += 1
	local toast = Widgets.label({
		Parent = toastHolder,
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 26),
		Text = text,
		TextColor3 = color or Widgets.colors.text,
		TextStrokeTransparency = 0.3,
		LayoutOrder = toastCounter,
	})
	local toasts = toastHolder:GetChildren()
	local shown = {}
	for _, child in toasts do
		if child:IsA("TextLabel") then
			table.insert(shown, child)
		end
	end
	if #shown > MAX_TOASTS then
		table.sort(shown, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		shown[1]:Destroy()
	end
	task.delay(TOAST_SECONDS, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

local function duration(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", math.max(minutes, 1))
end

local function showWelcome(info)
	local popup = Widgets.frame({
		Name = "Welcome",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(380, 180),
	})
	Widgets.label({
		Parent = popup,
		Size = UDim2.new(1, -24, 0, 100),
		Position = UDim2.fromOffset(12, 10),
		Text = string.format("Welcome back!\nYou were away %s and earned $%s", duration(info.seconds), Format.number(info.amount)),
		TextWrapped = true,
		TextSize = 22,
	})
	Widgets.button({
		Parent = popup,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(120, 40),
		Text = "OK",
		BackgroundColor3 = Widgets.colors.good,
	}, function()
		popup:Destroy()
	end)
end

local function refresh()
	local money = DataController:Get("money") or 0
	moneyLabel.Text = "$" .. Format.number(money)
	local characters = DataController:Get("characters") or {}
	local perSecond = Income.perSecond(characters, DataController:Get("rebirths") or 0, Characters, Economy, Progression)
	rateLabel.Text = "+$" .. Format.number(perSecond) .. "/s"

	local eggCount, standCount = 0, 0
	for _ in DataController:Get("eggs") or {} do
		eggCount += 1
	end
	for _ in characters do
		standCount += 1
	end
	eggsButton.Text = string.format("Eggs (%d)", eggCount)
	standsButton.Text = string.format("Stands (%d)", standCount)
end

function HudController:Init()
	moneyLabel = Widgets.label({
		Name = "Money",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 40),
		Text = "$0",
		TextSize = 32,
		TextColor3 = Widgets.colors.money,
		TextStrokeTransparency = 0.3,
	})
	rateLabel = Widgets.label({
		Name = "MoneyRate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(300, 22),
		Text = "+$0/s",
		TextSize = 16,
		TextColor3 = Widgets.colors.muted,
		TextStrokeTransparency = 0.4,
	})
	toastHolder = Widgets.frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(460, 140),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = toastHolder

	eggsButton = Widgets.button({
		Name = "EggsButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, -30),
		Size = UDim2.fromOffset(120, 48),
		Text = "Eggs (0)",
	}, function()
		Widgets.togglePanel("Eggs")
	end)
	standsButton = Widgets.button({
		Name = "StandsButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 30),
		Size = UDim2.fromOffset(120, 48),
		Text = "Stands (0)",
	}, function()
		Widgets.togglePanel("Stands")
	end)

	Net.Client("Notice"):On(function(text)
		HudController:Toast(text, Widgets.colors.text)
	end)
	Net.Client("Announce"):On(function(text, rarity)
		local info = Rarities.byName[rarity]
		HudController:Toast(text, info and info.color or Widgets.colors.text)
	end)
	Net.Client("Welcome"):On(showWelcome)
end

function HudController:Start()
	DataController:WaitForData()
	refresh()
	DataController.Changed:Connect(refresh)
end

return HudController

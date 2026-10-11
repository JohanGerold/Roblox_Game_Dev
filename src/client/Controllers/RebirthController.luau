-- Rebirth button and panel. Display and requests only: the server checks the money and does the reset
-- (ProgressionService). The panel asks for a second click ("Confirm") before it sends anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Net = require(ReplicatedStorage.Shared.Net)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local DataController = require(script.Parent.DataController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local CONFIRM_SECONDS = 3

local RebirthController = {}

local infoLabel: TextLabel
local costLabel: TextLabel
local nextLabel: TextLabel
local actionButton: TextButton
local confirmUntil = 0

-- Same formula as RebirthRules.cost on the server.
local function cost(rebirths: number): number
	return Progression.rebirthCostBase * Progression.rebirthCostGrowth ^ rebirths
end

local function refresh()
	local rebirths = DataController:Get("rebirths") or 0
	local money = DataController:Get("money") or 0
	local price = cost(rebirths)
	local affordable = money >= price
	infoLabel.Text = string.format("Rebirths so far: %d", rebirths)
	costLabel.Text = string.format("Cost: $%s", Format.number(price))
	costLabel.TextColor3 = affordable and Widgets.colors.good or Widgets.colors.text
	local nextText = string.format("Next: income +%d%%, damage +%d%%", math.floor(Progression.incomeMultiplierPerRebirth * 100), math.floor(Progression.damageMultiplierPerRebirth * 100))
	if table.find(Progression.extraTeamSlotAtRebirths, rebirths + 1) then
		nextText ..= ", +1 team slot"
	end
	nextLabel.Text = nextText
	actionButton.BackgroundColor3 = affordable and Widgets.colors.good or Widgets.colors.disabled
	actionButton.Text = os.clock() < confirmUntil and "Confirm" or "Rebirth"
end

function RebirthController:Init()
	local panel = Widgets.frame({
		Name = "RebirthPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 320),
	})
	Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "Rebirth",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	infoLabel = Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	costLabel = Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 106),
		Size = UDim2.new(1, -32, 0, 40),
		Text = "You keep: stands, eggs, boss moves, armor, weapons",
		TextSize = 14,
		TextColor3 = Widgets.colors.muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 150),
		Size = UDim2.new(1, -32, 0, 40),
		Text = "You reset: money, training, stand levels",
		TextSize = 14,
		TextColor3 = Widgets.colors.muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	nextLabel = Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 196),
		Size = UDim2.new(1, -32, 0, 40),
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	actionButton = Widgets.button({
		Parent = panel,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(180, 44),
		Text = "Rebirth",
	}, function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Net.Client("Rebirth"):Fire()
		else
			confirmUntil = os.clock() + CONFIRM_SECONDS
			task.delay(CONFIRM_SECONDS + 0.05, refresh)
		end
		refresh()
	end)
	Widgets.registerPanel("Rebirth", panel)
	Widgets.button({
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 90),
		Size = UDim2.fromOffset(120, 48),
		Text = "Rebirth",
	}, function()
		Widgets.togglePanel("Rebirth")
	end)
end

function RebirthController:Start()
	DataController:WaitForData()
	refresh()
	DataController.Changed:Connect(function(key)
		if key == "money" or key == "rebirths" then
			refresh()
		end
	end)
end

return RebirthController

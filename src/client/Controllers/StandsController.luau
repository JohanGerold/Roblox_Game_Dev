-- Stands panel: your stands (best first) with Place / Store and Upgrade buttons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Income = require(ReplicatedStorage.Shared.Util.Income)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local ROW_HEIGHT = 56

local StandsController = {}

local list: ScrollingFrame
local emptyLabel: TextLabel
local upgradeButtons: { { button: TextButton, cost: number } } = {}

local function firstFreeSlot(): number?
	local used = {}
	for _, stand in DataController:Get("characters") or {} do
		if stand.slot then
			used[stand.slot] = true
		end
	end
	for slot = 1, DataController:Get("baseSlots") or Economy.startingBaseSlots do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function colorUpgradeButtons()
	local money = DataController:Get("money") or 0
	for _, entry in upgradeButtons do
		entry.button.BackgroundColor3 = money >= entry.cost and Widgets.colors.good or Widgets.colors.disabled
	end
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	upgradeButtons = {}

	local sorted = {}
	for uid, stand in DataController:Get("characters") or {} do
		if Characters[stand.id] then
			table.insert(sorted, { uid = uid, stand = stand, cfg = Characters[stand.id] })
		end
	end
	table.sort(sorted, function(a, b)
		local ra, rb = Rarities.byName[a.cfg.rarity].index, Rarities.byName[b.cfg.rarity].index
		if ra ~= rb then
			return ra > rb
		end
		if a.stand.level ~= b.stand.level then
			return a.stand.level > b.stand.level
		end
		return a.uid < b.uid
	end)
	emptyLabel.Visible = #sorted == 0

	for order, entry in sorted do
		local stand, cfg = entry.stand, entry.cfg
		local row = Widgets.frame({
			Parent = list,
			Name = entry.uid,
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			BackgroundColor3 = Widgets.colors.row,
			LayoutOrder = order,
		})
		Widgets.label({
			Parent = row,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.5, 0, 0, 24),
			Text = cfg.displayName,
			TextColor3 = Rarities.byName[cfg.rarity].color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Widgets.label({
			Parent = row,
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(0.5, 0, 0, 20),
			Text = string.format("Lv %d  $%s/s", stand.level, Format.number(Income.standIncome(stand.id, stand.level, Characters, Economy))),
			TextSize = 14,
			TextColor3 = Widgets.colors.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Widgets.button({
			Parent = row,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 4),
			Size = UDim2.fromOffset(150, 22),
			Text = stand.slot and "Store" or "Place",
			TextSize = 14,
			BackgroundColor3 = stand.slot and Widgets.colors.disabled or Widgets.colors.accent,
		}, function()
			if stand.slot then
				Net.Client("PlaceStand"):Fire(entry.uid)
				return
			end
			local slot = firstFreeSlot()
			if slot then
				Net.Client("PlaceStand"):Fire(entry.uid, slot)
			else
				HudController:Toast("All base slots full. Store a stand first.", Widgets.colors.text)
			end
		end)
		local cost = Income.upgradeCost(stand.id, stand.level, Characters, Economy)
		if cost then
			local button = Widgets.button({
				Parent = row,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 28),
				Size = UDim2.fromOffset(150, 22),
				Text = "Upgrade $" .. Format.number(cost),
				TextSize = 14,
			}, function()
				Net.Client("UpgradeStand"):Fire(entry.uid)
			end)
			table.insert(upgradeButtons, { button = button, cost = cost })
		end
	end
	colorUpgradeButtons()
end

function StandsController:Init()
	local panel = Widgets.frame({
		Name = "StandsPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 148, 0.5, 0),
		Size = UDim2.fromOffset(380, 420),
	})
	Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "Stands",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	list = Widgets.list({
		Parent = panel,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 1, -52),
	})
	emptyLabel = Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 60),
		Text = "No stands yet. Hatch an egg!",
		TextColor3 = Widgets.colors.muted,
		TextWrapped = true,
	})
	Widgets.registerPanel("Stands", panel)
end

function StandsController:Start()
	DataController:WaitForData()
	rebuild()
	DataController.Changed:Connect(function(key)
		if key == "characters" or key == "baseSlots" then
			rebuild()
		elseif key == "money" then
			colorUpgradeButtons()
		end
	end)
end

return StandsController

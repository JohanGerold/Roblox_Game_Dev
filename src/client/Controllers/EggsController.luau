-- Eggs panel: each egg's odds, a countdown or Hatch button, and the hatch reveal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local OddsDisplay = require(ReplicatedStorage.Shared.Util.OddsDisplay)
local DataController = require(script.Parent.DataController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local REVEAL_SECONDS = 2.5
local ROW_HEIGHT = 64

local EggsController = {}

local list: ScrollingFrame
local emptyLabel: TextLabel
local rows: { [string]: { readyAt: number, status: TextLabel, hatch: TextButton } } = {}

local function oddsText(eggId: string): string
	local cfg = Eggs[eggId]
	if not cfg then
		return ""
	end
	local parts = {}
	for _, row in OddsDisplay.rows(cfg.odds, Rarities) do
		local color = Rarities.byName[row.rarity].color:ToHex()
		table.insert(parts, string.format('<font color="#%s">%s %s%%</font>', color, row.rarity, tostring(math.round(row.percent * 10) / 10)))
	end
	return table.concat(parts, "  ")
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rows = {}

	local sorted = {}
	for uid, egg in DataController:Get("eggs") or {} do
		table.insert(sorted, { uid = uid, egg = egg })
	end
	table.sort(sorted, function(a, b)
		if a.egg.readyAt ~= b.egg.readyAt then
			return a.egg.readyAt < b.egg.readyAt
		end
		return a.uid < b.uid
	end)
	emptyLabel.Visible = #sorted == 0

	for order, entry in sorted do
		local cfg = Eggs[entry.egg.eggId]
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
			Size = UDim2.new(0.5, -10, 0, 24),
			Text = cfg and cfg.displayName or entry.egg.eggId,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local status = Widgets.label({
			Parent = row,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 4),
			Size = UDim2.fromOffset(90, 24),
			Text = "",
			TextColor3 = Widgets.colors.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local hatch = Widgets.button({
			Parent = row,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 4),
			Size = UDim2.fromOffset(80, 26),
			Text = "Hatch",
			BackgroundColor3 = Widgets.colors.good,
			Visible = false,
		}, function()
			Net.Client("HatchEgg"):Fire(entry.uid)
		end)
		Widgets.label({
			Parent = row,
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 0, 26),
			Text = oddsText(entry.egg.eggId),
			RichText = true,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		rows[entry.uid] = { readyAt = entry.egg.readyAt, status = status, hatch = hatch }
	end
end

local function tickRows()
	local now = workspace:GetServerTimeNow()
	for _, row in rows do
		local remaining = row.readyAt - now
		if remaining <= 0 then
			row.status.Visible = false
			row.hatch.Visible = true
		else
			row.status.Visible = true
			row.hatch.Visible = false
			local seconds = math.ceil(remaining)
			row.status.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
		end
	end
end

local function showReveal(info)
	local character = Characters[info.id]
	if not character then
		return
	end
	local color = Rarities.byName[character.rarity].color
	local reveal = Widgets.label({
		Name = "HatchReveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(520, 60),
		Text = string.format("You hatched %s! (%s)", character.displayName, character.rarity),
		TextSize = 34,
		TextColor3 = color,
		TextStrokeTransparency = 0,
	})
	task.delay(REVEAL_SECONDS, function()
		reveal:Destroy()
	end)
end

function EggsController:Init()
	local panel = Widgets.frame({
		Name = "EggsPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 148, 0.5, 0),
		Size = UDim2.fromOffset(380, 420),
	})
	Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "Eggs",
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
		Text = "No eggs yet. Defeat the boss to earn one!",
		TextColor3 = Widgets.colors.muted,
		TextWrapped = true,
	})
	Widgets.registerPanel("Eggs", panel)
	Net.Client("Hatched"):On(showReveal)
end

function EggsController:Start()
	DataController:WaitForData()
	rebuild()
	DataController.Changed:Connect(function(key)
		if key == "eggs" then
			rebuild()
			tickRows()
		end
	end)
	while true do
		tickRows()
		task.wait(1)
	end
end

return EggsController

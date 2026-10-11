-- Four ability slots for the copied boss moves (keys 1-4 by default). Display and requests only: the
-- server checks the unlock, cooldown and reach (CombatService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Moves = require(ReplicatedStorage.Shared.Config.Moves)
local Net = require(ReplicatedStorage.Shared.Net)
local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local SLOTS = 4
local SLOT_SIZE = 64
local SLOT_STEP = 72

local AbilityBarController = {}

local slots: { { frame: Frame, name: TextLabel, overlay: Frame } } = {}
local usedAt: { [number]: number } = {}

local function moveFor(slot: number): (string?, any?)
	local set = DataController:Get("equippedBossSet")
	local boss = set and Bosses[set]
	local copies = set and (DataController:Get("bossMoves") or {})[set] or 0
	if not boss or slot > copies then
		return nil, nil
	end
	local id = boss.playerMoves[slot]
	return id, Moves[id]
end

local function refresh()
	local anyUnlocked = DataController:Get("equippedBossSet") ~= nil
	for i, slot in slots do
		slot.frame.Visible = anyUnlocked
		local _, move = moveFor(i)
		slot.name.Text = move and move.displayName or "Locked"
		slot.name.TextColor3 = move and Widgets.colors.text or Widgets.colors.muted
	end
end

local function cooldownFraction(slot: number): number
	local _, move = moveFor(slot)
	local used = usedAt[slot]
	if not move or not used then
		return 0
	end
	return math.clamp(1 - (os.clock() - used) / move.cooldown, 0, 1)
end

function AbilityBarController:Init()
	for i = 1, SLOTS do
		local frame = Widgets.frame({
			Name = "Ability" .. i,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - 2.5) * SLOT_STEP, 1, -80),
			Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
			BackgroundColor3 = Widgets.colors.row,
			Visible = false,
		})
		Widgets.label({
			Parent = frame,
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(20, 16),
			Text = tostring(i),
			TextSize = 14,
			TextColor3 = Widgets.colors.money,
		})
		local name = Widgets.label({
			Parent = frame,
			Position = UDim2.fromOffset(2, 18),
			Size = UDim2.new(1, -4, 1, -20),
			Text = "Locked",
			TextSize = 12,
			TextWrapped = true,
		})
		local overlay = Widgets.frame({
			Parent = frame,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 5,
		})
		slots[i] = { frame = frame, name = name, overlay = overlay }
	end
end

function AbilityBarController:Start()
	DataController:WaitForData()
	refresh()
	DataController.Changed:Connect(function(key)
		if key == "bossMoves" or key == "equippedBossSet" then
			refresh()
		end
	end)
	InputController.Action:Connect(function(action)
		local slot = tonumber(string.match(action, "^Ability(%d)$"))
		if slot and slot >= 1 and slot <= SLOTS and moveFor(slot) and cooldownFraction(slot) <= 0 then
			usedAt[slot] = os.clock()
			Net.Client("UseAbility"):Fire(slot)
		end
	end)
	RunService.RenderStepped:Connect(function()
		for i, slot in slots do
			slot.overlay.Size = UDim2.fromScale(1, cooldownFraction(i))
		end
	end)
end

return AbilityBarController

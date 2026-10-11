-- Weapon shop panel, opened by a local "Shop" prompt on the WeaponShop part. Display and requests only:
-- the server checks distance, ownership and money (WeaponService).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.Shared.Config.Armor)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local DataController = require(script.Parent.DataController)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local ROW_HEIGHT = 44

local ShopController = {}

local list: ScrollingFrame
local order = 0

local function row(text: string, buttonText: string, buttonColor: Color3, onClick: (() -> ())?)
	order += 1
	local frame = Widgets.frame({
		Parent = list,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		BackgroundColor3 = Widgets.colors.row,
		LayoutOrder = order,
	})
	Widgets.label({
		Parent = frame,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -160, 1, 0),
		Text = text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local button = Widgets.button({
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(140, 28),
		Text = buttonText,
		TextSize = 14,
		BackgroundColor3 = buttonColor,
	}, onClick or function() end)
	button.Active = onClick ~= nil
end

local function header(text: string)
	order += 1
	Widgets.label({
		Parent = list,
		Size = UDim2.new(1, -8, 0, 26),
		Text = text,
		TextSize = 18,
		TextColor3 = Widgets.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
end

local function contains(owned: { string }?, id: string): boolean
	return owned ~= nil and table.find(owned, id) ~= nil
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	order = 0
	local money = DataController:Get("money") or 0
	local weapons = DataController:Get("weapons") or { owned = {}, equipped = "" }
	local armor = DataController:Get("armor") or { owned = {}, equipped = {} }

	header("Weapons")
	local sorted = {}
	for id, weapon in Weapons do
		table.insert(sorted, { id = id, weapon = weapon })
	end
	table.sort(sorted, function(a, b)
		if a.weapon.price ~= b.weapon.price then
			return a.weapon.price < b.weapon.price
		end
		return a.id < b.id
	end)
	for _, entry in sorted do
		local id, weapon = entry.id, entry.weapon
		if weapons.equipped == id then
			row(weapon.displayName, "Equipped", Widgets.colors.disabled, nil)
		elseif contains(weapons.owned, id) then
			row(weapon.displayName, "Equip", Widgets.colors.accent, function()
				Net.Client("Equip"):Fire("weapon", id)
			end)
		else
			local color = money >= weapon.price and Widgets.colors.good or Widgets.colors.disabled
			row(weapon.displayName, "Buy $" .. Format.number(weapon.price), color, function()
				Net.Client("BuyWeapon"):Fire(id)
			end)
		end
	end

	header("Armor")
	local any = false
	for id, piece in Armor do
		if contains(armor.owned, id) then
			any = true
			if armor.equipped[piece.slot] == id then
				row(piece.displayName, "Equipped", Widgets.colors.disabled, nil)
			else
				row(piece.displayName, "Equip", Widgets.colors.accent, function()
					Net.Client("Equip"):Fire("armor", id)
				end)
			end
		end
	end
	if not any then
		header("None yet. Armor drops from bosses.")
	end
end

function ShopController:Init()
	local panel = Widgets.frame({
		Name = "ShopPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 360),
	})
	Widgets.label({
		Parent = panel,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "Weapon Shop",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	list = Widgets.list({
		Parent = panel,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 1, -52),
	})
	Widgets.registerPanel("Shop", panel)
end

function ShopController:Start()
	DataController:WaitForData()
	rebuild()
	DataController.Changed:Connect(function(key)
		if key == "money" or key == "weapons" or key == "armor" then
			rebuild()
		end
	end)
	task.spawn(function()
		local shop
		while not shop do
			shop = CollectionService:GetTagged("WeaponShop")[1]
			if not shop then
				task.wait(0.5)
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Shop"
		prompt.ObjectText = "Weapons"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = shop
		prompt.Triggered:Connect(function()
			Widgets.togglePanel("Shop")
		end)
	end)
end

return ShopController

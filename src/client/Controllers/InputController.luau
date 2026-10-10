-- Rebindable actions (spec section 13). Binds keyboard/mouse/gamepad/touch through ContextActionService
-- and announces each press as InputController.Action:Fire(actionName). Binds come from
-- Config/Keybinds defaults, overridden by data.settings.keybinds.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Keybinds = require(ReplicatedStorage.Shared.Config.Keybinds)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataController = require(script.Parent.DataController)

local InputController = {}
InputController.Action = Signal.new() -- Fire(action: string), on press only

local PREFIX = "Input_"
local GAMEPAD = { Attack = Enum.KeyCode.ButtonX, Parry = Enum.KeyCode.ButtonL1, Dodge = Enum.KeyCode.ButtonB }
local TOUCH_TITLE = { Attack = "Hit", Parry = "Parry", Dodge = "Dodge" }

local bound: { string } = {}

local function resolve(name: any): (Enum.KeyCode | Enum.UserInputType)?
	if type(name) ~= "string" then
		return nil
	end
	-- Indexing an Enum with an unknown name throws, so search the item lists instead.
	for _, enum in { Enum.KeyCode, Enum.UserInputType } do
		for _, item in enum:GetEnumItems() do
			if item.Name == name then
				return item
			end
		end
	end
	return nil
end

function InputController:Bind()
	for _, name in bound do
		ContextActionService:UnbindAction(name)
	end
	table.clear(bound)

	local settings = DataController:Get("settings")
	local overrides = settings and settings.keybinds or {}
	for action, default in Keybinds.defaults do
		local input = resolve(overrides[action]) or resolve(default)
		if not input then
			warn("[InputController] unknown input for " .. action)
		else
			local inputs: { any } = { input }
			if GAMEPAD[action] then
				table.insert(inputs, GAMEPAD[action])
			end
			local name = PREFIX .. action
			ContextActionService:BindAction(name, function(_, state)
				if state == Enum.UserInputState.Begin then
					InputController.Action:Fire(action)
				end
				return Enum.ContextActionResult.Pass
			end, TOUCH_TITLE[action] ~= nil, table.unpack(inputs))
			if TOUCH_TITLE[action] then
				ContextActionService:SetTitle(name, TOUCH_TITLE[action])
			end
			table.insert(bound, name)
		end
	end
end

function InputController:Start()
	DataController:WaitForData()
	self:Bind()
	DataController.Changed:Connect(function(key)
		if key == "settings" then
			self:Bind()
		end
	end)
end

return InputController

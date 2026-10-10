-- Thin Instance.new helpers with one shared style (dark panels, rounded corners, GothamBold).
-- Props are real Roblox property names; `Parent` defaults to the shared ScreenGui.
local Players = game:GetService("Players")

local Widgets = {}

Widgets.colors = {
	panel = Color3.fromRGB(24, 26, 34),
	row = Color3.fromRGB(38, 41, 54),
	accent = Color3.fromRGB(59, 130, 246),
	good = Color3.fromRGB(34, 197, 94),
	disabled = Color3.fromRGB(75, 80, 98),
	text = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(156, 163, 175),
	money = Color3.fromRGB(250, 204, 21),
}

local FONT = Enum.Font.GothamBold
local CORNER = 8
local DESIGN_HEIGHT = 720

local gui: ScreenGui? = nil
local panels: { [string]: GuiObject } = {}

local function make(className: string, defaults: { [string]: any }, props: { [string]: any }): Instance
	local instance = Instance.new(className)
	for key, value in defaults do
		if props[key] == nil then
			(instance :: any)[key] = value
		end
	end
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CORNER)
	if className ~= "TextLabel" and className ~= "ScrollingFrame" then
		corner.Parent = instance
	end
	instance.Parent = parent or Widgets.gui()
	return instance
end

-- The one ScreenGui every controller draws into, scaled to the screen height.
function Widgets.gui(): ScreenGui
	if gui then
		return gui
	end
	local created = Instance.new("ScreenGui")
	created.Name = "MainUi"
	created.ResetOnSpawn = false
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Parent = created
	local camera = workspace.CurrentCamera
	if camera then
		local function update()
			scale.Scale = math.clamp(camera.ViewportSize.Y / DESIGN_HEIGHT, 0.6, 1.2)
		end
		update()
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = created
	return created
end

function Widgets.frame(props: { [string]: any }): Frame
	return make("Frame", { BackgroundColor3 = Widgets.colors.panel, BorderSizePixel = 0 }, props) :: Frame
end

function Widgets.label(props: { [string]: any }): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Widgets.colors.text,
		TextSize = 18,
	}, props) :: TextLabel
end

function Widgets.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local button = make("TextButton", {
		BackgroundColor3 = Widgets.colors.accent,
		BorderSizePixel = 0,
		Font = FONT,
		TextColor3 = Widgets.colors.text,
		TextSize = 16,
	}, props) :: TextButton
	button.Activated:Connect(onClick)
	return button
end

-- A vertically scrolling list; add rows as children.
function Widgets.list(props: { [string]: any }): ScrollingFrame
	local scroller = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, props) :: ScrollingFrame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller
	return scroller
end

-- Panels are shown one at a time.
function Widgets.registerPanel(name: string, frame: GuiObject)
	frame.Visible = false
	panels[name] = frame
end

function Widgets.togglePanel(name: string)
	local target = panels[name]
	if not target then
		return
	end
	local show = not target.Visible
	for _, panel in panels do
		panel.Visible = false
	end
	target.Visible = show
end

return Widgets

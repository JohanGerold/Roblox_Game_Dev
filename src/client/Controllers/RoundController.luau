-- Day/night countdown, top right. Display only: the server owns RoundPhase / RoundEndsAt.
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local REFRESH_SECONDS = 0.2
local DAY_COLOR = Color3.fromRGB(255, 170, 90)
local NIGHT_COLOR = Color3.fromRGB(170, 190, 255)

local RoundController = {}

local label: TextLabel

local function render()
	local phase = workspace:GetAttribute("RoundPhase")
	if not phase then
		label.Visible = false
		return
	end
	local left = math.max(0, math.ceil((workspace:GetAttribute("RoundEndsAt") or 0) - workspace:GetServerTimeNow()))
	label.Text = string.format("%s %d:%02d", string.upper(phase), left // 60, left % 60)
	label.TextColor3 = phase == "Day" and DAY_COLOR or NIGHT_COLOR
	label.Visible = true
end

function RoundController:Init()
	label = Widgets.label({
		Name = "RoundTimer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(200, 36),
		Text = "",
		TextSize = 24,
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
end

function RoundController:Start()
	task.spawn(function()
		while true do
			render()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return RoundController

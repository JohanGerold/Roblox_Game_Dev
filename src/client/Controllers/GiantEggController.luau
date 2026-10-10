-- Status banner for the giant egg (countdown, head start, who carries it). Display only: the server
-- sends every state change through GiantEggState and decides everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local REFRESH_SECONDS = 0.2
local HOLD_SECONDS = 3
local GOLD = Color3.fromRGB(255, 205, 60)

local GiantEggController = {}

local label: TextLabel
local states: { [string]: { state: { [string]: any }, seq: number } } = {} -- latest state per egg id
local seq = 0
local holdText: string? = nil
local holdUntil = 0

local function secondsLeft(state): number
	return math.max(0, math.ceil((state.endsAt or 0) - workspace:GetServerTimeNow()))
end

local function describe(state): string?
	local phase = state.phase
	if phase == "Countdown" then
		return string.format("Giant Egg in %d...", secondsLeft(state))
	elseif phase == "HeadStart" then
		return string.format("Top 3 grab first: %d s", secondsLeft(state))
	elseif phase == "Free" then
		return "Giant Egg up for grabs!"
	elseif phase == "Carried" then
		if state.carrierUserId == Players.LocalPlayer.UserId then
			return "Bring it to your base pad!"
		end
		return string.format("%s has the Giant Egg!", state.carrierName or "Someone")
	elseif phase == "Returned" then
		return "The Giant Egg returned to the arena"
	elseif phase == "Delivered" then
		return string.format("%s delivered it!", state.carrierName or "Someone")
	elseif phase == "Despawned" then
		return "The Giant Egg vanished"
	end
	return nil
end

-- Several eggs can exist at once, so the banner shows the most relevant one: the egg you carry,
-- then countdowns, head starts, free eggs, and last other players' carried eggs (latest wins a tie).
local function priority(state): number
	local phase = state.phase
	if phase == "Carried" then
		return state.carrierUserId == Players.LocalPlayer.UserId and 5 or 1
	elseif phase == "Countdown" then
		return 4
	elseif phase == "HeadStart" then
		return 3
	end
	return 2
end

local function current(): { [string]: any }?
	local best, bestRank, bestSeq = nil, 0, 0
	for _, entry in states do
		local rank = priority(entry.state)
		if rank > bestRank or (rank == bestRank and entry.seq > bestSeq) then
			best, bestRank, bestSeq = entry.state, rank, entry.seq
		end
	end
	return best
end

local function render()
	local shown = current()
	local text = if os.clock() < holdUntil then holdText elseif shown then describe(shown) else nil
	label.Visible = text ~= nil
	if text then
		label.Text = text
	end
end

local function onState(state)
	local phase = state.phase
	if phase == "Returned" or phase == "Delivered" or phase == "Despawned" then
		holdText = describe(state)
		holdUntil = os.clock() + HOLD_SECONDS
	end
	seq += 1
	states[state.id] = if phase == "Delivered" or phase == "Despawned" then nil else { state = state, seq = seq }
	render()
end

function GiantEggController:Init()
	label = Widgets.label({
		Name = "GiantEggBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 222),
		Size = UDim2.fromOffset(460, 30),
		Text = "",
		TextSize = 22,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
	Net.Client("GiantEggState"):On(onState)
end

function GiantEggController:Start()
	task.spawn(function()
		while true do
			render()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return GiantEggController

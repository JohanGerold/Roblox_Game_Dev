-- Studio-only test hooks so play-tests can drive combat without a human. Reads two player attributes
-- (set from MCP): AutoAttack (boolean), AutoDefend ("Parry" | "Dodge") and FireRemote ("Name|arg|arg").
-- Does nothing outside Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Net = require(ReplicatedStorage.Shared.Net)
local CombatController = require(script.Parent.CombatController)

local player = Players.LocalPlayer

local StudioTestController = {}

local function unparryable(bossId: string, attackId: string): boolean
	local cfg = Bosses[bossId]
	for _, attack in cfg and cfg.attacks or {} do
		if attack.id == attackId then
			return attack.unparryable
		end
	end
	return false
end

function StudioTestController:Start()
	if not RunService:IsStudio() then
		return
	end

	task.spawn(function()
		while true do
			task.wait(0.45)
			if player:GetAttribute("AutoAttack") == true then
				CombatController:Attack()
			end
		end
	end)

	-- FireRemote = "Name|arg1|arg2": sends that client->server message (numeric args become numbers),
	-- then clears itself. The server still validates everything.
	player:GetAttributeChangedSignal("FireRemote"):Connect(function()
		local text = player:GetAttribute("FireRemote")
		if type(text) ~= "string" or text == "" then
			return
		end
		player:SetAttribute("FireRemote", nil)
		local parts = string.split(text, "|")
		local name = table.remove(parts, 1)
		for i, part in parts do
			parts[i] = tonumber(part) or part
		end
		Net.Client(name):Fire(table.unpack(parts))
	end)

	Net.Client("BossAttack"):On(function(bossId, attackId, impactTime)
		local mode = player:GetAttribute("AutoDefend")
		if mode ~= "Parry" and mode ~= "Dodge" then
			return
		end
		local kind = mode
		if kind == "Parry" and unparryable(bossId, attackId) then
			kind = "Dodge"
		end
		task.delay(math.max(0, impactTime - workspace:GetServerTimeNow() - 0.05), function()
			CombatController:Defend(kind, true)
		end)
	end)

	Net.Client("HitResult"):On(function(info)
		if player:GetAttribute("AutoDefend") == "Dodge" and info.result == "PerfectDodge" then
			CombatController:Attack()
		end
	end)
end

return StudioTestController

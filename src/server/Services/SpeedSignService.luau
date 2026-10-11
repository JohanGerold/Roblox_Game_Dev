-- Writes the boss's chase speed and the walk speed needed to outrun it with each egg onto the
-- SpeedSign at the domain gate (spec D6). Text only; the numbers come from config.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local SpeedRule = require(script.Parent.Parent.Logic.SpeedRule)

local SpeedSignService = {}

local function stageBoss()
	local ids = {}
	for id, cfg in Bosses do
		if cfg.kind == "Stage" and cfg.stageId == Map.stageId then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids[1] and Bosses[ids[1]]
end

function SpeedSignService:Start()
	local boss = stageBoss()
	if not boss then
		warn("[SpeedSignService] no stage boss for " .. Map.stageId)
		return
	end
	local signs = CollectionService:GetTagged("SpeedSign")
	if #signs == 0 then
		warn("[SpeedSignService] no SpeedSign on the map")
		return
	end
	local text = table.concat(SpeedRule.lines(boss.chaseSpeed, Eggs), "\n")
	for _, sign in signs do
		for _, d in sign:GetDescendants() do
			if d:IsA("TextLabel") then
				d.Text = text
			end
		end
	end
end

return SpeedSignService

-- Gives every boss participant a rank egg when a boss dies (ranks 1-3 the top egg, the rest the normal egg).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Server = script.Parent.Parent
local LootRank = require(Server.Logic.LootRank)
local AnnounceService = require(script.Parent.AnnounceService)
local BossService = require(script.Parent.BossService)
local EggService = require(script.Parent.EggService)

local LootService = {}

local function onDefeated(bossId: string, ledger: { [number]: number })
	local cfg = Bosses[bossId]
	local rankEggs = cfg and cfg.rankEggs
	if not rankEggs then
		return
	end
	for _, entry in LootRank.rank(ledger, Combat.minDamageShare, rankEggs.topCount) do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player then
			local eggId = entry.top and rankEggs.top or rankEggs.normal
			if EggService:Grant(player, eggId) then
				AnnounceService:Notice(player, string.format("Rank #%d! You got a %s", entry.rank, Eggs[eggId].displayName))
			end
		end
	end
end

function LootService:Start()
	BossService.Defeated:Connect(onDefeated)
end

return LootService

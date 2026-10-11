-- Drops every boss participant's rank egg in the arena when a boss dies (ranks 1-3 the top egg, the
-- rest the normal egg). The egg is a personal carryable: only its owner can pick it up and it counts
-- once delivered to their base (CarryService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Server = script.Parent.Parent
local CarryRules = require(Server.Logic.CarryRules)
local LootRank = require(Server.Logic.LootRank)
local AnnounceService = require(script.Parent.AnnounceService)
local BossService = require(script.Parent.BossService)
local CarryService = require(script.Parent.CarryService)
local EggService = require(script.Parent.EggService)

local LootService = {}

local function onDefeated(bossId: string, ledger: { [number]: number })
	local cfg = Bosses[bossId]
	local rankEggs = cfg and cfg.rankEggs
	if not rankEggs then
		return
	end
	local ranked = LootRank.rank(ledger, Combat.minDamageShare, rankEggs.topCount)
	local center = CarryService:GetArenaEggSpawn(bossId)
	local ring = center and CarryRules.ringPositions(center, Carry.personalRingRadius, #ranked)
	for i, entry in ranked do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player then
			local eggId = entry.top and rankEggs.top or rankEggs.normal
			local name = Eggs[eggId].displayName
			if ring and CarryService:SpawnPersonal(player, eggId, ring[i]) then
				AnnounceService:Notice(player, string.format("Rank #%d! Carry your %s home", entry.rank, name))
			elseif EggService:Grant(player, eggId) then
				-- no arena spawn on the map: a broken map must never eat rewards
				warn("[LootService] could not drop the " .. eggId .. " in the arena, granted it directly")
				AnnounceService:Notice(player, string.format("Rank #%d! You got a %s", entry.rank, name))
			end
		end
	end
end

function LootService:Start()
	BossService.Defeated:Connect(onDefeated)
end

return LootService

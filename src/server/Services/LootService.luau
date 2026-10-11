-- Drops every boss participant's rank egg in the arena when a boss dies (ranks 1-3 the top egg, the
-- rest the normal egg). The egg is a personal carryable: only its owner can pick it up and it counts
-- once delivered to their base (CarryService). Armor and moveset copies drop straight into the save.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Armor = require(ReplicatedStorage.Shared.Config.Armor)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Moves = require(ReplicatedStorage.Shared.Config.Moves)
local Server = script.Parent.Parent
local CarryRules = require(Server.Logic.CarryRules)
local DropRoll = require(Server.Logic.DropRoll)
local LootRank = require(Server.Logic.LootRank)
local AnnounceService = require(script.Parent.AnnounceService)
local BossService = require(script.Parent.BossService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)

local LootService = {}

local rng = Random.new()

-- Rolls the boss's armor and moveset-copy drops for one participant and saves what they got.
local function giveDrops(player: Player, bossId: string, cfg)
	local data = DataService:Get(player)
	if not data or not cfg.drops then
		return
	end
	local result = DropRoll.roll(cfg.drops, data.armor.owned, data.bossMoves[bossId] or 0, #cfg.playerMoves, rng)
	if result.armorId then
		local piece = Armor[result.armorId]
		DataService:Update(player, "armor", function(armor)
			table.insert(armor.owned, result.armorId)
			if not armor.equipped[piece.slot] then
				armor.equipped[piece.slot] = result.armorId
			end
			return armor
		end)
		AnnounceService:Notice(player, "Armor drop: " .. piece.displayName .. "!")
	end
	if result.moveCopy then
		local copies = (data.bossMoves[bossId] or 0) + 1
		DataService:Update(player, "bossMoves", function(bossMoves)
			bossMoves[bossId] = copies
			return bossMoves
		end)
		if data.equippedBossSet == nil then
			DataService:Update(player, "equippedBossSet", function()
				return bossId
			end)
		end
		AnnounceService:Notice(player, "You copied " .. Moves[cfg.playerMoves[copies]].displayName .. "!")
	end
end

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
			giveDrops(player, bossId, cfg)
		end
	end
end

function LootService:Start()
	BossService.Defeated:Connect(onDefeated)
end

return LootService

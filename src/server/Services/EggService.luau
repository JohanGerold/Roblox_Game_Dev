-- Personal eggs: grants them and hatches them into stands. Rolls happen only here, on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local Server = script.Parent.Parent
local EggRoll = require(Server.Logic.EggRoll)
local EggRules = require(Server.Logic.EggRules)
local StandPlace = require(Server.Logic.StandPlace)
local Uid = require(Server.Logic.Uid)
local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)

local ANNOUNCE_FROM_RARITY_INDEX = 6 -- Mythic

local REASON_TEXT = {
	["no egg"] = "That egg doesn't exist.",
	["not ready"] = "That egg isn't ready yet.",
	["inventory full"] = "Your stand inventory is full.",
}

local EggService = {}

local rng = Random.new()
local hatched

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Adds an egg that hatches after the egg's hatchSeconds. Returns its uid, or nil if the egg id is
-- unknown, data isn't loaded, or egg storage is full.
function EggService:Grant(player: Player, eggId: string): string?
	local cfg = Eggs[eggId]
	local data = DataService:Get(player)
	if not cfg or not data then
		return nil
	end
	if not EggRules.canReceive(count(data.eggs), Economy) then
		AnnounceService:Notice(player, string.format("Egg storage full (%d). Hatch some eggs!", Economy.eggCap))
		return nil
	end
	local uid
	local ok = DataService:Update(player, "eggs", function(eggs)
		uid = Uid.new("e", eggs, rng)
		eggs[uid] = { eggId = eggId, readyAt = os.time() + cfg.hatchSeconds }
		return eggs
	end)
	return ok and uid or nil
end

local function hatch(player: Player, eggUid: string)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local egg = data.eggs[eggUid]
	local ok, reason = EggRules.canHatch(egg, os.time(), count(data.characters), Economy)
	if not ok then
		AnnounceService:Notice(player, REASON_TEXT[reason] or "Can't hatch that.")
		return
	end
	local cfg = Eggs[egg.eggId]
	if not cfg then
		warn("[EggService] unknown egg id in save: " .. tostring(egg.eggId))
		return
	end

	local charId = EggRoll.roll(cfg, Characters, rng)
	-- Remove the egg first: if the player's data is gone, nothing is given.
	local removed = DataService:Update(player, "eggs", function(eggs)
		eggs[eggUid] = nil
		return eggs
	end)
	if not removed then
		return
	end
	local newUid
	DataService:Update(player, "characters", function(characters)
		newUid = Uid.new("c", characters, rng)
		characters[newUid] = { id = charId, level = 1, slot = StandPlace.firstFreeSlot(characters, data.baseSlots) }
		return characters
	end)

	hatched:Fire(player, { uid = newUid, id = charId })
	local character = Characters[charId]
	if Rarities.byName[character.rarity].index >= ANNOUNCE_FROM_RARITY_INDEX then
		AnnounceService:All(string.format("%s hatched %s!", player.DisplayName, character.displayName), character.rarity)
	end
end

function EggService:Init()
	hatched = Net.Server("Hatched")
	Net.Server("HatchEgg"):On(hatch)
end

return EggService

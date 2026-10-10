-- Stand level upgrades, paid for with money. Cost and scaling come from config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Income = require(ReplicatedStorage.Shared.Util.Income)
local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local UpgradeService = {}

local function upgrade(player: Player, charUid: string)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local stand = data.characters[charUid]
	if not stand then
		AnnounceService:Notice(player, "You don't have that stand.")
		return
	end
	local cost = Income.upgradeCost(stand.id, stand.level, Characters, Economy)
	if not cost then
		AnnounceService:Notice(player, "Max level")
		return
	end
	if not EconomyService:TrySpend(player, cost) then
		AnnounceService:Notice(player, "Not enough money")
		return
	end
	DataService:Update(player, "characters", function(characters)
		characters[charUid].level += 1
		return characters
	end)
end

function UpgradeService:Init()
	Net.Server("UpgradeStand"):On(upgrade)
end

return UpgradeService

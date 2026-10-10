-- Server-wide announcements and personal toasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local AnnounceService = {}

local announce, notice

function AnnounceService:All(text: string, rarity: string)
	announce:FireAll(text, rarity)
end

function AnnounceService:Notice(player: Player, text: string)
	notice:Fire(player, text)
end

function AnnounceService:Init()
	announce = Net.Server("Announce")
	notice = Net.Server("Notice")
end

return AnnounceService

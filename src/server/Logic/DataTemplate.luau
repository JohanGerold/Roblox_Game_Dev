-- Player save layout (spec section 6). Saves store ids only; stats come from config.
local DataTemplate = {}

DataTemplate.CURRENT_VERSION = 1

function DataTemplate.new(): { [string]: any }
	return {
		version = DataTemplate.CURRENT_VERSION,
		money = 0,
		rebirths = 0,
		lastSeen = 0, -- unix time, for offline earnings
		training = { speed = 0, power = 0 },
		characters = {}, -- [uid] = { id, level, slot }
		baseSlots = 4,
		standTeam = {}, -- list of character uids
		eggs = {}, -- [uid] = { eggId, readyAt }
		bossMoves = {}, -- [bossId] = copies collected
		equippedBossSet = nil,
		armor = { owned = {}, equipped = {} },
		weapons = { owned = { "Fists" }, equipped = "Fists" },
		settings = { fewerEffects = false, keybinds = {} },
	}
end

return DataTemplate

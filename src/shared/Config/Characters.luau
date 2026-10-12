-- Stage 1 roster (Jujutsu Kaisen, renamed): docs/specs/2026-10-11-stage1-roster-design.md.
-- `model` names live in ReplicatedStorage.Assets.Characters and equal the id. `family` links forms for future
-- ascension. Stats are per rarity. `role` is "damage" unless set: "buffer" (Utahame) and "healer" (Hanamo) deal
-- normal stand damage until their role spec exists.
local STATS = {
	Common = { baseIncome = 1, basePower = 1 },
	Rare = { baseIncome = 8, basePower = 6 },
	Epic = { baseIncome = 40, basePower = 30 },
	Legendary = { baseIncome = 250, basePower = 180 },
	Mythic = { baseIncome = 2000, basePower = 1500 },
	Celestial = { baseIncome = 20000, basePower = 15000 },
}

local function stand(id: string, displayName: string, rarity: string, family: string, role: string?, walkAnim: string?)
	local stats = STATS[rarity]
	return {
		displayName = displayName,
		rarity = rarity,
		family = family,
		model = id,
		walkAnim = walkAnim or "Walk_Default",
		baseIncome = stats.baseIncome,
		basePower = stats.basePower,
		role = role or "damage",
	}
end

return {
	Yuju_Base = stand("Yuju_Base", "Yuju Itadore", "Common", "Yuju"),
	Miwo_Base = stand("Miwo_Base", "Kasumo Miwo", "Common", "Miwo"),
	Nobaru_Base = stand("Nobaru_Base", "Nobaru Kugisake", "Rare", "Nobaru"),
	Momo_Base = stand("Momo_Base", "Momo Nishimiye", "Rare", "Momo"),
	Pando_Base = stand("Pando_Base", "Pando", "Rare", "Pando"),
	Megumu_Base = stand("Megumu_Base", "Megumu Fushigoro", "Epic", "Megumu"),
	Mai_Base = stand("Mai_Base", "Mai Zenim", "Epic", "Mai"),
	Kamo_Base = stand("Kamo_Base", "Noritoshe Kamo", "Epic", "Kamo"),
	Inumako_Base = stand("Inumako_Base", "Togi Inumako", "Epic", "Inumako"),
	Mechamaro_Base = stand("Mechamaro_Base", "Mechamaro", "Legendary", "Mechamaro"),
	Yago_Base = stand("Yago_Base", "Masamachi Yago", "Legendary", "Yago"),
	Utahame_Base = stand("Utahame_Base", "Utahame Iori", "Legendary", "Utahame", "buffer"),
	Hanamo_Base = stand("Hanamo_Base", "Hanamo", "Legendary", "Hanamo", "healer"),
	Toudo_Base = stand("Toudo_Base", "Aoi Toudo", "Mythic", "Toudo", nil, "Walk_Serious"),
	Gakugonji_Base = stand("Gakugonji_Base", "Gakugonji", "Mythic", "Gakugonji", nil, "Walk_Serious"),
	Gojou_Blindfold = stand("Gojou_Blindfold", "Satoro Gojou (Blindfold)", "Celestial", "Gojou", nil, "Walk_Serious"),
}

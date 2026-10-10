-- 12 tiers, Common -> Absolute. Aura: none below Mythic, static at Mythic, animated above.
local order = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
	"Celestial", "Divine", "Transcendent", "Primordial", "Omniversal", "Absolute",
}

local colors = {
	Common = "9CA3AF", Uncommon = "22C55E", Rare = "3B82F6", Epic = "A855F7",
	Legendary = "F59E0B", Mythic = "F43F5E", Celestial = "67E8F9", Divine = "FCD34D",
	Transcendent = "F472B6", Primordial = "C4B5FD", Omniversal = "E879F9", Absolute = "F87171",
}

local byName = {}
for i, name in order do
	byName[name] = {
		index = i,
		color = Color3.fromHex(colors[name]),
		aura = i < 6 and "None" or i == 6 and "Static" or "Animated",
		auraIntensity = math.max(0, i - 6),
	}
end

return { order = order, byName = byName }

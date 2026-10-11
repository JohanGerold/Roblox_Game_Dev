-- Day/night round cycle (spec D10-D12). Times in seconds.
-- lighting: Ambient/OutdoorAmbient/ClockTime go on Lighting; Density/Color/Decay/Haze/Glare on its Atmosphere.
return {
	daySeconds = 240,
	nightSeconds = 45,
	lightingTweenSeconds = 3,
	fieldEggs = {
		small = "Field_Small",
		shiny = "Field_Shiny",
		giant = "Stage1_Giant",
		smallExtra = 2, -- small egg slots = players + smallExtra
		shinyChance = 0.10, -- per small slot
		giantChance = 0.25, -- one extra giant egg per day
	},
	lighting = {
		Day = {
			ClockTime = 17.6,
			Ambient = Color3.fromRGB(90, 30, 20),
			OutdoorAmbient = Color3.fromRGB(120, 50, 30),
			Density = 0.35,
			Color = Color3.fromRGB(255, 110, 60),
			Decay = Color3.fromRGB(120, 30, 20),
			Haze = 2,
			Glare = 0.5,
		},
		Night = {
			ClockTime = 0,
			Ambient = Color3.fromRGB(25, 20, 40),
			OutdoorAmbient = Color3.fromRGB(30, 25, 50),
			Density = 0.45,
			Color = Color3.fromRGB(60, 50, 90),
			Decay = Color3.fromRGB(20, 15, 40),
			Haze = 1,
			Glare = 0,
		},
	},
}

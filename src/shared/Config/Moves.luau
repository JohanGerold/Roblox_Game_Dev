-- Boss moves players copy from drops (Bosses.playerMoves ids). Placeholder numbers for the playtest.
-- damage is the base before power, armor and rebirth multipliers; range in studs; cooldown in seconds.
return {
	Lofy_Punch = { displayName = "Rubber Punch", damage = 80, range = 12, cooldown = 4 },
	Lofy_Stretch = { displayName = "Stretch Strike", damage = 60, range = 24, cooldown = 6 },
	Lofy_Barrage = { displayName = "Gatling Barrage", damage = 200, range = 12, cooldown = 12 },
	Lofy_Ultimate = { displayName = "Giant Fist", damage = 600, range = 16, cooldown = 30 },
}

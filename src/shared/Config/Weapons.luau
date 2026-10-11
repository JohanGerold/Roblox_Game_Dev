-- combat: each hit has damage, range (studs) and minInterval (seconds between hits).
return {
	Fists = { displayName = "Fists", price = 0, kind = "Physical", model = "Fists", combo = { { damage = 10, range = 8, minInterval = 0.3 }, { damage = 10, range = 8, minInterval = 0.3 }, { damage = 16, range = 9, minInterval = 0.5 } }, abilities = {} },
	Stick = { displayName = "Stick", price = 500, kind = "Physical", model = "Stick", combo = { { damage = 18, range = 10, minInterval = 0.35 }, { damage = 22, range = 10, minInterval = 0.45 } }, abilities = {} },
	Katana = { displayName = "Katana", price = 25000, kind = "Physical", model = "Katana", combo = { { damage = 60, range = 11, minInterval = 0.3 }, { damage = 60, range = 11, minInterval = 0.3 }, { damage = 120, range = 12, minInterval = 0.6 } }, abilities = {} },
}

-- Treadmill (speed) and sandbag (power) training. Speed points add 1:1 to walk speed up to maxWalkSpeed.
return {
	speedPerSecond = 0.05,
	powerPerSecond = 0.05,
	baseWalkSpeed = 16,
	maxWalkSpeed = 60,
	trainRange = 6, -- studs (flat) from the station while training
	tickSeconds = 1, -- the server re-checks and adds progress this often
}

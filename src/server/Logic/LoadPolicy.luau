-- When to give up loading a player's profile. Without a timeout, a DataStore outage would
-- keep a player in the game with no data (ProfileStore retries forever when given a Cancel).
local LoadPolicy = {}

LoadPolicy.TIMEOUT_SECONDS = 120

function LoadPolicy.shouldCancel(playerInGame: boolean, elapsedSeconds: number, timeoutSeconds: number): boolean
	return not playerInGame or elapsedSeconds > timeoutSeconds
end

return LoadPolicy

-- Sliding-window limiter: at most `max` allowed calls per `windowSeconds` per key.
-- Blocked calls are not recorded. Pure; the caller supplies `now`.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(max: number, windowSeconds: number)
	return setmetatable({ max = max, window = windowSeconds, hits = {} :: { [any]: { number } } }, RateLimiter)
end

function RateLimiter:allow(key: any, now: number): boolean
	local list = self.hits[key] or {}

	local kept = {}
	for _, t in list do
		if now - t < self.window then
			table.insert(kept, t)
		end
	end

	if #kept >= self.max then
		self.hits[key] = kept
		return false
	end
	table.insert(kept, now)
	self.hits[key] = kept
	return true
end

function RateLimiter:remove(key: any)
	self.hits[key] = nil
end

return RateLimiter

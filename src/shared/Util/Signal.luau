-- Minimal signal: Connect(fn) -> { Disconnect }, Fire(...).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ listeners = {} :: { [number]: (...any) -> () }, nextId = 0 }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	self.nextId += 1
	local id = self.nextId
	self.listeners[id] = fn
	return {
		Disconnect = function()
			self.listeners[id] = nil
		end,
	}
end

function Signal:Fire(...)
	for _, fn in self.listeners do
		task.spawn(fn, ...)
	end
end

return Signal

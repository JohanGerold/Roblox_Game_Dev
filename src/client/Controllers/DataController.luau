-- Client copy of the player's own data (read-only; the server is the only writer).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataController = {}
DataController.Changed = Signal.new() -- Fire(key, value)

local data: { [string]: any }? = nil

function DataController:Get(key: string): any
	return data and data[key]
end

function DataController:WaitForData(): { [string]: any }
	while data == nil do
		task.wait(0.1)
	end
	return data :: { [string]: any }
end

function DataController:Init()
	Net.Client("DataInit"):On(function(initial)
		data = initial
	end)
	Net.Client("DataChanged"):On(function(key, value)
		if data then
			data[key] = value
		end
		DataController.Changed:Fire(key, value)
	end)
end

function DataController:Start()
	Net.Client("RequestData"):Fire() -- in case DataInit arrived before this client was listening
end

return DataController

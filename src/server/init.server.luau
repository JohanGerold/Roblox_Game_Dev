-- Two-phase boot: every service's Init runs first, then every Start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

Net.InitServer()

local services = {}
for _, module in script.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(services, module)
	end
end
table.sort(services, function(a, b)
	return a.Name < b.Name
end)

local loaded = {}
for _, module in services do
	local ok, service = xpcall(require, debug.traceback, module)
	if ok then
		table.insert(loaded, { name = module.Name, service = service })
	else
		warn(string.format("[Boot] failed to load %s: %s", module.Name, tostring(service)))
	end
end

for _, entry in loaded do
	if entry.service.Init then
		local ok, err = xpcall(entry.service.Init, debug.traceback, entry.service)
		if not ok then
			warn(string.format("[Boot] %s.Init failed: %s", entry.name, tostring(err)))
		end
	end
end

for _, entry in loaded do
	if entry.service.Start then
		task.spawn(function()
			local ok, err = xpcall(entry.service.Start, debug.traceback, entry.service)
			if not ok then
				warn(string.format("[Boot] %s.Start failed: %s", entry.name, tostring(err)))
			end
		end)
	end
end

print(string.format("[Boot] server: %d services started", #loaded))

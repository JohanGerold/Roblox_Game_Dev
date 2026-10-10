-- Two-phase boot: every controller's Init runs first, then every Start.
local controllers = {}
for _, module in script.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(controllers, module)
	end
end
table.sort(controllers, function(a, b)
	return a.Name < b.Name
end)

local loaded = {}
for _, module in controllers do
	local ok, controller = xpcall(require, debug.traceback, module)
	if ok then
		table.insert(loaded, { name = module.Name, controller = controller })
	else
		warn(string.format("[Boot] failed to load %s: %s", module.Name, tostring(controller)))
	end
end

for _, entry in loaded do
	if entry.controller.Init then
		local ok, err = xpcall(entry.controller.Init, debug.traceback, entry.controller)
		if not ok then
			warn(string.format("[Boot] %s.Init failed: %s", entry.name, tostring(err)))
		end
	end
end

for _, entry in loaded do
	if entry.controller.Start then
		task.spawn(function()
			local ok, err = xpcall(entry.controller.Start, debug.traceback, entry.controller)
			if not ok then
				warn(string.format("[Boot] %s.Start failed: %s", entry.name, tostring(err)))
			end
		end)
	end
end

print(string.format("[Boot] client: %d controllers started", #loaded))

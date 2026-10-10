-- Studio test runner. Usage (MCP execute_luau, Edit datamodel):
--   local r = game.ServerStorage.Tests.Runner:Clone()
--   return require(r).run()
-- Cloning avoids require caching so the latest Rojo-synced code is tested.

local Runner = {}

local function makeExpect()
	local expect = {}

	function expect.eq(actual, expected, msg)
		if actual ~= expected then
			error(
				string.format(
					"%sexpected %s, got %s",
					msg and (msg .. ": ") or "",
					tostring(expected),
					tostring(actual)
				),
				2
			)
		end
	end

	function expect.near(actual, expected, tol, msg)
		if type(actual) ~= "number" or math.abs(actual - expected) > tol then
			error(
				string.format(
					"%sexpected %s ± %s, got %s",
					msg and (msg .. ": ") or "",
					tostring(expected),
					tostring(tol),
					tostring(actual)
				),
				2
			)
		end
	end

	function expect.truthy(value, msg)
		if not value then
			error(msg or "expected a truthy value", 2)
		end
	end

	function expect.errors(fn, msg)
		local ok = pcall(fn)
		if ok then
			error(msg or "expected function to error", 2)
		end
	end

	return expect
end

function Runner.run(): string
	local specsFolder = game.ServerStorage.Tests.specs
	local temp = Instance.new("Folder")
	temp.Name = "TestMods"

	local shared = game.ReplicatedStorage.Shared:Clone()
	shared.Parent = temp
	local logic = game.ServerScriptService.Server.Logic:Clone()
	logic.Parent = temp
	local mods = { Shared = shared, Logic = logic }

	local passed, failures = 0, {}
	local specs = {}
	for _, child in specsFolder:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:sub(-5) == ".spec" then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)

	for _, specModule in specs do
		local ok, spec = pcall(function()
			return require(specModule:Clone())
		end)
		if not ok then
			table.insert(failures, string.format("FAIL %s: could not load spec: %s", specModule.Name, tostring(spec)))
		else
			local names = {}
			for name in spec do
				table.insert(names, name)
			end
			table.sort(names)
			for _, name in names do
				local testOk, err = pcall(spec[name], makeExpect(), mods)
				if testOk then
					passed += 1
				else
					table.insert(failures, string.format("FAIL %s/%s: %s", specModule.Name, name, tostring(err)))
				end
			end
		end
	end

	temp:Destroy()
	return string.format("PASS %d\n%s\nFAIL %d", passed, table.concat(failures, "\n"), #failures)
end

return Runner

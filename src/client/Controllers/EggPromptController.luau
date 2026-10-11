-- Hides the Grab prompt of personal eggs that belong to someone else. Display only: the server
-- still refuses a grab with "not yours".
local Players = game:GetService("Players")

local EggPromptController = {}

local function hideIfNotMine(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	if owner ~= nil and owner ~= Players.LocalPlayer.UserId then
		instance.MaxActivationDistance = 0
	end
end

function EggPromptController:Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Eggs")
		folder.DescendantAdded:Connect(hideIfNotMine)
		for _, d in folder:GetDescendants() do
			hideIfNotMine(d)
		end
	end)
end

return EggPromptController

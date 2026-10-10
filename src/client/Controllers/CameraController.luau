-- Combat mode (Ctrl): cursor locked, camera follows the mouse, character faces the camera.
-- Cursor mode is the Roblox default so menus can be clicked. Roblox Shift Lock is disabled by the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputController = require(script.Parent.InputController)

local player = Players.LocalPlayer

local CameraController = {}
CameraController.combatMode = false

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function CameraController:SetCombatMode(on: boolean)
	self.combatMode = on
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		local h = humanoid()
		if h then
			h.AutoRotate = true
		end
	end
end

function CameraController:Start()
	InputController.Action:Connect(function(action)
		if action == "ToggleCombatMode" then
			self:SetCombatMode(not self.combatMode)
		end
	end)

	player.CharacterAdded:Connect(function()
		self:SetCombatMode(false)
	end)

	RunService.RenderStepped:Connect(function()
		if not self.combatMode then
			return
		end
		local h = humanoid()
		local root = h and h.RootPart
		local camera = workspace.CurrentCamera
		if not h or not root or not camera or h.Health <= 0 then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		h.AutoRotate = false
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 1e-3 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end)
end

return CameraController

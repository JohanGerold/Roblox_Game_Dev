-- Placeholder combat visuals (swing flash, boss telegraphs, popups, damage numbers). Visual only:
-- the server decides every outcome. Real effects replace these in build step 12.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CombatFx = {}

local TELEGRAPH_COLOR = Color3.fromRGB(255, 40, 40)
local FLAT = 0.2

local popupGui: ScreenGui?

local function getGui(): ScreenGui
	if popupGui and popupGui.Parent then
		return popupGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	popupGui = gui
	return gui
end

function CombatFx.swing(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(2.5, 2.5, 2.5)
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.4
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CFrame = root.CFrame * CFrame.new(0, 0, -4)
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.new(4.5, 4.5, 4.5) }):Play()
	Debris:AddItem(flash, 0.2)
end

function CombatFx.popup(text: string, color: Color3)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromOffset(500, 50)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 32
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = getGui()
	local tween = TweenService:Create(label, TweenInfo.new(1), {
		Position = UDim2.new(0.5, 0, 0.3, -40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	Debris:AddItem(label, 1.1)
end

-- Red ground marker shaped like the hitbox that fills in until impact. Cones are drawn as a box
-- covering the cone's width. Removed early if the boss is staggered.
function CombatFx.telegraph(hitbox, bossModel: Model, impactTime: number)
	local pivot = bossModel:GetPivot()
	local boxCf, boxSize = bossModel:GetBoundingBox()
	local groundY = boxCf.Position.Y - boxSize.Y / 2 + 0.15
	local origin = CFrame.new(pivot.X, groundY, pivot.Z) * (pivot - pivot.Position)

	local marker = Instance.new("Part")
	if hitbox.shape == "Sphere" then
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(FLAT, hitbox.radius * 2, hitbox.radius * 2)
		marker.CFrame = origin * CFrame.Angles(0, 0, math.rad(90))
	elseif hitbox.shape == "Cone" then
		local width = 2 * hitbox.range * math.sin(math.rad(math.min(hitbox.angle, 180) / 2))
		marker.Size = Vector3.new(width, FLAT, hitbox.range)
		marker.CFrame = origin * CFrame.new(0, 0, -hitbox.range / 2)
	else
		marker.Size = Vector3.new(hitbox.size.X, FLAT, hitbox.size.Z)
		marker.CFrame = origin
	end
	marker.Material = Enum.Material.Neon
	marker.Color = TELEGRAPH_COLOR
	marker.Transparency = 0.85
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Parent = workspace

	local duration = math.max(0.05, impactTime - workspace:GetServerTimeNow())
	TweenService:Create(marker, TweenInfo.new(duration), { Transparency = 0.4 }):Play()

	local connection
	local function remove()
		if connection then
			connection:Disconnect()
		end
		marker:Destroy()
	end
	connection = bossModel:GetAttributeChangedSignal("State"):Connect(function()
		if bossModel:GetAttribute("State") == "Staggered" then
			remove()
		end
	end)
	task.delay(duration, remove)
end

function CombatFx.damageNumber(position: Vector3, amount: number, staggered: boolean, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = staggered and 30 or 24
	label.TextColor3 = color or (staggered and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(255, 255, 255))
	label.TextStrokeTransparency = 0.3
	label.Text = tostring(math.floor(amount + 0.5))
	label.Parent = billboard

	local info = TweenInfo.new(0.8)
	TweenService:Create(anchor, info, { CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.9)
end

return CombatFx

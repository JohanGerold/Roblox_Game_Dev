-- Placeholder combat visuals (swing flash, boss telegraphs, popups, damage numbers). Visual only:
-- the server decides every outcome. Real effects replace these in build step 12.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WaveTiming = require(ReplicatedStorage.Shared.Util.WaveTiming)

local CombatFx = {}

local TELEGRAPH_COLOR = Color3.fromRGB(255, 40, 40)
local FLAT = 0.2

local RING_COLOR = Color3.fromRGB(255, 200, 80)
local RING_WIDTH = 1.2
local RING_START_SCALE = 2 -- the timing ring starts at this many times the marker radius

local popupGui: ScreenGui?

-- Assets.VFX.<vfxFolder>.<vfx>.<name> if Astra's art exists, else nil (placeholders are used).
local function vfxTemplate(vfxFolder: string?, vfx: string?, name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local root = assets and assets:FindFirstChild("VFX")
	local folder = root and vfxFolder and root:FindFirstChild(vfxFolder)
	local attackFolder = folder and vfx and folder:FindFirstChild(vfx)
	return attackFolder and attackFolder:FindFirstChild(name)
end

-- A flat ring on the ground: a CylinderHandleAdornment (it has an inner radius) on an invisible anchor part.
local function makeRing(center: Vector3, radius: number): (Part, CylinderHandleAdornment)
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(center)
	anchor.Parent = workspace
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	ring.Height = 0.3
	ring.Radius = radius
	ring.InnerRadius = math.max(0, radius - RING_WIDTH)
	ring.Color3 = RING_COLOR
	ring.Transparency = 0.15
	ring.ZIndex = 1
	ring.Parent = anchor
	return anchor, ring
end

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

-- Ground warnings for a boss attack (spec: gogo-attacks section 5). Visual only; the server judges everything.
--   Slam / Ground Fire: a filled marker plus a ring that shrinks onto the marker edge at impact.
--   Sweep (cone) and boxes: the filled marker only.
--   Flame Wave: a ring on the ground drawn at its true radius as it grows.
-- Real art replaces the placeholders by name: Assets.VFX.<vfxFolder>.<attack.vfx>.Marker / .Impact (ASSETS.md 2a).
-- options = { payload: table?, vfxFolder: string?, fewerEffects: boolean? }. Everything is removed at impact, or
-- early when the boss is staggered, dies or goes enraged.
function CombatFx.telegraph(attack, bossModel: Model, impactTime: number, options)
	options = options or {}
	local payload = options.payload
	local hitbox = attack.hitbox
	local startedAt = workspace:GetServerTimeNow()
	local duration = math.max(0.05, impactTime - startedAt)

	local pivot = bossModel:GetPivot()
	local boxCf, boxSize = bossModel:GetBoundingBox()
	local groundY = boxCf.Position.Y - boxSize.Y / 2 + 0.15
	local bossOrigin = CFrame.new(pivot.X, groundY, pivot.Z) * (pivot - pivot.Position)

	local made: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, instance in made do
			instance:Destroy()
		end
	end
	local function track(instance: Instance): Instance
		table.insert(made, instance)
		return instance
	end

	local function playImpact(at: CFrame)
		if options.fewerEffects then
			return
		end
		local impact = vfxTemplate(options.vfxFolder, attack.vfx, "Impact")
		if not impact then
			return
		end
		local clone = impact:Clone()
		if clone:IsA("Model") then
			clone:PivotTo(at)
		elseif clone:IsA("BasePart") then
			clone.CFrame = at
		end
		clone.Parent = workspace
		for _, d in clone:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = true
			end
		end
		Debris:AddItem(clone, 2)
	end

	-- the filled marker (placeholder part, or Astra's 1 x 1 Marker scaled to the area)
	local function fill(size: Vector3, cf: CFrame, round: boolean)
		local custom = vfxTemplate(options.vfxFolder, attack.vfx, "Marker")
		local marker: BasePart
		if custom then
			local clone = custom:Clone()
			local part = clone:IsA("Model") and clone.PrimaryPart or clone
			if not part or not part:IsA("BasePart") then
				clone:Destroy()
				custom = nil
			else
				part.Size = Vector3.new(size.X, part.Size.Y, size.Z)
				if clone:IsA("Model") then
					clone:PivotTo(cf)
				else
					part.CFrame = cf
				end
				for _, d in clone:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
					end
				end
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
				clone.Parent = workspace
				track(clone)
				return
			end
		end
		marker = Instance.new("Part")
		if round then
			marker.Shape = Enum.PartType.Cylinder
			marker.Size = Vector3.new(FLAT, size.X, size.Z)
			marker.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		else
			marker.Size = Vector3.new(size.X, FLAT, size.Z)
			marker.CFrame = cf
		end
		marker.Material = Enum.Material.Neon
		marker.Color = TELEGRAPH_COLOR
		marker.Transparency = 0.85
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Parent = workspace
		track(marker)
		TweenService:Create(marker, TweenInfo.new(duration), { Transparency = 0.4 }):Play()
	end

	if attack.targeting == "Wave" and payload then
		local center = Vector3.new(payload.x, groundY, payload.z)
		local anchor, ring = makeRing(center, payload.startRadius)
		track(anchor)
		local wave = { waveStartRadius = payload.startRadius, waveSpeed = payload.speed }
		table.insert(connections, RunService.Heartbeat:Connect(function()
			local radius = WaveTiming.radiusAt(workspace:GetServerTimeNow(), impactTime, wave, payload.maxRadius)
			ring.Radius = radius
			ring.InnerRadius = math.max(0, radius - RING_WIDTH)
			if radius >= payload.maxRadius then
				finish()
			end
		end))
		task.delay(duration, function()
			if not finished then
				playImpact(CFrame.new(center))
			end
		end)
	else
		local center = bossOrigin
		local radius
		if hitbox.shape == "Sphere" or hitbox.shape == "Circle" then
			radius = payload and payload.radius or hitbox.radius
			if payload then
				center = CFrame.new(payload.x, groundY, payload.z)
			end
			fill(Vector3.new(radius * 2, FLAT, radius * 2), center, true)
		elseif hitbox.shape == "Cone" then
			local width = 2 * hitbox.range * math.sin(math.rad(math.min(hitbox.angle, 180) / 2))
			fill(Vector3.new(width, FLAT, hitbox.range), center * CFrame.new(0, 0, -hitbox.range / 2), false)
		else
			fill(Vector3.new(hitbox.size.X, FLAT, hitbox.size.Z), center, false)
		end
		if radius then
			local anchor, ring = makeRing(center.Position, radius * RING_START_SCALE)
			track(anchor)
			table.insert(connections, RunService.Heartbeat:Connect(function()
				local alpha = math.clamp((workspace:GetServerTimeNow() - startedAt) / duration, 0, 1)
				local r = radius * RING_START_SCALE + (radius - radius * RING_START_SCALE) * alpha
				ring.Radius = r
				ring.InnerRadius = math.max(0, r - RING_WIDTH)
			end))
		end
		task.delay(duration, function()
			if not finished then
				playImpact(center)
				finish()
			end
		end)
	end

	table.insert(connections, bossModel:GetAttributeChangedSignal("State"):Connect(function()
		local state = bossModel:GetAttribute("State")
		if state == "Staggered" or state == "Dead" or state == "Guard" then
			finish()
		end
	end))
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

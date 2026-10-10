-- Builds Workspace.Map (graybox) from Config/Map + MapLayout. NOT synced by Rojo.
-- Run through MCP execute_luau (Edit datamodel); safe to run repeatedly (replaces Workspace.Map).
-- Returns the list of MapContract problems (empty = map is valid).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local map = require(ReplicatedStorage.Shared.Config.Map:Clone())
local Layout = require(ServerScriptService.Server.Logic.MapLayout:Clone())
local Contract = require(ServerScriptService.Server.Logic.MapContract:Clone())

for _, name in { "Map", "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local root = Instance.new("Folder")
root.Name = "Map"

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, opts): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in opts or {} do
		if k == "tag" then
			CollectionService:AddTag(p, v)
		elseif k == "attrs" then
			for ak, av in v do
				p:SetAttribute(ak, av)
			end
		else
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function marker(parent, name, tag, cf, color)
	return part(parent, name, Vector3.new(4, 0.4, 4), cf, color, {
		tag = tag,
		CanCollide = false,
		Transparency = 0.6,
	})
end

local function label(p: BasePart, text: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.Font = Enum.Font.GothamBold
	tl.Text = text
	tl.Parent = gui
end

local GRAY = Color3.fromRGB(120, 120, 125)
local DARK = Color3.fromRGB(60, 60, 65)

-- Ground and invisible boundary walls
local half = map.boundaryHalfSize
part(root, "Ground", Vector3.new(half * 2, 1, half * 2), CFrame.new(0, -0.5, 0), Color3.fromRGB(90, 130, 90), { Material = Enum.Material.Grass })
for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	local alongX = d[1] ~= 0
	part(root, "Boundary", Vector3.new(alongX and 2 or half * 2, 60, alongX and half * 2 or 2), CFrame.new(d[1] * half, 30, d[2] * half), GRAY, { Transparency = 1 })
end

-- Boss arena
local arena = Instance.new("Model")
arena.Name = "Arena"
CollectionService:AddTag(arena, "BossArena")
arena:SetAttribute("StageId", map.stageId)
local d = map.arenaRadius * 2
part(arena, "Floor", Vector3.new(0.4, d, d), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK, { Shape = Enum.PartType.Cylinder })
local segments = 24
local segLen = 2 * math.pi * map.arenaRadius / segments + 1
for i = 1, segments do
	local a = math.rad((i - 1) * 360 / segments)
	local pos = Vector3.new(map.arenaRadius * math.cos(a), map.arenaWallHeight / 2, map.arenaRadius * math.sin(a))
	part(arena, "Wall", Vector3.new(segLen, map.arenaWallHeight, 2), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), GRAY)
end
marker(arena, "BossSpawn", "BossSpawn", CFrame.new(0, 0.6, 0), Color3.fromRGB(220, 60, 60))
marker(arena, "GiantEggSpawn", "GiantEggSpawn", CFrame.new(15, 0.6, 0), Color3.fromRGB(240, 200, 60))
arena.Parent = root

-- Hub stations
local hub = Instance.new("Folder")
hub.Name = "Hub"
local st = Layout.stationCFrames(map)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "HubSpawn"
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = st.HubSpawn * CFrame.new(0, 0.5, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Color = Color3.fromRGB(80, 160, 220)
spawn.Parent = hub

local shop = part(hub, "WeaponShop", Vector3.new(12, 8, 6), st.WeaponShop * CFrame.new(0, 4, 0), Color3.fromRGB(200, 140, 60), { tag = "WeaponShop" })
label(shop, "WEAPONS", Enum.NormalId.Front)
for i, cf in st.Treadmill do
	part(hub, "Treadmill" .. i, Vector3.new(4, 1, 8), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(70, 70, 200), { tag = "Treadmill" })
end
for i, cf in st.Sandbag do
	part(hub, "Sandbag" .. i, Vector3.new(6, 3, 3), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 90, 90), { tag = "Sandbag", Shape = Enum.PartType.Cylinder })
end
hub.Parent = root

-- Bases
local baseCFrames = Layout.baseCFrames(map)
local slotOffsets = Layout.slotOffsets(map)
local s = map.baseSize
for i = 1, map.baseCount do
	local cf = baseCFrames[i]
	local base = Instance.new("Model")
	base.Name = string.format("Base_%02d", i)
	CollectionService:AddTag(base, "Base")
	base:SetAttribute("BaseIndex", i)

	local floor = part(base, "Floor", Vector3.new(s, 1, s), cf * CFrame.new(0, 0.5, 0), GRAY)
	base.PrimaryPart = floor
	local top = 1
	part(base, "WallBack", Vector3.new(s, 3, 1), cf * CFrame.new(0, top + 1.5, s / 2 - 0.5), DARK)
	part(base, "WallLeft", Vector3.new(1, 3, s - 2), cf * CFrame.new(-s / 2 + 0.5, top + 1.5, 0), DARK)
	part(base, "WallRight", Vector3.new(1, 3, s - 2), cf * CFrame.new(s / 2 - 0.5, top + 1.5, 0), DARK)

	for idx, off in slotOffsets do
		part(base, "Slot" .. idx, Vector3.new(map.slotSize, 0.4, map.slotSize), cf * CFrame.new(off.X, top + 0.2, off.Z), Color3.fromRGB(120, 180, 230), {
			tag = "StandSlot",
			attrs = { SlotIndex = idx },
		})
	end

	part(base, "DeliveryPad", Vector3.new(map.deliveryPadSize, 0.6, map.deliveryPadSize), cf * CFrame.new(0, top + 0.3, -map.deliveryPadOffset), Color3.fromRGB(60, 220, 100), {
		tag = "EggDeliveryPad",
		Material = Enum.Material.Neon,
	})
	marker(base, "BaseSpawn", "BaseSpawn", cf * CFrame.new(0, 3, -10), Color3.fromRGB(255, 255, 255))

	local sign = part(base, "BaseSign", Vector3.new(14, 6, 1), cf * CFrame.new(0, top + 3, -s / 2 + 0.5), DARK, { tag = "BaseSign" })
	label(sign, "Free base", Enum.NormalId.Front)
	label(sign, "Free base", Enum.NormalId.Back)

	base.Parent = root
	if i % 4 == 0 then
		task.wait()
	end
end

root.Parent = workspace
return Contract.check(root, map)

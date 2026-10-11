-- Builds Workspace.Map (graybox strip) from Config/Map + MapLayout. NOT synced by Rojo.
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
local WALL_DARK = Color3.fromRGB(45, 30, 35)
local FENCE = Color3.fromRGB(110, 80, 50)
local ARENA = map.arenaCenter

-- Every wall line gets an invisible full-height block (keeps players in) plus a visible wall of `visibleHeight`.
local function wall(parent: Instance, name: string, from: Vector3, to: Vector3, visibleHeight: number, color: Color3)
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	local alongX = math.abs(to.X - from.X) > math.abs(to.Z - from.Z)
	local function size(height: number)
		return Vector3.new(alongX and len or 2, height, alongX and 2 or len)
	end
	part(parent, name .. "Block", size(map.wallHeight), CFrame.new(mid.X, mid.Y + map.wallHeight / 2, mid.Z), GRAY, { Transparency = 1 })
	part(parent, name, size(visibleHeight), CFrame.new(mid.X, mid.Y + visibleHeight / 2, mid.Z), color)
end

-- Grounds (top at y = 0)
local h, c, dm = map.home, map.corridor, map.domain
local function ground(name: string, zone, color: Color3, material: Enum.Material)
	local w = zone.maxX - zone.minX
	part(root, name, Vector3.new(w, 1, zone.halfWidth * 2), CFrame.new(zone.minX + w / 2, -0.5, 0), color, { Material = material })
end
ground("HomeGround", h, Color3.fromRGB(90, 130, 90), Enum.Material.Grass)
ground("CorridorGround", c, Color3.fromRGB(55, 50, 60), Enum.Material.Slate)
ground("DomainGround", dm, Color3.fromRGB(90, 25, 25), Enum.Material.CrackedLava)
part(root, "Path", Vector3.new(h.maxX - h.minX, 0.05, map.pathWidth), CFrame.new((h.minX + h.maxX) / 2, 0.025, 0), Color3.fromRGB(150, 145, 140), { Material = Enum.Material.Concrete })

-- Walls
local walls = Instance.new("Folder")
walls.Name = "Walls"
local hz, cz, dz = h.halfWidth, c.halfWidth, dm.halfWidth
-- home: 3-high fence around the perimeter, open at the corridor mouth
wall(walls, "HomeNorth", Vector3.new(h.minX, 0, -hz), Vector3.new(h.maxX, 0, -hz), 3, FENCE)
wall(walls, "HomeSouth", Vector3.new(h.minX, 0, hz), Vector3.new(h.maxX, 0, hz), 3, FENCE)
wall(walls, "HomeWest", Vector3.new(h.minX, 0, -hz), Vector3.new(h.minX, 0, hz), 3, FENCE)
wall(walls, "HomeEastNorth", Vector3.new(h.maxX, 0, -hz), Vector3.new(h.maxX, 0, -cz), 3, FENCE)
wall(walls, "HomeEastSouth", Vector3.new(h.maxX, 0, cz), Vector3.new(h.maxX, 0, hz), 3, FENCE)
-- corridor sides and domain perimeter (opening at the gate)
wall(walls, "CorridorNorth", Vector3.new(c.minX, 0, -cz), Vector3.new(c.maxX, 0, -cz), 14, WALL_DARK)
wall(walls, "CorridorSouth", Vector3.new(c.minX, 0, cz), Vector3.new(c.maxX, 0, cz), 14, WALL_DARK)
wall(walls, "DomainNorth", Vector3.new(dm.minX, 0, -dz), Vector3.new(dm.maxX, 0, -dz), 14, WALL_DARK)
wall(walls, "DomainSouth", Vector3.new(dm.minX, 0, dz), Vector3.new(dm.maxX, 0, dz), 14, WALL_DARK)
wall(walls, "DomainEast", Vector3.new(dm.maxX, 0, -dz), Vector3.new(dm.maxX, 0, dz), 14, WALL_DARK)
wall(walls, "DomainGateNorth", Vector3.new(dm.minX, 0, -dz), Vector3.new(dm.minX, 0, -cz), 14, WALL_DARK)
wall(walls, "DomainGateSouth", Vector3.new(dm.minX, 0, cz), Vector3.new(dm.minX, 0, dz), 14, WALL_DARK)
walls.Parent = root

-- Gate arch at the domain entrance; the beam is the SpeedSign
local gate = Instance.new("Folder")
gate.Name = "Gate"
for _, side in { -1, 1 } do
	part(gate, "GatePillar", Vector3.new(3, 12, 3), CFrame.new(dm.minX, 6, side * 16.5), WALL_DARK)
end
local sign = part(gate, "SpeedSign", Vector3.new(1, 8, 30), CFrame.new(dm.minX, 16, 0), WALL_DARK, { tag = "SpeedSign" })
label(sign, "SPEED CHECK", Enum.NormalId.Left)
label(sign, "SPEED CHECK", Enum.NormalId.Right)
gate.Parent = root

-- Safe zone (invisible, no collision)
part(root, "HomeZone", Vector3.new(h.maxX - h.minX, 40, hz * 2), CFrame.new((h.minX + h.maxX) / 2, 20, 0), GRAY, {
	tag = "HomeZone",
	Transparency = 1,
	CanCollide = false,
	CanTouch = false,
	CanQuery = false,
})

-- Boss arena
local arena = Instance.new("Model")
arena.Name = "Arena"
CollectionService:AddTag(arena, "BossArena")
arena:SetAttribute("StageId", map.stageId)
local d = map.arenaRadius * 2
part(arena, "Floor", Vector3.new(0.4, d, d), CFrame.new(ARENA) * CFrame.Angles(0, 0, math.rad(90)), DARK, { Shape = Enum.PartType.Cylinder })
local segments = 24
local segLen = 2 * math.pi * map.arenaRadius / segments + 1
for i = 1, segments do
	local a = math.rad((i - 1) * 360 / segments)
	local pos = ARENA + Vector3.new(map.arenaRadius * math.cos(a), map.arenaWallHeight / 2, map.arenaRadius * math.sin(a))
	part(arena, "Wall", Vector3.new(segLen, map.arenaWallHeight, 2), CFrame.lookAt(pos, Vector3.new(ARENA.X, pos.Y, ARENA.Z)), GRAY)
end
marker(arena, "BossSpawn", "BossSpawn", CFrame.new(ARENA + Vector3.new(0, 0.6, 0)), Color3.fromRGB(220, 60, 60))
marker(arena, "GiantEggSpawn", "GiantEggSpawn", CFrame.new(ARENA + map.giantEggOffset + Vector3.new(0, 0.6, 0)), Color3.fromRGB(240, 200, 60))
for i, pos in Layout.fieldEggSpawns(map) do
	part(arena, "FieldEggSpawn" .. i, Vector3.new(3, 0.4, 3), CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color3.fromRGB(240, 200, 60), {
		tag = "FieldEggSpawn",
		Transparency = 1,
		CanCollide = false,
	})
end
arena.Parent = root

-- Hub stations (home end)
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
part(hub, "FuseMachineSpot", Vector3.new(8, 1, 8), st.FuseMachine * CFrame.new(0, 0.5, 0), GRAY)
for i, cf in st.Treadmill do
	part(hub, "Treadmill" .. i, Vector3.new(4, 1, 8), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(70, 70, 200), { tag = "Treadmill" })
end
for i, cf in st.Sandbag do
	part(hub, "Sandbag" .. i, Vector3.new(6, 3, 3), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 90, 90), { tag = "Sandbag", Shape = Enum.PartType.Cylinder })
end
hub.Parent = root

-- Bases (plots)
local plotCFrames = Layout.plotCFrames(map)
local slotOffsets = Layout.slotOffsets(map)
local s = map.baseSize
for i = 1, map.baseCount do
	local cf = plotCFrames[i]
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
	marker(base, "BaseSpawn", "BaseSpawn", cf * CFrame.new(0, 3, -6), Color3.fromRGB(255, 255, 255))

	-- on the back wall; its Front face (local -Z) reads from the path
	local baseSign = part(base, "BaseSign", Vector3.new(14, 6, 1), cf * CFrame.new(0, 7, s / 2 - 0.5), DARK, { tag = "BaseSign" })
	label(baseSign, "Free base", Enum.NormalId.Front)
	label(baseSign, "Free base", Enum.NormalId.Back)

	base.Parent = root
end

root.Parent = workspace
return Contract.check(root, map)

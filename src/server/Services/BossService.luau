-- Spawns bosses from config into tagged arenas, runs their AI (BossBrain), telegraphs attacks and
-- reports impacts. CombatService decides what an impact does to each player.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Logic = script.Parent.Parent.Logic
local BossBrain = require(Logic.BossBrain)
local ArenaCheck = require(Logic.ArenaCheck)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Hitbox = require(Logic.Hitbox)
local ChaseNav = require(Logic.ChaseNav)
local ZoneCheck = require(Logic.ZoneCheck)

local ATTRIBUTE_INTERVAL = 0.1
local PLACEHOLDER_SIZE = Vector3.new(8, 12, 8)

local BossService = {}
BossService.Impact = Signal.new() -- Fire(boss, attack, victims: { Player }, impactTime)
BossService.Defeated = Signal.new() -- Fire(bossId: string, ledger: { [userId]: damage })

local records: { any } = {}
local bossFolder: Folder
local rng = Random.new()
local bossAttackRemote
local warnedPlaceholder: { [string]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function makePlaceholder(cfg): Model
	local model = Instance.new("Model")
	model.Name = cfg.model
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = PLACEHOLDER_SIZE
	root.Color = Color3.fromRGB(170, 40, 40)
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model
	local face = Instance.new("Part")
	face.Name = "Face"
	face.Size = Vector3.new(3, 3, 1)
	face.Color = Color3.fromRGB(255, 220, 60)
	face.CFrame = root.CFrame * CFrame.new(0, 3, -PLACEHOLDER_SIZE.Z / 2 - 0.5) -- front is -Z (LookVector)
	face.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, face
	weld.Parent = model
	model.PrimaryPart = root
	return model
end

local function makeModel(cfg): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local bossAssets = assets and assets:FindFirstChild("Bosses")
	local template = bossAssets and bossAssets:FindFirstChild(cfg.model)
	local model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		if not warnedPlaceholder[cfg.model] then
			warnedPlaceholder[cfg.model] = true
			warn("[BossService] no asset Assets.Bosses." .. cfg.model .. ", using a placeholder")
		end
		model = makePlaceholder(cfg)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return model
end

local function setAttributes(rec)
	local b = rec.brain
	local model = rec.model
	model:SetAttribute("BossId", rec.id)
	model:SetAttribute("Hp", b.hp)
	model:SetAttribute("MaxHp", b.maxHp)
	model:SetAttribute("Poise", b.poise)
	model:SetAttribute("MaxPoise", b.cfg.maxPoise)
	model:SetAttribute("State", b.state)
	rec.nextAttr = os.clock() + ATTRIBUTE_INTERVAL
	rec.shownState = b.state
end

local function place(rec, position: Vector3, lookAt: Vector3)
	rec.pos = position
	local at = Vector3.new(position.X, rec.groundY + rec.height / 2, position.Z)
	local toward = Vector3.new(lookAt.X - at.X, 0, lookAt.Z - at.Z)
	local cf
	if toward.Magnitude > 1e-3 then
		cf = CFrame.lookAt(at, at + toward)
	else
		cf = CFrame.new(at) * ((rec.facing or CFrame.identity) - (rec.facing or CFrame.identity).Position)
	end
	rec.model:PivotTo(cf)
	rec.facing = cf
end

local function setDeadVisual(rec, dead: boolean)
	for _, d in rec.model:GetDescendants() do
		if d:IsA("BasePart") then
			if dead then
				rec.original[d] = rec.original[d] or { d.Transparency, d.CanCollide }
				d.Transparency = 1
				d.CanCollide = false
			elseif rec.original[d] then
				d.Transparency, d.CanCollide = rec.original[d][1], rec.original[d][2]
			end
		end
	end
end

local function clearRage(rec)
	if rec.rage then
		rec.rage:Destroy()
		rec.rage = nil
	end
	rec.model:SetAttribute("Enraged", nil)
end

local function resetBoss(rec)
	clearRage(rec)
	BossBrain.reset(rec.brain, now())
	setDeadVisual(rec, false)
	rec.diedAt = nil
	rec.emptySince = nil
	place(rec, rec.home, rec.home + rec.facing.LookVector)
	setAttributes(rec)
end

local function livingPlayers(): { { player: Player, root: BasePart } }
	local found = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			table.insert(found, { player = player, root = root })
		end
	end
	return found
end

local function onDeath(rec)
	rec.diedAt = now()
	setDeadVisual(rec, true)
	setAttributes(rec)
	print("[BossService] " .. rec.id .. " defeated")
	local ledger = table.clone(rec.brain.ledger)
	BossService.Defeated:Fire(rec.id, ledger)
end

-- The revived boss: full HP, immune, red glow; it guards the eggs instead of fighting.
local function enterGuard(rec, t: number)
	BossBrain.enterGuard(rec.brain, t)
	setDeadVisual(rec, false)
	rec.diedAt = nil
	rec.emptySince = nil
	place(rec, rec.home, rec.home + rec.facing.LookVector)
	local glow = Instance.new("Highlight")
	glow.FillColor = Color3.fromRGB(255, 40, 40)
	glow.FillTransparency = 0.6
	glow.Adornee = rec.model
	glow.Parent = rec.model
	rec.rage = glow
	rec.model:SetAttribute("Enraged", true)
	setAttributes(rec)
end

-- Nearest carrier (any egg) who is outside the home zone.
local function chaseTarget(rec)
	local CarryService = require(script.Parent.CarryService)
	local zone
	for _, d in CollectionService:GetTagged("HomeZone") do
		if d:IsA("BasePart") then
			zone = d
			break
		end
	end
	local best, bestDist
	for _, player in CarryService:GetCarriers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and not (zone and ZoneCheck.inside(zone.CFrame, zone.Size, root.Position)) then
			local d = (flat(root.Position) - flat(rec.pos)).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = { player = player, humanoid = humanoid, root = root }, d
			end
		end
	end
	return best
end

local function stepGuard(rec, dt: number, t: number)
	local cfg = rec.cfg
	if t >= rec.brain.stateEndsAt then
		resetBoss(rec)
		return
	end
	local target = chaseTarget(rec)
	local goal = ChaseNav.goal(rec.pos, target and target.root.Position or rec.home, Map, cfg.bodyRadius)
	local offset = flat(goal) - flat(rec.pos)
	if offset.Magnitude > 0.3 then
		local stepped = rec.pos + offset.Unit * math.min(cfg.chaseSpeed * dt, offset.Magnitude)
		local newPos = ChaseNav.clamp(stepped, Map, cfg.bodyRadius)
		place(rec, Vector3.new(newPos.X, rec.pos.Y, newPos.Z), goal)
	end
	if target and BossService:DistanceToBody(rec, target.root.Position) <= cfg.catchRange then
		local health = target.humanoid.Health
		target.humanoid.Health = math.min(health, math.max(1, health - cfg.catchDamage))
		require(script.Parent.CarryService):ReturnToSpawn(target.player, "caught")
		require(script.Parent.AnnounceService):All("The boss took back " .. target.player.DisplayName .. "'s egg!", "Legendary")
		bossAttackRemote:FireAll(rec.id, "Catch", t)
	end
	if os.clock() >= rec.nextAttr then
		setAttributes(rec)
	end
end

local function step(rec, dt: number)
	local brain = rec.brain
	local cfg = rec.cfg
	local t = now()

	if rec.dormant then
		return
	end

	if brain.state == "Dead" then
		if t - rec.diedAt >= cfg.reviveSeconds then
			enterGuard(rec, t)
		end
		return
	end

	if brain.state == "Guard" then
		stepGuard(rec, dt, t)
		return
	end

	-- nearest living player in the arena is the target
	-- Only players inside the arena are chased, but an impact hits everyone in its hitbox, so
	-- standing on or past the wall is no shelter.
	local candidates = livingPlayers()
	local target, targetDist
	for _, c in candidates do
		local d = (flat(c.root.Position) - flat(rec.pos)).Magnitude
		if ArenaCheck.inside(rec.center, Map.arenaRadius, c.root.Position, 0) and (not targetDist or d < targetDist) then
			target, targetDist = c, d
		end
	end
	local inRange = target ~= nil and targetDist <= cfg.bodyRadius + cfg.engageRange

	if target then
		rec.emptySince = nil
	else
		rec.emptySince = rec.emptySince or t
		if t - rec.emptySince >= cfg.emptyResetSeconds and (brain.hp < brain.maxHp or brain.participantCount > 0) then
			resetBoss(rec)
			return
		end
	end

	-- movement: only while idle
	if brain.state == "Idle" then
		local goal = target and target.root.Position or rec.home
		local offset = flat(goal) - flat(rec.pos)
		local stopAt = target and (cfg.bodyRadius + cfg.engageRange) or 0.5
		if offset.Magnitude > stopAt then
			local distance = math.min(cfg.moveSpeed * dt, offset.Magnitude - stopAt)
			local newPos = rec.pos + offset.Unit * distance
			local fromCenter = flat(newPos) - flat(rec.center)
			local limit = Map.arenaRadius - cfg.bodyRadius
			if fromCenter.Magnitude > limit then
				newPos = rec.center + fromCenter.Unit * limit
			end
			place(rec, newPos, goal)
		elseif target then
			place(rec, rec.pos, target.root.Position)
		end
	end

	local events = BossBrain.update(brain, t, dt, inRange, rng)
	for _, event in events do
		if event == "Windup" then
			if target then
				place(rec, rec.pos, target.root.Position)
			end
			bossAttackRemote:FireAll(rec.id, brain.attack.id, brain.impactTime)
		elseif event == "Impact" then
			local origin = CFrame.new(rec.pos.X, rec.groundY, rec.pos.Z) * (rec.facing - rec.facing.Position)
			local victims = {}
			for _, c in candidates do
				if Hitbox.contains(brain.attack.hitbox, origin, c.root.Position) then
					table.insert(victims, c.player)
				end
			end
			BossService.Impact:Fire(rec, brain.attack, victims, brain.impactTime)
		end
	end

	if rec.shownState ~= brain.state or os.clock() >= rec.nextAttr then
		setAttributes(rec)
	end
end

local function spawnBoss(arena: Model, id: string, cfg)
	local spawnPart
	for _, d in arena:GetDescendants() do
		if d:HasTag("BossSpawn") and d:IsA("BasePart") then
			spawnPart = d
			break
		end
	end
	if not spawnPart then
		warn("[BossService] arena has no BossSpawn, skipping " .. id)
		return
	end
	local model = makeModel(cfg)
	local _, size = model:GetBoundingBox()
	local box = arena:GetBoundingBox()
	local rec = {
		id = id,
		cfg = cfg,
		brain = BossBrain.new(cfg, now()),
		model = model,
		arena = arena,
		center = Vector3.new(box.Position.X, spawnPart.Position.Y, box.Position.Z),
		home = Vector3.new(spawnPart.Position.X, spawnPart.Position.Y, spawnPart.Position.Z),
		groundY = spawnPart.Position.Y - spawnPart.Size.Y / 2,
		height = size.Y,
		original = {},
	}
	model.Parent = bossFolder
	place(rec, rec.home, rec.home + Vector3.new(0, 0, -1))
	setAttributes(rec)
	table.insert(records, rec)
end

function BossService:GetBosses()
	return records
end

-- At night (round cycle) the boss is reset to full HP and stands at home: it never attacks, moves or
-- takes damage until `on` is false again. Safe to call repeatedly.
function BossService:SetDormant(on: boolean)
	for _, rec in records do
		if on then
			resetBoss(rec)
		end
		rec.dormant = on or nil
		rec.model:SetAttribute("Dormant", on)
	end
end

function BossService:IsStaggered(boss): boolean
	return boss.brain.state == "Staggered"
end

function BossService:DamageBoss(boss, player: Player, amount: number): number
	if boss.dormant then
		return 0
	end
	BossBrain.addParticipant(boss.brain, player.UserId)
	local dealt, killed = BossBrain.applyDamage(boss.brain, player.UserId, amount)
	if killed then
		onDeath(boss)
	elseif dealt > 0 then
		setAttributes(boss)
	end
	return dealt
end

function BossService:Parry(boss, poiseDamage: number)
	if boss.dormant then
		return
	end
	BossBrain.applyParry(boss.brain, poiseDamage, now())
	setAttributes(boss)
end

function BossService:IsInArena(boss, position: Vector3): boolean
	return ArenaCheck.inside(boss.center, Map.arenaRadius, position, Combat.arenaTolerance)
end

-- Horizontal distance from a point to the boss's body surface (0 if inside).
function BossService:DistanceToBody(boss, position: Vector3): number
	return math.max(0, (flat(position) - flat(boss.pos)).Magnitude - boss.cfg.bodyRadius)
end

function BossService:Init()
	bossFolder = Instance.new("Folder")
	bossFolder.Name = "Bosses"
	bossFolder.Parent = workspace
	bossAttackRemote = Net.Server("BossAttack")
	for _, arena in CollectionService:GetTagged("BossArena") do
		local stageId = arena:GetAttribute("StageId")
		if arena:IsA("Model") then
			for id, cfg in Bosses do
				if cfg.kind == "Stage" and cfg.stageId == stageId then
					spawnBoss(arena, id, cfg)
				end
			end
		end
	end
end

function BossService:Start()
	RunService.Heartbeat:Connect(function(dt)
		for _, rec in records do
			local ok, err = xpcall(step, debug.traceback, rec, dt)
			if not ok then
				warn("[BossService] " .. tostring(err))
				pcall(resetBoss, rec)
			end
		end
	end)
end

return BossService

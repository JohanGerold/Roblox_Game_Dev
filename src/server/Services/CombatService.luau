-- Server side of combat: validates player attacks, defend claims and counters, judges boss impacts
-- against each victim's claims, and applies damage in both directions (spec section 8).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Armor = require(ReplicatedStorage.Shared.Config.Armor)
local Bosses = require(ReplicatedStorage.Shared.Config.Bosses)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Carry = require(ReplicatedStorage.Shared.Config.Carry)
local Moves = require(ReplicatedStorage.Shared.Config.Moves)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local Logic = script.Parent.Parent.Logic
local AbilityRules = require(Logic.AbilityRules)
local ComboCheck = require(Logic.ComboCheck)
local DamageCalc = require(Logic.DamageCalc)
local DefenseJudge = require(Logic.DefenseJudge)
local BossService = require(script.Parent.BossService)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)

local CombatService = {}

local histories: { [Player]: any } = {}
local combos: { [Player]: any } = {}
local counterUntil: { [Player]: number } = {}
local abilityUsedAt: { [Player]: { [number]: number } } = {}

local hitResult, damageNumbers

local function now(): number
	return workspace:GetServerTimeNow()
end

local function history(player: Player)
	histories[player] = histories[player] or DefenseJudge.newHistory()
	return histories[player]
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return root :: BasePart
	end
	return nil
end

-- Nearest living boss whose body surface is within `reach` studs of `position`; the player must be
-- inside the boss's arena (plus a small tolerance), so the wall is no safe spot to attack from.
local function bossInReach(position: Vector3, reach: number)
	local best, bestDist
	for _, boss in BossService:GetBosses() do
		if boss.brain.state ~= "Dead" and BossService:IsInArena(boss, position) then
			local d = BossService:DistanceToBody(boss, position)
			if d <= reach and (not bestDist or d < bestDist) then
				best, bestDist = boss, d
			end
		end
	end
	return best
end

local function strike(player: Player, boss, baseDamage: number, data)
	local staggered = BossService:IsStaggered(boss)
	local amount = DamageCalc.playerDamage(baseDamage, {
		power = data.training.power,
		rebirths = data.rebirths,
		armorBonus = DamageCalc.armorBonus(data.armor.equipped, Armor),
		staggered = staggered,
	}, Combat, Progression)
	local dealt = BossService:DamageBoss(boss, player, amount)
	if dealt > 0 then
		local p = boss.pos
		damageNumbers:Fire(player, { amount = dealt, x = p.X, y = p.Y + 6, z = p.Z, staggered = staggered })
	end
end

local function onAttack(player: Player, comboIndex: number, weaponId: string)
	local data = DataService:Get(player)
	local root = aliveRoot(player)
	if not data or not root or data.weapons.equipped ~= weaponId then
		return
	end
	local weapon = Weapons[weaponId]
	if not weapon then
		return
	end
	combos[player] = combos[player] or ComboCheck.newState()
	if not ComboCheck.accept(combos[player], comboIndex, weapon.combo, now(), Combat) then
		return
	end
	local hit = weapon.combo[comboIndex]
	local carrier = CarryService:CarrierInReach(player, root.Position, hit.range + Combat.rangeTolerance)
	if carrier then
		local humanoid = carrier.Character and carrier.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(Carry.carrierHitDamage)
		end
		CarryService:Drop(carrier, "hit")
		hitResult:Fire(carrier, { result = "Hit", damage = Carry.carrierHitDamage, attackId = "PlayerHit" })
		return
	end
	local boss = bossInReach(root.Position, hit.range + Combat.rangeTolerance)
	if boss then
		strike(player, boss, hit.damage, data)
	end
end

-- A copied boss move on slot 1-4: same reach check and damage formula as a weapon hit. A swing that
-- misses still spends the cooldown.
local function onUseAbility(player: Player, slot: number)
	local data = DataService:Get(player)
	local root = aliveRoot(player)
	if not data or not root then
		return
	end
	local set = data.equippedBossSet
	local used = abilityUsedAt[player] or {}
	abilityUsedAt[player] = used
	local ok, _, moveId = AbilityRules.canUse(slot, set, set and data.bossMoves[set] or 0, used[slot], now(), Bosses, Moves, Combat)
	if not ok then
		return
	end
	used[slot] = now()
	local move = Moves[moveId]
	local boss = bossInReach(root.Position, move.range + Combat.rangeTolerance)
	if boss then
		strike(player, boss, move.damage, data)
	end
end

local function onDefend(player: Player, kind: string, pressTime: number)
	DefenseJudge.accept(history(player), kind, pressTime, now(), Combat)
end

local function onCounter(player: Player)
	local data = DataService:Get(player)
	local root = aliveRoot(player)
	local until_ = counterUntil[player]
	if not data or not root or not until_ or now() > until_ then
		return
	end
	local boss = bossInReach(root.Position, Combat.counterRange)
	if not boss then
		return
	end
	counterUntil[player] = nil
	strike(player, boss, Combat.counterDamage, data)
end

local function judgeVictim(boss, attack, player: Player, impactTime: number)
	local root = aliveRoot(player)
	if not root or player.Parent ~= Players then
		return
	end
	local result = DefenseJudge.judge(history(player), impactTime, attack.unparryable, Combat, attack.parryWindow)
	local taken = 0
	if result == "Parried" then
		if attack.poiseOnParry > 0 then
			BossService:Parry(boss, attack.poiseOnParry)
		end
	elseif result == "PerfectDodge" then
		counterUntil[player] = now() + Combat.counterWindow
	elseif result == "Hit" then
		taken = attack.damage
		local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(attack.damage)
		end
	end
	hitResult:Fire(player, { result = result, damage = taken, attackId = attack.id })
end

function CombatService:Init()
	StarterPlayer.EnableMouseLockOption = false
	hitResult = Net.Server("HitResult")
	damageNumbers = Net.Server("DamageNumbers")
end

function CombatService:Start()
	Net.Server("Attack"):On(onAttack)
	Net.Server("Defend"):On(onDefend)
	Net.Server("Counter"):On(onCounter)
	Net.Server("UseAbility"):On(onUseAbility)

	BossService.Impact:Connect(function(boss, attack, victims, impactTime)
		task.delay(Combat.judgeDelay, function()
			for _, player in victims do
				local ok, err = xpcall(judgeVictim, debug.traceback, boss, attack, player, impactTime)
				if not ok then
					warn("[CombatService] " .. tostring(err))
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		histories[player] = nil
		combos[player] = nil
		abilityUsedAt[player] = nil
		counterUntil[player] = nil
	end)
end

return CombatService

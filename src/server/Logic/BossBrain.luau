-- Pure boss state machine (spec section 8): HP, poise, attack cycle and the damage ledger.
-- No Roblox instances; BossService feeds it time, target presence and damage.
local BossBrain = {}

local function init(b, now: number)
	local cfg = b.cfg
	b.state = "Idle"
	b.stateEndsAt = now + cfg.idleSeconds
	b.attack = nil
	b.impactTime = nil
	b.hp = cfg.maxHp
	b.maxHp = cfg.maxHp
	b.poise = cfg.maxPoise
	b.lastPoiseHitAt = now
	b.participants = {}
	b.participantCount = 0
	b.ledger = {}
	b.readyAt = {} -- attack id -> time it may be chosen again (cooldowns)
end

function BossBrain.new(cfg, now: number)
	local b = { cfg = cfg }
	init(b, now)
	return b
end

function BossBrain.reset(b, now: number)
	init(b, now)
end

-- Enraged guard phase after a death: full HP, nothing counted, immune and passive until it ends.
function BossBrain.enterGuard(b, now: number)
	init(b, now)
	b.state = "Guard"
	b.stateEndsAt = now + b.cfg.guardSeconds
end

-- Events come back in order: "Windup", "Impact", "StaggerEnded". One state change per call.
-- targetInRange: someone is in melee range (Self attacks). anyInArena: someone is in the arena (Player and
-- Wave attacks); it defaults to targetInRange.
function BossBrain.update(b, now: number, dt: number, targetInRange: boolean, rng: Random, anyInArena: boolean?): { string }
	local events = {}
	local cfg = b.cfg
	local state = b.state
	if state == "Dead" or state == "Guard" then
		return events
	end

	if state == "Staggered" then
		if now >= b.stateEndsAt then
			b.state = "Idle"
			b.stateEndsAt = now + cfg.idleSeconds
			b.poise = cfg.maxPoise
			table.insert(events, "StaggerEnded")
		end
		return events
	end

	if now - b.lastPoiseHitAt >= cfg.poiseRegenDelay then
		b.poise = math.min(cfg.maxPoise, b.poise + cfg.poiseRegen * dt)
	end

	if state == "Idle" then
		if now >= b.stateEndsAt then
			local arena = if anyInArena == nil then targetInRange else anyInArena
			local eligible = {}
			for _, attack in cfg.attacks do
				local ready = now >= (b.readyAt[attack.id] or 0)
				if attack.targeting == "Self" or attack.targeting == nil then
					if targetInRange then
						table.insert(eligible, attack)
					end
				elseif arena and ready then
					table.insert(eligible, attack)
				end
			end
			if #eligible > 0 then
				local attack = eligible[rng:NextInteger(1, #eligible)]
				b.readyAt[attack.id] = now + (attack.cooldown or 0)
				b.attack = attack
				b.impactTime = now + attack.windup
				b.state = "Windup"
				table.insert(events, "Windup")
			end
		end
	elseif state == "Windup" then
		if now >= b.impactTime then
			b.state = "Active"
			b.stateEndsAt = b.impactTime + b.attack.activeWindow
			table.insert(events, "Impact")
		end
	elseif state == "Active" then
		if now >= b.stateEndsAt then
			b.state = "Recovery"
			b.stateEndsAt += b.attack.recovery
		end
	elseif state == "Recovery" then
		if now >= b.stateEndsAt then
			b.state = "Idle"
			b.stateEndsAt = now + cfg.idleSeconds
			b.attack = nil
			b.impactTime = nil
		end
	end
	return events
end

-- First sighting of a userId counts as a participant; each one after the first adds hpPerExtraPlayer.
function BossBrain.addParticipant(b, userId: number)
	if b.state == "Guard" or b.participants[userId] then
		return
	end
	b.participants[userId] = true
	b.participantCount += 1
	if b.participantCount > 1 then
		b.maxHp += b.cfg.hpPerExtraPlayer
		b.hp += b.cfg.hpPerExtraPlayer
	end
end

-- Returns (damage dealt, killed). Dead bosses and non-positive amounts deal nothing.
function BossBrain.applyDamage(b, userId: number, amount: number): (number, boolean)
	if b.state == "Dead" or b.state == "Guard" or not (amount > 0) then
		return 0, false
	end
	local dealt = math.min(amount, b.hp)
	b.hp -= dealt
	b.ledger[userId] = (b.ledger[userId] or 0) + dealt
	if b.hp <= 0 then
		b.hp = 0
		b.state = "Dead"
		b.attack = nil
		b.impactTime = nil
		return dealt, true
	end
	return dealt, false
end

-- Returns true if this parry broke poise (the boss is now Staggered).
function BossBrain.applyParry(b, poiseDamage: number, now: number): boolean
	if b.state == "Dead" or b.state == "Guard" or b.state == "Staggered" then
		return false
	end
	b.poise = math.max(0, b.poise - poiseDamage)
	b.lastPoiseHitAt = now
	if b.poise <= 0 then
		b.state = "Staggered"
		b.stateEndsAt = now + b.cfg.staggerSeconds
		b.attack = nil
		b.impactTime = nil
		return true
	end
	return false
end

return BossBrain

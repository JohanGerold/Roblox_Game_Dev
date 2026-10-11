local function load(mods)
	return require(mods.Logic.BossBrain), require(mods.Shared.Config.Bosses).Boss_Lofy
end

-- Advances an idle brain to the start of a Windup. Returns the brain and the time of the Windup event.
local function toWindup(BB, cfg)
	local b = BB.new(cfg, 0)
	local now = cfg.idleSeconds
	local events = BB.update(b, now, 0.1, true, Random.new(1))
	assert(events[1] == "Windup", "helper expected a Windup")
	return b, now
end


-- A copy of the real boss config whose attack list is only the named attacks.
local function cfgWith(cfg, ids)
	local copy = table.clone(cfg)
	copy.attacks = {}
	for _, id in ids do
		for _, attack in cfg.attacks do
			if attack.id == id then
				table.insert(copy.attacks, attack)
			end
		end
	end
	return copy
end

return {
	["starts idle at full hp and poise"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		expect.eq(b.state, "Idle")
		expect.eq(b.hp, 5000)
		expect.eq(b.poise, 100)
	end,
	["idle waits for a target in range"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		local events = BB.update(b, 5, 0.1, false, Random.new(1))
		expect.eq(#events, 0)
		expect.eq(b.state, "Idle")
	end,
	["a full attack cycle returns to idle"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b, now = toWindup(BB, cfg)
		expect.eq(b.state, "Windup")
		expect.near(b.impactTime, now + b.attack.windup, 1e-9)
		expect.eq(#BB.update(b, now + 0.1, 0.1, true, Random.new(1)), 0, "still winding up")
		local events = BB.update(b, b.impactTime, 0.1, true, Random.new(1))
		expect.eq(events[1], "Impact")
		expect.eq(b.state, "Active")
		BB.update(b, b.impactTime + b.attack.activeWindow + 0.01, 0.1, true, Random.new(1))
		expect.eq(b.state, "Recovery")
		BB.update(b, b.stateEndsAt + 0.01, 0.1, true, Random.new(1))
		expect.eq(b.state, "Idle")
	end,
	["hp scales per participant"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.addParticipant(b, 1)
		BB.addParticipant(b, 2)
		BB.addParticipant(b, 2)
		expect.eq(b.participantCount, 2)
		expect.eq(b.maxHp, 6500)
		expect.eq(b.hp, 6500)
	end,
	["damage after death returns zero"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		local dealt, killed = BB.applyDamage(b, 1, 99999)
		expect.eq(dealt, 5000)
		expect.eq(killed, true)
		expect.eq(b.state, "Dead")
		local dealt2, killed2 = BB.applyDamage(b, 2, 100)
		expect.eq(dealt2, 0)
		expect.eq(killed2, false)
	end,
	["ledger sums damage per user"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.applyDamage(b, 1, 10)
		BB.applyDamage(b, 1, 15)
		BB.applyDamage(b, 2, 7)
		expect.eq(b.ledger[1], 25)
		expect.eq(b.ledger[2], 7)
	end,
	["non-positive damage is ignored"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		local dealt, killed = BB.applyDamage(b, 1, -50)
		expect.eq(dealt, 0)
		expect.eq(killed, false)
		expect.eq(b.hp, 5000)
	end,
	["poise break cancels the windup"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b, now = toWindup(BB, cfg)
		local oldImpact = b.impactTime
		expect.eq(BB.applyParry(b, 75, now + 0.1), false)
		expect.eq(BB.applyParry(b, 25, now + 0.2), true)
		expect.eq(b.state, "Staggered")
		expect.eq(b.attack, nil)
		local events = BB.update(b, oldImpact, 0.1, true, Random.new(1))
		expect.eq(table.find(events, "Impact"), nil)
	end,
	["parry is ignored while staggered or dead"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		expect.eq(BB.applyParry(b, 100, 1), true)
		expect.eq(BB.applyParry(b, 100, 2), false)
		local d = BB.new(cfg, 0)
		BB.applyDamage(d, 1, 99999)
		expect.eq(BB.applyParry(d, 100, 1), false)
	end,
	["stagger ends with full poise"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.applyParry(b, 100, 10)
		expect.eq(#BB.update(b, 12, 0.1, true, Random.new(1)), 0, "still staggered")
		local events = BB.update(b, 10 + cfg.staggerSeconds, 0.1, true, Random.new(1))
		expect.eq(events[1], "StaggerEnded")
		expect.eq(b.state, "Idle")
		expect.eq(b.poise, 100)
	end,
	["poise regenerates only after the delay"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.applyParry(b, 25, 10)
		BB.update(b, 12, 1, false, Random.new(1))
		expect.eq(b.poise, 75)
		BB.update(b, 15, 1, false, Random.new(1))
		expect.near(b.poise, 80, 1e-9)
	end,
	["reset restores the full state"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.addParticipant(b, 1)
		BB.addParticipant(b, 2)
		BB.applyDamage(b, 1, 300)
		BB.applyParry(b, 40, 1)
		BB.reset(b, 50)
		expect.eq(b.hp, 5000)
		expect.eq(b.maxHp, 5000)
		expect.eq(b.poise, 100)
		expect.eq(b.state, "Idle")
		expect.eq(b.participantCount, 0)
		expect.eq(next(b.ledger), nil)
		expect.near(b.stateEndsAt, 50 + cfg.idleSeconds, 1e-9)
	end,
	["guard is immune and never attacks"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.enterGuard(b, 10)
		expect.eq(b.state, "Guard")
		expect.eq(b.hp, 5000)
		local dealt, killed = BB.applyDamage(b, 1, 100)
		expect.eq(dealt, 0)
		expect.eq(killed, false)
		expect.eq(BB.applyParry(b, 500, 11), false)
		expect.eq(#BB.update(b, 15, 0.1, true, Random.new(1)), 0)
		expect.eq(b.state, "Guard")
		expect.near(b.stateEndsAt, 10 + cfg.guardSeconds, 1e-9)
	end,
	["guard clears the ledger and participants"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.addParticipant(b, 1)
		BB.addParticipant(b, 2)
		BB.applyDamage(b, 1, 99999)
		BB.enterGuard(b, 5)
		expect.eq(next(b.ledger), nil)
		expect.eq(b.participantCount, 0)
		expect.eq(b.maxHp, cfg.maxHp)
		BB.addParticipant(b, 3)
		expect.eq(b.participantCount, 0)
	end,
	["reset after guard is a normal fight"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		BB.enterGuard(b, 0)
		BB.reset(b, 70)
		expect.eq(b.state, "Idle")
		local dealt = BB.applyDamage(b, 1, 100)
		expect.eq(dealt, 100)
	end,
	["melee attacks only start with a target in range"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfgWith(cfg, { "Slam", "Sweep" }), 0)
		expect.eq(#BB.update(b, 5, 0.1, false, Random.new(1), true), 0)
		expect.eq(b.state, "Idle")
	end,
	["ranged attacks start with anyone in the arena"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfgWith(cfg, { "GroundFire" }), 0)
		local events = BB.update(b, 5, 0.1, false, Random.new(1), true)
		expect.eq(events[1], "Windup")
		expect.eq(b.attack.id, "GroundFire")
	end,
	["an empty arena casts nothing"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfgWith(cfg, { "GroundFire", "FlameWave" }), 0)
		expect.eq(#BB.update(b, 5, 0.1, false, Random.new(1), false), 0)
		expect.eq(b.state, "Idle")
	end,
	["a cooldown blocks a repeat until it is over"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfgWith(cfg, { "GroundFire" }), 0)
		local rng = Random.new(1)
		BB.update(b, 1, 0.1, false, rng, true) -- windup at t = 1, cooldown 6 -> ready at 7
		BB.update(b, b.impactTime, 0.1, false, rng, true)
		BB.update(b, b.stateEndsAt + 0.01, 0.1, false, rng, true)
		BB.update(b, b.stateEndsAt + 0.01, 0.1, false, rng, true)
		expect.eq(b.state, "Idle")
		expect.eq(#BB.update(b, 6.9, 0.1, false, rng, true), 0, "still cooling down")
		expect.eq(BB.update(b, 7, 0.1, false, rng, true)[1], "Windup")
	end,
	["reset clears cooldowns"] = function(expect, mods)
		local BB, cfg = load(mods)
		local c = cfgWith(cfg, { "GroundFire" })
		local b = BB.new(c, 0)
		BB.update(b, 1, 0.1, false, Random.new(1), true)
		BB.reset(b, 10)
		expect.eq(BB.update(b, 11, 0.1, false, Random.new(1), true)[1], "Windup")
	end,
	["anyInArena defaults to targetInRange"] = function(expect, mods)
		local BB, cfg = load(mods)
		local b = BB.new(cfg, 0)
		expect.eq(BB.update(b, 5, 0.1, true, Random.new(1))[1], "Windup")
	end,
	["a mixed list picks only what is eligible"] = function(expect, mods)
		local BB, cfg = load(mods)
		for seed = 1, 20 do
			local b = BB.new(cfg, 0)
			BB.update(b, 5, 0.1, false, Random.new(seed), true)
			expect.truthy(b.attack ~= nil and b.attack.targeting ~= "Self", "seed " .. seed .. " out of melee range")
		end
	end,
}

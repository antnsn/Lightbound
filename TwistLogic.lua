-- Twist counting for Unsealed Wrath, no WoW API (tested in tests/test_twist.lua).
-- Each main-hand swing stores a copy of the active Seal for 15 s, up to 3. A swing while the stacks are
-- of another Seal consumes them all (the burst) and stores one of the Seal you have now.
-- The client hides the Echo buffs in combat, so the stacks are counted here from swings and seal casts.
-- Known limit: a missed or dodged swing counts too (addons get no combat log).
local _, ns = ...

local L = {}
ns.TwistLogic = L

L.MAX, L.LIFE = 3, 15

function L.New()
	return { seal = nil, stacks = 0, stackSeal = nil, storedAt = nil, swingAt = nil, swingDur = nil }
end

local function Clear(s) s.stacks, s.stackSeal, s.storedAt = 0, nil, nil end

-- a seal cast from your spellbook (never a seal's proc)
function L.Seal(s, name) s.seal = name end

-- 15 s after the last stored copy the stacks are gone
function L.Expire(s, now)
	if s.storedAt and now - s.storedAt > L.LIFE then Clear(s) end
end

-- a main-hand swing: "store", "burst" (plus how many were used), or nil with no seal up
function L.Swing(s, dur, now)
	L.Expire(s, now)
	s.swingAt, s.swingDur = now, dur
	if not s.seal then return nil end
	local burst
	if s.stacks > 0 and s.stackSeal ~= s.seal then
		burst = s.stacks
		Clear(s)
	end
	if s.stackSeal == s.seal then
		s.stacks = math.min(L.MAX, s.stacks + 1)
	else
		s.stacks, s.stackSeal = 1, s.seal
	end
	s.storedAt = now
	if burst then return "burst", burst end
	return "store"
end

-- the readable truth out of combat: { [seal name] = { n = stacks, expires = time or nil } }.
-- Keeps the buff's own expiry, so stacks from before don't get a fresh 15 s.
function L.Sync(s, bySeal, now)
	Clear(s)
	for name, e in pairs(bySeal) do
		if e.n and e.n > 0 then
			s.stacks, s.stackSeal = math.min(L.MAX, e.n), name
			s.storedAt = (e.expires and e.expires > 0) and (e.expires - L.LIFE) or now
		end
	end
end

-- when the next swing lands, or nil when no swing is running (stopped attacking)
function L.NextSwing(s, now)
	if not (s.swingAt and s.swingDur) then return nil end
	local at = s.swingAt + s.swingDur
	if now > at + 1 then return nil end
	return at
end

-- what to do now:
--  "noseal" no seal up · "other" a seal outside the twist · "build" keep swinging with the build seal
--  "ready" three stored, swap before the next swing · "swap" inside the window: swap now
--  "burst" burst seal on, the next swing uses the stacks · "back" stacks used: back to the build seal
function L.Advice(s, now, build, burst, window)
	L.Expire(s, now)
	if not s.seal then return "noseal" end
	if s.seal == build then
		if s.stackSeal == build and s.stacks >= L.MAX then
			local nextAt = L.NextSwing(s, now)
			if nextAt and nextAt - now <= window then return "swap" end
			return "ready"
		end
		return "build"
	elseif s.seal == burst then
		if s.stackSeal == build and s.stacks > 0 then return "burst" end
		return "back"
	end
	return "other"
end

-- Twist counting for Unsealed Wrath, no WoW API (tested in tests/test_twist.lua).
-- Each main-hand swing stores a copy of the active Seal for 15 s, up to 3. A swing while the stacks are
-- of another Seal consumes them all (the burst) and stores one of the Seal you have now.
-- The client hides the Echo buffs in combat, so the stacks are counted here from swings and seal casts.
-- A swing that doesn't land stores nothing. Two signals take such a swing back:
--  * the target shows a miss, dodge or parry in the same moment (L.Avoid; it may come before the swing);
--  * no update of your own buffs right after the swing (L.Hit marks one, L.Settle takes back the rest).
--    A landed swing always updates the Echo buff; this works on any target, targeted or not. It only
--    starts after CONFIRM_START swings in a row were confirmed (proof the client sends the updates), and
--    stops again after CONFIRM_START take-backs in a row (it no longer does).
local _, ns = ...

local L = {}
ns.TwistLogic = L

L.MAX, L.LIFE = 3, 15
-- The target's miss/dodge/parry belongs to your swing only in the same frame (GetTime is per frame,
-- and in game both arrive together). Wider would take in other players' attacks on the same target.
L.AVOID_WINDOW = 0.02
L.CONFIRM_WINDOW = 0.3 -- your Echo buff updates within ~0.1 s of a landed swing (seen in game)
L.CONFIRM_START = 3

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
	if s.avoidAt and now - s.avoidAt <= L.AVOID_WINDOW then -- the target said miss just before
		s.avoidAt, s.undo = nil, nil
		return "avoided"
	end
	s.avoidAt, s.undo = nil, nil
	if not s.seal then return nil end
	s.undo = { stacks = s.stacks, stackSeal = s.stackSeal, storedAt = s.storedAt, at = now }
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

-- the last swing didn't land (miss, dodge, parry): put the stacks back as they were. True when undone.
local function Revert(s)
	local u = s.undo
	s.stacks, s.stackSeal, s.storedAt, s.undo = u.stacks, u.stackSeal, u.storedAt, nil
end

-- the target showed a miss, dodge or parry: take back the swing of this moment (or the one coming)
function L.Avoid(s, now)
	local u = s.undo
	if not u or now - u.at > L.AVOID_WINDOW then
		s.avoidAt = now
		return false
	end
	Revert(s)
	return true
end

-- your buffs changed: the swing just before landed
function L.Hit(s, now)
	local u = s.undo
	if u and not u.hit and now - u.at <= L.CONFIRM_WINDOW then
		u.hit = true
		s.hits, s.lost = (s.hits or 0) + 1, 0
		if s.hits >= L.CONFIRM_START then s.confirming = true end
	end
end

-- every frame: a swing with no buff update in time didn't land
function L.Settle(s, now)
	local u = s.undo
	if not u or u.hit or now - u.at <= L.CONFIRM_WINDOW then return end
	s.hits = 0
	if not s.confirming then s.undo = nil return end
	Revert(s)
	s.lost = (s.lost or 0) + 1
	if s.lost >= L.CONFIRM_START then s.confirming, s.lost = false, 0 end -- updates stopped coming
end

-- the readable truth out of combat: { [seal name] = { n = stacks, expires = time or nil } }.
-- Keeps the buff's own expiry, so stacks from before don't get a fresh 15 s.
function L.Sync(s, bySeal, now)
	Clear(s)
	s.undo, s.avoidAt = nil, nil -- the real buffs win over any pending take-back
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
--  "swap" three stored: swap now (they last 15 s, so any time before the next swing is fine;
--         a swing still on the build seal only refreshes them)
--  "burst" burst seal on, the next swing uses the stacks · "back" stacks used: back to the build seal
function L.Advice(s, now, build, burst)
	L.Expire(s, now)
	if not s.seal then return "noseal" end
	if s.seal == build then
		if s.stackSeal == build and s.stacks >= L.MAX then return "swap" end
		return "build"
	elseif s.seal == burst then
		if s.stackSeal == build and s.stacks > 0 then return "burst" end
		return "back"
	end
	return "other"
end

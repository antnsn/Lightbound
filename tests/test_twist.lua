-- Plain Lua 5.1 tests for TwistLogic.lua: lua5.1 tests/test_twist.lua (from the addon folder)
local ns = {}
assert(loadfile("TwistLogic.lua"))("Lightbound", ns)
local L = ns.TwistLogic
local C, R = "Seal of Command", "Seal of Righteousness"

local function eq(a, b, msg) if a ~= b then error((msg or "") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

-- three swings with Command store three, the fourth stays at three
local s = L.New()
L.Seal(s, C, 0)
eq(L.Swing(s, 3.3, 1), "store", "swing 1")
L.Swing(s, 3.3, 4.3); L.Swing(s, 3.3, 7.6)
eq(s.stacks, 3, "three stacks"); eq(s.stackSeal, C, "of Command")
L.Swing(s, 3.3, 10.9)
eq(s.stacks, 3, "capped at three")

-- no seal: a swing stores nothing
local n = L.New()
eq(L.Swing(n, 3.3, 1), nil, "no seal no store"); eq(n.stacks, 0, "still zero")

-- swap to Righteousness: next swing bursts the three and stores one Righteousness
L.Seal(s, R, 12)
eq(s.stacks, 3, "swapping alone keeps the stacks")
local what, used = L.Swing(s, 3.3, 14.2)
eq(what, "burst", "burst on the swap swing"); eq(used, 3, "three consumed")
eq(s.stacks, 1, "one stored after burst"); eq(s.stackSeal, R, "of Righteousness")

-- 15 s without a swing clears them
L.Expire(s, 14.2 + 15.1)
eq(s.stacks, 0, "expired"); eq(s.stackSeal, nil, "no stack seal")

-- recasting the same seal keeps stacks
local t = L.New(); L.Seal(t, C, 0); L.Swing(t, 3.3, 1); L.Swing(t, 3.3, 4.3)
L.Seal(t, C, 5); eq(t.stacks, 2, "same seal recast keeps stacks")

-- advice: build, swap as soon as three are stored (they last 15 s), burst pending, back
local a = L.New(); L.Seal(a, C, 0)
eq(L.Advice(a, 0.5, C, R), "build", "no stacks yet: build")
L.Swing(a, 3.3, 1); L.Swing(a, 3.3, 4.3); L.Swing(a, 3.3, 7.6) -- next swing at 10.9
eq(L.Advice(a, 7.7, C, R), "swap", "three stacks: swap right away")
eq(L.Advice(a, 10.6, C, R), "swap", "still swap just before the swing")
L.Seal(a, R, 10.7)
eq(L.Advice(a, 10.8, C, R), "burst", "Righteousness on, Command stacks waiting")
L.Swing(a, 3.3, 10.9)
eq(L.Advice(a, 11, C, R), "back", "after the burst: back to Command")
L.Seal(a, C, 11.5)
eq(L.Advice(a, 11.6, C, R), "build", "back on Command: build again")
eq(L.Advice(L.New(), 1, C, R), "noseal", "no seal")
local o = L.New(); L.Seal(o, "Seal of the Crusader", 0)
eq(L.Advice(o, 1, C, R), "other", "another seal")

-- next swing time; none once the swing timer has run out for a while
local w = L.New(); L.Seal(w, C, 0); L.Swing(w, 3.3, 1)
eq(L.NextSwing(w, 2), 4.3, "next swing")
eq(L.NextSwing(w, 6), nil, "no swing running")

-- out of combat sync from the Echo buffs
local y = L.New(); L.Seal(y, C, 0); L.Swing(y, 3.3, 1)
L.Sync(y, { [C] = { n = 3, expires = 12 } }, 2); eq(y.stacks, 3, "synced count"); eq(y.stackSeal, C, "synced seal")
L.Expire(y, 12.5); eq(y.stacks, 0, "synced stacks keep their own expiry")
L.Sync(y, { [C] = { n = 2 } }, 3); eq(y.stacks, 2, "no expiry given: counts from now")
L.Sync(y, {}, 3); eq(y.stacks, 0, "synced none")

-- a dodged, parried or missed swing stores nothing (and bursts nothing): undo it
local d = L.New(); L.Seal(d, C, 0)
L.Swing(d, 3.3, 1); L.Swing(d, 3.3, 4.3)
L.Swing(d, 3.3, 7.6); eq(L.Avoid(d, 7.6), true, "avoid right after the swing")
eq(d.stacks, 2, "dodged swing not counted")
eq(math.abs(L.NextSwing(d, 8) - 10.9) < 1e-9, true, "the swing timer still moved on")
eq(L.Avoid(d, 7.7), false, "only once per swing")
L.Swing(d, 3.3, 10.9); eq(L.Avoid(d, 10.95), false, "a later frame: someone else's"); eq(d.stacks, 3, "kept")
L.Seal(d, R, 12)
eq(L.Swing(d, 3.3, 14.2), "burst", "burst swing")
L.Avoid(d, 14.2)
eq(d.stacks, 3, "a dodged burst swing keeps the stacks"); eq(d.stackSeal, C, "still Command")

-- the target's miss can come in before the swing event in the same frame
local m = L.New(); L.Seal(m, C, 0)
L.Swing(m, 3.3, 1)
eq(L.Avoid(m, 4.3), false, "miss first: nothing to undo yet")
eq(L.Swing(m, 3.3, 4.3), "avoided", "the swing it belonged to stores nothing")
eq(m.stacks, 1, "still one")
eq(L.Swing(m, 3.3, 7.6), "store", "a later swing is not affected"); eq(m.stacks, 2, "two")

-- a swing that lands updates your Echo buff right after; no update means it didn't land
local h = L.New(); L.Seal(h, C, 0)
L.Swing(h, 3.3, 1); L.Hit(h, 1.1); L.Settle(h, 1.5)
L.Swing(h, 3.3, 4.3); L.Hit(h, 4.4); L.Settle(h, 5)
L.Swing(h, 3.3, 7.6); L.Hit(h, 7.7); L.Settle(h, 8)
eq(h.stacks, 3, "three confirmed swings")
L.Seal(h, R, 9)
L.Swing(h, 3.3, 10.9); L.Settle(h, 11)
eq(h.stacks, 1, "not settled before the confirm window ends")
L.Settle(h, 10.9 + L.CONFIRM_WINDOW + 0.01)
eq(h.stacks, 3, "no aura update after the burst swing: it didn't land, the three wait")
eq(h.stackSeal, C, "still Command")
L.Swing(h, 3.3, 14.2); L.Hit(h, 14.3); L.Settle(h, 15); eq(h.stackSeal, R, "this one landed")

-- an unrelated buff change near a swing can't switch take-backs on by itself
local q = L.New(); L.Seal(q, C, 0)
L.Swing(q, 3.3, 1); L.Hit(q, 1.1)
L.Swing(q, 3.3, 4.3); L.Settle(q, 5)
eq(q.stacks, 2, "one stray update: still trusting every swing")

-- three take-backs in a row: the updates stopped coming, trust every swing again
local r = L.New(); L.Seal(r, C, 0)
for i = 0, 2 do L.Swing(r, 3.3, i * 3.3); L.Hit(r, i * 3.3 + 0.1) end
for i = 3, 5 do L.Swing(r, 3.3, i * 3.3); L.Settle(r, i * 3.3 + 1) end
eq(r.confirming, false, "switched off")
L.Swing(r, 3.3, 20); L.Settle(r, 21); eq(r.stacks, 3, "counted again")

-- until one swing has been confirmed this way, unconfirmed swings are trusted (client may not tell)
local u = L.New(); L.Seal(u, C, 0)
L.Swing(u, 3.3, 1); L.Settle(u, 2); L.Swing(u, 3.3, 4.3); L.Settle(u, 5)
eq(u.stacks, 2, "no confirmation seen yet: keep counting every swing")

-- a sync from the real buffs drops a pending take-back (it must not undo the truth later)
local z = L.New(); L.Seal(z, C, 0)
L.Swing(z, 3.3, 1); L.Hit(z, 1.1)
L.Swing(z, 3.3, 4.3); L.Sync(z, {}, 4.35); L.Settle(z, 5)
eq(z.stacks, 0, "synced zero stays zero")

print("all ok")

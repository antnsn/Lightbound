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

-- advice: build, ready, swap inside the window, burst pending, back
local a = L.New(); L.Seal(a, C, 0)
eq(L.Advice(a, 0.5, C, R, 0.4), "build", "no stacks yet: build")
L.Swing(a, 3.3, 1); L.Swing(a, 3.3, 4.3); L.Swing(a, 3.3, 7.6) -- next swing at 10.9
eq(L.Advice(a, 8, C, R, 0.4), "ready", "three stacks, swing far: ready")
eq(L.Advice(a, 10.6, C, R, 0.4), "swap", "inside the window: swap")
L.Seal(a, R, 10.7)
eq(L.Advice(a, 10.8, C, R, 0.4), "burst", "Righteousness on, Command stacks waiting")
L.Swing(a, 3.3, 10.9)
eq(L.Advice(a, 11, C, R, 0.4), "back", "after the burst: back to Command")
L.Seal(a, C, 11.5)
eq(L.Advice(a, 11.6, C, R, 0.4), "build", "back on Command: build again")
eq(L.Advice(L.New(), 1, C, R, 0.4), "noseal", "no seal")
local o = L.New(); L.Seal(o, "Seal of the Crusader", 0)
eq(L.Advice(o, 1, C, R, 0.4), "other", "another seal")

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

print("all ok")

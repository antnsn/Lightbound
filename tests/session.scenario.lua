--@moods: missing off buffed notalent secret
-- Lightbound's tests/test_session.lua as a wowbench scenario: login, a ride, a fight, a relog,
-- a respec and back, in five client moods. Unlike the original it loads every file in the
-- .toc, so the other modules have to survive the session too.
-- Run: wowbench test .

local mood = wb.mood
local s = wb.state

s.spells = { [20375] = "Seal of Command", [21084] = "Seal of Righteousness", [20271] = "Judgement",
	[1311703] = "Echo of Command", [1311704] = "Echo of Righteousness" }
s.slots[13] = 270225
s.bags[11122] = 1 -- Carrot on a Stick

local db = { skin = "lightbound", wellRestedKeep = true, wellFedKeep = true, carrotSwap = true, carrotSlot = "Top", twist = true }
if mood == "off" then db.wellRested = false db.wellFed = false end
if mood == "notalent" then s.known["Unsealed Wrath"] = false s.noSpellData = true end
if mood == "secret" then s.secret = true end

local base = {}
if mood == "buffed" then base = { wb.aura("Well-Rested", 429959, 7200), wb.aura("Well Fed", 433, 1800) } end
local function with(...)
	local l = {}
	for _, a in ipairs(base) do l[#l + 1] = a end
	for i = 1, select("#", ...) do l[#l + 1] = select(i, ...) end
	return l
end

s.auras.player = base
wb.login({ saved = { LightboundDB = db } })
wb.advance(7)
wb.expect("cards", wb.shown("LightboundWellRestedFrame") and wb.shown("LightboundWellFedFrame"),
	mood == "missing" or mood == "notalent" or mood == "secret")

-- a ride
wb.mount(true)
wb.setAuras(with(wb.aura("Swift Horse", 23229)))
wb.advance(1)
wb.expect("carrotOn", s.slots[13], 11122)
wb.mount(false)
wb.setAuras(with())
wb.advance(1)
wb.expect("carrotOff", s.slots[13], 270225)

-- the first fight after login, with Seal of Command
local seal = wb.aura("Seal of Command", 20375, 30)
wb.setAuras(with(seal))
wb.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 20375)
wb.advance(0.5)
wb.combat(true)
wb.advance(0.5)
wb.expect("twistFirstFight", wb.shown("LightboundTwistFrame"), mood ~= "notalent") -- the one fight that can't know yet
wb.expect("sealBar", wb.shown("LightboundSealFrame"), true)
for _ = 1, 3 do wb.fire("PLAYER_SWING", 3.3, 0) wb.fire("UNIT_AURA", "player") wb.advance(3.3) end
wb.combat(false)
wb.setAuras(with(seal, wb.aura("Echo of Command", 1311703, 15, 3)))
wb.advance(2)
wb.expect("twistHiddenAfter", wb.shown("LightboundTwistFrame"), false)

-- the client has its spell data now: the cooldown icons get their pictures
s.noSpellData = false
wb.fire("SPELLS_CHANGED")
local iconsOk = true
for _, f in ipairs(wb.frames()) do
	if f.spell and f.tex and f.tex.__texture ~= 136243 then iconsOk = false end
end
wb.expect("cdIcons", iconsOk, true)

-- a loading screen with talent events that fire before the lookup can work
s.auras.player = base
wb.fire("PLAYER_ENTERING_WORLD", true, false)
wb.fire("PLAYER_TALENT_UPDATE")
wb.fire("TRAIT_CONFIG_UPDATED")
wb.advance(7)
wb.setAuras(with(seal))
wb.combat(true)
wb.advance(0.5)
wb.expect("twistAfterRelog", wb.shown("LightboundTwistFrame"), true)
wb.combat(false)
wb.advance(1)

-- a respec that drops the talent
s.known["Unsealed Wrath"] = false
wb.fire("PLAYER_TALENT_UPDATE")
wb.combat(true)
wb.advance(0.5)
-- when the lookup never worked the memory stays (can't tell a respec from login)
wb.expect("twistAfterRespec", wb.shown("LightboundTwistFrame"), mood == "notalent")
wb.combat(false)
wb.advance(1)

-- and back to the Retribution loadout
if mood ~= "notalent" then s.known["Unsealed Wrath"] = nil end
wb.fire("TRAIT_CONFIG_UPDATED")
wb.setAuras(with(seal))
wb.combat(true)
wb.advance(0.5)
wb.expect("twistBackToRet", wb.shown("LightboundTwistFrame"), true)
wb.combat(false)
wb.advance(1)

-- a second ride
wb.mount(true)
wb.advance(1)
wb.expect("carrotAgain", s.slots[13], 11122)

-- new in wowbench: a real /reload, SavedVariables through the WTF text round trip
wb.reload()
wb.advance(3)
wb.check(wb.saved("LightboundDB") and wb.saved("LightboundDB").twist == true, "LightboundDB survives /reload")
wb.check(wb.savedText:find("LightboundDB = {", 1, true), "SavedVariables written as Lua")

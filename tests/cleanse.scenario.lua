--@moods: cleanse purify ignore key
-- the Cleanse frame (LibBound Cleanse.lua, moved from Lightbound): a group member with a debuff the
-- paladin can remove gets a row that casts on them; Purify alone leaves Magic alone; /lb ignore;
-- the mouseover key. The stand-in client has no SecureGroupHeader, so the frame runs as the list.
local m = wb.mood
local s = wb.state
s.spells = { [20375] = "Seal of Command", [20271] = "Judgement", [1152] = "Purify", [4987] = "Cleanse" }
if m == "purify" then s.known[4987] = false end
wb.login({ saved = { LightboundDB = { skin = "lightbound" } } })
local G = wb.G
local bound = {}
G.SetOverrideBindingClick = function(owner, prio, key, button) bound[key] = button end
G.ClearOverrideBindings = function() bound = {} end
wb.join({ { unit = "party1", name = "Friend", classFile = "WARRIOR" } })
local debuff = m == "purify" and { name = "Frost Nova", spellId = 122, dispelName = "Magic", icon = 135848 }
	or { name = "Venom", spellId = 111, dispelName = "Poison", icon = 136016 }
s.auras.party1 = { debuff }
wb.fire("UNIT_AURA", "party1")
wb.advance(2)
local row = wb.frame("LightboundCleanseRow1")
wb.check(row ~= nil, "the cleanse rows exist")

if m == "cleanse" then
	wb.expect("the afflicted member's row casts on them", row:GetAttribute("unit"), "party1")
	wb.expect("with Cleanse on a left click", row:GetAttribute("spell1"), "Cleanse")
	wb.expect("as a spell", row:GetAttribute("type1"), "spell")
	wb.check(row.data ~= nil, "and the row shows the debuff")
	wb.check(wb.shown("LightboundCleanseFrame"), "the frame is up")
	-- the options page and all its rows fit on the page
	wb.slash("/lb")
	local page
	for _, p in ipairs(wb.ns.optionsState.pages) do if p.title == "Cleanse" then page = p.frame end end
	wb.check(page ~= nil, "the Cleanse options page is there")
	wb.check(page and -page.cleanseBottom <= page:GetHeight(), "and fits the window: " .. tostring(page and page.cleanseBottom))
elseif m == "purify" then
	wb.expect("Purify is the spell", row:GetAttribute("spell1"), "Purify")
	wb.check(row.data == nil, "and a Magic debuff is not something it can remove")
elseif m == "ignore" then
	wb.slash("/lb ignore Venom")
	wb.check(wb.saved("LightboundDB").clIgnore.venom, "/lb ignore keeps a debuff name")
	wb.fire("UNIT_AURA", "party1")
	wb.advance(2)
	wb.check(row.data == nil, "an ignored debuff gets no row")
	wb.slash("/lbignore Venom")
	wb.check(not wb.saved("LightboundDB").clIgnore.venom, "the space-free alias toggles it back")
elseif m == "key" then
	wb.ns.db.clKey = "F"
	wb.ns.ApplyCleanseKey()
	wb.expect("the key clicks the cleanse button", bound.F, "LightboundCleanseKeyButton")
	local key = wb.frame("LightboundCleanseKeyButton")
	wb.expect("which casts on the mouseover, else the target", key:GetAttribute("macrotext"),
		"/cast [@mouseover,help,nodead][help,nodead] Cleanse")
end

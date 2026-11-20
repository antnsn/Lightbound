-- Lightbound on LibBound: the options window and its pages, /lb commands, the travel panel with
-- the Hearthstone (every Bound addon has it), the minimap button.
local s = wb.state
s.spells = { [20375] = "Seal of Command", [20271] = "Judgement" }
s.bags[6948] = 1
wb.login({ saved = { LightboundDB = { skin = "lightbound" } } })
wb.advance(7)
wb.slash("/lb")
wb.check(wb.shown("LightboundOptions"), "/lb opens the options")
local titles = {}
for _, p in ipairs(wb.ns.optionsState.pages) do titles[#titles + 1] = p.title end
local list = table.concat(titles, ", ")
wb.check(list:find("^Righteous Fury, Aura, Seal timer, Combat, My buffs, Buff key, Raid overview, Reagents, "),
	"Lightbound's own pages first: " .. list)
wb.check(list:find("Extras, Skin$"), "the shared Extras and Skin last")
wb.slash("/lb rested")
wb.expect("/lb rested toggles Well-Rested", wb.saved("LightboundDB").wellRested, false)
wb.slash("/lbrested")
wb.expect("and the space-free alias", wb.saved("LightboundDB").wellRested, true)
wb.slash("/rfr toggle")
wb.expect("/rfr still works", wb.saved("LightboundDB").enabled, false)
wb.slash("/lb ignore Curse of Tongues")
wb.check(wb.saved("LightboundDB").clIgnore["curse of tongues"], "/lb ignore keeps its behaviour")
wb.check(wb.frame("LightboundMinimapButton"), "minimap button")
wb.openGameMenu()
wb.expect("the travel panel with the Hearthstone", wb.shown("LightboundTravel"), true)
wb.closeGameMenu()
wb.slash("/lb unlock")
wb.check(wb.shown("LightboundWellRestedFrame"), "unlocked: the Well-Rested card shows to be placed")
wb.slash("/lb lock")

--@moods: same low verylow greater combat
-- The blessing key: a group member far below you gets the best rank of the blessing they can take
-- (a rank goes only on someone at most 10 levels below its spell level), cast by spell ID.
local m = wb.mood
local s = wb.state
s.player.level = 57
local MIGHT = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }
for _, id in ipairs(MIGHT) do s.spells[id] = "Blessing of Might" end
s.spells[19977] = "Blessing of Light" -- rank 1 is level 40
s.known[25291] = false -- level 60: not yet at 57
s.spells[25782] = "Greater Blessing of Might"
if m == "greater" then s.bags[21177] = 20 end -- Symbol of Kings
wb.login({ saved = { LightboundDB = { pbEnabled = true, pbRF = false, pbGreater = m == "greater" } } })
local ns = wb.ns
ns.AuraNeeded = function() return nil end -- no aura step before the blessings
ns.GetNormalAssign = function() return nil end
ns.GetAssign = function() return m == "verylow" and 5 or 2 end -- 2 = Might, 5 = Light (ns.PP_SPELL)
wb.G.UnitCanAssist = function(_, unit) return wb.unit(unit) ~= nil end
s.auras.player = { wb.aura("Blessing of Might", 19838, 300), wb.aura("Blessing of Light", 19977, 300) }
wb.join({ { name = "Wife", classFile = "WARRIOR", level = (m == "same" or m == "greater") and 57 or 22 } }, m == "greater")
wb.advance(3)
local btn = wb.frame("LightboundPartyBuffButton")
wb.check(btn ~= nil, "the blessing key button")

if m == "greater" then
	wb.expect("a raid with Symbols: the Greater Blessing still", btn:GetAttribute("macrotext"), "/cast [nocombat,@raid1] Greater Blessing of Might")
	return
elseif m == "combat" then
	wb.expect("out of combat: the lower rank", btn:GetAttribute("type"), "spell")
	wb.combat(true)
	wb.advance(0.5)
	wb.check(btn:GetAttribute("type") ~= "spell", "in combat the key casts nothing (secure, like [nocombat])")
	wb.combat(false)
	wb.advance(1)
	wb.expect("after the fight it is back", btn:GetAttribute("type"), "spell")
	return
end
if m == "same" then
	wb.expect("your level: the best known rank, by name", btn:GetAttribute("macrotext"), "/cast [nocombat,@party1] Blessing of Might")
elseif m == "low" then
	wb.expect("a level 22: cast by spell ID", btn:GetAttribute("type"), "spell")
	wb.expect("rank 4 (level 32), not rank 6 (52)", btn:GetAttribute("spell"), 19836)
	wb.expect("on her", btn:GetAttribute("unit"), "party1")
else
	wb.expect("too low for any rank of Light (40): nothing for her", btn:GetAttribute("macrotext"), nil)
	wb.expect("no spell either", btn:GetAttribute("type"), nil)
	local why = {}
	ns.ExplainPartyBuff()
	wb.check(wb.printed("too low"), "/lb why says so")
end

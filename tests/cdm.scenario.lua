--@moods: painted flat blizzard off late world missing combat ellesmere
-- Blizzard's Cooldown Manager in the addon's skin (LibBound CooldownSkin): its icons keep working
-- in combat (the game draws the stacks and timers, which addons can't read on Forever); the skin
-- only changes their edge, mask and count font. Positions stay with Edit Mode.
local m = wb.mood
local s = wb.state
s.spells = { [20375] = "Seal of Command", [20271] = "Judgement" }
local db = { skin = ({ flat = "flat", blizzard = "blizzard" })[m] or "lightbound" }
if m == "off" then db.cdmSkin = false end
wb.login({ saved = { LightboundDB = db } })
wb.advance(7)
local G = wb.G
if m == "ellesmere" then
	-- EllesmereUI's Cooldown Manager draws its own icons and keeps Blizzard's invisible: we step aside
	local loaded = G.C_AddOns.IsAddOnLoaded
	G.C_AddOns.IsAddOnLoaded = function(name) return name == "EllesmereUICooldownManager" or loaded(name) end
	G.C_AddOns.DoesAddOnExist = function(name) return name == "EllesmereUICooldownManager" end
end
local switched = {}
G.C_AddOns.DisableAddOn = function(name, who) switched[#switched + 1] = "off " .. name .. " " .. tostring(who) end
G.C_AddOns.EnableAddOn = function(name, who) switched[#switched + 1] = "on " .. name .. " " .. tostring(who) end
local OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"

-- a stand-in for one Blizzard icon: icon texture under a rounded mask, the overlay atlas, the count
local function Item(parent)
	local f = G.CreateFrame("Frame", nil, parent)
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	local mask = f:CreateMaskTexture()
	local masked = true
	f.Icon.GetMaskTexture = function(_, i) if i == 1 and masked then return mask end end
	f.Icon.RemoveMaskTexture = function(_, x) if x == mask then masked = false end end
	f.Icon.AddMaskTexture = function(_, x) if x == mask then masked = true end end
	local ov = f:CreateTexture(nil, "OVERLAY")
	ov:SetAtlas(OVERLAY)
	f.Applications = G.CreateFrame("Frame", nil, f)
	f.Applications.Applications = f.Applications:CreateFontString(nil, "OVERLAY")
	return f, ov, function() return masked end
end
-- a stand-in viewer: its pool of active icons, and the two methods LibBound hooks
local function Viewer(name)
	local v = G.CreateFrame("Frame", name, G.UIParent)
	local active = {}
	v.itemFramePool = { EnumerateActive = function() return pairs(active) end }
	function v:RefreshLayout() end
	function v:OnAcquireItemFrame() end
	return v, active
end

local function Load()
	if m == "world" then wb.fire("PLAYER_ENTERING_WORLD") else wb.fire("ADDON_LOADED", "Blizzard_CooldownViewer") end
end

if m == "missing" then
	Load()
	wb.expect("no Cooldown Manager: no error", #wb.takeErrors(), 0)
else
	local v, active = Viewer("BuffIconCooldownViewer")
	local e = Viewer("EssentialCooldownViewer")
	local item, overlay, masked = Item(v)
	active[item] = true
	if m ~= "late" then Load() end
	if m == "combat" then wb.combat(true) end
	v:RefreshLayout()
	local st = wb.ns.cooldownSkin.State(item)
	local count = item.Applications.Applications

	if m == "painted" or m == "flat" or m == "world" or m == "combat" then
		wb.check(st and st.on, "the icon takes the skin")
		wb.expect("Blizzard's rounded overlay hidden", overlay:IsShown(), false)
		wb.expect("and its rounded mask off", masked(), false)
		wb.check(st.border and st.border:IsShown(), "our edge round it")
		wb.expect("the count in the skin's card font", (count:GetFont()), wb.ns.UI.F.card)
		local r, g, b = count:GetTextColor()
		if m == "flat" then
			wb.check(r == 1 and g == 1 and b == 1, "white count in Flat")
		else
			wb.check(r > b, "gold count in the Lightbound skin")
		end
		-- an icon the viewer adds later (a new buff tracked)
		local item2 = Item(e)
		e:OnAcquireItemFrame(item2)
		local st2 = wb.ns.cooldownSkin.State(item2)
		wb.check(st2 and st2.on, "an icon added later takes it too")
		v:RefreshLayout()
		wb.expect("skinned once, not again on every refresh", wb.ns.cooldownSkin.State(item), st)
	elseif m == "blizzard" then
		wb.expect("the Blizzard skin: the game's own look stays", st, nil)
		wb.expect("overlay kept", overlay:IsShown(), true)
		wb.expect("mask kept", masked(), true)
	elseif m == "off" then
		wb.expect("turned off: untouched", st, nil)
		wb.expect("overlay kept", overlay:IsShown(), true)
		wb.ns.db.cdmSkin = true
		wb.ns.Refresh()
		st = wb.ns.cooldownSkin.State(item)
		wb.check(st and st.on, "turned on: skinned without a reload")
		wb.expect("overlay hidden", overlay:IsShown(), false)
		wb.ns.db.cdmSkin = false
		wb.ns.Refresh()
		wb.expect("off again: overlay back", overlay:IsShown(), true)
		wb.expect("mask back", masked(), true)
		wb.expect("edge gone", st.border:IsShown(), false)
		wb.check(count:GetFont() ~= wb.ns.UI.F.card or wb.ns.UI.F.card == "Fonts\\FRIZQT__.TTF", "count font back")
	elseif m == "ellesmere" then
		wb.expect("EllesmereUI in charge: Blizzard's icons untouched", st, nil)
		wb.expect("overlay kept", overlay:IsShown(), true)
	elseif m == "late" then
		wb.expect("before the Cooldown Manager loads: untouched", st, nil)
		Load()
		wb.check(wb.ns.cooldownSkin.State(item), "skinned once it loads")
	end
	wb.expect("no errors", #wb.takeErrors(), 0)
end

-- the options page: the toggle, Blizzard's settings, buffs worth tracking for a paladin
wb.combat(false)
wb.slash("/lb")
local opt = wb.ns.optionsState
local text, found = "", false
local function Collect(f)
	for _, r in ipairs({ f:GetRegions() }) do if r.GetText and r:GetText() then text = text .. r:GetText() .. "|" end end
	for _, c in ipairs({ f:GetChildren() }) do
		if c.GetText and c:GetText() then text = text .. c:GetText() .. "|" end
		Collect(c)
	end
end
for i, pg in ipairs(opt.pages) do
	if pg.title == "Cooldown Manager" then found = true; opt.Select(i); Collect(pg.frame) end
end
wb.check(found, "a Cooldown Manager page")
wb.check(text:find("Open the Cooldown Manager", 1, true), "a button to Blizzard's settings")
wb.check(text:find("Holy Shield", 1, true), "suggests paladin buffs to track")
if m == "ellesmere" then
	wb.check(text:find("EllesmereUI", 1, true), "the page says EllesmereUI's Cooldown Manager is in charge")
	wb.check(text:find("Who draws the Cooldown Manager", 1, true), "and lets you pick who draws it")
	local cs = wb.ns.cooldownSkin
	wb.expect("EllesmereUI now", cs.Choice(), "EllesmereUI")
	cs.Choose("Lightbound")
	wb.expect("picking Lightbound turns EllesmereUI's Cooldown Manager off for this character", switched[1],
		"off EllesmereUICooldownManager " .. tostring(wb.state.player.name or G.UnitName("player")))
	wb.expect("shown as picked until the reload", cs.Choice(), "Lightbound")
	wb.check(wb.printed("reload"), "and it says a reload makes it happen")
	cs.Choose("EllesmereUI")
	local joined = table.concat(switched, "|")
	wb.check(joined:find("on EllesmereUICooldownManager", 1, true), "picking EllesmereUI turns it back on")
	wb.check(joined:find("on EllesmereUI ", 1, true), "with the EllesmereUI it needs (it may be off for this character)")
else
	wb.check(not text:find("Who draws", 1, true), "no choice without another Cooldown Manager addon")
end

-- Paladin cooldowns: one row per paladin in the group with Blessing of Protection, Freedom and
-- Sacrifice, Divine Shield and Divine Protection. Bright = ready, dim with a sweep and seconds =
-- on cooldown. Your own row also shows Forbearance. Shared between Lightbound users over LBND
-- ("CDS key:dur:left ..."); PallyPower users show as "no sync".
-- On Forever the client hides cooldown times in combat: your own row then keeps the last known
-- values, and a cast seen in combat is assumed to have started the full cooldown.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = _G.issecretvalue or function() return false end
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>"
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end

-- key, spell name (any rank), base spell id (for the icon), fallback icon, usual cooldown
local SPELLS = {
	{ key = "bop", name = "Blessing of Protection", id = 1022, icon = 135964, cd = 300 },
	{ key = "freedom", name = "Blessing of Freedom", id = 1044, icon = 135968, cd = 25 },
	{ key = "sac", name = "Blessing of Sacrifice", id = 6940, icon = 135966, cd = 30 },
	{ key = "ds", name = "Divine Shield", id = 642, icon = 135896, cd = 300 },
	{ key = "dp", name = "Divine Protection", id = 498, icon = 135962, cd = 300 },
}
local BY_KEY = {}
for _, s in ipairs(SPELLS) do BY_KEY[s.key] = s end
local SHARED = { ds = "dp", dp = "ds" } -- Divine Shield and Divine Protection share a cooldown
local FORBEARANCE = { name = "Forbearance", id = 25771, icon = 135942, cd = 60 }
local FORB_SLOT = #SPELLS + 1

local NAME_W, ICON, GAP, ROW_H, PAD = 84, 22, 3, 24, 6
local ROW_W = 8 + PAD + NAME_W + 4 + FORB_SLOT * (ICON + GAP) - GAP + PAD + 4

ns.cds = {}          -- name -> { bop = { readyAt, dur }, ... } for every paladin incl. you
local baseDur = {}   -- key -> cooldown length seen the last time it was readable
local forb           -- when your Forbearance runs out, or nil
local frame, title, rows, list = nil, nil, {}, {}
local Me

local function Known(spell)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spell) end
		return GetSpellInfo(spell)
	end)
	return ok and info ~= nil
end

local function Texture(id, fallback)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
		return GetSpellTexture(id)
	end)
	return (ok and Clean(tex)) or fallback
end

local function ClearCD(cd)
	if cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
end

local function FormatTime(s)
	if s >= 3600 then return ("%dh"):format(s / 3600) end
	if s >= 60 then return ("%dm"):format(math.ceil(s / 60)) end
	return ("%d"):format(math.ceil(s))
end

-- Your own cooldowns ----------------------------------------------------------------
local function ScanSelf()
	local me = ns.cds[Me] or {}
	for _, s in ipairs(SPELLS) do
		if Known(s.name) then
			local old = me[s.key]
			local ok, cd = pcall(C_Spell.GetSpellCooldown, s.name)
			local start = ok and type(cd) == "table" and cd.startTime or nil
			local dur = ok and type(cd) == "table" and cd.duration or nil
			if start == nil or isSecret(start) or isSecret(dur) then
				-- hidden in combat: keep what we knew
				me[s.key] = old or { readyAt = 0, dur = s.cd }
				me[s.key].hidden = true
			elseif dur and dur > 1.5 then
				me[s.key] = { readyAt = start + dur, dur = dur }
				baseDur[s.key] = dur
			else
				me[s.key] = { readyAt = 0, dur = baseDur[s.key] or s.cd }
			end
		else
			me[s.key] = nil
		end
	end
	ns.cds[Me] = me
end

-- Forbearance on you. Returns true when the debuff list could not be read.
local function ReadForbearance()
	local found, hidden = nil, false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
		if not ok then hidden = true break end
		if not a then break end
		local name = Clean(a.name)
		if not name or name == RESTRICTED then
			hidden = true
		elseif name == FORBEARANCE.name then
			local exp = Clean(a.expirationTime)
			found = (exp and exp > 0) and exp or (GetTime() + FORBEARANCE.cd)
			break
		end
	end
	if InCombatLockdown() then hidden = true end -- debuffs can be left out of the list in combat
	if found then forb = found elseif not hidden then forb = nil end
	if forb and forb <= GetTime() then forb = nil end
	return hidden
end

-- Target of the last Blessing of Protection cast (UNIT_SPELLCAST_SENT); Forbearance lands on the recipient, not the caster.
local lastBopTarget
-- A tracked spell was cast. When the client hides the cooldown, assume it started now.
local function Cast(key)
	ScanSelf()
	local me, now = ns.cds[Me], GetTime()
	local c = me and me[key]
	if not c then return end
	if c.hidden and c.readyAt <= now + 1 then
		local dur = baseDur[key] or BY_KEY[key].cd
		me[key] = { readyAt = now + dur, dur = dur, hidden = true, assumed = true }
		local other = SHARED[key]
		if other and me[other] then me[other] = { readyAt = now + dur, dur = dur, hidden = true, assumed = true } end
	end
	local onSelf = key == "ds" or key == "dp" or (key == "bop" and lastBopTarget == (UnitName("player")))
	if onSelf and ReadForbearance() and not forb then
		forb = now + FORBEARANCE.cd
	end
	if key == "bop" then lastBopTarget = nil end
end

-- Sharing ---------------------------------------------------------------------------
local function Message()
	local me, now, parts = ns.cds[Me] or {}, GetTime(), {}
	for _, s in ipairs(SPELLS) do
		local c = me[s.key]
		if c then
			parts[#parts + 1] = ("%s:%d:%d"):format(s.key, math.floor(c.dur or 0), math.floor(math.max((c.readyAt or 0) - now, 0)))
		else
			parts[#parts + 1] = s.key .. ":n:n"
		end
	end
	return "CDS " .. table.concat(parts, " ")
end

local function SendCDS(target)
	if not ns.SendLB or not IsInGroup() then return end
	ScanSelf()
	ns.SendLB(Message(), target)
end

local pendingSend
local function SoonSend(delay)
	if pendingSend then return end
	pendingSend = true
	C_Timer.After(delay or 1.5, function() pendingSend = false; SendCDS() end)
end

if ns.OnLBSync then ns.OnLBSync(function(target) SendCDS(target) end) end

local Redraw
if ns.OnLB then
	ns.OnLB("CDS", function(sender, rest)
		if not Me or sender == Me then return end
		if ns.UnitForName and not ns.UnitForName(sender) then return end -- only people in your group
		local t, now = {}, GetTime()
		for key, d, l in rest:gmatch("(%a+):([%dn]+):([%dn]+)") do
			local dn, ln = tonumber(d), tonumber(l)
			if BY_KEY[key] and dn and ln then t[key] = { readyAt = now + ln, dur = dn } end
		end
		ns.cds[sender] = t
		if Redraw then Redraw() end
	end)
end

-- Frame ------------------------------------------------------------------------------
local function ShouldShow()
	local db = ns.db
	if ns.unlocked then return true end
	if not db.cdEnabled then return false end
	if db.cdOnlyRaid then return IsInRaid() end
	return IsInGroup()
end

local function MakeSlot(row, i, spell)
	local f = CreateFrame("Frame", nil, row)
	f:SetSize(ICON, ICON)
	f:SetPoint("LEFT", PAD + NAME_W + 4 + (i - 1) * (ICON + GAP), 0)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints(); f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.icon:SetTexture(Texture(spell.id, spell.icon))
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints()
	if f.cd.SetDrawEdge then f.cd:SetDrawEdge(false) end
	if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
	if f.cd.SetSwipeColor then f.cd:SetSwipeColor(0, 0, 0, 0.75) end
	-- the text sits on its own frame so the sweep doesn't cover it
	local top = CreateFrame("Frame", nil, f)
	top:SetAllPoints(); top:SetFrameLevel(f:GetFrameLevel() + 3)
	f.text = top:CreateFontString(nil, "OVERLAY")
	f.text:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
	f.text:SetPoint("CENTER", 0, 0)
	f.text:SetTextColor(1, 0.9, 0.5)
	f.spell = spell
	f:SetScript("OnEnter", function(self)
		if ns.unlocked or not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.spell.name)
		GameTooltip:AddLine(self.tip, 1, 1, 1)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- state: nil = spell not known, 0 = ready, >0 = seconds left
	f.Set = function(self, c, now)
		if not c then
			ClearCD(self.cd); self.cdKey = nil
			self.icon:SetDesaturated(true); self:SetAlpha(0.12); self.text:SetText("")
			self.tip = "not known"
			return
		end
		local left = (c.readyAt or 0) - now
		if left > 0 then
			local key = c.readyAt .. ":" .. (c.dur or 0)
			if self.cdKey ~= key then
				self.cdKey = key
				if c.dur and c.dur > 0 then self.cd:SetCooldown(c.readyAt - c.dur, c.dur) else ClearCD(self.cd) end
			end
			self.icon:SetDesaturated(true); self:SetAlpha(0.75)
			self.text:SetText(FormatTime(left))
			self.tip = "ready in " .. FormatTime(left) .. (left < 60 and "s" or "") .. (c.assumed and " (assumed, hidden in combat)" or "")
		else
			if self.cdKey then ClearCD(self.cd); self.cdKey = nil end
			self.icon:SetDesaturated(false); self:SetAlpha(1)
			self.text:SetText("")
			self.tip = "ready"
		end
	end
	return f
end

local function MakeRow(i)
	local r = CreateFrame("Frame", nil, frame)
	r:SetSize(ROW_W - 8, ROW_H)
	r:SetPoint("TOPLEFT", 4, -20 - (i - 1) * ROW_H)
	r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
	r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
	r.name = r:CreateFontString(nil, "OVERLAY")
	r.name:SetFont("Fonts\\ARIALN.TTF", 13, "")
	r.name:SetPoint("LEFT", PAD, 0); r.name:SetWidth(NAME_W); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
	if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) end
	r.none = r:CreateFontString(nil, "OVERLAY")
	r.none:SetFont("Fonts\\ARIALN.TTF", 12, "")
	r.none:SetPoint("LEFT", PAD + NAME_W + 6, 0); r.none:SetTextColor(0.6, 0.6, 0.6)
	r.none:SetText("no sync")
	r.slots = {}
	for k, s in ipairs(SPELLS) do r.slots[k] = MakeSlot(r, k, s) end
	r.slots[FORB_SLOT] = MakeSlot(r, FORB_SLOT, FORBEARANCE)
	r.slots[FORB_SLOT].text:SetTextColor(1, 0.4, 0.4)
	rows[i] = r
	return r
end

local function Draw(names, data, myForb)
	local now = GetTime()
	for i, name in ipairs(names) do
		local r = rows[i] or MakeRow(i)
		r.name:SetText(name == Me and (name .. " (you)") or name)
		local d = data[name]
		for k = 1, #SPELLS do
			local slot = r.slots[k]
			slot:EnableMouse(not ns.unlocked)
			if d then slot:Show(); slot:Set(d[SPELLS[k].key], now) else slot:Hide() end
		end
		r.none:SetShown(not d)
		local fs = r.slots[FORB_SLOT]
		if name == Me and myForb and myForb > now then
			fs:Show(); fs:EnableMouse(not ns.unlocked)
			fs:Set({ readyAt = myForb, dur = FORBEARANCE.cd }, now)
		else
			fs:Hide()
		end
		r:Show()
	end
	for i = #names + 1, #rows do rows[i]:Hide() end
	frame:SetHeight(22 + math.max(#names, 1) * ROW_H + 4)
end

local function Rescan()
	list = {}
	if not ns.GroupPaladins then return end
	for _, name in ipairs(ns.GroupPaladins()) do
		if name ~= Me or ns.db.cdShowSelf then list[#list + 1] = name end
	end
	-- forget paladins who left
	local keep = {}
	for _, name in ipairs(list) do keep[name] = true end
	for name in pairs(ns.cds) do if name ~= Me and not keep[name] then ns.cds[name] = nil end end
end

Redraw = function()
	if not frame or not frame:IsShown() or ns.unlocked then return end
	Draw(list, ns.cds, forb)
end

function M:Update()
	if not frame then return end
	Me = Me or ns.MyName()
	if ns.unlocked then
		-- placeholder: you plus a sample paladin
		local now = GetTime()
		local sample = {
			[Me] = { bop = { readyAt = now + 240, dur = 300 }, freedom = { readyAt = 0, dur = 25 }, sac = { readyAt = 0, dur = 30 },
				ds = { readyAt = now + 110, dur = 300 }, dp = { readyAt = now + 110, dur = 300 } },
			Lightbringer = { bop = { readyAt = 0, dur = 300 }, freedom = { readyAt = now + 12, dur = 25 }, sac = { readyAt = 0, dur = 30 },
				ds = { readyAt = 0, dur = 300 } },
		}
		frame:Show()
		Draw({ Me, "Lightbringer" }, sample, now + 45)
		return
	end
	if not ShouldShow() then frame:Hide() return end
	ScanSelf()
	ReadForbearance()
	Rescan()
	if #list == 0 then frame:Hide() return end
	frame:Show()
	Draw(list, ns.cds, forb)
end

function M:Init()
	Me = ns.MyName()
	frame = CreateFrame("Frame", "LightboundCooldownsFrame", UIParent, "BackdropTemplate")
	frame:SetSize(ROW_W, 60)
	frame:SetFrameStrata("MEDIUM")
	frame:Hide()
	if ns.UI and ns.UI.Box then
		ns.UI.Box(frame, 0.85)
	else
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(); bg:SetColorTexture(0.075, 0.058, 0.042, 0.88)
	end
	title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
	title:SetPoint("TOPLEFT", 6, -4)
	title:SetTextColor(1, 0.82, 0)
	title:SetText("Paladin cooldowns")
	ns.MakeMovable(frame, "cdPoint")
	ns.ApplyPoint(frame, "cdPoint")

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("SPELLS_CHANGED")
	ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	ev:RegisterUnitEvent("UNIT_AURA", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
	ev:SetScript("OnEvent", function(_, event, _, a4, a5, a6)
		if event == "UNIT_SPELLCAST_SENT" then
			-- (unit, target, castGUID, spellID)
			if ns.SpellName(a6) == "Blessing of Protection" then
				local t = (type(a4) == "string" and not isSecret(a4)) and a4 or nil
				lastBopTarget = t and Ambiguate(t, "none") or nil
			end
			return
		end
		local spellID = a5 -- UNIT_SPELLCAST_SUCCEEDED: (unit, castGUID, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			for _, s in ipairs(SPELLS) do
				if name == s.name then Cast(s.key); SoonSend(1.5) end
			end
			Redraw()
			return
		elseif event == "SPELL_UPDATE_COOLDOWN" then
			if frame:IsShown() and not ns.unlocked then ScanSelf(); Redraw() end
			return
		elseif event == "UNIT_AURA" then
			if frame:IsShown() and not ns.unlocked then ReadForbearance(); Redraw() end
			return
		elseif event == "PLAYER_REGEN_ENABLED" then
			SoonSend(2) -- cooldowns are readable again: send the real values
		elseif event == "SPELLS_CHANGED" then
			SoonSend(3)
		elseif event == "GROUP_ROSTER_UPDATE" and not IsInGroup() then
			for k in pairs(ns.cds) do if k ~= Me then ns.cds[k] = nil end end
		end
		M:Update()
	end)
	C_Timer.NewTicker(1, function() if frame:IsShown() and not ns.unlocked then ReadForbearance(); Redraw() end end)
	M:Update()
end

-- Options page --------------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Cooldowns", "Every paladin's protective cooldowns, shared between Lightbound users.")
	local W = UI.CONTENT_W
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "cdEnabled", "Show the cooldowns frame",
		"Blessing of Protection, Freedom and Sacrifice, Divine Shield and Divine Protection, one row per paladin.")) + 4)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "cdOnlyRaid", "Only in raids", "Off: also in a party.")) + 4)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "cdShowSelf", "Include my own row",
		"Your row also shows Forbearance while it blocks Divine Shield and Blessing of Protection.")) + 14)
	local n = UI.Font(p, 12, UI.C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("Bright = ready, dim with seconds = on cooldown. Paladins without Lightbound show as \"no sync\". In combat the client hides cooldown times, so your own row keeps the last known values. Unlock frames to move it.")
end

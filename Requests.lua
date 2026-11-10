-- Blessing requests: someone whispers "kings pls" (or says it in party/raid/say when enabled)
-- and a row with their name and the blessing appears. Click it (out of combat) to bless them.
-- Rows go away after a while, when the blessing shows up on them, or when your cast lands.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local ROW_W, ROW_H, MAX_ROWS = 230, 24, 8
local frame, title, rows = nil, nil, {}
local requests = {} -- oldest first: { name, unit, guid, class, key, spell, known, at, base }
local pending, pendingAt -- request of the last click, until the cast lands (or fails, or 3 s pass)
local PENDING_WINDOW = 3
local isSecret = _G.issecretvalue or function() return false end
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end

-- word -> blessing key; "*" means "whatever this class is assigned"
local WORDS = {
	kings = "Kings", bok = "Kings",
	might = "Might", bom = "Might",
	wisdom = "Wisdom", wis = "Wisdom", bow = "Wisdom",
	salvation = "Salvation", salv = "Salvation", bos = "Salvation",
	light = "Light", bol = "Light",
	sanctuary = "Sanctuary", sanc = "Sanctuary", sanct = "Sanctuary",
	buff = "*", bless = "*", blessing = "*",
}

local SAMPLE = {
	{ name = "Thrall", class = "SHAMAN", key = "Wisdom", spell = "Blessing of Wisdom", known = true, age = 4 },
	{ name = "Garrosh", class = "WARRIOR", key = "Might", spell = "Blessing of Might", known = true, age = 17 },
	{ name = "Jaina", class = "MAGE", key = "Salvation", spell = "Blessing of Salvation", known = false, age = 41 },
}

-- Blessing key named in the text, "*" for a plain buff/bless request, nil when it isn't one.
local function Parse(text)
	local generic = false
	for word in text:lower():gmatch("%a+") do
		local key = WORDS[word]
		if key == "*" then generic = true
		elseif key then return key end
	end
	return generic and "*" or nil
end

local function SpellTexture(name)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
		return GetSpellTexture(name)
	end)
	return ok and tex or 135906
end

local function UnitByGUID(guid)
	if not guid then return nil end
	for _, u in ipairs(ns.PB.Units()) do
		if UnitExists(u) and Clean(UnitGUID(u)) == guid then return u end
	end
	return nil
end

local function FindUnit(r)
	local u = UnitByGUID(r.guid) or ns.UnitForName(r.name)
	if u and not UnitExists(u) then u = nil end
	return u
end

-- The blessing to cast: the one asked for, else the assigned one for their class, else Kings/Might.
-- An explicit ask still goes through the tank guard (a tank asking for Salvation gets the
-- replacement, or nil when it's set to None). Second value: a note for the tooltip.
local function Resolve(key, unit, class)
	if key == "*" then
		if unit and class then
			local assigned = ns.PB.Assignment(unit, class, ns.PartyBuffSource()) -- already tank-guarded
			if assigned then return assigned end
		end
		return ns.PB.SpellKnown("Blessing of Kings") and "Kings" or "Might"
	end
	if unit and class and ns.TankAssignment then
		local guarded, _, note = ns.TankAssignment(unit, class, key, false)
		return guarded, note
	end
	return key
end

local function Find(name)
	for i, r in ipairs(requests) do if r.name == name then return r, i end end
end

local function Add(name, guid, key)
	local r = Find(name)
	local new = r == nil
	if new then r = { name = name } end
	r.guid = r.guid or guid
	local unit = FindUnit(r)
	if ns.db.rqGroupOnly and not unit then return end
	local class
	if unit then
		class = select(2, UnitClass(unit))
	elseif guid then
		local ok, _, c = pcall(GetPlayerInfoByGUID, guid)
		if ok then class = Clean(c) end
	end
	local note
	key, note = Resolve(key, unit, class)
	if not key then
		if note then ns.Print(("%s asks for Salvation: %s"):format(name, note)) end
		return
	end
	if new then
		while #requests >= ns.db.rqRows do table.remove(requests, 1) end
		requests[#requests + 1] = r
	end
	r.unit, r.class, r.key, r.spell, r.at = unit, class, key, "Blessing of " .. key, GetTime()
	r.known = ns.PB.SpellKnown(r.spell)
	r.base = unit and ns.PB.TimeLeft(unit, key) or 0 -- time they already had; a refresh request
	if r.base == math.huge then r.base = 0 end
	if new and ns.db.rqSound then PlaySound(SOUNDKIT.READY_CHECK or 8960, "Master") end
	if InCombatLockdown() and frame and not frame:IsShown() then
		-- the frame can't be shown in combat; say it in chat instead
		ns.Print(("%s asks for %s (after combat)"):format(name, key))
	end
	M:Update()
end

local function OnChat(event, text, sender, guid)
	if not ns.db.rqEnabled or not text or not sender then return end
	if event ~= "CHAT_MSG_WHISPER" and not ns.db.rqChat then return end
	local ok, key = pcall(Parse, text)
	if not ok or not key then return end
	local name = Ambiguate(sender, "none")
	if name == UnitName("player") or name == ns.MyName() then return end
	Add(name, Clean(guid), key)
end

-- Drop requests that are old, blessed, or (group only) from someone who left.
local function Prune()
	local now, ttl, changed = GetTime(), ns.db.rqTTL, false
	for i = #requests, 1, -1 do
		local r = requests[i]
		local done = now - r.at > ttl
		if not done and r.unit and (not UnitExists(r.unit) or (r.guid and Clean(UnitGUID(r.unit)) ~= r.guid)) then
			r.unit = FindUnit(r)
			if not r.unit and ns.db.rqGroupOnly then done = true end
		end
		if not done and r.unit then
			local left = ns.PB.TimeLeft(r.unit, r.key)
			if left and left > r.base + 10 then done = true end
		end
		if done then table.remove(requests, i); changed = true end
	end
	while #requests > ns.db.rqRows do table.remove(requests, 1); changed = true end
	return changed
end

local function Configure(row)
	if InCombatLockdown() then return end
	local r = row.data
	if r and r.known and not ns.unlocked then
		row:SetAttribute("type", "macro")
		if r.unit then
			row:SetAttribute("macrotext", ("/cast [nocombat,@%s,help] %s"):format(r.unit, r.spell))
		else
			row:SetAttribute("macrotext", ("/target %s\n/cast [nocombat,@target,help] %s\n/targetlasttarget"):format(r.name, r.spell))
		end
		pending, pendingAt = r, GetTime()
	else
		row:SetAttribute("type", nil)
		pending = nil
	end
end

local function Height(n) return 22 + math.max(n, 1) * (ROW_H + 2) end

local function Draw()
	local combat, now = InCombatLockdown(), GetTime()
	local list = ns.unlocked and SAMPLE or requests
	for i, row in ipairs(rows) do
		local r = list[i]
		if r and i > ns.db.rqRows and not ns.unlocked then r = nil end
		row.data = r
		if r then
			local cc = r.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class]
			row.icon:SetTexture(SpellTexture(r.spell))
			row.icon:SetDesaturated(not r.known)
			row.name:SetText(r.name)
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) else row.name:SetTextColor(1, 1, 1) end
			local tag
			if not r.known then tag = "|cffff5555not known|r"
			elseif combat then tag = "|cff999999after combat|r"
			else tag = "|cffffd100" .. r.key .. "|r" end
			row.state:SetText(("%s  |cff999999%ds|r"):format(tag, r.age or math.floor(now - r.at)))
			row:SetAlpha((combat or not r.known) and 0.55 or 1)
			row:EnableMouse(not ns.unlocked)
			if not combat then row:Show() end
		else
			-- Empty rows stay shown at alpha 0 (rows can't be shown in combat, so every slot is
			-- prepared out of combat; a request that arrives mid-fight is drawn into one of them).
			row:SetAlpha(0)
			row:EnableMouse(false)
			if not combat then
				if i <= ns.db.rqRows or (ns.unlocked and i <= #list) then row:Show() else row:Hide() end
			end
		end
	end
	if not combat then frame:SetHeight(Height(ns.unlocked and #list or ns.db.rqRows)) end
end

function M:Update()
	if not frame then return end
	if not ns.unlocked then
		if not ns.db.rqEnabled then wipe(requests) end
		Prune()
	end
	if InCombatLockdown() then
		if frame:IsShown() then Draw() end
		return
	end
	if not ns.unlocked and #requests == 0 then frame:Hide() return end
	frame:Show()
	Draw()
end

function M:Init()
	frame = CreateFrame("Frame", "LightboundRequestsFrame", UIParent, "BackdropTemplate")
	frame:SetSize(ROW_W, 100)
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
	title:SetText("Blessing requests")
	ns.MakeMovable(frame, "rqPoint")
	ns.ApplyPoint(frame, "rqPoint")

	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", "LightboundRequestRow" .. i, frame, "SecureActionButtonTemplate")
		row:SetSize(ROW_W - 8, ROW_H)
		row:SetPoint("TOPLEFT", 4, -20 - (i - 1) * (ROW_H + 2))
		row:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
		row:SetAttribute("checkselfcast", false)
		row:SetAttribute("checkfocuscast", false)
		row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
		row.bg:SetColorTexture(0.165, 0.125, 0.082, 0.8)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_H - 4, ROW_H - 4); row.icon:SetPoint("LEFT", 2, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetFont("Fonts\\ARIALN.TTF", 13, ""); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.state = row:CreateFontString(nil, "OVERLAY")
		row.state:SetFont("Fonts\\ARIALN.TTF", 13, ""); row.state:SetPoint("RIGHT", -6, 0)
		local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("PreClick", function(self) Configure(self) end)
		row:SetScript("PostClick", function(self)
			local r = self.data
			if r and not InCombatLockdown() then r.clicked = GetTime() end
		end)
		row:SetScript("OnEnter", function(self)
			local r = self.data
			if not r or ns.unlocked then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(r.name .. " asks for " .. r.key)
			if not r.known then
				GameTooltip:AddLine("You don't know " .. r.spell, 1, 0.4, 0.4)
			elseif InCombatLockdown() then
				GameTooltip:AddLine("After combat: click to cast " .. r.spell, 0.6, 0.6, 0.6)
			elseif r.unit then
				GameTooltip:AddLine("Click: " .. r.spell, 0.6, 0.9, 0.6)
			else
				GameTooltip:AddLine("Not in your group. Click: target by name and cast " .. r.spell, 0.6, 0.9, 0.6)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:Hide()
		rows[i] = row
	end

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER", "CHAT_MSG_SAY" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function(_, event, a1, a2, a3, _, _, _, _, _, _, _, _, a12)
		if event == "PLAYER_REGEN_DISABLED" then
			-- Lockdown is already on when this fires, so nothing protected can be done here. Rows are
			-- prepared by Draw() out of combat and the click macro carries [nocombat], so a stale
			-- target can't fire. Just redraw the states.
			Draw()
			return
		elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" or event == "UNIT_SPELLCAST_INTERRUPTED" then
			-- out of range, line of sight, ...: the request stays, the click is forgotten
			if pending and ns.SpellName(a3) == pending.spell then pending = nil end
			return
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(a3)
			-- only a cast right after the click counts; a later cast of the same blessing on someone else doesn't
			if pending and GetTime() - (pendingAt or 0) > PENDING_WINDOW then pending = nil end
			if pending and name == pending.spell then
				if pending.guid then
					local recent = ns.PB.recent
					recent[pending.guid] = recent[pending.guid] or {}
					recent[pending.guid][pending.key] = GetTime()
				end
				local _, i = Find(pending.name)
				if i then table.remove(requests, i) end
			end
			pending = nil
		elseif event:find("^CHAT_MSG_") then
			OnChat(event, a1, a2, a12)
			return -- Add() already refreshed
		end
		M:Update()
	end)
	C_Timer.NewTicker(1, function() M:Update() end)
end

-- Options page --------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Requests", "Shows who asked for a blessing in chat. Click a row to bless them.")
	local W = UI.CONTENT_W
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "rqEnabled", "Show blessing requests",
		"Whispers like \"kings pls\", \"bom\" or just \"buff\" become clickable rows.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "rqChat", "Also read party, raid and say", "Off: whispers only.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "rqGroupOnly", "Only from people in your group",
		"Off: whispers from anyone count; clicking targets them by name first.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "rqSound", "Sound on a new request")) + 6)
	p:Add(select(2, UI.Slider(p, p.y, "Requests disappear after", "rqTTL", 15, 180, 5, " s")) + 8)
	p:Add(select(2, UI.Slider(p, p.y, "Rows", "rqRows", 1, MAX_ROWS, 1, "")) + 8)
end

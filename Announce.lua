-- Announce:
--  * Divine Intervention picker: a short list of raid healers (pinned target first). Click a row to cast
--    Divine Intervention on that player, in combat too. Rows are secure buttons set up out of combat;
--    in combat the row -> unit mapping stays fixed and only names and dimming are redrawn.
--  * Chat announcements for Divine Intervention (raid warning for leaders/assists) and Redemption.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local DI, REZ = "Divine Intervention", "Redemption"
local MAX_ROWS, ROW_W, ROW_H, HEAD_H = 10, 180, 20, 22
local HEALER = { PRIEST = 1, DRUID = 2, SHAMAN = 3, PALADIN = 4 } -- listed first, in this order
local PLACEHOLDER = { "PRIEST", "DRUID", "SHAMAN", "PALADIN" }

local frame, rows = nil, {}
local shownRows = 0
local lastDITarget      -- { name, at } from the last clicked row (PostClick runs in combat too)
local sent              -- { spell, name, at } from UNIT_SPELLCAST_SENT
local lastRez = {}      -- target name -> time of the last Redemption announcement
local isSecret = ns.IsSecret -- see Core.lua

local function Clean(v) if v == nil or isSecret(v) then return nil end return v end
local function Safe(fn, ...) local ok, v = pcall(fn, ...) if not ok then return nil end return Clean(v) end
local function Short(name) return (name:gsub("%-[^%-]*$", "")) end -- drop "-Realm"

local function Known(spell)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spell) end
		return GetSpellInfo(spell)
	end)
	return ok and info ~= nil
end

local function Texture(spell)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
		return GetSpellTexture(spell)
	end)
	return (ok and tex) or 136106
end

-- true/false, or nil when the client hides it (combat)
local function InRange(unit)
	local ok, r = pcall(function()
		if C_Spell and C_Spell.IsSpellInRange then return C_Spell.IsSpellInRange(DI, unit) end
		return IsSpellInRange(DI, unit)
	end)
	if not ok then return nil end
	r = Clean(r)
	if r == nil then return nil end
	return r == true or r == 1
end

-- Chat ------------------------------------------------------------------------------
local function Channel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
end

-- raid warning only when allowed (leader/assist in a raid) and asked for
local function Announce(msg, warning)
	local chan = Channel()
	if not chan then return end
	if warning and chan == "RAID" and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
		chan = "RAID_WARNING"
	end
	pcall(SendChatMessage, msg, chan)
end

local function OnDI()
	local now, target = GetTime(), nil
	if sent and sent.spell == DI and now - sent.at < 2 then target = sent.name end
	if not target and lastDITarget and now - lastDITarget.at < 5 then target = lastDITarget.name end
	sent, lastDITarget = nil, nil
	if not ns.db.diAnnounce then return end
	Announce(("Divine Intervention on %s!"):format(target and Short(target) or "a healer"), ns.db.diWarning)
end

local function OnRez()
	local db = ns.db
	local now, target = GetTime(), nil
	if sent and sent.spell == REZ and now - sent.at < 15 then target = sent.name end -- 10 s cast
	sent = nil
	if not target and UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target")
		and Safe(UnitIsDeadOrGhost, "target") then
		target = Safe(UnitName, "target")
	end
	if not (db.rezAnnounce or db.rezWhisper) then return end
	local key = target or "?"
	if lastRez[key] and now - lastRez[key] < 3 then return end -- recast on the same person: say it once
	lastRez[key] = now
	if db.rezAnnounce then Announce("Resurrecting " .. (target and Short(target) or "a fallen ally"), false) end
	if db.rezWhisper and target then pcall(SendChatMessage, "Resurrecting you", "WHISPER", nil, target) end
end

-- Picker ----------------------------------------------------------------------------
local function ShouldShow()
	if ns.unlocked then return true end
	local db = ns.db
	if not db.diEnabled or not Known(DI) then return false end
	return IsInRaid() or (db.diParty and IsInGroup())
end

-- { unit, name, class } for everyone but you: pinned first, healers next, then by class and name
local function Candidates()
	local list, raid = {}, IsInRaid()
	local n = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
	for i = 1, n do
		local u = (raid and "raid" or "party") .. i
		if UnitExists(u) and not UnitIsUnit(u, "player") and UnitIsConnected(u) then
			local name = UnitName(u) or u
			local _, class = UnitClass(u)
			list[#list + 1] = { unit = u, name = name, class = class or "", order = HEALER[class] or 99,
				pinned = name == ns.db.diPinned }
		end
	end
	table.sort(list, function(a, b)
		if a.pinned ~= b.pinned then return a.pinned end
		if a.order ~= b.order then return a.order < b.order end
		if a.class ~= b.class then return a.class < b.class end
		return a.name < b.name
	end)
	return list
end

-- out of combat only: row -> unit mapping, secure attributes, visibility and frame size
local function Configure()
	if InCombatLockdown() then return end
	local list = ns.unlocked and {} or Candidates()
	local n = math.max(1, math.min(ns.db.diRows or 6, MAX_ROWS))
	shownRows = 0
	for i, row in ipairs(rows) do
		local c = i <= n and list[i] or nil
		row.unit = c and c.unit or nil
		row.placeholder = ns.unlocked and i <= n
		row.dead, row.far = nil, nil
		row:SetAttribute("unit", row.unit)
		row:SetAttribute("spell", row.unit and DI or nil)
		row:SetAttribute("type", row.unit and "spell" or nil)
		row:EnableMouse(not ns.unlocked) -- let the drag reach the frame while unlocked
		local show = row.unit ~= nil or row.placeholder
		row:SetShown(show)
		if show then shownRows = shownRows + 1 end
	end
	frame:SetHeight(HEAD_H + math.max(shownRows, 1) * (ROW_H + 2) + 6)
end

-- safe in combat: only text, colors and alpha
local function Draw()
	for i, row in ipairs(rows) do
		if row.placeholder then
			local class = PLACEHOLDER[(i - 1) % #PLACEHOLDER + 1]
			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			row.name:SetText("Healer " .. i)
			row.name:SetTextColor(cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1)
			row.state:SetText(i == 2 and "|cff999999far|r" or "")
			row.pin:SetShown(i == 1)
			row:SetAlpha(i == 2 and 0.4 or 1)
		elseif row.unit then
			local name = Safe(UnitName, row.unit)
			if name then
				row.name:SetText(name)
				row.pin:SetShown(name == ns.db.diPinned)
			end
			local ok, _, class = pcall(UnitClass, row.unit)
			local cc = ok and class and not isSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) end
			local dead, far = Safe(UnitIsDeadOrGhost, row.unit), InRange(row.unit)
			if dead ~= nil then row.dead = dead end
			if far ~= nil then row.far = not far end
			local state = row.dead and "|cffff5555dead|r" or (row.far and "|cff999999far|r") or ""
			row.state:SetText(state)
			row:SetAlpha(state ~= "" and 0.4 or 1)
		end
	end
end

function M:Update()
	if not frame then return end
	if InCombatLockdown() then
		if frame:IsShown() then Draw() end
		return
	end
	if not ShouldShow() then frame:Hide() return end
	Configure()
	if shownRows == 0 then frame:Hide() return end
	frame:Show()
	Draw()
end

local function OnRowClick(self)
	local unit = self:GetAttribute("unit")
	if ns.unlocked or not unit then return end
	if IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then -- "shift-type*" is "none": no cast, pin instead
		if InCombatLockdown() then return end
		local name = Safe(UnitName, unit)
		if not name then return end
		ns.db.diPinned = ns.db.diPinned ~= name and name or nil
		ns.Print(ns.db.diPinned and (name .. " pinned as Divine Intervention target.") or "Divine Intervention pin cleared.")
		M:Update()
		return
	end
	lastDITarget = { name = Safe(UnitName, unit), at = GetTime() }
end

local function OnRowEnter(self)
	if ns.unlocked or not self:GetAttribute("unit") then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(DI)
	GameTooltip:AddLine("Click: cast on " .. (Safe(UnitName, self:GetAttribute("unit")) or "this player"), 0.6, 0.9, 0.6)
	GameTooltip:AddLine("Shift-click (out of combat): pin or unpin as preferred target", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function M:Init()
	frame = CreateFrame("Frame", "LightboundDIFrame", UIParent, "BackdropTemplate")
	frame:SetSize(ROW_W, 100)
	frame:SetFrameStrata("MEDIUM")
	frame:Hide()
	if ns.UI and ns.UI.Box then
		ns.UI.Box(frame, 0.85)
	else
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(); bg:SetColorTexture(0.075, 0.058, 0.042, 0.88)
	end
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(14, 14); icon:SetPoint("TOPLEFT", 6, -4)
	icon:SetTexture(Texture(DI)); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
	title:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	title:SetTextColor(1, 0.82, 0)
	title:SetText(DI)
	ns.MakeMovable(frame, "diPoint")
	ns.ApplyPoint(frame, "diPoint")

	local clicks = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp"
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", "LightboundDIRow" .. i, frame, "SecureActionButtonTemplate")
		row:SetSize(ROW_W - 8, ROW_H)
		row:SetPoint("TOPLEFT", 4, -HEAD_H - (i - 1) * (ROW_H + 2))
		row:RegisterForClicks(clicks)
		row:SetAttribute("checkselfcast", false)
		row:SetAttribute("checkfocuscast", false)
		row:SetAttribute("shift-type*", "none") -- shift-click pins (PostClick) instead of casting
		row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
		row.bg:SetColorTexture(0.165, 0.125, 0.082, 0.8)
		row.pin = row:CreateTexture(nil, "ARTWORK")
		row.pin:SetPoint("TOPLEFT"); row.pin:SetPoint("BOTTOMLEFT"); row.pin:SetWidth(3)
		row.pin:SetColorTexture(1, 0.82, 0, 1); row.pin:Hide()
		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetFont("Fonts\\ARIALN.TTF", 13, ""); row.name:SetPoint("LEFT", 8, 0)
		row.state = row:CreateFontString(nil, "OVERLAY")
		row.state:SetFont("Fonts\\ARIALN.TTF", 12, ""); row.state:SetPoint("RIGHT", -6, 0)
		row.name:SetPoint("RIGHT", row.state, "LEFT", -4, 0); row.name:SetJustifyH("LEFT")
		local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("PostClick", OnRowClick)
		row:SetScript("OnEnter", OnRowEnter)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:Hide()
		rows[i] = row
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do
		ev:RegisterEvent(e)
	end
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	ev:SetScript("OnEvent", function(_, event, _, a2, a3, a4)
		if event == "UNIT_SPELLCAST_SENT" then -- unit, target, castGUID, spellID
			local name = ns.SpellName(a4)
			if name == DI or name == REZ then sent = { spell = name, name = Clean(a2), at = GetTime() } end
			return
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then -- unit, castGUID, spellID
			local name = ns.SpellName(a3)
			-- spell ID hidden (combat) right after a picker click: it was Divine Intervention
			if name == nil and lastDITarget and GetTime() - lastDITarget.at < 1 then name = DI end
			if name == DI then OnDI() elseif name == REZ then OnRez() end
			return
		elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
			local name = ns.SpellName(a3)
			if name == nil or name == DI or name == REZ then sent, lastDITarget = nil, nil end
			return
		end
		M:Update()
	end)
	C_Timer.NewTicker(1, function() if frame:IsShown() then M:Update() end end) -- range and deaths
	M:Update()
end

-- Options page ----------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Announce", "Divine Intervention target picker and chat announcements.")
	local W = UI.CONTENT_W
	p:Add(UI.Section(p, p.y, "Divine Intervention") + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "diEnabled", "Show the target picker in raids",
		"Click a healer to cast Divine Intervention on them. Shift-click pins a preferred target at the top.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "diParty", "Also in parties")) + 6)
	p:Add(select(2, UI.Slider(p, p.y, "Picker rows", "diRows", 1, MAX_ROWS, 1, "")) + 8)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "diAnnounce", "Announce Divine Intervention in chat")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "diWarning", "Use raid warning when you're leader or assist")) + 6)
	p:Add(UI.Section(p, p.y, "Redemption") + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "rezAnnounce", "Announce resurrections",
		"\"Resurrecting <name>\" in party or raid chat when Redemption lands.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "rezWhisper", "Also whisper the target")) + 6)
end

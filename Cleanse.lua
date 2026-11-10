-- Cleanse list: group members (and pets) carrying a debuff you can remove, one click each.
-- Cleanse removes Poison, Disease and Magic; Purify only Poison and Disease. Whichever you know
-- is used, Cleanse preferred.
--
-- Rows are secure buttons (type=spell, unit=<unitID>). Their attributes can only change out of
-- combat, so:
--  * out of combat every row is mapped: afflicted units first, then the rest of the group as
--    invisible "standby" rows. In a party with 5 rows everyone always has a row;
--  * in combat the row -> unit mapping is frozen. Only the visuals change (icon, count, alpha).
--    A unit that has no row when combat starts can't get one until it ends. Rows are never
--    shown/hidden in combat (protected frames); alpha does the hiding instead;
--  * PLAYER_REGEN_ENABLED re-maps immediately.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = _G.issecretvalue or function() return false end
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end

local ROW_W, ROW_H, TITLE_H, MAX_ROWS = 190, 22, 18, 10
local frame, title, rows = nil, nil, {}
local spell, types                   -- "Cleanse"/"Purify" and the debuff types it removes
local afflicted = {}                 -- unit -> true from the last scan (for the sound)
local dirty = false

local TYPE_COLOR = {
	Poison = { 0.0, 0.6, 0.0 }, Disease = { 0.6, 0.4, 0.0 }, Magic = { 0.2, 0.6, 1.0 },
}

local function Known(name)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) end
		return GetSpellInfo(name)
	end)
	return ok and info ~= nil
end

-- Picks the dispel spell. Returns true when it changed.
local function PickSpell()
	local s, t
	if Known("Cleanse") then s, t = "Cleanse", { Poison = true, Disease = true, Magic = true }
	elseif Known("Purify") then s, t = "Purify", { Poison = true, Disease = true } end
	local changed = s ~= spell
	spell, types = s, t
	return changed
end

local function Texture(name)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
		return GetSpellTexture(name)
	end)
	return (ok and tex) or 135953
end

local function InRange(unit)
	if UnitIsUnit(unit, "player") then return true end
	local ok, r = pcall(C_Spell.IsSpellInRange, spell, unit)
	if not ok or isSecret(r) or r == nil then
		return UnitInRange and Clean((UnitInRange(unit))) ~= false
	end
	return r == true or r == 1
end

local function Units()
	local db = ns.db
	local list = { "player" }
	if db.clPets then list[#list + 1] = "pet" end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if not UnitIsUnit(u, "player") then
				list[#list + 1] = u
				if db.clPets then list[#list + 1] = "raidpet" .. i end
			end
		end
	elseif IsInGroup() then
		for i = 1, GetNumSubgroupMembers() do
			list[#list + 1] = "party" .. i
			if db.clPets then list[#list + 1] = "partypet" .. i end
		end
	end
	return list
end

-- Removable debuffs on unit: { count, icon, type, names = {} } or nil. Secret types are skipped.
local function Scan(unit)
	if not types or not UnitExists(unit) or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then return nil end
	local ignore = ns.db.clIgnore or {}
	local found
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
		if not ok or not a then break end
		local dtype = Clean(a.dispelName)
		if dtype and types[dtype] then
			local name = Clean(a.name)
			if not (name and ignore[strlower(name)]) then
				found = found or { count = 0, names = {} }
				found.count = found.count + 1
				found.icon = found.icon or Clean(a.icon)
				found.type = found.type or dtype
				found.names[#found.names + 1] = (name or "?") .. " |cff999999(" .. dtype .. ")|r"
			end
		end
	end
	return found
end

local function ShouldShow()
	if ns.unlocked then return true end
	return ns.db.clEnabled and spell ~= nil and IsInGroup()
end

local function Rows() return math.max(1, math.min(MAX_ROWS, ns.db.clRows or 5)) end

-- Visuals for one row; safe in combat (no Show/Hide/attribute calls).
-- EnableMouse is not protected, so standby rows (mapped but nothing to cleanse) never take clicks.
local function Paint(row, unit, d)
	if not unit then row:SetAlpha(0); row:EnableMouse(false); row.unit = nil; return end
	row.unit = unit
	if not d then row:SetAlpha(0); row:EnableMouse(false); row.data = nil; return end
	row.data = d
	row:EnableMouse(not ns.unlocked)
	local _, class = UnitClass(unit)
	local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	local name = Clean(UnitName(unit)) or unit
	row.name:SetText(name)
	if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) else row.name:SetTextColor(0.8, 0.8, 0.8) end
	row.icon:SetTexture(d.icon or 136207)
	row.count:SetText(d.count > 1 and ("x" .. d.count) or "")
	local c = TYPE_COLOR[d.type] or { 0.4, 0.4, 0.4 }
	row.bg:SetColorTexture(c[1], c[2], c[3], 0.45)
	row:SetAlpha(InRange(unit) and 1 or 0.35)
end

local function Map(row, unit)
	if InCombatLockdown() then return end
	if unit and spell then
		row:SetAttribute("type", "spell")
		row:SetAttribute("spell", spell)
		row:SetAttribute("unit", unit)
	else
		row:SetAttribute("type", nil)
		row:SetAttribute("spell", nil)
		row:SetAttribute("unit", nil)
	end
end

local function Placeholder()
	local sample = {
		{ "Partymember", "WARRIOR", 136207, "Poison", 1 }, { "Healer", "PRIEST", 136118, "Magic", 2 }, { "Ranged", "MAGE", 136127, "Disease", 1 },
	}
	for i, row in ipairs(rows) do
		local s = sample[i]
		if s and i <= Rows() then
			row.name:SetText(s[1])
			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[s[2]]
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) end
			row.icon:SetTexture(s[3])
			row.count:SetText(s[5] > 1 and ("x" .. s[5]) or "")
			local c = TYPE_COLOR[s[4]]
			row.bg:SetColorTexture(c[1], c[2], c[3], 0.45)
			row:SetAlpha(1); row.data = nil
		else
			row:SetAlpha(0); row.data = nil
		end
	end
	title:SetText("Cleanse")
end

function M:Update()
	if not frame then return end
	local db = ns.db
	local combat = InCombatLockdown()
	if ns.unlocked and not combat then
		frame:Show(); frame:SetAlpha(1)
		-- placeholders must not cast or eat the drag: clear the secure action and mouse on every row
		for i, row in ipairs(rows) do
			Map(row, nil)
			row:EnableMouse(false)
			row.unit, row.data = nil, nil
			row:SetShown(i <= Rows())
		end
		frame:SetHeight(TITLE_H + Rows() * (ROW_H + 2) + 6)
		Placeholder()
		return
	end
	if not combat then
		if not ShouldShow() then
			frame:Hide()
			wipe(afflicted)
			return
		end
		frame:Show()
	elseif not frame:IsShown() then
		return
	end

	-- full scan: which units carry something removable (also drives the sound)
	local units, hits, now = Units(), {}, {}
	local total = 0
	for _, u in ipairs(units) do
		local d = Scan(u)
		hits[u] = d
		if d then
			total = total + 1
			now[u] = true
			if not afflicted[u] and db.clSound and spell then
				PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
			end
		end
	end
	afflicted = now

	local n = Rows()
	if not combat then
		-- re-map: afflicted first, then standby units, then nothing
		local order = {}
		for _, u in ipairs(units) do if hits[u] then order[#order + 1] = u end end
		for _, u in ipairs(units) do if not hits[u] then order[#order + 1] = u end end
		for i, row in ipairs(rows) do
			local u = i <= n and order[i] or nil
			Map(row, u)
			row:SetShown(i <= n)
			Paint(row, u, u and hits[u])
		end
		frame:SetHeight(TITLE_H + n * (ROW_H + 2) + 6)
	else
		for _, row in ipairs(rows) do
			if row:IsShown() then Paint(row, row.unit, row.unit and hits[row.unit]) end
		end
	end

	-- header: how many are afflicted, and how many have no row right now
	local shown = 0
	for _, row in ipairs(rows) do if row:IsShown() and row.data then shown = shown + 1 end end
	local text = spell or "Cleanse"
	if total > shown then text = text .. ("  |cffff5555+%d more|r"):format(total - shown) end
	if combat and total > shown then text = text .. " |cff999999(fixed in combat)|r" end
	title:SetText(text)
	frame:SetAlpha(total > 0 and 1 or 0) -- alpha, not Hide: the rows must stay usable in combat
end

function M:Init()
	PickSpell()
	frame = CreateFrame("Frame", "LightboundCleanseFrame", UIParent, "BackdropTemplate")
	frame:SetSize(ROW_W, TITLE_H + 5 * (ROW_H + 2) + 6)
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
	ns.MakeMovable(frame, "clPoint")
	ns.ApplyPoint(frame, "clPoint")

	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", "LightboundCleanseRow" .. i, frame, "SecureActionButtonTemplate")
		row:SetSize(ROW_W - 8, ROW_H)
		row:SetPoint("TOPLEFT", 4, -TITLE_H - (i - 1) * (ROW_H + 2))
		row:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
		row:SetAttribute("checkselfcast", false)
		row:SetAttribute("checkfocuscast", false)
		row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_H - 4, ROW_H - 4); row.icon:SetPoint("LEFT", 2, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetFont("Fonts\\ARIALN.TTF", 13, ""); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.name:SetPoint("RIGHT", -28, 0); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
		row.count = row:CreateFontString(nil, "OVERLAY")
		row.count:SetFont("Fonts\\ARIALN.TTF", 13, "OUTLINE"); row.count:SetPoint("RIGHT", -6, 0)
		row.count:SetTextColor(1, 0.82, 0)
		local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("OnEnter", function(self)
			local d = self.data
			if not d or ns.unlocked or not self.unit then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(Clean(UnitName(self.unit)) or self.unit)
			for _, line in ipairs(d.names) do GameTooltip:AddLine(line, 1, 1, 1) end
			GameTooltip:AddLine("Click: " .. (spell or "Cleanse"), 0.6, 0.9, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:SetAlpha(0)
		row:Hide()
		rows[i] = row
	end

	local function Schedule()
		if dirty then return end
		dirty = true
		C_Timer.After(0, function() dirty = false; M:Update() end)
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
		"PLAYER_REGEN_DISABLED", "SPELLS_CHANGED", "UNIT_PET" }) do
		ev:RegisterEvent(e)
	end
	ev:RegisterEvent("UNIT_AURA")
	ev:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_AURA" then
			if not unit or not (unit == "player" or unit == "pet" or unit:match("^party%d$") or unit:match("^raid%d+$")
				or unit:match("^partypet%d$") or unit:match("^raidpet%d+$")) then return end
			Schedule()
			return
		elseif event == "SPELLS_CHANGED" then
			if not PickSpell() then return end
		end
		Schedule()
	end)
	C_Timer.NewTicker(0.5, function() if frame:IsShown() then M:Update() end end) -- range changes without events
	M:Update()
end

-- Options ----------------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Cleanse", "Group members with a debuff you can remove. Click a row to cleanse. In combat the rows keep the units they had when it started.")
	local W = UI.CONTENT_W
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "clEnabled", "Show the cleanse list", "Only while grouped, and only when you know Cleanse or Purify.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "clSound", "Sound when someone new needs cleansing")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "clPets", "Include pets")) + 6)
	p:Add(select(2, UI.Slider(p, p.y, "Rows", "clRows", 1, MAX_ROWS, 1, "")) + 8)
	p:Add(UI.Section(p, p.y, "Ignored debuffs") + 6)
	local list = UI.Font(p, 13, UI.C.text)
	list:SetPoint("TOPLEFT", 0, p.y); list:SetPoint("RIGHT", p, "RIGHT")
	list:SetWordWrap(true)
	p:Add(40)
	local hint = UI.Font(p, 12, UI.C.dim)
	hint:SetPoint("TOPLEFT", 0, p.y); hint:SetPoint("RIGHT", p, "RIGHT")
	hint:SetText("/lb ignore <debuff name> adds or removes a debuff from this list. Rows with only ignored debuffs are not shown.")
	p:Add(30)
	p:SetScript("OnShow", function()
		local names = {}
		for n in pairs(ns.db.clIgnore or {}) do names[#names + 1] = n end
		table.sort(names)
		list:SetText(#names > 0 and table.concat(names, ", ") or "|cff999999none|r")
	end)
end

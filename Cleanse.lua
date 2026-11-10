-- Cleanse: group members (and pets) carrying a debuff you can remove, one click each, plus a
-- mouseover cleanse key. Cleanse removes Poison, Disease and Magic; Purify only Poison and
-- Disease. Whichever you know is used, Cleanse preferred.
--
-- Two presentations share one scanner (clMode):
--  * Grid (default): Decursive-style micro unit frames, one fixed cell per group member. Cells are
--    secure buttons (type=spell, unit=<unitID>) laid out OUT of combat only (Layout). In combat
--    only colours, alpha, icon and text change; a roster change marks the layout dirty and it is
--    rebuilt on PLAYER_REGEN_ENABLED. Clicking any cell casts on that unit, afflicted or not,
--    which still works when aura data is secret.
--  * List: rows mapped out of combat, afflicted units first, then the rest of the group as
--    invisible standby rows. The mapping is frozen in combat; alpha does the hiding.
--
-- The key (clKey) clicks a hidden macro button: cleanse the mouseover unit (a cell, a row, any
-- unit frame), else the target. Override bindings are applied out of combat, deferred otherwise.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = _G.issecretvalue or function() return false end
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>" -- placeholder the client returns for hidden names
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end
local function CleanName(v) v = Clean(v); if v == RESTRICTED then return nil end return v end
local function Flag(fn, unit) local ok, v = pcall(fn, unit); return ok and Clean(v) or false end
local utf8sub = string.utf8sub or string.sub

local ROW_W, ROW_H, TITLE_H, MAX_ROWS, GAP = 190, 22, 18, 10, 2
local FONT = "Fonts\\ARIALN.TTF"
local KEY_BUTTON = "LightboundCleanseKeyButton"
local frame, title, rows, cells = nil, nil, {}, {}
local keyBtn, keyOwner, keyPending
local spell, types                   -- "Cleanse"/"Purify" and the debuff types it removes
local afflicted = {}                 -- unit -> true from the last scan (for the sound)
local laid = {}                      -- units with a grid cell, in cell order (from the last Layout)
local layoutDirty = false            -- a Layout was requested in combat
local dirty, needLayout = false, false

local TYPE_COLOR = {
	Poison = { 0.0, 0.6, 0.0 }, Disease = { 0.6, 0.4, 0.0 }, Magic = { 0.2, 0.6, 1.0 },
}
local CLEAN_BG = { 0.16, 0.16, 0.16, 0.85 }

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

local function Mode() return ns.db.clMode == "List" and "List" or "Grid" end
local function Rows() return math.max(1, math.min(MAX_ROWS, ns.db.clRows or 5)) end
local function PerRow() return math.max(1, math.min(10, ns.db.clPerRow or 5)) end
local function CellSize() return math.max(14, math.min(40, ns.db.clCell or 22)) end

-- Spell range first, UnitInRange as the fallback; unreadable means in range.
local function InRange(unit)
	if UnitIsUnit(unit, "player") then return true end
	local ok, r = pcall(function()
		if C_Spell and C_Spell.IsSpellInRange then return C_Spell.IsSpellInRange(spell, unit) end
		return IsSpellInRange(spell, unit)
	end)
	if ok and not isSecret(r) and r ~= nil then return r == true or r == 1 end
	if not UnitInRange then return true end
	local ok2, inR, checked = pcall(UnitInRange, unit)
	if not ok2 or isSecret(inR) or inR == nil then return true end
	if Clean(checked) == false then return true end
	return inR and true or false
end

-- Group units in display order: party = player, party1-4; raid = raid1..N by subgroup then index
-- (one row per raid group at 5 per row). Pets follow the players.
local function Units()
	local db, list, pets = ns.db, {}, {}
	if IsInRaid() then
		local order = {}
		for i = 1, GetNumGroupMembers() do
			local ok, _, _, sub = pcall(GetRaidRosterInfo, i)
			order[#order + 1] = { i = i, sub = (ok and Clean(sub)) or 9 }
		end
		table.sort(order, function(a, b) if a.sub ~= b.sub then return a.sub < b.sub end return a.i < b.i end)
		for _, o in ipairs(order) do
			list[#list + 1] = "raid" .. o.i
			if db.clPets then pets[#pets + 1] = "raidpet" .. o.i end
		end
	else
		list[1] = "player"
		if db.clPets then pets[1] = "pet" end
		for i = 1, GetNumSubgroupMembers() do
			list[#list + 1] = "party" .. i
			if db.clPets then pets[#pets + 1] = "partypet" .. i end
		end
	end
	for _, p in ipairs(pets) do list[#list + 1] = p end
	return list
end

-- "gone" (no such unit), "down" (offline, dead) or "ok".
local function Status(unit)
	if not Flag(UnitExists, unit) then return "gone" end
	if not Flag(UnitIsConnected, unit) or Flag(UnitIsDeadOrGhost, unit) then return "down" end
	return "ok"
end

-- Removable debuffs on unit: { count, icon, type, names = {} } or nil. Secret types are skipped.
local function Scan(unit)
	if not types or Status(unit) ~= "ok" then return nil end
	local ignore = ns.db.clIgnore or {}
	local found
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
		if not ok or not a then break end
		local dtype = Clean(a.dispelName)
		if dtype and types[dtype] then
			local name = CleanName(a.name)
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

local function ClassColor(unit)
	local ok, _, class = pcall(UnitClass, unit)
	class = ok and Clean(class)
	local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if cc then return cc.r, cc.g, cc.b end
	return 0.8, 0.8, 0.8
end

local function Map(btn, unit)
	if InCombatLockdown() then return end
	if unit and spell then
		btn:SetAttribute("type", "spell")
		btn:SetAttribute("spell", spell)
		btn:SetAttribute("unit", unit)
	else
		btn:SetAttribute("type", nil)
		btn:SetAttribute("spell", nil)
		btn:SetAttribute("unit", nil)
	end
end

local function Tooltip(self)
	if ns.unlocked or not self.unit then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local r, g, b = ClassColor(self.unit)
	GameTooltip:AddLine(CleanName(UnitName(self.unit)) or self.unit, r, g, b)
	local d = self.data
	if d then
		for _, line in ipairs(d.names) do GameTooltip:AddLine(line, 1, 1, 1) end
	else
		GameTooltip:AddLine("Nothing to cleanse", 0.6, 0.6, 0.6)
	end
	if self.oor then GameTooltip:AddLine("Out of range", 1, 0.3, 0.3) end
	GameTooltip:AddLine("Click: " .. (spell or "Cleanse"), 0.6, 0.9, 0.6)
	GameTooltip:Show()
end

-- List rows -----------------------------------------------------------------------------
-- Visuals for one row; safe in combat (no Show/Hide/attribute calls).
-- EnableMouse is not protected, so standby rows (mapped but nothing to cleanse) never take clicks.
local function PaintRow(row, unit, d)
	if not unit then row:SetAlpha(0); row:EnableMouse(false); row.unit = nil; return end
	row.unit = unit
	if not d then row:SetAlpha(0); row:EnableMouse(false); row.data = nil; return end
	row.data = d
	row:EnableMouse(not ns.unlocked)
	row.name:SetText(CleanName(UnitName(unit)) or unit)
	row.name:SetTextColor(ClassColor(unit))
	row.icon:SetTexture(d.icon or 136207)
	row.count:SetText(d.count > 1 and ("x" .. d.count) or "")
	local c = TYPE_COLOR[d.type] or { 0.4, 0.4, 0.4 }
	row.bg:SetColorTexture(c[1], c[2], c[3], 0.45)
	row.oor = ns.db.clRange and not InRange(unit)
	row:SetAlpha(row.oor and 0.4 or 1)
end

local function MakeRow(i)
	local row = CreateFrame("Button", "LightboundCleanseRow" .. i, frame, "SecureActionButtonTemplate")
	row:SetSize(ROW_W - 8, ROW_H)
	row:SetPoint("TOPLEFT", 4, -TITLE_H - (i - 1) * (ROW_H + GAP))
	row:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	row:SetAttribute("checkselfcast", false)
	row:SetAttribute("checkfocuscast", false)
	row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ROW_H - 4, ROW_H - 4); row.icon:SetPoint("LEFT", 2, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.name = row:CreateFontString(nil, "OVERLAY")
	row.name:SetFont(FONT, 13, ""); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", -28, 0); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
	row.count = row:CreateFontString(nil, "OVERLAY")
	row.count:SetFont(FONT, 13, "OUTLINE"); row.count:SetPoint("RIGHT", -6, 0)
	row.count:SetTextColor(1, 0.82, 0)
	local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
	row:SetScript("OnEnter", function(self) if self.data then Tooltip(self) end end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetAlpha(0)
	row:Hide()
	return row
end

-- Grid cells ----------------------------------------------------------------------------
local function Edge(cell, p1, p2, w, h)
	local t = cell:CreateTexture(nil, "OVERLAY", nil, 2)
	t:SetColorTexture(1, 1, 1, 1)
	t:SetPoint(p1); t:SetPoint(p2)
	if w then t:SetWidth(w) else t:SetHeight(h) end
	return t
end

local function MakeCell(i)
	local cell = CreateFrame("Button", "LightboundCleanseCell" .. i, frame, "SecureActionButtonTemplate")
	cell:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	cell:SetAttribute("checkselfcast", false)
	cell:SetAttribute("checkfocuscast", false)
	cell.bg = cell:CreateTexture(nil, "BACKGROUND"); cell.bg:SetAllPoints()
	cell.icon = cell:CreateTexture(nil, "ARTWORK")
	cell.icon:SetPoint("TOPLEFT", 1, -1); cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cell.icon:Hide()
	cell.name = cell:CreateFontString(nil, "OVERLAY")
	cell.name:SetPoint("CENTER"); cell.name:SetWordWrap(false)
	cell.count = cell:CreateFontString(nil, "OVERLAY", nil)
	cell.count:SetPoint("BOTTOMRIGHT", -1, 0)
	cell.count:SetTextColor(1, 0.82, 0)
	cell.edges = {
		Edge(cell, "TOPLEFT", "TOPRIGHT", nil, 1), Edge(cell, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
		Edge(cell, "TOPLEFT", "BOTTOMLEFT", 1), Edge(cell, "TOPRIGHT", "BOTTOMRIGHT", 1),
	}
	cell.SetBorder = function(self, on) for _, e in ipairs(self.edges) do e:SetAlpha(on and 1 or 0) end end
	cell:SetBorder(false)
	local hl = cell:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.12)
	cell:SetScript("OnEnter", Tooltip)
	cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
	cell:Hide()
	return cell
end

-- Visuals for one cell; safe in combat. `best` marks the unit with the most debuffs.
local function PaintCell(cell, d, best)
	local unit, db = cell.unit, ns.db
	cell.data = d
	local status = Status(unit)
	if status == "gone" then
		cell.bg:SetColorTexture(unpack(CLEAN_BG)); cell.icon:Hide(); cell.count:SetText("")
		cell.name:SetText(""); cell:SetBorder(false); cell.oor = nil
		cell:SetAlpha(0.15)
		return
	end
	if db.clNames and CellSize() >= 26 then
		local name = CleanName(UnitName(unit))
		cell.name:SetText(name and utf8sub(name, 1, 3) or "")
		cell.name:SetTextColor(ClassColor(unit))
	else
		cell.name:SetText("")
	end
	if d then
		local c = TYPE_COLOR[d.type] or { 0.4, 0.4, 0.4 }
		cell.bg:SetColorTexture(c[1], c[2], c[3], 0.9)
		cell.icon:SetTexture(d.icon or 136207); cell.icon:Show()
		cell.count:SetText(d.count > 1 and d.count or "")
		cell:SetBorder(best)
	else
		cell.bg:SetColorTexture(unpack(CLEAN_BG)); cell.icon:Hide(); cell.count:SetText("")
		cell:SetBorder(false)
	end
	if status == "down" then cell.oor = nil; cell:SetAlpha(0.25); cell:SetBorder(false); return end
	cell.oor = db.clRange and not InRange(unit)
	cell:SetAlpha(cell.oor and 0.4 or 1)
end

-- Layout --------------------------------------------------------------------------------
local PLACEHOLDER = {
	{ "Partymember", "WARRIOR", 136207, "Poison", 1 }, { "Healer", "PRIEST", 136118, "Magic", 2 },
	{ "Ranged", "MAGE", 136127, "Disease", 1 }, { "Tank", "PALADIN" }, { "Rogue", "ROGUE" },
}

local function PlaceholderGrid()
	for i, cell in ipairs(cells) do
		local s = PLACEHOLDER[i]
		if s and cell:IsShown() then
			cell.name:SetText(ns.db.clNames and CellSize() >= 26 and s[1]:sub(1, 3) or "")
			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[s[2]]
			if cc then cell.name:SetTextColor(cc.r, cc.g, cc.b) end
			if s[3] then
				local c = TYPE_COLOR[s[4]]
				cell.bg:SetColorTexture(c[1], c[2], c[3], 0.9)
				cell.icon:SetTexture(s[3]); cell.icon:Show()
				cell.count:SetText(s[5] > 1 and s[5] or "")
			else
				cell.bg:SetColorTexture(unpack(CLEAN_BG)); cell.icon:Hide(); cell.count:SetText("")
			end
			cell:SetBorder(i == 2)
			cell:SetAlpha(1)
		end
	end
end

local function PlaceholderList()
	for i, row in ipairs(rows) do
		local s = PLACEHOLDER[i]
		if s and s[3] and i <= Rows() then
			row.name:SetText(s[1])
			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[s[2]]
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) end
			row.icon:SetTexture(s[3])
			row.count:SetText(s[5] > 1 and ("x" .. s[5]) or "")
			local c = TYPE_COLOR[s[4]]
			row.bg:SetColorTexture(c[1], c[2], c[3], 0.45)
			row:SetAlpha(1)
		else
			row:SetAlpha(0)
		end
		row.data = nil
	end
end

-- Positions, sizes and secure attributes. Out of combat only; in combat it is deferred to
-- PLAYER_REGEN_ENABLED.
function M:Layout()
	if not frame then return end
	if InCombatLockdown() then layoutDirty = true return end
	layoutDirty = false
	local grid = Mode() == "Grid"
	local placeholder = ns.unlocked
	-- list rows
	local n = (not grid) and Rows() or 0
	for i = 1, MAX_ROWS do
		local row = rows[i]
		if i <= n then
			if placeholder then Map(row, nil); row:EnableMouse(false); row.unit, row.data = nil, nil end
			row:Show()
		else
			Map(row, nil); row:EnableMouse(false); row.unit, row.data = nil, nil
			row:Hide()
		end
	end
	-- grid cells
	wipe(laid)
	local units = {}
	if grid then
		if placeholder then
			for i = 1, #PLACEHOLDER do units[i] = false end
		elseif ShouldShow() then
			units = Units()
		end
	end
	local size, per = CellSize(), PerRow()
	local fontSize = math.max(8, math.floor(size * 0.45))
	for i = 1, math.max(#units, #cells) do
		local u = units[i]
		local cell = cells[i]
		if u ~= nil and not cell then cell = MakeCell(i); cells[i] = cell end
		if cell then
			if u ~= nil then
				local col, row = (i - 1) % per, math.floor((i - 1) / per)
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", 4 + col * (size + GAP), -TITLE_H - row * (size + GAP))
				cell:SetSize(size, size)
				cell.name:SetFont(FONT, fontSize, "OUTLINE")
				cell.count:SetFont(FONT, fontSize, "OUTLINE")
				cell.unit, cell.data, cell.oor = u or nil, nil, nil
				Map(cell, u or nil)
				cell:EnableMouse(u and true or false)
				cell:Show()
				if u then laid[#laid + 1] = u end
			else
				Map(cell, nil); cell:EnableMouse(false); cell.unit, cell.data = nil, nil
				cell:Hide()
			end
		end
	end
	-- frame size
	if grid then
		local count = math.max(#units, 1)
		local cols = math.min(count, per)
		local rws = math.ceil(count / per)
		frame:SetSize(math.max(64, 8 + cols * (size + GAP) - GAP), TITLE_H + rws * (size + GAP) + 4)
	else
		frame:SetSize(ROW_W, TITLE_H + n * (ROW_H + GAP) + 6)
	end
end

-- Update --------------------------------------------------------------------------------
function M:Update()
	if not frame then return end
	local db = ns.db
	local combat = InCombatLockdown()
	local grid = Mode() == "Grid"
	if ns.unlocked and not combat then
		frame:Show(); frame:SetAlpha(1)
		title:SetText("Cleanse")
		if grid then PlaceholderGrid() else PlaceholderList() end
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
	local total, best, bestN = 0, nil, 0
	for _, u in ipairs(units) do
		local d = Scan(u)
		hits[u] = d or false
		if d then
			total = total + 1
			now[u] = true
			if d.count > bestN then best, bestN = u, d.count end
			if not afflicted[u] and db.clSound and spell then
				PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
			end
		end
	end
	afflicted = now

	local text = spell or "Cleanse"
	if grid then
		for i = 1, #laid do
			local cell = cells[i]
			local u = cell.unit
			local d = hits[u]
			if d == nil then d = Scan(u) end -- a unit that left the roster since the last Layout
			PaintCell(cell, d or nil, u == best)
		end
		if combat and layoutDirty then text = text .. " |cff999999(roster changed)|r" end
		title:SetText(text)
		frame:SetAlpha(1)
		return
	end

	-- list: re-map out of combat (afflicted first, then standby units), paint only in combat
	local n = Rows()
	if not combat then
		local order = {}
		for _, u in ipairs(units) do if hits[u] then order[#order + 1] = u end end
		for _, u in ipairs(units) do if not hits[u] then order[#order + 1] = u end end
		for i, row in ipairs(rows) do
			local u = i <= n and order[i] or nil
			Map(row, u)
			PaintRow(row, u, u and hits[u] or nil)
		end
	else
		for _, row in ipairs(rows) do
			if row:IsShown() then PaintRow(row, row.unit, row.unit and hits[row.unit] or nil) end
		end
	end
	local shown = 0
	for _, row in ipairs(rows) do if row:IsShown() and row.data then shown = shown + 1 end end
	if total > shown then text = text .. ("  |cffff5555+%d more|r"):format(total - shown) end
	if combat and total > shown then text = text .. " |cff999999(fixed in combat)|r" end
	title:SetText(text)
	frame:SetAlpha(total > 0 and 1 or 0) -- alpha, not Hide: the rows must stay usable in combat
end

-- Key -----------------------------------------------------------------------------------
local function ConfigureKey()
	if not keyBtn or InCombatLockdown() then return end
	if spell then
		keyBtn:SetAttribute("type", "macro")
		keyBtn:SetAttribute("macrotext", ("/cast [@mouseover,help,nodead][help,nodead] %s"):format(spell))
	else
		keyBtn:SetAttribute("type", nil)
		keyBtn:SetAttribute("macrotext", nil)
	end
end

function ns.ApplyCleanseKey()
	if not keyOwner then return end
	if InCombatLockdown() then keyPending = true return end
	ConfigureKey()
	ClearOverrideBindings(keyOwner)
	if ns.db.clKey and spell then
		SetOverrideBindingClick(keyOwner, true, ns.db.clKey, KEY_BUTTON, "LeftButton")
	end
	keyPending = false
end

-- Init ----------------------------------------------------------------------------------
-- The frame is anchored by its top-left corner so it grows down/right without moving.
local function SaveTopLeft(self)
	local l, t = self:GetLeft(), self:GetTop()
	if not l or not t then return end
	ns.db.clPoint = { "TOPLEFT", "UIParent", "BOTTOMLEFT", l, t }
end

function M:Init()
	PickSpell()
	frame = CreateFrame("Frame", "LightboundCleanseFrame", UIParent, "BackdropTemplate")
	frame:SetSize(ROW_W, TITLE_H + 5 * (ROW_H + GAP) + 6)
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
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveTopLeft(self) end)
	if ns.db.clPoint[1] ~= "TOPLEFT" then SaveTopLeft(frame); ns.ApplyPoint(frame, "clPoint") end -- pre-grid position

	for i = 1, MAX_ROWS do rows[i] = MakeRow(i) end

	keyOwner = CreateFrame("Frame")
	keyBtn = CreateFrame("Button", KEY_BUTTON, UIParent, "SecureActionButtonTemplate")
	keyBtn:SetSize(1, 1)
	keyBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100) -- off screen; used only through the key
	keyBtn:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	keyBtn:SetAttribute("checkselfcast", false)
	keyBtn:SetAttribute("checkfocuscast", false)

	local function Schedule(layout)
		if layout then needLayout = true end
		if dirty then return end
		dirty = true
		C_Timer.After(0, function()
			dirty = false
			if needLayout then needLayout = false; M:Layout() end
			M:Update()
		end)
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
			Schedule(false)
			return
		elseif event == "SPELLS_CHANGED" then
			if not PickSpell() then return end
			ns.ApplyCleanseKey()
		elseif event == "PLAYER_REGEN_ENABLED" then
			if keyPending then ns.ApplyCleanseKey() end
		elseif event == "PLAYER_REGEN_DISABLED" then
			Schedule(false)
			return
		end
		Schedule(true) -- roster, pets, zoning, combat end, spell set: positions may change
	end)
	C_Timer.NewTicker(0.5, function() if frame:IsShown() then M:Update() end end) -- range changes without events
	ns.ApplyCleanseKey()
	M:Layout()
	M:Update()
end

-- Options ----------------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Cleanse", "Who needs a Cleanse. Click a cell or row to cast. Positions only change out of combat.")
	local W = UI.CONTENT_W
	local half = math.floor(W / 2)
	p:Add(UI.Section(p, p.y, "Show") + 2)
	UI.DBToggle(p, 0, p.y, half, "clEnabled", "Show the cleanse frame")
	UI.DBToggle(p, half, p.y, half, "clPets", "Include pets")
	p:Add(28)
	UI.DBToggle(p, 0, p.y, half, "clRange", "Dim players out of range")
	UI.DBToggle(p, half, p.y, half, "clSound", "Sound when someone new needs it")
	p:Add(30)
	p:Add(UI.Section(p, p.y, "Layout") + 2)
	p:Add(select(2, UI.Cycle(p, p.y, "Grid or list", { "Grid", "List" },
		function() return ns.db.clMode == "List" and "List" or "Grid" end,
		function(v) ns.db.clMode = v end,
		function() return ns.db.clMode == "List" and "one row per afflicted unit" or "one cell per group member" end)) + 2)
	p:Add(select(2, UI.Slider(p, p.y, "Grid: cells per row", "clPerRow", 1, 10, 1, "")))
	p:Add(select(2, UI.Slider(p, p.y, "Grid: cell size", "clCell", 14, 40, 1, " px")))
	p:Add(select(2, UI.Slider(p, p.y, "List: rows", "clRows", 1, MAX_ROWS, 1, "")))
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "clNames", "Grid: show names in the cells  (three letters, from 26 px up)")) + 4)
	p:Add(UI.Section(p, p.y, "Key") + 2)
	p:Add(select(2, UI.KeyButton(p, p.y, "Cleanse key", "clKey", function() ns.ApplyCleanseKey() end, "cleanse key")) - 8)
	local note = UI.Font(p, 12, UI.C.dim)
	note:SetPoint("TOPLEFT", 0, p.y); note:SetPoint("RIGHT", p, "RIGHT")
	note:SetText("Cleanses the player under your mouse (a grid cell, the list, or any raid frame), else your target. Works in combat.")
	p:Add(32)
	local list = UI.Font(p, 12, UI.C.dim)
	list:SetPoint("TOPLEFT", 0, p.y); list:SetPoint("RIGHT", p, "RIGHT")
	list:SetWordWrap(true)
	p:Add(24)
	p:SetScript("OnShow", function()
		local names = {}
		for n in pairs(ns.db.clIgnore or {}) do names[#names + 1] = n end
		table.sort(names)
		list:SetText("Ignored debuffs: |cffffffff" .. (#names > 0 and table.concat(names, ", ") or "none")
			.. "|r   (/lb ignore <debuff name> adds or removes one)")
	end)
end

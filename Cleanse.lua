-- Cleanse: group members (and pets) carrying a debuff you can remove, one click each, plus a
-- mouseover cleanse key. Cleanse removes Poison, Disease and Magic; Purify only Poison and
-- Disease. Whichever you know is used, Cleanse preferred.
--
-- Two presentations share one scanner (clMode):
--  * Grid (default): Decursive-style micro unit frames, one cell per group member, driven by two
--    SecureGroupHeaders (players, pets). Blizzard's secure code creates the cells, assigns their
--    unit attribute and lays them out, in combat too, so joins, leaves and raid-ID shifts never
--    leave a cell pointing at the wrong person. Clicking a cell casts on its unit, afflicted or
--    not, which still works when aura data is secret.
--    The debuff itself (type colour, icon, stacks) is drawn by Blizzard: every cell carries a
--    native AuraContainer (CustomAuraContainerTemplate) with one HARMFUL slot filtered to the
--    dispel types the known spell removes. Addon Lua cannot read aura data while restrictions
--    are active (combat, encounters), the container can. Its AuraButton is configured once in
--    initializeFrame (afterwards it is forbidden to us): a white texture tinted per dispel type
--    through a colour curve, the icon inset on top, the stack count. The container follows the
--    cell's unit attribute through an OnAttributeChanged hook. We still paint, from Lua, what
--    stays readable: class-coloured names, range/dead/offline alpha, the "best" border (only
--    when the scan can see it). Without AuraContainer support (or if any call fails) the cell
--    falls back to painting the scan result itself, as before.
--  * List: rows mapped out of combat, afflicted units first, then the rest of the group as
--    invisible standby rows. The mapping is frozen in combat; alpha does the hiding. The list,
--    the tooltips, the sound and the afflicted count come from the Lua scan, so in combat they
--    only know what the client still lets addons read.
--
-- The key (clKey) clicks a hidden macro button: cleanse the mouseover unit (a cell, a row, any
-- unit frame), else the target. Override bindings are applied out of combat, deferred otherwise.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = ns.IsSecret -- see Core.lua
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>" -- placeholder the client returns for hidden names
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end
local function CleanName(v) v = Clean(v); if v == RESTRICTED then return nil end return v end
local function Flag(fn, unit) local ok, v = pcall(fn, unit); return ok and Clean(v) or false end
local utf8sub = string.utf8sub or string.sub

local ROW_W, ROW_H, TITLE_H, MAX_ROWS, GAP = 198, 22, 24, 10, 2
local INSET = 8 -- room between the frame edge and the cells/rows (and the bottom)
local FONT = "Fonts\\ARIALN.TTF"
local KEY_BUTTON = "LightboundCleanseKeyButton"
local frame, title, rows = nil, nil, {}
local header, petHeader              -- SecureGroupHeader (players) and SecureGroupPetHeader (pets)
local MAX_CELLS = 40                 -- players or pets one header can hold (pre-created out of combat)
local placeholders = {}              -- plain cells drawn while the frames are unlocked
local keyBtn, keyOwner, keyPending
local spell, types                   -- "Cleanse"/"Purify" and the debuff types it removes
local afflicted = {}                 -- unit -> true from the last scan (for the sound)
local hidden = {}                    -- unit -> true when the last scan met debuffs it could not read
local auraSupport                    -- nil = untested, true/false = native AuraContainer usable
local dispelCurve                    -- dispel type ID -> colour for the native cells (false = unavailable)
local applied = {}                   -- header configuration from the last Layout
local layoutNotified = false         -- told the user a Layout is waiting for combat to end
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

-- Grid needs the secure header; without it (template missing) the list is all there is.
local wantMode = function() return (ns.db.clMode == "List" or not header) and "List" or "Grid" end
local laidOut -- the mode the frames were last laid out in; Update paints that one until Layout can run again
local function Mode() return laidOut or wantMode() end
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

-- Group units in display order: party = player, party1-4; raid = raid1..N by subgroup then index.
-- Pets follow the players. Drives the scan, the sound and the list; the grid cells get their
-- units from the secure headers.
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

-- Removable debuffs on unit: { count, icon, type, names = {} } or nil. Secret types are skipped
-- (and remembered in hidden[unit], so the tooltip can say why it knows nothing).
local LearnIgnored -- below, with the native aura display (Scan feeds it ignored spell IDs)
local function Scan(unit)
	hidden[unit] = nil
	if not types or Status(unit) ~= "ok" then return nil end
	local ignore = ns.db.clIgnore or {}
	local found
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
		if not ok or not a then break end
		if isSecret(a.dispelName) then hidden[unit] = true end
		local dtype = Clean(a.dispelName)
		if dtype and types[dtype] then
			local name = CleanName(a.name)
			if name and ignore[strlower(name)] then
				LearnIgnored(strlower(name), Clean(a.spellId))
			else
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
	return ns.db.clEnabled and spell ~= nil and (IsInGroup() or ns.db.clSolo)
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
		-- restricted: the cell's native display may show a debuff the scan cannot read
		GameTooltip:AddLine(hidden[self.unit] and "Debuff details hidden right now" or "Nothing to cleanse", 0.6, 0.6, 0.6)
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
	row:SetSize(ROW_W - INSET * 2, ROW_H)
	row:SetPoint("TOPLEFT", INSET, -TITLE_H - (i - 1) * (ROW_H + GAP))
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
-- The secure headers create the cells (SecureActionButtonTemplate, named <header>UnitButtonN) and
-- give them their unit. Visuals are added here the first time a cell is seen, out of combat.
-- Layers, bottom to top: cell bg (clean grey, or the type colour in the fallback), the native
-- AuraContainer (cell level + 2), then cell.top (+ 6) with the name and the "best" border, so
-- the native icon never covers them.
local function Edge(parent, p1, p2, w, h)
	local t = parent:CreateTexture(nil, "OVERLAY", nil, 2)
	t:SetColorTexture(1, 1, 1, 1)
	t:SetPoint(p1); t:SetPoint(p2)
	if w then t:SetWidth(w) else t:SetHeight(h) end
	return t
end

local function SetFonts(cell, size)
	local fontSize = math.max(8, math.floor(size * 0.45))
	cell.name:SetFont(FONT, fontSize, "OUTLINE")
	cell.count:SetFont(FONT, fontSize, "OUTLINE")
	-- the native count belongs to Blizzard once registered; it may refuse while auras are secret
	if cell.auraCount then pcall(cell.auraCount.SetFont, cell.auraCount, FONT, fontSize, "OUTLINE") end
end

-- Native aura display ---------------------------------------------------------------------
-- Dispel types the known spell removes, as the container's candidate filter wants them.
-- The ignore list is by name, but the container filters by spell ID: the IDs of ignored debuffs are
-- learned from scans while auras are readable (db.clIgnoreIDs[name] = { [id] = true }). The client
-- only honours excludeSpellIDs for spells that are never secret as auras.
local NEVER_SECRET = Enum and Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret or 0
local function IgnoredIDs()
	local ids, list = {}, {}
	local names, learned = ns.db.clIgnore or {}, ns.db.clIgnoreIDs or {}
	for name, set in pairs(learned) do
		if names[name] then
			for id in pairs(set) do
				local ok, level = true, NEVER_SECRET
				if C_Secrets and C_Secrets.GetSpellAuraSecrecy then ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, id) end
				if ok and not isSecret(level) and level == NEVER_SECRET and not ids[id] then
					ids[id] = true; list[#list + 1] = id
				end
			end
		end
	end
	table.sort(list)
	return list
end

local function TypeFilters()
	local t = {}
	for k in pairs(types or {}) do t[k] = true end -- no spell: an empty set shows nothing
	local f = { includeDispelTypes = t }
	local ex = IgnoredIDs()
	if #ex > 0 then
		-- the filter wants a set keyed by spell ID ({ [id] = true }), not a list
		f.excludeSpellIDs = {}
		for _, id in ipairs(ex) do f.excludeSpellIDs[id] = true end
	end
	return f
end

local function TypesKey()
	if not types then return "" end
	return (types.Magic and "M" or "") .. (types.Poison and "P" or "") .. (types.Disease and "D" or "")
		.. ":" .. table.concat(IgnoredIDs(), ",")
end

local RefreshAuraFilters -- defined below the headers; called when the ignore list changes
LearnIgnored = function(name, spellID)
	if not spellID then return end
	ns.db.clIgnoreIDs = ns.db.clIgnoreIDs or {}
	local set = ns.db.clIgnoreIDs[name]
	if set and set[spellID] then return end
	ns.db.clIgnoreIDs[name] = set or {}
	ns.db.clIgnoreIDs[name][spellID] = true
	if RefreshAuraFilters then RefreshAuraFilters() end
end

-- Dispel type ID -> colour, evaluated by Blizzard for each aura (the type itself stays secret).
-- IDs: Magic 1, Curse 2, Disease 3, Poison 4, Enrage 9, Bleed 11. Step curve: each point holds
-- until the next, so the types we never remove get explicit transparent points.
local function Curve()
	if dispelCurve == nil then
		local ok, curve = pcall(function()
			local c = C_CurveUtil.CreateColorCurve()
			c:SetType(Enum.LuaCurveType.Step)
			local clear = CreateColor(0, 0, 0, 0)
			local function Col(t) local v = TYPE_COLOR[t]; return CreateColor(v[1], v[2], v[3], 0.9) end
			c:AddPoint(0, clear)
			c:AddPoint(1, Col("Magic"))
			c:AddPoint(2, clear) -- Curse
			c:AddPoint(3, Col("Disease"))
			c:AddPoint(4, Col("Poison"))
			c:AddPoint(5, clear) -- everything above, Enrage and Bleed included
			c:AddPoint(11, clear)
			return c
		end)
		dispelCurve = ok and curve or false
	end
	return dispelCurve or nil
end

-- Runs once, inside AddAuraSlot: the only moment the AuraButton is ours to configure. Its
-- regions must be its own descendants; anchoring to the container (which fills the cell) makes
-- later cell resizes follow without touching the button again.
local function InitAuraButton(cell, c, ab)
	ab:EnableMouse(false) -- clicks belong to the secure cell
	ab:ClearAllPoints(); ab:SetAllPoints(c)
	local bg = ab:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(ab)
	bg:SetColorTexture(1, 1, 1, 1) -- white, tinted per dispel type by Blizzard
	local opts = {
		showWhenHarmful = true, showWithoutDispelType = false,
		style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
	}
	opts.customDispelColorCurve = Curve() -- without it Blizzard's own debuff colours apply
	ab:ClearDispelTypeTextures()
	ab:AddDispelTypeTexture(bg, opts)
	local icon = ab:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1) -- type colour shows as a frame
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ab:SetIcon(icon)
	local count = ab:CreateFontString(nil, "OVERLAY")
	count:SetFont(FONT, math.max(8, math.floor(CellSize() * 0.45)), "OUTLINE")
	count:SetPoint("BOTTOMRIGHT", -1, 0)
	count:SetTextColor(1, 0.82, 0)
	ab:SetApplicationCount(count) -- the aura's stacks (the fallback showed the number of debuffs)
	cell.auraCount = count
end

-- Points the container at the cell's unit. Disabling first clears the slot, so the old
-- unit's debuff never shows on the new one. Called from the attribute hook, in combat too.
local function SetAuraUnit(cell, unit)
	local c = cell.aura
	if not c then return end
	if type(unit) ~= "string" or unit == "" then unit = "none" end
	if cell.auraUnit == unit then return end -- the header re-sets attributes on every layout
	cell.auraUnit = unit
	pcall(c.SetEnabled, c, false)
	pcall(c.SetUnit, c, unit)
	pcall(c.SetEnabled, c, true)
end

-- Feature detection, once: the template lives in a load-on-demand Blizzard addon.
local function AuraSupported()
	if auraSupport == nil then
		if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn
			and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
			pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
		end
		auraSupport = (C_UnitAuras ~= nil and C_CurveUtil ~= nil and CreateColor ~= nil and Enum ~= nil
			and Enum.CustomAuraButtonDispelTypeTextureStyle ~= nil and Enum.LuaCurveType ~= nil) and true or false
	end
	return auraSupport
end

-- Gives a secure cell its native aura display. Out of combat only; any failure turns the
-- feature off for every cell, which then paint from the scan as before.
local function AttachAuras(cell)
	if cell.aura ~= nil or not AuraSupported() or InCombatLockdown() then return end
	local c
	local ok = pcall(function()
		c = CreateFrame("AuraContainer", nil, cell, "CustomAuraContainerTemplate")
		c:SetAllPoints(cell)
		c:SetFrameLevel(cell:GetFrameLevel() + 2)
		c:EnableMouse(false)
		c:AddAuraSlot("LB_CLEANSE", "HARMFUL", {
			sortMethod = 0, sortDirection = 0, -- AuraContainerSortMethod.Default, AuraContainerSortDirection.Normal
			candidateFilters = TypeFilters(),
			-- Blizzard runs this through securecall, which swallows errors: success is judged by
			-- cell.auraCount, set as its last step
			initializeFrame = function(ab) pcall(InitAuraButton, cell, c, ab) end,
		})
		c:SetUnit("none")
		c:SetShown(true)
		c:SetEnabled(true)
	end)
	if not ok or not cell.auraCount then
		if c then pcall(c.SetEnabled, c, false); pcall(c.Hide, c) end
		cell.aura, cell.auraCount = false, nil
		auraSupport = false
		return
	end
	cell.aura, cell.auraTypes = c, TypesKey()
	-- SecureGroupHeader reassigns "unit" in combat as well; follow it
	cell:HookScript("OnAttributeChanged", function(self, name, value)
		if name == "unit" then SetAuraUnit(self, value) end
	end)
	SetAuraUnit(cell, cell:GetAttribute("unit"))
end

-- New spell, new dispel types. Out of combat (ConfigureHeader).
local function UpdateAuraFilters(cell)
	local c = cell.aura
	if not c or cell.auraTypes == TypesKey() then return end
	if pcall(c.SetAuraSlotCandidateFilters, c, "LB_CLEANSE", TypeFilters()) then cell.auraTypes = TypesKey() end
end

-- every cell of both headers; out of combat only (filters are part of the layout)
local filtersPending = false
RefreshAuraFilters = function()
	if InCombatLockdown() then filtersPending = true return end
	filtersPending = false
	for _, h in ipairs({ header, petHeader }) do
		if h then for _, cell in ipairs({ h:GetChildren() }) do UpdateAuraFilters(cell) end end
	end
end
ns.CleanseIgnoreChanged = function() RefreshAuraFilters() end

local function Style(cell, secure)
	if secure then
		cell:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	end
	cell.bg = cell:CreateTexture(nil, "BACKGROUND"); cell.bg:SetAllPoints()
	cell.bg:SetColorTexture(unpack(CLEAN_BG))
	cell.icon = cell:CreateTexture(nil, "ARTWORK")
	cell.icon:SetPoint("TOPLEFT", 1, -1); cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cell.icon:Hide()
	cell.top = CreateFrame("Frame", nil, cell) -- above the native display; takes no mouse
	cell.top:SetAllPoints()
	cell.top:SetFrameLevel(cell:GetFrameLevel() + 6)
	cell.name = cell.top:CreateFontString(nil, "OVERLAY")
	cell.name:SetPoint("CENTER"); cell.name:SetWordWrap(false)
	cell.count = cell.top:CreateFontString(nil, "OVERLAY", nil)
	cell.count:SetPoint("BOTTOMRIGHT", -1, 0)
	cell.count:SetTextColor(1, 0.82, 0)
	local top = cell.top
	cell.edges = {
		Edge(top, "TOPLEFT", "TOPRIGHT", nil, 1), Edge(top, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
		Edge(top, "TOPLEFT", "BOTTOMLEFT", 1), Edge(top, "TOPRIGHT", "BOTTOMRIGHT", 1),
	}
	cell.SetBorder = function(self, on) for _, e in ipairs(self.edges) do e:SetAlpha(on and 1 or 0) end end
	cell:SetBorder(false)
	SetFonts(cell, CellSize())
	local hl = cell:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.12)
	cell:SetScript("OnEnter", Tooltip)
	cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if secure then AttachAuras(cell) end
end

-- Visuals for one cell; safe in combat. `best` marks the unit with the most debuffs. With the
-- native display active the debuff look is Blizzard's; Lua only adds name, border and alpha.
local function PaintCell(cell, d, best)
	local unit, db = cell.unit, ns.db
	cell.data = d
	local status = Status(unit)
	if db.clNames and CellSize() >= 26 then
		local name = CleanName(UnitName(unit))
		cell.name:SetText(name and utf8sub(name, 1, 3) or "")
		cell.name:SetTextColor(ClassColor(unit))
	else
		cell.name:SetText("")
	end
	if d and not cell.aura then
		local c = TYPE_COLOR[d.type] or { 0.4, 0.4, 0.4 }
		cell.bg:SetColorTexture(c[1], c[2], c[3], 0.9)
		cell.icon:SetTexture(d.icon or 136207); cell.icon:Show()
		cell.count:SetText(d.count > 1 and d.count or "")
	else
		cell.bg:SetColorTexture(unpack(CLEAN_BG)); cell.icon:Hide(); cell.count:SetText("")
	end
	cell:SetBorder(d and best or false)
	if status ~= "ok" then cell.oor = nil; cell:SetAlpha(0.25); cell:SetBorder(false); return end
	cell.oor = db.clRange and not InRange(unit)
	cell:SetAlpha(cell.oor and 0.4 or 1)
end

-- Paints every cell the header currently shows, reading the unit the header gave it (it may
-- have been reassigned in combat). Cells are pre-created and styled by ConfigureHeader; should
-- one still lack visuals, textures and font strings may be created in combat (not protected).
local function PaintHeader(h, hits, best)
	for _, cell in ipairs({ h:GetChildren() }) do
		if cell:IsShown() then
			if not cell.bg then pcall(Style, cell, true)
			elseif cell.aura == nil and not InCombatLockdown() then AttachAuras(cell) end -- styled in combat
			local unit = cell:GetAttribute("unit")
			cell.unit = unit
			if unit then
				local d = hits[unit]
				if d == nil then d = Scan(unit) end
				PaintCell(cell, d or nil, unit == best)
			end
		end
	end
end

-- Secure headers -------------------------------------------------------------------------
-- Runs in the restricted environment for every new cell, with self = the cell.
local function InitSnippet()
	local size = CellSize()
	local code = ("self:SetWidth(%d) self:SetHeight(%d)\n"):format(size, size)
	if spell then
		code = code .. ([[
			self:SetAttribute("type", "spell")
			self:SetAttribute("spell", %q)
			self:SetAttribute("checkselfcast", false)
			self:SetAttribute("checkfocuscast", false)
		]]):format(spell)
	end
	return code
end

-- Attributes the header reads once: who to show, in what order, and how to flow them. With
-- point LEFT the units run left to right and each new header "column" is a new row below.
local function MakeHeader(name, template)
	local ok, h = pcall(CreateFrame, "Frame", name, frame, template)
	if not ok or not h or not h:GetScript("OnEvent") then
		if ok and h then h:Hide() end
		return nil
	end
	h:Hide()
	h:SetAttribute("showParty", true)
	h:SetAttribute("showRaid", true)
	h:SetAttribute("showPlayer", true)
	h:SetAttribute("groupBy", "GROUP")
	h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
	h:SetAttribute("sortMethod", "INDEX")
	h:SetAttribute("point", "LEFT")
	h:SetAttribute("xOffset", GAP)
	h:SetAttribute("yOffset", 0)
	h:SetAttribute("columnAnchorPoint", "TOP")
	h:SetAttribute("template", "SecureActionButtonTemplate")
	return h
end

-- Cell size, spell and row length. Out of combat only. Existing cells are updated directly;
-- the snippet covers cells the header creates later. unitsPerColumn goes last: every attribute
-- change makes a visible header lay itself out again.
local function ConfigureHeader(h)
	local size, per = CellSize(), PerRow()
	h:SetAttribute("initialConfigFunction", InitSnippet())
	h:SetAttribute("showSolo", ns.db.clSolo and true or false)
	for _, cell in ipairs({ h:GetChildren() }) do
		cell:SetSize(size, size)
		cell:SetAttribute("type", spell and "spell" or nil)
		cell:SetAttribute("spell", spell)
		if cell.bg then
			SetFonts(cell, size)
			if cell.aura == nil then AttachAuras(cell) end -- styled in combat earlier
			UpdateAuraFilters(cell)
		end
	end
	h:SetAttribute("columnSpacing", GAP)
	h:SetAttribute("maxColumns", math.ceil(40 / per))
	-- Pre-create every child now (out of combat): a negative startingIndex makes the header build
	-- buttons for the indices below 1 as well, so a member who joins mid-fight gets a cell that
	-- already has its visuals. Same trick as oUF/ShadowedUF.
	if not h.preallocated then
		h.preallocated = true
		h:SetAttribute("startingIndex", -(MAX_CELLS - 1))
		h:Show()
		h:SetAttribute("startingIndex", 1)
		for _, cell in ipairs({ h:GetChildren() }) do
			if not cell.bg then Style(cell, true) end
		end
	end
	h:SetAttribute("unitsPerColumn", per)
end

local function Applied()
	return applied.mode == wantMode() and applied.size == CellSize() and applied.per == PerRow()
		and applied.spell == spell and applied.pets == (ns.db.clPets and true or false)
		and applied.solo == (ns.db.clSolo and true or false)
end

-- The headers size themselves when they lay out; the frame wraps them. Out of combat only.
local function FitFrame()
	if InCombatLockdown() or not header then return end
	local w, h = header:GetWidth(), math.max(header:GetHeight(), CellSize())
	if petHeader and petHeader:IsShown() and petHeader:GetHeight() > 1 then
		w = math.max(w, petHeader:GetWidth())
		h = h + GAP + petHeader:GetHeight()
	end
	frame:SetSize(math.max(72, INSET * 2 + w), TITLE_H + h + INSET)
end

-- Layout --------------------------------------------------------------------------------
local PLACEHOLDER = {
	{ "Partymember", "WARRIOR", 136207, "Poison", 1 }, { "Healer", "PRIEST", 136118, "Magic", 2 },
	{ "Ranged", "MAGE", 136127, "Disease", 1 }, { "Tank", "PALADIN" }, { "Rogue", "ROGUE" },
}

local function PlaceholderGrid()
	for i, cell in ipairs(placeholders) do
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

-- Mode, sizes, header options and list attributes. Out of combat only; in combat it is
-- deferred to PLAYER_REGEN_ENABLED (and announced once if an option is waiting).
function M:Layout()
	if not frame then return end
	if InCombatLockdown() then
		if not layoutNotified and not Applied() then
			layoutNotified = true
			ns.Print("cleanse layout changes after combat.")
		end
		return
	end
	layoutNotified = false
	laidOut = wantMode()
	local grid = laidOut == "Grid"
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
	-- headers: the live grid. Hidden headers hide their cells too.
	local live = grid and not placeholder
	if header then
		if live then
			if not Applied() or not header:IsShown() then ConfigureHeader(header) end
			header:Show()
		else
			header:Hide()
		end
	end
	if petHeader then
		if live and ns.db.clPets then
			if not Applied() or not petHeader:IsShown() then ConfigureHeader(petHeader) end
			petHeader:Show()
		else
			petHeader:Hide()
		end
	end
	applied = { mode = laidOut, size = CellSize(), per = PerRow(), spell = spell, pets = ns.db.clPets and true or false,
		solo = ns.db.clSolo and true or false }
	-- placeholder cells: five fake members while unlocked
	local size, per = CellSize(), PerRow()
	for i = 1, #PLACEHOLDER do
		local cell = placeholders[i]
		if grid and placeholder then
			if not cell then
				cell = CreateFrame("Button", nil, frame)
				Style(cell, false)
				cell:EnableMouse(false)
				placeholders[i] = cell
			end
			local col, row = (i - 1) % per, math.floor((i - 1) / per)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", INSET + col * (size + GAP), -TITLE_H - row * (size + GAP))
			cell:SetSize(size, size)
			SetFonts(cell, size)
			cell:Show()
		elseif cell then
			cell:Hide()
		end
	end
	-- frame size
	if not grid then
		frame:SetSize(ROW_W, TITLE_H + n * (ROW_H + GAP) - GAP + INSET)
	elseif placeholder then
		local count = #PLACEHOLDER
		local cols, rws = math.min(count, per), math.ceil(count / per)
		frame:SetSize(math.max(72, INSET * 2 + cols * (size + GAP) - GAP), TITLE_H + rws * (size + GAP) - GAP + INSET)
	else
		FitFrame()
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
		frame:Show() -- a hidden header lays itself out when it becomes visible
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
		if header then PaintHeader(header, hits, best) end
		if petHeader and petHeader:IsShown() then PaintHeader(petHeader, hits, best) end
		title:SetText(text)
		frame:SetAlpha(1)
		if not combat then FitFrame() end -- the header may have grown or shrunk since the last Layout
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
	frame:SetSize(ROW_W, TITLE_H + 5 * (ROW_H + GAP) - GAP + INSET)
	frame:SetFrameStrata("LOW")
	frame:Hide()
	if ns.UI and ns.UI.Box then
		ns.UI.Box(frame, 0.85)
	else
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(); bg:SetColorTexture(0.075, 0.058, 0.042, 0.88)
	end
	title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
	title:SetPoint("TOPLEFT", INSET, -7)
	title:SetTextColor(1, 0.82, 0)
	ns.MakeMovable(frame, "clPoint")
	ns.ApplyPoint(frame, "clPoint")
	-- drags keep the TOPLEFT anchor (Core.lua), so growth (more members, bigger cells) goes down/right
	if ns.db.clPoint[1] ~= "TOPLEFT" then SaveTopLeft(frame); ns.ApplyPoint(frame, "clPoint") end -- pre-grid position

	for i = 1, MAX_ROWS do rows[i] = MakeRow(i) end

	header = MakeHeader("LightboundCleanseHeader", "SecureGroupHeaderTemplate")
	if header then
		header:SetPoint("TOPLEFT", INSET, -TITLE_H)
		petHeader = MakeHeader("LightboundCleansePetHeader", "SecureGroupPetHeaderTemplate")
		if petHeader then petHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP) end
	end

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
			if filtersPending then RefreshAuraFilters() end
			if keyPending then ns.ApplyCleanseKey() end
		elseif event == "PLAYER_REGEN_DISABLED" then
			Schedule(false)
			return
		end
		Schedule(true) -- roster, pets, zoning, combat end, spell set: sizes or options may change
	end)
	C_Timer.NewTicker(0.5, function() if frame:IsShown() then M:Update() end end) -- range changes without events
	ns.ApplyCleanseKey()
	M:Layout()
	M:Update()
end

-- Options ----------------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Cleanse", "Who needs a Cleanse. Click a cell or row to cast. Layout options apply out of combat.")
	local W = UI.CONTENT_W
	local half = math.floor(W / 2)
	p:Add(UI.Section(p, p.y, "Show") + 2)
	UI.DBToggle(p, 0, p.y, half, "clEnabled", "Show the cleanse frame")
	UI.DBToggle(p, half, p.y, half, "clPets", "Include pets")
	p:Add(28)
	UI.DBToggle(p, 0, p.y, half, "clRange", "Dim players out of range")
	UI.DBToggle(p, half, p.y, half, "clSound", "Sound when someone new needs it")
	p:Add(28)
	UI.DBToggle(p, 0, p.y, W, "clSolo", "Show when solo (just you, and your pet with pets on)")
	p:Add(30)
	p:Add(UI.Section(p, p.y, "Layout") + 2)
	p:Add(select(2, UI.Cycle(p, p.y, "Grid or list", { "Grid", "List" },
		function() return ns.db.clMode == "List" and "List" or "Grid" end,
		function(v) ns.db.clMode = v end,
		function() return ns.db.clMode == "List" and "one row per afflicted unit" or "one cell per group member, follows the roster in combat" end)) + 2)
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

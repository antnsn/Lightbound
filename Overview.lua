-- Raid overview: one row per class in the group that you have a blessing for, with how many
-- are missing it and the shortest time left. Click a row (out of combat) to bless that class:
-- Greater Blessing in a raid when you can, otherwise the next member who needs it.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local ROW_W, ROW_H = 230, 24
local frame, title, rows = nil, nil, {}
local pending -- { spell, key, class, guid, greater } of the last click

local function Format(s)
	if s == math.huge then return "on" end
	if s >= 60 then return ("%d:%02d"):format(s / 60, s % 60) end
	return ("%ds"):format(s)
end

local function SymbolCount()
	return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(ns.PB.SYMBOL)) or (GetItemCount and GetItemCount(ns.PB.SYMBOL)) or 0
end

local function SpellTexture(name)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
		return GetSpellTexture(name)
	end)
	return ok and tex or 135906
end

-- Per class: { class, key, total, missing, low, minLeft, unit, spell, greater }
local function Scan()
	local PB, db = ns.PB, ns.db
	local source, raid = ns.PartyBuffSource(), IsInRaid()
	local refresh, now = db.pbRefreshMinutes * 60, GetTime()
	local haveSymbol = SymbolCount() > 0
	local byClass, order = {}, {}
	for _, unit in ipairs(PB.Units()) do
		if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
			local _, class = UnitClass(unit)
			local key, greaterOK = nil, false
			if class then key, greaterOK = PB.Assignment(unit, class, source) end
			if key then
				local c = byClass[class]
				if not c then
					c = { class = class, key = key, total = 0, missing = 0, low = 0, minLeft = math.huge, greaterOK = true }
					byClass[class] = c
					order[#order + 1] = c
				end
				if not greaterOK then c.greaterOK = false end -- someone has a per-player blessing
				c.total = c.total + 1
				local unitKey = key
				local left = PB.TimeLeft(unit, unitKey)
				local guid = UnitGUID(unit)
				if left == nil then
					local t = guid and PB.recent[guid] and PB.recent[guid][unitKey]
					left = t and (PB.GREATER_DURATION - (now - t)) or 0
				end
				if left <= 0 then c.missing = c.missing + 1
				elseif left <= refresh then c.low = c.low + 1 end
				if left < c.minLeft then c.minLeft = math.max(left, 0) end
				if left <= refresh and not c.unit and UnitIsVisible(unit) then
					local spell = "Blessing of " .. unitKey
					if PB.SpellKnown(spell) and PB.InRange(spell, unit) then c.unit, c.unitKey = unit, unitKey end
				end
			end
		end
	end
	for _, c in ipairs(order) do
		local greater = "Greater Blessing of " .. c.key
		c.greater = db.pbGreater and raid and c.greaterOK and haveSymbol and PB.SpellKnown(greater) or false
		if c.unit then
			c.spell = c.greater and greater or ("Blessing of " .. c.unitKey)
		end
	end
	table.sort(order, function(a, b) return (ns.PP_CLASS[a.class] or 99) < (ns.PP_CLASS[b.class] or 99) end)
	return order
end

local function ShouldShow()
	local db = ns.db
	if ns.unlocked then return true end
	if not db.ovEnabled then return false end
	if db.ovOnlyRaid then return IsInRaid() end
	return IsInGroup()
end

local function Configure(row)
	if InCombatLockdown() then return end
	local c = row.data
	if c and c.unit and c.spell then
		row:SetAttribute("type", "macro")
		row:SetAttribute("macrotext", ("/cast [nocombat,@%s] %s"):format(c.unit, c.spell))
		pending = { spell = c.spell, key = c.key, class = c.class, guid = UnitGUID(c.unit), greater = c.greater }
	else
		row:SetAttribute("type", nil)
		pending = nil
	end
end

local function Draw(list)
	local UI = ns.UI
	local combat = InCombatLockdown()
	title:SetText(("Blessings  |cff999999%d symbols|r"):format(SymbolCount()))
	if SymbolCount() < (ns.db.reagentWarn or 0) then
		title:SetText(("Blessings  |cffff5555%d symbols|r"):format(SymbolCount()))
	end
	for i, row in ipairs(rows) do
		local c = list[i]
		row.data = c
		if c then
			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
			local cname = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or c.class
			row.icon:SetTexture(SpellTexture((c.greater and "Greater Blessing of " or "Blessing of ") .. c.key))
			row.name:SetText(cname)
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) end
			if c.missing > 0 then
				row.state:SetText(("|cffff5555%d/%d missing|r"):format(c.missing, c.total))
				row.bg:SetColorTexture(0.45, 0.08, 0.10, 0.55)
			elseif c.low > 0 then
				row.state:SetText("|cffffd100" .. Format(c.minLeft) .. "|r")
				row.bg:SetColorTexture(0.40, 0.30, 0.05, 0.5)
			else
				row.state:SetText("|cff9fdf9f" .. Format(c.minLeft) .. "|r")
				row.bg:SetColorTexture(0.165, 0.125, 0.082, 0.8)
			end
			if not combat then row:Show() end
		elseif not combat then
			row:Hide()
		end
	end
	if not combat then
		frame:SetHeight(22 + math.max(#list, 1) * (ROW_H + 2))
	end
end

function M:Update()
	if not frame then return end
	if InCombatLockdown() then
		if frame:IsShown() then Draw(Scan()) end
		return
	end
	if not ShouldShow() then frame:Hide() return end
	local list
	if ns.unlocked then
		list = {
			{ class = "WARRIOR", key = "Might", total = 5, missing = 2, low = 0, minLeft = 0 },
			{ class = "PRIEST", key = "Wisdom", total = 3, missing = 0, low = 1, minLeft = 45 },
			{ class = "MAGE", key = "Wisdom", total = 4, missing = 0, low = 0, minLeft = 812 },
		}
	else
		list = Scan()
		if #list == 0 then frame:Hide() return end
	end
	frame:Show()
	Draw(list)
end

function M:Init()
	local UI = ns.UI
	frame = CreateFrame("Frame", "LightboundOverviewFrame", UIParent, "BackdropTemplate")
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
	ns.MakeMovable(frame, "ovPoint")
	ns.ApplyPoint(frame, "ovPoint")

	for i = 1, 9 do
		local row = CreateFrame("Button", "LightboundOverviewRow" .. i, frame, "SecureActionButtonTemplate")
		row:SetSize(ROW_W - 8, ROW_H)
		row:SetPoint("TOPLEFT", 4, -20 - (i - 1) * (ROW_H + 2))
		row:RegisterForClicks(GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
		row:SetAttribute("checkselfcast", false)
		row:SetAttribute("checkfocuscast", false)
		row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_H - 4, ROW_H - 4); row.icon:SetPoint("LEFT", 2, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetFont("Fonts\\ARIALN.TTF", 13, ""); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.state = row:CreateFontString(nil, "OVERLAY")
		row.state:SetFont("Fonts\\ARIALN.TTF", 13, ""); row.state:SetPoint("RIGHT", -6, 0)
		local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("PreClick", function(self) Configure(self) end)
		row:SetScript("OnEnter", function(self)
			local c = self.data
			if not c or ns.unlocked then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine((c.greater and "Greater Blessing of " or "Blessing of ") .. c.key)
			GameTooltip:AddLine(("%d of %d missing, %d running low"):format(c.missing, c.total, c.low), 1, 1, 1)
			if c.unit then
				GameTooltip:AddLine("Click: " .. (c.greater and "bless the whole class" or ("bless " .. (UnitName(c.unit) or "?"))), 0.6, 0.9, 0.6)
			else
				GameTooltip:AddLine("Nobody in range needs it", 0.6, 0.6, 0.6)
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
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "PLAYER_REGEN_DISABLED" then
			if not InCombatLockdown() then
				for _, row in ipairs(rows) do row:SetAttribute("type", nil) end
			end
			return
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			if pending and name == pending.spell then
				local now, recent = GetTime(), ns.PB.recent
				if pending.greater then
					-- a Greater Blessing lands on everyone of that class
					for _, unit in ipairs(ns.PB.Units()) do
						local _, class = UnitClass(unit)
						local guid = UnitGUID(unit)
						if class == pending.class and guid then
							recent[guid] = recent[guid] or {}
							recent[guid][pending.key] = now
						end
					end
				elseif pending.guid then
					recent[pending.guid] = recent[pending.guid] or {}
					recent[pending.guid][pending.key] = now
				end
			end
			pending = nil
		end
		M:Update()
	end)
	C_Timer.NewTicker(1, function() M:Update() end)
end

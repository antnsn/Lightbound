-- Raid blessings window (/lb raid): one row per paladin in the group, one column per class
-- plus the aura. Click a cell to change it (left = next, right = previous). The group leader and
-- assists can change every row, others only their own (or anyone who allows it).
local _, ns = ...

local win, rows, header = nil, {}, {}
local NAME_W, CELL, GAP, ROW_H, PAD = 170, 30, 6, 40, 20
local HEADER_H, FOOTER_H, COLS_Y = 44, 56, 70

local CLASS_ICON = {
	"Interface\\Icons\\ClassIcon_Warrior", "Interface\\Icons\\ClassIcon_Rogue", "Interface\\Icons\\ClassIcon_Priest",
	"Interface\\Icons\\ClassIcon_Druid", "Interface\\Icons\\ClassIcon_Paladin", "Interface\\Icons\\ClassIcon_Hunter",
	"Interface\\Icons\\ClassIcon_Mage", "Interface\\Icons\\ClassIcon_Warlock", "Interface\\Icons\\ClassIcon_Shaman",
}

-- Auto-assign: what each class wants, best first. Salvation stays manual (tanks don't want it).
local WANTS = {
	WARRIOR = { "Might", "Kings", "Light", "Sanctuary" },
	ROGUE = { "Might", "Kings", "Light" },
	HUNTER = { "Might", "Kings", "Wisdom", "Light" },
	PRIEST = { "Wisdom", "Kings", "Light" },
	MAGE = { "Wisdom", "Kings", "Light" },
	WARLOCK = { "Wisdom", "Kings", "Light" },
	DRUID = { "Wisdom", "Kings", "Might", "Light" },
	SHAMAN = { "Wisdom", "Kings", "Might", "Light" },
	PALADIN = { "Wisdom", "Kings", "Might", "Light" },
}
local AURA_ORDER = { 1, 2, 3, 6, 5, 4, 7 } -- Devotion, Retribution, Concentration, Fire, Frost, Shadow, Sanctity

local function Texture(spell)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
		return GetSpellTexture(spell)
	end)
	return ok and tex or nil
end
-- textures by number, cached once found (only spells you know have a texture by name)
local blessTex, auraTex = {}, {}
local FALLBACK_BLESS = { 135970, 135906, 135995, 135967, 135943, 136051 }
local FALLBACK_AURA = { 135893, 135873, 135933, 136192, 135865, 135824, 135934 }
local function BlessTexture(i)
	blessTex[i] = blessTex[i] or Texture("Blessing of " .. ns.PP_SPELL[i])
	return blessTex[i] or FALLBACK_BLESS[i]
end
local function AuraTexture(i)
	auraTex[i] = auraTex[i] or Texture(ns.PP_AURA[i] .. " Aura")
	return auraTex[i] or FALLBACK_AURA[i]
end

-- Blessing numbers a paladin can cast (unknown info: all). Salvation is always offered,
-- because PallyPower on Forever never reports it.
local function BlessOptions(name)
	local p = ns.pallys[name]
	local list = { 0 }
	for i = 1, #ns.PP_SPELL do
		if not p or not next(p.bless or {}) or p.bless[i] or i == 4 then list[#list + 1] = i end
	end
	return list
end

local function AuraOptions(name)
	local p = ns.pallys[name]
	local list = { 0 }
	for i = 1, #ns.PP_AURA do
		if not p or not next(p.auras or {}) or p.auras[i] then list[#list + 1] = i end
	end
	return list
end

local function Step(list, cur, dir)
	local pos = 1
	for i, v in ipairs(list) do if v == cur then pos = i end end
	pos = pos + dir
	if pos > #list then pos = 1 elseif pos < 1 then pos = #list end
	return list[pos]
end

local function AutoAssign()
	local pallys, editable = {}, {}
	for _, name in ipairs(ns.GroupPaladins()) do
		if ns.CanControl(name) and (ns.pallys[name] or name == ns.MyName()) then
			pallys[#pallys + 1] = name
			editable[name] = true
		end
	end
	if #pallys == 0 then return end
	local plan = {}
	for _, name in ipairs(pallys) do plan[name] = {} end
	-- paladins we can't change keep their blessings; don't double up on those
	local fixed = {}
	for _, name in ipairs(ns.GroupPaladins()) do
		if not editable[name] then
			for cid = 1, 9 do
				local v = ns.GetAssign(name, cid)
				if v > 0 then fixed[cid] = fixed[cid] or {}; fixed[cid][v] = true end
			end
		end
	end
	for cid, class in ipairs(ns.PP_CLASS_NAME) do
		local used, taken = {}, fixed[cid] or {}
		for _, key in ipairs(WANTS[class]) do
			local idx = ns.PP_SPELL_ID[key]
			if not taken[idx] then
				-- the paladin who knows this blessing and the fewest other wanted ones
				-- best: most talent points, then highest rank, then the one who knows the fewest
				-- other wanted blessings (keeps a Kings paladin free for Kings)
				local best, bestScore
				for _, name in ipairs(pallys) do
					local p = ns.pallys[name]
					if not used[name] and p and p.bless[idx] then
						local count = 0
						for _, k in ipairs(WANTS[class]) do if p.bless[ns.PP_SPELL_ID[k]] then count = count + 1 end end
						local score = ((p.talents and p.talents[idx]) or 0) * 1000 + ((p.ranks and p.ranks[idx]) or 0) * 10 - count
						if not bestScore or score > bestScore then best, bestScore = name, score end
					end
				end
				if best then used[best] = true; taken[idx] = true; plan[best][cid] = idx end
			end
		end
	end
	local auraTaken = {}
	for _, name in ipairs(ns.GroupPaladins()) do
		if not editable[name] then auraTaken[ns.GetAuraAssign(name)] = true end
	end
	for _, name in ipairs(pallys) do
		ns.SetAllAssign(name, plan[name])
		local p = ns.pallys[name]
		for _, i in ipairs(AURA_ORDER) do
			if not auraTaken[i] and p and p.auras and p.auras[i] then
				auraTaken[i] = true
				ns.SetAuraAssign(name, i)
				break
			end
		end
	end
	ns.Print("blessings auto-assigned for " .. #pallys .. " paladin" .. (#pallys == 1 and "" or "s") .. ".")
end

local function Cell(parent, onClick, onEnter)
	local UI = ns.UI
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(CELL, CELL)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.bg = UI.Tex(b, "BACKGROUND", UI.C.button); b.bg:SetAllPoints()
	UI.Border(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.dash = UI.Font(b, 14, UI.C.dim); b.dash:SetPoint("CENTER"); b.dash:SetText("-")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		self.bg:SetColorTexture(unpack(UI.C.hover))
		if onEnter then onEnter(self) end
	end)
	b:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(unpack(UI.C.button))
		GameTooltip:Hide()
	end)
	b.Set = function(self, tex, editable)
		if tex then self.icon:SetTexture(tex); self.icon:Show(); self.dash:Hide()
		else self.icon:Hide(); self.dash:Show() end
		self.icon:SetDesaturated(false)
		self:SetAlpha(editable and 1 or 0.55)
	end
	return b
end

local function ColX(cid) return NAME_W + (cid - 1) * (CELL + GAP) end
local AURA_X = ColX(10) + 12
local CD_X = AURA_X + CELL + 18
local TOTAL_W = CD_X + 2 * (CELL + GAP)
local CD_ICON = { 135928, 135899 } -- Lay on Hands, Divine Intervention

-- Per-player popup: members of one class, click to set their own blessing from this paladin
local popup
local function ShowPopup(anchor, pally, cid)
	local UI = ns.UI
	if not popup then
		popup = CreateFrame("Frame", "LightboundPerPlayerPopup", win, "BackdropTemplate")
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:EnableMouse(true)
		UI.Box(popup, 0.97)
		popup.title = UI.Font(popup, 12, UI.C.accent); popup.title:SetPoint("TOPLEFT", 8, -6)
		popup.lines = {}
		popup:SetScript("OnHide", function(self) self.pally = nil end)
	end
	local class = ns.PP_CLASS_NAME[cid]
	local members = {}
	for _, unit in ipairs(ns.PB.Units()) do
		local _, c = UnitClass(unit)
		if c == class then members[#members + 1] = GetUnitName(unit, true) or UnitName(unit) end
	end
	if #members == 0 then ns.Print("nobody of that class in the group.") return end
	local cname = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
	popup.title:SetText(pally .. " > " .. cname .. " (per player)")
	popup.pally, popup.cid = pally, cid
	for i, member in ipairs(members) do
		local line = popup.lines[i]
		if not line then
			line = UI.Button(popup, "", 220, 22)
			line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			line:SetPoint("TOPLEFT", 6, -22 - (i - 1) * 24)
			line.label:SetJustifyH("LEFT"); line.label:ClearAllPoints(); line.label:SetPoint("LEFT", 8, 0)
			popup.lines[i] = line
		end
		local function Sync()
			local idx = ns.GetNormalAssign(popup.pally, popup.cid, member)
			line:SetLabel(member .. "  " .. UI.Hex(UI.C.dim) .. (idx and ns.PP_SPELL[idx] or "class blessing") .. "|r")
		end
		line:SetScript("OnClick", function(_, button)
			local cur = ns.GetNormalAssign(popup.pally, popup.cid, member) or 0
			ns.SetNormalAssign(popup.pally, popup.cid, member, Step(BlessOptions(popup.pally), cur, button == "RightButton" and -1 or 1))
			Sync()
		end)
		Sync()
		line:Show()
	end
	for i = #members + 1, #popup.lines do popup.lines[i]:Hide() end
	popup:SetSize(232, 28 + #members * 24)
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	popup:Show()
end

local function CdText(c)
	if not c or not c.known then return nil end
	local left = (c.readyAt or 0) - GetTime()
	if left <= 0 then return "|cff9fdf9fok|r" end
	if left >= 3600 then return ("%dh"):format(left / 3600) end
	if left >= 60 then return ("%dm"):format(left / 60) end
	return ("%ds"):format(left)
end

local function MakeRow(i)
	local UI = ns.UI
	local r = CreateFrame("Frame", nil, win.body)
	r:SetSize(TOTAL_W, ROW_H)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
	r.stripe = UI.Tex(r, "BACKGROUND", UI.C.side); r.stripe:SetAllPoints()
	r.name = UI.Font(r, 14, UI.C.text); r.name:SetPoint("TOPLEFT", 8, -6); r.name:SetWidth(NAME_W - 14)
	r.info = UI.Font(r, 11, UI.C.dim); r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
	r.cells = {}
	for cid = 1, 9 do
		local c = Cell(r, function(self, button)
			if not ns.CanControl(r.pally) then ns.Print("only the leader or an assist can change " .. r.pally .. ".") return end
			if IsShiftKeyDown() then ShowPopup(self, r.pally, cid) return end
			local cur = ns.GetAssign(r.pally, cid)
			ns.SetAssign(r.pally, cid, Step(BlessOptions(r.pally), cur, button == "RightButton" and -1 or 1))
		end, function(self)
			local idx = ns.GetAssign(r.pally, cid)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local class = ns.PP_CLASS_NAME[cid]
			local cname = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
			GameTooltip:AddLine(r.pally .. " > " .. cname)
			GameTooltip:AddLine(idx > 0 and ("Blessing of " .. ns.PP_SPELL[idx]) or "Nothing assigned", 1, 1, 1)
			for member, idx2 in pairs(ns.GetNormalAssigns(r.pally, cid)) do
				GameTooltip:AddLine(member .. ": " .. (ns.PP_SPELL[idx2] or "?"), 0.6, 0.8, 1)
			end
			if ns.CanControl(r.pally) then
				GameTooltip:AddLine("Left-click next, right-click previous", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("Shift-click: blessing per player", 0.6, 0.6, 0.6)
			end
			GameTooltip:Show()
		end)
		c:SetPoint("LEFT", r, "LEFT", ColX(cid), 0)
		c.badge = ns.UI.Font(c, 10, ns.UI.C.accent, "OVERLAY")
		c.badge:SetPoint("BOTTOMRIGHT", -1, 1)
		r.cells[cid] = c
	end
	r.aura = Cell(r, function(self, button)
		if not ns.CanControl(r.pally) then ns.Print("only the leader or an assist can change " .. r.pally .. ".") return end
		local cur = ns.GetAuraAssign(r.pally)
		ns.SetAuraAssign(r.pally, Step(AuraOptions(r.pally), cur, button == "RightButton" and -1 or 1))
	end, function(self)
		local idx = ns.GetAuraAssign(r.pally)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(r.pally .. " > aura")
		GameTooltip:AddLine(idx > 0 and (ns.PP_AURA[idx] .. " Aura") or "No aura assigned", 1, 1, 1)
		GameTooltip:Show()
	end)
	r.aura:SetPoint("LEFT", r, "LEFT", AURA_X, 0)
	r.cds = {}
	for k = 1, 2 do
		local cd = CreateFrame("Frame", nil, r)
		cd:SetSize(CELL, CELL)
		cd:SetPoint("LEFT", r, "LEFT", CD_X + (k - 1) * (CELL + GAP), 0)
		cd.icon = cd:CreateTexture(nil, "ARTWORK"); cd.icon:SetAllPoints()
		cd.icon:SetTexture(CD_ICON[k]); cd.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		cd.text = ns.UI.Font(cd, 11, ns.UI.C.text, "OVERLAY")
		cd.text:SetFont(ns.UI.FONT, 11, "OUTLINE")
		cd.text:SetPoint("BOTTOM", 0, 1); cd.text:SetJustifyH("CENTER")
		cd:EnableMouse(true)
		cd:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(k == 1 and "Lay on Hands" or "Divine Intervention")
			GameTooltip:AddLine(self.tip or "unknown", 1, 1, 1)
			GameTooltip:Show()
		end)
		cd:SetScript("OnLeave", function() GameTooltip:Hide() end)
		r.cds[k] = cd
	end
	rows[i] = r
	return r
end

local function Refresh()
	if not win or not win:IsShown() then return end
	local UI = ns.UI
	local list = ns.GroupPaladins()
	local me = ns.MyName()
	for i, name in ipairs(list) do
		local r = rows[i] or MakeRow(i)
		r.pally = name
		r.stripe:SetAlpha(i % 2 == 0 and 0.5 or 1)
		local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
		r.name:SetText(name == me and (name .. "  " .. UI.Hex(UI.C.dim) .. "(you)|r") or name)
		if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) end
		local p = ns.pallys[name]
		local bits = {}
		if not p then bits[#bits + 1] = "|cffff6666no addon|r"
		else
			bits[#bits + 1] = (tonumber(p.symbols) or 0) .. " symbols"
			if name ~= me and p.freeassign then bits[#bits + 1] = "open" end
			if ns.IsGroupLeader(name) then bits[#bits + 1] = "lead" end
		end
		r.info:SetText(table.concat(bits, " · "))
		local edit = ns.CanControl(name)
		for cid = 1, 9 do
			local idx = ns.GetAssign(name, cid)
			r.cells[cid]:Set(idx > 0 and BlessTexture(idx) or nil, edit)
			local n = 0
			for _ in pairs(ns.GetNormalAssigns(name, cid)) do n = n + 1 end
			r.cells[cid].badge:SetText(n > 0 and ("+" .. n) or "")
		end
		for k = 1, 2 do
			local cd, info = r.cds[k], p and p.cd and p.cd[k]
			local t = CdText(info)
			cd.text:SetText(t or "")
			cd.icon:SetDesaturated(not t or not t:find("ok"))
			cd:SetAlpha(t and 1 or 0.3)
			cd.tip = t and (t:find("ok") and "ready" or ("ready in " .. t)) or "not known or not synced"
		end
		local aidx = ns.GetAuraAssign(name)
		r.aura:Set(aidx > 0 and AuraTexture(aidx) or nil, edit)
		r:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	win:SetHeight(COLS_Y + 34 + #list * ROW_H + FOOTER_H + 10)
	win.open:SetLabel(ns.db.freeAssign and "Others may assign me: on" or "Others may assign me: off")
	local status
	if ns.GroupPassive() then
		status = "PallyPower is loaded: Lightbound only reads its assignments. Remove PallyPower to sync from here."
	elseif not IsInGroup() then
		status = "Not in a group. Changes are saved and sent when you join one."
	elseif ns.IsGroupLeader(me) then
		status = "You are leader or assist: you can change every row."
	else
		status = "You can change your own row. The leader or an assist can change all."
	end
	win.status:SetText(status)
end
ns.RaidWindowRefresh = Refresh

local function Build()
	local UI = ns.UI
	local C = UI.C
	local width = PAD * 2 + TOTAL_W
	win = CreateFrame("Frame", "LightboundRaidFrame", UIParent)
	win:SetSize(width, 300)
	win:SetPoint("CENTER")
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:Hide()
	tinsert(UISpecialFrames, win:GetName())
	UI.Skin(win, "Raid blessings")
	local wm = UI.Watermark(win, 220, 0.06)
	wm:SetPoint("CENTER", win, "CENTER", 0, -10)

	local head = CreateFrame("Frame", nil, win)
	head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(HEADER_H)
	UI.Tex(head, "BACKGROUND", C.header):SetAllPoints()
	local hl = UI.Tex(head, "ARTWORK", C.border); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)
	head:EnableMouse(true); head:RegisterForDrag("LeftButton")
	head:SetScript("OnDragStart", function() win:StartMoving() end)
	head:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
	local logo = head:CreateTexture(nil, "ARTWORK"); logo:SetSize(34, 34); logo:SetPoint("LEFT", 8, -2)
	logo:SetTexture(UI.MEDIA .. "Logo64")
	local title = UI.Title(head, 15); title:SetPoint("LEFT", logo, "RIGHT", 6, 0); title:SetText("Lightbound")

	-- column headers
	local cols = CreateFrame("Frame", nil, win)
	cols:SetPoint("TOPLEFT", PAD, -COLS_Y + 14); cols:SetSize(TOTAL_W, 26)
	local pl = UI.Font(cols, 12, C.dim); pl:SetPoint("LEFT", 8, 0); pl:SetText("PALADIN")
	for cid = 1, 9 do
		local t = cols:CreateTexture(nil, "ARTWORK")
		t:SetSize(22, 22); t:SetPoint("LEFT", ColX(cid) + (CELL - 22) / 2, 0)
		t:SetTexture(CLASS_ICON[cid]); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		header[cid] = t
	end
	local al = UI.Font(cols, 12, C.dim); al:SetPoint("LEFT", AURA_X - 2, 0); al:SetText("AURA")
	local cl = UI.Font(cols, 12, C.dim); cl:SetPoint("LEFT", CD_X + 4, 0); cl:SetText("COOLDOWNS")

	win.body = CreateFrame("Frame", nil, win)
	win.body:SetPoint("TOPLEFT", PAD, -COLS_Y - 16)
	win.body:SetSize(TOTAL_W, 10)

	local footer = CreateFrame("Frame", nil, win)
	footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(FOOTER_H)
	UI.Tex(footer, "BACKGROUND", C.header):SetAllPoints()
	local fl = UI.Tex(footer, "ARTWORK", C.border); fl:SetPoint("TOPLEFT"); fl:SetPoint("TOPRIGHT"); fl:SetHeight(1)
	local auto = UI.Button(footer, "Auto-assign", 110, 26, true)
	auto:SetPoint("TOPLEFT", 16, -8)
	auto:SetScript("OnClick", AutoAssign)
	local clear = UI.Button(footer, "Clear", 70, 26)
	clear:SetPoint("LEFT", auto, "RIGHT", 8, 0)
	clear:SetScript("OnClick", function() ns.ClearAssignments() end)
	local sync = UI.Button(footer, "Refresh", 80, 26)
	sync:SetPoint("LEFT", clear, "RIGHT", 8, 0)
	sync:SetScript("OnClick", function() ns.RequestSync(); Refresh() end)
	local open = UI.Button(footer, "", 190, 26)
	open:SetPoint("TOPRIGHT", -16, -8)
	open:SetScript("OnClick", function()
		ns.db.freeAssign = not ns.db.freeAssign
		ns.SendSelf()
		Refresh()
	end)
	open:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Let any paladin in the group change your blessings,")
		GameTooltip:AddLine("not only the leader and assists.", 1, 1, 1)
		GameTooltip:Show()
	end)
	open:HookScript("OnLeave", function() GameTooltip:Hide() end)
	win.open = open
	win.status = UI.Font(footer, 11, C.dim)
	win.status:SetPoint("BOTTOMLEFT", 16, 6); win.status:SetPoint("RIGHT", -16, 0)

	win:SetScript("OnShow", function()
		ns.RequestSync(); Refresh()
		win.ticker = win.ticker or C_Timer.NewTicker(1, function() if win:IsShown() then Refresh() end end)
	end)
end

function ns.ToggleRaidWindow()
	if not ns.db or not ns.UI then return end
	if not win then Build() end
	if win:IsShown() then win:Hide() else win:Show() end
end

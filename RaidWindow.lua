-- Blessings window (/lb blessings, also /lb raid): one row per paladin in the group, one column
-- per class plus the aura and the Judgement (Lightbound users only, see Judgements.lua). Click a
-- cell to change it (left = next, right = previous). The group leader and assists can change every
-- row, others only their own (or anyone who allows it).
-- This is the only place that decides blessings: your row is what the buff key casts, solo, in a
-- party and in a raid. Under your row sits the tank line: what a tank gets from you instead of
-- Salvation, shown only under the classes you give Salvation.
local _, ns = ...

local win, rows, header = nil, {}, {}
local NAME_W, CELL, GAP, ROW_H, PAD = 170, 30, 6, 40, 20
local TANK_H, TANK_CELL = 30, 24 -- the tank line under your row
local CELL_Y = -(ROW_H - CELL) / 2 -- cells sit in the top ROW_H of a row (your row is taller)
local SALVATION = 4
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

-- Blessing numbers a paladin can cast (unknown info: all). Salvation is always offered for
-- others, because PallyPower on Forever never reports it; for you we know your spellbook.
local function BlessOptions(name)
	local p = ns.pallys[name]
	local mine = name == ns.MyName()
	local list = { 0 }
	for i = 1, #ns.PP_SPELL do
		if not p or not next(p.bless or {}) or p.bless[i] or (i == SALVATION and not mine) then list[#list + 1] = i end
	end
	return list
end

-- true when this is your row and you haven't learned blessing `idx` (the buff key can't cast it)
local function Unlearned(name, idx)
	if idx <= 0 or name ~= ns.MyName() then return false end
	local p = ns.pallys[name]
	return p and next(p.bless or {}) and not p.bless[idx] or false
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
	b.Set = function(self, tex, editable, unlearned)
		if tex then self.icon:SetTexture(tex); self.icon:Show(); self.dash:Hide()
		else self.icon:Hide(); self.dash:Show() end
		-- a blessing you haven't learned yet: grey icon, red tint
		self.icon:SetDesaturated(unlearned and true or false)
		self.icon:SetVertexColor(1, unlearned and 0.35 or 1, unlearned and 0.35 or 1)
		self.unlearned = unlearned
		self:SetAlpha(editable and 1 or 0.55)
	end
	return b
end

local function ColX(cid) return NAME_W + (cid - 1) * (CELL + GAP) end
local AURA_X = ColX(10) + 12
local JUDGE_X = AURA_X + CELL + GAP
local CD_X = JUDGE_X + CELL + 18
local TOTAL_W = CD_X + 3 * (CELL + GAP)
local CD_ICON = { 135928, 135899, 135964 } -- Lay on Hands, Divine Intervention, Blessing of Protection
local CD_NAME = { "Lay on Hands", "Divine Intervention", "Blessing of Protection" }

-- Per-player popup: members of one class, click to set their own blessing from this paladin
local popup
local function ClassMembers(class)
	local members = {}
	for _, unit in ipairs(ns.PB.Units()) do
		local _, c = UnitClass(unit)
		if c == class then members[#members + 1] = GetUnitName(unit, true) or UnitName(unit) end
	end
	return members
end
local function ShowPopup(anchor, pally, cid)
	local UI = ns.UI
	if not popup then
		popup = CreateFrame("Frame", "LightboundPerPlayerPopup", win, "BackdropTemplate")
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:EnableMouse(true)
		UI.Box(popup, 0.97)
		popup.title = UI.Font(popup, 12, UI.C.accent); popup.title:SetPoint("TOPLEFT", 8, -6)
		popup.lines = {}
		local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
		close:SetSize(22, 22); close:SetPoint("TOPRIGHT", 2, 2)
		close:SetScript("OnClick", function() popup:Hide() end)
		-- Escape closes just the popup; other keys go on to the game. Propagation can't be changed
		-- in combat, so there Escape falls through and closes the Blessings window (and the popup).
		popup:EnableKeyboard(true)
		popup:SetScript("OnKeyDown", function(self, key)
			if InCombatLockdown() then return end
			if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); self:Hide()
			else self:SetPropagateKeyboardInput(true) end
		end)
		popup:SetScript("OnHide", function(self)
			self.pally, self.row, self.sig = nil, nil, nil
			-- back to passing keys on, after this Escape is done (so it doesn't close the window too)
			C_Timer.After(0, function() if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end end)
		end)
	end
	local class = ns.PP_CLASS_NAME[cid]
	local members = ClassMembers(class)
	if #members == 0 then ns.Print("nobody of that class in the group.") return end
	local cname = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
	popup.title:SetText(pally .. " > " .. cname .. " (per player)")
	-- the row it belongs to and who was listed: Refresh closes it when either changes
	popup.pally, popup.cid, popup.row, popup.sig = pally, cid, anchor:GetParent(), table.concat(members, ",")
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
	popup:SetSize(232, 30 + #members * 24)
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	if not InCombatLockdown() then popup:SetPropagateKeyboardInput(true) end
	popup:Show()
end

local Refresh -- defined below; the tank line calls it

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
	r:SetSize(TOTAL_W, ROW_H) -- placed by Refresh: your row is taller
	r.stripe = UI.Tex(r, "BACKGROUND", UI.C.side); r.stripe:SetAllPoints()
	r.name = UI.Font(r, 14, UI.C.text); r.name:SetPoint("TOPLEFT", 8, -6); r.name:SetWidth(NAME_W - 14)
	r.name:SetWordWrap(false) -- long names (with a surname) are cut, not wrapped over the info line
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
			if self.unlearned then
				GameTooltip:AddLine("You haven't learned this yet: the buff key skips it", 1, 0.35, 0.35)
			end
			for member, idx2 in pairs(ns.GetNormalAssigns(r.pally, cid)) do
				GameTooltip:AddLine(member .. ": " .. (ns.PP_SPELL[idx2] or "?"), 0.6, 0.8, 1)
			end
			if ns.CanControl(r.pally) then
				GameTooltip:AddLine("Left-click next, right-click previous", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("Shift-click: blessing per player", 0.6, 0.6, 0.6)
			end
			GameTooltip:Show()
		end)
		c:SetPoint("TOPLEFT", r, "TOPLEFT", ColX(cid), CELL_Y)
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
	r.aura:SetPoint("TOPLEFT", r, "TOPLEFT", AURA_X, CELL_Y)
	r.judge = Cell(r, function(self, button)
		if not ns.CanControl(r.pally) then ns.Print("only the leader or an assist can change " .. r.pally .. ".") return end
		if not ns.SetJudgeAssign then return end
		local cur = ns.GetJudgeAssign(r.pally)
		ns.SetJudgeAssign(r.pally, Step(ns.JUDGEMENTS, cur, button == "RightButton" and -1 or 1))
	end, function(self)
		local c = ns.GetJudgeAssign and ns.GetJudgeAssign(r.pally) or "None"
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(r.pally .. " > Judgement")
		GameTooltip:AddLine(c ~= "None" and ("Judgement of " .. (c == "Crusader" and "the Crusader" or c)) or "No Judgement assigned", 1, 1, 1)
		local p = ns.pallys[r.pally]
		if r.pally ~= ns.MyName() and not (p and p.lightbound) then
			GameTooltip:AddLine("Only paladins running Lightbound see this.", 0.6, 0.6, 0.6)
		end
		GameTooltip:Show()
	end)
	r.judge:SetPoint("TOPLEFT", r, "TOPLEFT", JUDGE_X, CELL_Y)
	r.cds = {}
	for k = 1, 3 do
		local cd = CreateFrame("Frame", nil, r)
		cd:SetSize(CELL, CELL)
		cd:SetPoint("TOPLEFT", r, "TOPLEFT", CD_X + (k - 1) * (CELL + GAP), CELL_Y)
		cd.icon = cd:CreateTexture(nil, "ARTWORK"); cd.icon:SetAllPoints()
		cd.icon:SetTexture(CD_ICON[k]); cd.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		cd.text = ns.UI.Font(cd, 11, ns.UI.C.text, "OVERLAY")
		cd.text:SetFont(ns.UI.FONT, 11, "OUTLINE")
		cd.text:SetPoint("BOTTOM", 0, 1); cd.text:SetJustifyH("CENTER")
		cd:EnableMouse(true)
		cd:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(CD_NAME[k])
			GameTooltip:AddLine(self.tip or "unknown", 1, 1, 1)
			GameTooltip:Show()
		end)
		cd:SetScript("OnLeave", function() GameTooltip:Hide() end)
		r.cds[k] = cd
	end
	-- tank line: under your row only
	local t = CreateFrame("Frame", nil, r)
	t:SetPoint("TOPLEFT", 0, -ROW_H); t:SetSize(TOTAL_W, TANK_H)
	t.guard = UI.Toggle(t, 12, -2, NAME_W - 16, "On tanks", nil,
		function() return ns.db.tankGuard end,
		function(v) ns.db.tankGuard = v end)
	t.guard:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Never Blessing of Salvation on a tank")
		GameTooltip:AddLine("A tank gets the blessing on this line from you instead.", 1, 1, 1)
		GameTooltip:AddLine("Who counts as a tank: Options > Tanks.", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	t.guard:HookScript("OnLeave", function() GameTooltip:Hide() end)
	t.cells = {}
	for cid = 1, 9 do
		local class = ns.PP_CLASS_NAME[cid]
		local c = Cell(t, function(_, button)
			if not ns.db.tankGuard then return end
			ns.StepTankBless(class, button == "RightButton" and -1 or 1)
			Refresh()
		end, function(self)
			local cname = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
			local key = ns.TankBless(class)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(cname .. " tanks, instead of Salvation")
			GameTooltip:AddLine(key ~= "None" and ("Blessing of " .. key) or "Nothing: skip tanks of this class", 1, 1, 1)
			GameTooltip:AddLine("Left-click next, right-click previous", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		c:SetSize(TANK_CELL, TANK_CELL)
		c:SetPoint("TOPLEFT", t, "TOPLEFT", ColX(cid) + (CELL - TANK_CELL) / 2, -(TANK_H - TANK_CELL) / 2)
		t.cells[cid] = c
	end
	t.none = UI.Font(t, 12, UI.C.dim)
	t.none:SetPoint("LEFT", t, "LEFT", ColX(1), 0)
	t.none:SetText("You give no Salvation, so tanks just get your row.")
	r.tankLine = t
	rows[i] = r
	return r
end

function Refresh()
	if not win or not win:IsShown() then return end
	local UI = ns.UI
	local list = ns.GroupPaladins()
	local me = ns.MyName()
	local y = 0
	for i, name in ipairs(list) do
		local r = rows[i] or MakeRow(i)
		r.pally = name
		local mine = name == me
		-- your row: highlighted and taller, with the tank line under it
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
		r:SetHeight(mine and (ROW_H + TANK_H) or ROW_H)
		y = y + r:GetHeight()
		if mine then
			r.stripe:SetColorTexture(UI.C.selected[1], UI.C.selected[2], UI.C.selected[3], 0.55)
		else
			r.stripe:SetColorTexture(unpack(UI.C.side))
			r.stripe:SetAlpha(i % 2 == 0 and 0.5 or 1)
		end
		if mine then r.stripe:SetAlpha(1) end
		local t = r.tankLine
		t:SetShown(mine)
		if mine then
			t.guard.Sync()
			local any = false
			for cid = 1, 9 do
				local c = t.cells[cid]
				-- Salvation on the class, or on any one player of it (Shift-click)
				local salv = ns.GetAssign(name, cid) == SALVATION
				if not salv then
					for _, idx in pairs(ns.GetNormalAssigns(name, cid)) do
						if tonumber(idx) == SALVATION then salv = true break end
					end
				end
				if salv then
					any = true
					local key = ns.TankBless(ns.PP_CLASS_NAME[cid])
					c:Set(key ~= "None" and BlessTexture(ns.PP_SPELL_ID[key]) or nil, ns.db.tankGuard)
					c:Show()
				else
					c:Hide()
				end
			end
			t.none:SetShown(not any)
		end
		local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
		r.name:SetText(name)
		if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) end
		local p = ns.pallys[name]
		local bits = {}
		if name == me then bits[1] = "you" end
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
			r.cells[cid]:Set(idx > 0 and BlessTexture(idx) or nil, edit, Unlearned(name, idx))
			local n = 0
			for _ in pairs(ns.GetNormalAssigns(name, cid)) do n = n + 1 end
			r.cells[cid].badge:SetText(n > 0 and ("+" .. n) or "")
		end
		for k = 1, 3 do
			local cd, info = r.cds[k], p and p.cd and p.cd[k]
			if k == 3 then -- Blessing of Protection comes from Cooldowns.lua (Lightbound users only)
				local c = ns.cds and ns.cds[name] and ns.cds[name].bop
				info = c and { known = true, readyAt = c.readyAt, dur = c.dur } or nil
			end
			local t = CdText(info)
			cd.text:SetText(t or "")
			cd.icon:SetDesaturated(not t or not t:find("ok"))
			cd:SetAlpha(t and 1 or 0.3)
			cd.tip = t and (t:find("ok") and "ready" or ("ready in " .. t)) or "not known or not synced"
		end
		local aidx = ns.GetAuraAssign(name)
		r.aura:Set(aidx > 0 and AuraTexture(aidx) or nil, edit)
		local jc = ns.GetJudgeAssign and ns.GetJudgeAssign(name) or "None"
		r.judge:Set(jc ~= "None" and ns.JudgeTexture(jc) or nil, edit)
		r:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	-- the per-player popup must not stay over a cell that now shows another paladin or class roster
	if popup and popup:IsShown() then
		local row = popup.row
		if not row or not row:IsShown() or row.pally ~= popup.pally
			or table.concat(ClassMembers(ns.PP_CLASS_NAME[popup.cid]), ",") ~= popup.sig then
			popup:Hide()
		end
	end
	win:SetHeight(COLS_Y + 34 + y + FOOTER_H + 10)
	win.open.Sync()
	local status
	if ns.GroupPassive() then
		status = "PallyPower is loaded: Lightbound only reads its assignments. Remove PallyPower to sync from here."
	elseif not IsInGroup() then
		status = "Not in a group: your row is what the buff key casts. Other paladins show up here when you group."
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
	UI.Skin(win, "Blessings")
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
	local jt = cols:CreateTexture(nil, "ARTWORK") -- Judgement column: the icon, the word doesn't fit
	jt:SetSize(22, 22); jt:SetPoint("LEFT", JUDGE_X + (CELL - 22) / 2, 0)
	jt:SetTexture(ns.JudgeTexture and ns.JudgeTexture("None") or 135959); jt:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local cl = UI.Font(cols, 12, C.dim); cl:SetPoint("LEFT", CD_X + 4, 0); cl:SetText("COOLDOWNS")

	win.body = CreateFrame("Frame", nil, win)
	win.body:SetPoint("TOPLEFT", PAD, -COLS_Y - 16)
	win.body:SetSize(TOTAL_W, 10)

	local footer = CreateFrame("Frame", nil, win)
	footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(FOOTER_H)
	UI.Tex(footer, "BACKGROUND", C.header):SetAllPoints()
	local fl = UI.Tex(footer, "ARTWORK", C.border); fl:SetPoint("TOPLEFT"); fl:SetPoint("TOPRIGHT"); fl:SetHeight(1)
	local function Tip(widget, title, text)
		widget:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(title)
			if text then GameTooltip:AddLine(text, 1, 1, 1) end
			GameTooltip:Show()
		end)
		widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
	end
	local auto = UI.Button(footer, "Auto-assign", 110, 26, true)
	auto:SetPoint("TOPLEFT", 16, -8)
	auto:SetScript("OnClick", AutoAssign)
	Tip(auto, "Auto-assign", "Fill every row you can change from what each class wants.")
	local sync = UI.Button(footer, "Refresh", 80, 26)
	sync:SetPoint("LEFT", auto, "RIGHT", 8, 0)
	sync:SetScript("OnClick", function() ns.RequestSync(); Refresh() end)
	Tip(sync, "Refresh", "Ask the other paladins for their rows.")
	local open = UI.Toggle(footer, 16 + 110 + 8 + 80 + 20, -8, 200, "Others may assign me", nil,
		function() return ns.db.freeAssign end,
		function(v) ns.db.freeAssign = v; ns.SendSelf(); Refresh() end)
	Tip(open, "Others may assign me", "Let any paladin in the group change your row, not only the leader and assists.")
	win.open = open
	-- Clear on its own at the right, away from the buttons pressed by habit
	local clear = UI.Button(footer, "Clear", 70, 26)
	clear:SetPoint("TOPRIGHT", -16, -8)
	clear:SetScript("OnClick", function() ns.ClearAssignments() end)
	Tip(clear, "Clear", "Empty every row you can change (only your own unless you're leader or assist).")
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

-- Always open (the options' "Open blessings" button must not close an open window)
function ns.OpenRaidWindow()
	if not ns.db or not ns.UI then return end
	if not win then Build() end
	win:Show(); win:Raise()
end

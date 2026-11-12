-- Tanks: never Blessing of Salvation on a tank.
-- A unit counts as a tank when it is on the tank list (/lb > Tanks, or /lb tank <name>), is the
-- raid's main tank or main assist, or has the tank role. When the blessing picked for a tank is
-- Salvation, the per-class fallback (tankBless) is cast instead, as a normal blessing so the rest
-- of the class keeps Salvation; Greater Salvation is also held back for a class that has a tank.
-- The tank list is shared between Lightbound paladins over LBND: "TANKS name,name" (leader and
-- assists send, everyone receives; long lists continue with "TANKS +name,name").
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = ns.IsSecret -- see Core.lua
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end

ns.TANK_CHOICES = { "Might", "Wisdom", "Kings", "Light", "Sanctuary", "None" }
local ROW_H, LIST_H, MSG_MAX = 24, 150, 220

local page, listScroll, listChild, hint
local rows = {}
local scan = { at = 0, units = {}, class = {} } -- tank detection, rebuilt at most once a second

-- Names: realm dropped for your own realm, like Group.lua
local function Normalize(name)
	if not name then return nil end
	local base, realm = strsplit("-", name)
	if realm and realm ~= (GetNormalizedRealmName and GetNormalizedRealmName()) then return name end
	return base
end
local function UnitKey(unit) return Normalize((GetUnitName and GetUnitName(unit, true)) or UnitName(unit)) end

local function List() ns.db.tankList = ns.db.tankList or {}; return ns.db.tankList end
local function Listed(name)
	if not name then return false end
	local l = List()
	return (l[name] or l[Normalize(name)]) and true or false
end
local function Sorted()
	local names = {}
	for name, on in pairs(List()) do if on then names[#names + 1] = name end end
	table.sort(names)
	return names
end

-- Detection ---------------------------------------------------------------------------
-- "list", "main tank", "main assist", "tank role" or nil
local function Detect(unit)
	if Listed(UnitKey(unit)) then return "list" end
	local ok, v = pcall(GetPartyAssignment, "MAINTANK", unit)
	if ok and Clean(v) then return "main tank" end
	ok, v = pcall(GetPartyAssignment, "MAINASSIST", unit)
	if ok and Clean(v) then return "main assist" end
	if UnitGroupRolesAssigned then
		ok, v = pcall(UnitGroupRolesAssigned, unit)
		if ok and Clean(v) == "TANK" then return "tank role" end
	end
	return nil
end

local function Scan()
	local now = GetTime()
	if now - scan.at < 1 then return scan end
	scan.at, scan.units, scan.class = now, {}, {}
	for _, unit in ipairs(ns.PB.Units()) do
		if UnitExists(unit) then
			local how = Detect(unit)
			scan.units[unit] = how or false
			local _, class = UnitClass(unit)
			if how and class then scan.class[class] = true end
		end
	end
	return scan
end
local function Dirty() scan.at = 0 end

-- true, how when the unit is a tank
function ns.IsTank(unit)
	if not unit or not UnitExists(unit) then return false end
	local how = Scan().units[unit]
	if how == nil then how = Detect(unit) end -- a unit token outside the group list
	if how then return true, how end
	return false
end

function ns.IsTankName(name)
	if Listed(name) then return true, "list" end
	local unit = ns.UnitForName and ns.UnitForName(Normalize(name))
	if unit then return ns.IsTank(unit) end
	return false
end

function ns.ClassHasTank(class) return Scan().class[class] or false end

-- Called by PartyBuff's Assignment with the blessing it picked. Returns key, greaterOK, note.
function ns.TankAssignment(unit, class, key, greaterOK)
	if key ~= "Salvation" or not ns.db.tankGuard then return key, greaterOK end
	local tank, how = ns.IsTank(unit)
	if not tank then
		-- a Greater Salvation would land on the tank too: single blessings for this class
		if greaterOK and ns.ClassHasTank(class) then return key, false, "tank in class: no Greater Salvation" end
		return key, greaterOK
	end
	local alt = (ns.db.tankBless or {})[class] or "Kings"
	if alt == "None" or alt == "Salvation" then return nil, false, "tank (" .. how .. "): Salvation skipped" end
	return alt, false, ("tank (%s): Salvation replaced by %s"):format(how, alt)
end

-- Sharing (LBND) -----------------------------------------------------------------------
local function CanShare() return IsInGroup() and ns.IsGroupLeader and ns.IsGroupLeader(ns.MyName()) or false end

-- "TANKS a,b,c" replaces the list; "TANKS +d,e" adds to it (long lists go in pieces)
local function Broadcast(target)
	if not ns.SendLB or not CanShare() then return end
	local chunk, first = "", true
	local function flush()
		ns.SendLB("TANKS " .. (first and "" or "+") .. chunk, target)
		chunk, first = "", false
	end
	for _, name in ipairs(Sorted()) do
		if #chunk > 0 and #chunk + #name + 1 > MSG_MAX then flush() end
		chunk = chunk .. (#chunk > 0 and "," or "") .. name
	end
	flush()
end

local function Receive(sender, rest)
	if sender == ns.MyName() then return end
	if not (ns.UnitForName and ns.UnitForName(sender)) or not ns.IsGroupLeader(sender) then return end
	local before = table.concat(Sorted(), ",")
	local add = rest:sub(1, 1) == "+"
	if add then rest = rest:sub(2) end
	local l = List()
	if not add then for k in pairs(l) do l[k] = nil end end
	for name in rest:gmatch("[^,%s]+") do l[name] = true end
	Dirty()
	local names = Sorted()
	if table.concat(names, ",") ~= before then
		ns.Print(sender .. (#names > 0 and (" set the tanks: " .. table.concat(names, ", ")) or " cleared the tank list."))
	end
	ns.Refresh()
end

-- Changing the list ----------------------------------------------------------------------
function ns.SetTank(name, on)
	name = Normalize(name)
	if not name or name == "" then return end
	List()[name] = on and true or nil
	Dirty(); Broadcast(); ns.Refresh()
end

function ns.ClearTanks()
	local l = List()
	for k in pairs(l) do l[k] = nil end
	Dirty(); Broadcast(); ns.Refresh()
end

-- /lb tank <name>: add or remove a tank; no name lists them
function ns.ToggleTank(arg)
	arg = strtrim(arg or "")
	if arg == "" then
		local names = Sorted()
		ns.Print("tanks: " .. (#names > 0 and table.concat(names, ", ") or "nobody on the list") .. ". /lb tank <name> adds or removes one.")
		local found = {}
		for unit, how in pairs(Scan().units) do
			if how and how ~= "list" then found[#found + 1] = (UnitName(unit) or unit) .. " (" .. how .. ")" end
		end
		table.sort(found)
		if #found > 0 then print("  also counted as tanks: " .. table.concat(found, ", ")) end
		return
	end
	local name
	for _, unit in ipairs(ns.PB.Units()) do -- match a group member whatever the case
		local n = UnitKey(unit)
		if n and strlower(n) == strlower(arg) then name = n break end
	end
	name = name or (arg:sub(1, 1):upper() .. arg:sub(2))
	local on = not Listed(name)
	ns.SetTank(name, on)
	ns.Print(name .. (on and " is now a tank." or " is no longer a tank.")
		.. ((IsInGroup() and not CanShare()) and " Only the leader or an assist shares the list." or ""))
end

-- What a tank of `class` gets from you instead of Salvation ("None" skips them), and a step
-- through the choices. Set in the Blessings window, on the line under your row.
function ns.TankBless(class) return (ns.db.tankBless or {})[class] or "Kings" end
function ns.StepTankBless(class, dir)
	local list, cur, idx = ns.TANK_CHOICES, ns.TankBless(class), 1
	for j, v in ipairs(list) do if v == cur then idx = j end end
	idx = (idx - 1 + dir) % #list + 1
	ns.db.tankBless = ns.db.tankBless or {}
	ns.db.tankBless[class] = list[idx]
	ns.Refresh()
end

-- Options page ------------------------------------------------------------------------

local function Row(i)
	local UI = ns.UI
	local r = CreateFrame("Button", nil, listChild)
	r:SetHeight(ROW_H)
	r.box = r:CreateTexture(nil, "ARTWORK")
	r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up"); r.box:SetSize(24, 24); r.box:SetPoint("LEFT", -2, 0)
	r.check = r:CreateTexture(nil, "OVERLAY")
	r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); r.check:SetAllPoints(r.box)
	local glow = r:CreateTexture(nil, "HIGHLIGHT")
	glow:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight"); glow:SetBlendMode("ADD"); glow:SetAllPoints(r.box)
	r.name = UI.Font(r, 13, UI.C.text)
	r.name:SetPoint("LEFT", r.box, "RIGHT", 2, 0); r.name:SetPoint("RIGHT", -2, 0)
	r.name:SetWordWrap(false)
	r:SetScript("OnClick", function(self)
		if not self.key then return end
		local on = not Listed(self.key)
		PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		ns.SetTank(self.key, on)
	end)
	r:SetScript("OnEnter", function(self)
		if not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.key)
		GameTooltip:AddLine(self.tip, 1, 1, 1)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = r
	return r
end

-- group members (sorted, class-coloured) plus listed names that aren't in the group
local function RefreshList()
	if not listChild then return end
	local UI = ns.UI
	local entries, seen = {}, {}
	for _, unit in ipairs(ns.PB.Units()) do
		if UnitExists(unit) then
			local name = UnitKey(unit)
			if name and not seen[name] then
				seen[name] = true
				local _, class = UnitClass(unit)
				entries[#entries + 1] = { name = name, class = class, how = Detect(unit) }
			end
		end
	end
	for name, on in pairs(List()) do
		if on and not seen[name] then seen[name] = true; entries[#entries + 1] = { name = name, away = true } end
	end
	table.sort(entries, function(a, b)
		if (a.away or false) ~= (b.away or false) then return not a.away end
		return a.name < b.name
	end)
	local colW = math.floor(listChild:GetWidth() / 2)
	for i, e in ipairs(entries) do
		local r = rows[i] or Row(i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", ((i - 1) % 2) * colW, -math.floor((i - 1) / 2) * ROW_H)
		r:SetWidth(colW - 6)
		r.key = e.name
		local cc = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
		local badge = ""
		if e.away then badge = UI.Hex(UI.C.dim) .. "  not in group|r"
		elseif e.how and e.how ~= "list" then badge = UI.Hex(UI.C.accent) .. "  " .. e.how .. "|r" end
		r.name:SetText((cc and UI.Hex({ cc.r, cc.g, cc.b }) or UI.Hex(UI.C.text)) .. e.name .. "|r" .. badge)
		r.check:SetShown(Listed(e.name))
		r.tip = e.away and "On the list but not in the group. Click to remove."
			or (e.how and e.how ~= "list" and ("Counts as a tank (" .. e.how .. ") even without the mark.") or "Click to mark as a tank.")
		r:Show()
	end
	for i = #entries + 1, #rows do rows[i]:Hide() end
	listChild:SetHeight(math.max(LIST_H, math.ceil(#entries / 2) * ROW_H))
	local max = math.max(listChild:GetHeight() - LIST_H, 0)
	if listScroll:GetVerticalScroll() > max then listScroll:SetVerticalScroll(max) end
	local text
	if IsInGroup() and not CanShare() then
		text = "Only the leader or an assist shares the list with the other Lightbound paladins; your changes stay on your side."
	else
		text = "Shared with the other Lightbound paladins in the group. Names stay on the list when people leave."
	end
	hint:SetText((#entries > 12 and "Scroll with the mouse wheel. " or "") .. text)
end

ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local W = UI.CONTENT_W
	local p = UI.NewPage("Tanks", "Who counts as a tank: marked tanks, the raid's main tanks and assists, and the tank role. What they get instead of Salvation is set in the Blessings window.")
	page = p
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "tankGuard", "Never Blessing of Salvation on a tank",
		"Tanks get the blessing on the line under your row in the Blessings window, never a Greater one.")) + 6)

	local y = p.y
	p:Add(UI.Section(p, y, "Tanks in the group") + 4)
	local clear = UI.Button(p, "Clear list", 90, 20)
	clear:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, y + 4)
	clear:SetScript("OnClick", function() ns.ClearTanks() end)
	listScroll = CreateFrame("ScrollFrame", nil, p)
	listScroll:SetPoint("TOPLEFT", 0, p.y); listScroll:SetSize(W, LIST_H)
	listChild = CreateFrame("Frame", nil, listScroll)
	listChild:SetSize(W, LIST_H)
	listScroll:SetScrollChild(listChild)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", function(self, d)
		local max = math.max(listChild:GetHeight() - LIST_H, 0)
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * ROW_H * 2)))
	end)
	p:Add(LIST_H + 4)
	hint = UI.Font(p, 12, UI.C.dim)
	hint:SetPoint("TOPLEFT", 0, p.y); hint:SetPoint("RIGHT", p, "RIGHT")
	p:SetScript("OnShow", function() M:Update() end)
end

-- Module ---------------------------------------------------------------------------------
function M:Update()
	if page and page:IsShown() then RefreshList() end
end

function M:Init()
	if ns.OnLB then ns.OnLB("TANKS", Receive) end
	if ns.OnLBSync then ns.OnLBSync(function(target) Broadcast(target) end) end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterEvent("PARTY_LEADER_CHANGED")
	pcall(ev.RegisterEvent, ev, "PLAYER_ROLES_ASSIGNED")
	ev:SetScript("OnEvent", function() Dirty(); M:Update() end)
end

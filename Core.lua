-- Shared setup: saved settings, safe aura reading, movable frames, /lb command.
local addonName, ns = ...

local _, class = UnitClass("player")
ns.isPaladin = class == "PALADIN"

ns.defaults = {
	enabled = true, sound = true, raid = true, world = true,
	snap = true, gridSize = 20, -- unlocked frames snap to a grid around the screen centre
	rfPoint = { "CENTER", "UIParent", "CENTER", 0, 180 },
	seal = true, sealEmptyInCombat = true, sealHeight = 220, sealWidth = 22,
	sealPoint = { "CENTER", "UIParent", "CENTER", -260, -60 },
	sealDur = {},
	wellRested = true, wellRestedMinutes = 5, wellRestedSound = true, wellRestedIcon = true, wellRestedKeep = false,
	wrPoint = { "CENTER", "UIParent", "CENTER", 0, 260 },
	wellFed = true, wellFedMinutes = 3, wellFedSound = true, wellFedIcon = true, wellFedKeep = false,
	wfPoint = { "CENTER", "UIParent", "CENTER", 0, 200 },
	blessEnabled = true, blessOnlyProblems = false, blessWarnMinutes = 1, blessHideResting = true, blessOnlyGrouped = false,
	blessTrack = { Might = true, Wisdom = false, Kings = true, Salvation = false, Light = false, Sanctuary = false },
	blPoint = { "CENTER", "UIParent", "CENTER", 0, -200 },
	pbEnabled = true, pbShowNext = true, pbRefreshMinutes = 1, pbKey = nil,
	pbSource = "Auto", pbGreater = true, pbRF = true, pbAura = true, freeAssign = false, minimap = true, minimapAngle = 220,
	ovEnabled = true, ovOnlyRaid = true, ovPoint = { "CENTER", "UIParent", "CENTER", -380, 120 },
	reagentBuy = true, reagentKings = 100, reagentDivinity = 5, reagentWarn = 20,
	procEnabled = true, procSound = true, prPoint = { "CENTER", "UIParent", "CENTER", 0, 110 },
	judgeEnabled = true, judgeMissing = true, jdPoint = { "CENTER", "UIParent", "CENTER", -90, 110 },
	trEnabled = true, trReckoning = true, trReckoningSound = false, trConsecration = true, trHolyShock = true,
	trHolyShockSound = false, trMana = true, trManaPct = 30, trManaSound = true,
	trPoint = { "CENTER", "UIParent", "CENTER", 0, 60 },
	jaEnabled = true, jaSound = true, jaOnlyMine = false, jaPoint = { "CENTER", "UIParent", "CENTER", 0, 10 }, judgeAssign = {},
	cdEnabled = true, cdOnlyRaid = false, cdShowSelf = true, cdPoint = { "CENTER", "UIParent", "CENTER", -380, -80 },
	auraWarn = true, auraOnlyGrouped = false, auraStrict = false, auraChoice = "Devotion",
	auPoint = { "CENTER", "UIParent", "CENTER", 80, 180 },
	-- pbSource and pbAssign (the old own class list) are only read once by MigrateClassList in Group.lua
	pbAssign = { WARRIOR = "Might", PALADIN = "Wisdom", HUNTER = "Might", ROGUE = "Might", PRIEST = "Wisdom",
		SHAMAN = "Wisdom", MAGE = "Wisdom", WARLOCK = "Wisdom", DRUID = "Wisdom" },
	pbPoint = { "CENTER", "UIParent", "CENTER", 0, -260 },
	clEnabled = true, clSolo = true, clSound = true, clRows = 5, clPets = false, clIgnore = {},
	clMode = "Grid", clPerRow = 5, clCell = 22, clNames = false, clRange = true,
	clPoint = { "TOPLEFT", "UIParent", "CENTER", 285, 190 },
	rqEnabled = true, rqSound = true, rqChat = false, rqGroupOnly = true, rqTTL = 60, rqRows = 4,
	rqPoint = { "CENTER", "UIParent", "CENTER", 380, -40 },
	diEnabled = true, diParty = false, diRows = 6, diAnnounce = true, diWarning = true,
	diPoint = { "CENTER", "UIParent", "CENTER", 380, -220 },
	rezAnnounce = true, rezWhisper = false,
	tankGuard = true, tankList = {},
	tankBless = { WARRIOR = "Might", DRUID = "Might", PALADIN = "Kings", HUNTER = "Kings", ROGUE = "Kings",
		PRIEST = "Kings", SHAMAN = "Kings", MAGE = "Kings", WARLOCK = "Kings" },
}

-- Secret values (hidden from addons in combat on Forever). Newer clients expose canaccessvalue,
-- older ones issecretvalue; Decursive uses the former. Support both, assume readable otherwise.
local issecretvalue, canaccessvalue = _G.issecretvalue, _G.canaccessvalue
local function IsSecret(v)
	if issecretvalue then return issecretvalue(v) end
	if canaccessvalue then return not canaccessvalue(v) end
	return false
end
ns.IsSecret = IsSecret
local isSecret = IsSecret
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>"

local function Clean(v)
	-- secret first: even comparing a secret value with nil is not allowed
	if isSecret(v) or v == nil then return nil end
	return v
end

-- True in combat. InCombatLockdown() only turns true after PLAYER_REGEN_DISABLED has fired, so
-- also ask UnitAffectingCombat (true already then); a secret answer counts as in combat.
function ns.InCombat()
	if InCombatLockdown() then return true end
	local ok, c = pcall(UnitAffectingCombat, "player")
	if not ok or isSecret(c) then return true end
	return c and true or false
end

-- Reads the player's buffs. Returns a table name -> { icon, duration, expires, mine }
-- and a flag that is true when some auras were hidden from addons (combat restrictions).
-- mine: true if you cast it, false if someone else did, nil if the source can't be read.
function ns.ReadPlayerBuffs()
	local buffs, hidden = {}, false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok then return buffs, true end
		if not a then break end
		local name = Clean(a.name)
		if not name or name == RESTRICTED then
			hidden = true
		else
			local src = Clean(a.sourceUnit)
			local mine
			if src then mine = (src == "player") end
			-- the same name from two casters: keep yours
			if not (buffs[name] and buffs[name].mine) then
				buffs[name] = { icon = Clean(a.icon), duration = Clean(a.duration), expires = Clean(a.expirationTime), mine = mine }
			end
		end
	end
	if ns.InCombat() then
		-- seals and some self buffs can simply be left out of the list in combat
		hidden = true
	end
	return buffs, hidden
end

function ns.SpellName(spellID)
	if not spellID or isSecret(spellID) then return nil end
	local ok, name = pcall(function()
		if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
		return (GetSpellInfo(spellID))
	end)
	return ok and Clean(name) or nil
end

-- Movable frames ------------------------------------------------------------

ns.movers = {}
ns.unlocked = false

function ns.MakeMovable(frame, key)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	-- our own drag (not StartMoving) so the frame can lock onto the grid while it moves; the
	-- frame keeps the anchor point it is saved by (Cleanse stays TOPLEFT so it grows down/right)
	frame:SetScript("OnDragStart", function(self) ns.BeginDrag(self, key) end)
	frame:SetScript("OnDragStop", function(self) ns.EndDrag(self, key) end)
	-- while unlocked, the mouse wheel scales the frame (saved per frame in db.scales)
	frame:SetScript("OnMouseWheel", function(self, delta)
		if not ns.unlocked or InCombatLockdown() then return end
		local old = self:GetScale()
		local new = math.floor((old + delta * 0.1) * 10 + 0.5) / 10
		new = math.max(0.5, math.min(2.5, new))
		if new == old then return end
		-- keep the saved anchor point where it is on screen
		local point = (ns.db[key] and ns.db[key][1]) or "CENTER"
		local l, r, t, b = self:GetLeft(), self:GetRight(), self:GetTop(), self:GetBottom()
		if not l then return end
		local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
		local y = point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2
		self:SetScale(new)
		ns.db.scales = ns.db.scales or {}
		ns.db.scales[key] = (new ~= 1) and new or nil
		ns.db[key] = { point, "UIParent", "BOTTOMLEFT", x * old / new, y * old / new }
		ns.ApplyPoint(self, key)
		ns.Print(("frame scale %d%%"):format(new * 100 + 0.5))
	end)
	ns.movers[#ns.movers + 1] = { frame = frame, key = key }
end

-- Grid snapping -----------------------------------------------------------------------
-- Lines every gridSize (UI units) out from the screen centre, so frames line up with each other
-- and sit the same distance left and right of the middle. The frame's own anchor point (the
-- corner or centre its position is saved by) is what snaps. Hold Shift while dropping to skip it.
local function GridSize() return math.max(4, math.floor(tonumber(ns.db.gridSize) or 20)) end

-- the frame's anchor point (the one its position is saved by), in UIParent units
local function AnchorXY(frame, point)
	local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not l then return nil end
	local s = frame:GetScale() -- parent is UIParent
	return (point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2) * s,
		(point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2) * s
end

local function CursorXY()
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	return x / s, y / s
end

local function Snap(ax, ay)
	if not ns.db.snap or IsShiftKeyDown() then return ax, ay end
	local cx, cy = UIParent:GetCenter()
	local g = GridSize()
	return cx + math.floor((ax - cx) / g + 0.5) * g, cy + math.floor((ay - cy) / g + 0.5) * g
end

-- one drag at a time; a separate driver frame so the dragged frame's own OnUpdate stays intact
local drag = { frame = nil }
local driver = CreateFrame("Frame")
driver:Hide()
local function Place(frame, point, ax, ay)
	local fs = frame:GetScale() -- SetPoint offsets are in the frame's own scale
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, "BOTTOMLEFT", ax / fs, ay / fs)
end
driver:SetScript("OnUpdate", function()
	local f = drag.frame
	if not f then driver:Hide() return end
	-- the button came up without an OnDragStop (released over another frame): finish here
	if not IsMouseButtonDown("LeftButton") then ns.EndDrag(f, drag.key) return end
	local x, y = CursorXY()
	local ax, ay = Snap(x + drag.ox, y + drag.oy)
	drag.ax, drag.ay = ax, ay
	Place(f, drag.point, ax, ay)
end)

function ns.BeginDrag(frame, key)
	if not ns.unlocked or InCombatLockdown() then return end
	local point = (ns.db[key] and ns.db[key][1]) or "CENTER"
	local ax, ay = AnchorXY(frame, point)
	if not ax then return end
	local x, y = CursorXY()
	drag.frame, drag.key, drag.point = frame, key, point
	drag.ox, drag.oy, drag.ax, drag.ay = ax - x, ay - y, ax, ay
	driver:Show()
end

function ns.EndDrag(frame, key)
	if drag.frame ~= frame then return end
	driver:Hide()
	local fs = frame:GetScale()
	ns.db[key] = { drag.point, "UIParent", "BOTTOMLEFT", drag.ax / fs, drag.ay / fs }
	drag.frame = nil
	ns.ApplyPoint(frame, key)
end

-- the grid itself, shown while frames are unlocked
local grid, panel
local ShowGrid

-- small bar at the top while unlocked: grid size, snap on/off and Lock, so nothing has to be
-- changed in the options while placing frames. The mouse wheel over it changes the size too.
local function GridPanel()
	if panel then return panel end
	local UI = ns.UI
	panel = CreateFrame("Frame", "LightboundGridPanel", UIParent, "BackdropTemplate")
	panel:SetSize(330, 36)
	panel:SetPoint("TOP", UIParent, "TOP", 0, -12)
	panel:SetFrameStrata("DIALOG")
	panel:EnableMouse(true)
	if UI and UI.Box then UI.Box(panel, 0.92) end
	local function Btn(text, w)
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		b:SetSize(w, 22); b:SetText(text)
		return b
	end
	local function Resize(delta)
		ns.db.gridSize = math.max(4, math.min(100, GridSize() + delta))
		ns.db.snap = true
		ShowGrid(ns.unlocked)
	end
	local minus = Btn("-", 24); minus:SetPoint("LEFT", 10, 0)
	minus:SetScript("OnClick", function() Resize(IsShiftKeyDown() and -1 or -4) end)
	panel.size = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	panel.size:SetPoint("LEFT", minus, "RIGHT", 6, 0); panel.size:SetWidth(70)
	local plus = Btn("+", 24); plus:SetPoint("LEFT", panel.size, "RIGHT", 6, 0)
	plus:SetScript("OnClick", function() Resize(IsShiftKeyDown() and 1 or 4) end)
	local snap = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	snap:SetSize(24, 24); snap:SetPoint("LEFT", plus, "RIGHT", 10, 0)
	snap:SetScript("OnClick", function(self) ns.db.snap = self:GetChecked() and true or false; ShowGrid(ns.unlocked) end)
	local snapText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	snapText:SetPoint("LEFT", snap, "RIGHT", 2, 0); snapText:SetText("Snap")
	panel.snap = snap
	local lock = Btn("Lock", 60); lock:SetPoint("RIGHT", -10, 0)
	lock:SetScript("OnClick", function() if ns.unlocked then ns.ToggleMove() end end)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, d) Resize(d > 0 and 4 or -4) end)
	panel:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Grid")
		GameTooltip:AddLine("- / + or the mouse wheel: grid size (Shift: 1 px steps)", 1, 1, 1)
		GameTooltip:AddLine("Hold Shift while dragging a frame to place it freely", 1, 1, 1)
		GameTooltip:Show()
	end)
	panel:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return panel
end

function ShowGrid(show)
	if show then
		local pn = GridPanel()
		pn.size:SetText(GridSize() .. " px")
		pn.snap:SetChecked(ns.db.snap and true or false)
		pn:Show()
	elseif panel then
		panel:Hide()
	end
	if not show or not ns.db.snap then if grid then grid:Hide() end return end
	if not grid then
		grid = CreateFrame("Frame", nil, UIParent)
		grid:SetAllPoints(UIParent)
		grid:SetFrameStrata("BACKGROUND")
		grid.lines = {}
	end
	local g = GridSize()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local used = 0
	local function Line(vertical, offset, centre)
		used = used + 1
		local t = grid.lines[used]
		if not t then t = grid:CreateTexture(nil, "BACKGROUND"); grid.lines[used] = t end
		t:ClearAllPoints()
		if centre then t:SetColorTexture(1, 0.82, 0, 0.45) else t:SetColorTexture(1, 1, 1, 0.08) end
		if vertical then
			t:SetPoint("TOP", grid, "TOP", offset, 0); t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0); t:SetWidth(1)
		else
			t:SetPoint("LEFT", grid, "LEFT", 0, offset); t:SetPoint("RIGHT", grid, "RIGHT", 0, offset); t:SetHeight(1)
		end
		t:Show()
	end
	for i = 0, math.floor(w / 2 / g) do
		Line(true, i * g, i == 0)
		if i > 0 then Line(true, -i * g) end
	end
	for i = 0, math.floor(h / 2 / g) do
		Line(false, i * g, i == 0)
		if i > 0 then Line(false, -i * g) end
	end
	for i = used + 1, #grid.lines do grid.lines[i]:Hide() end
	grid:Show()
end
ns.ShowGrid = ShowGrid

function ns.ApplyPoint(frame, key)
	local p = ns.db[key]
	local scale = ns.db.scales and ns.db.scales[key] or 1
	if frame:GetScale() ~= scale then frame:SetScale(scale) end
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end

-- Click-to-cast overlays ----------------------------------------------------------
-- A secure button laid over a warning icon: click it to cast the spell. It is a separate frame on
-- UIParent, positioned to match the icon, so the icon itself stays unprotected and can show and
-- hide in combat. Lua only moves, shows or hides the overlay out of combat. A secure state driver
-- hides it the moment combat starts (the icon may vanish or move mid-fight), and the next
-- out-of-combat Sync brings it back. Create overlays out of combat only.
function ns.CastOverlay(owner)
	local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
	b:RegisterForClicks("AnyDown", "AnyUp") -- the secure handler acts on the phase ActionButtonUseKeyDown picks
	b:SetAttribute("_onstate-lbcombat", [[ if newstate == 1 or newstate == "1" then self:Hide() end ]])
	RegisterStateDriver(b, "lbcombat", "[combat] 1; 0")
	b:SetAttribute("type", "macro")
	b:Hide()
	b:SetScript("OnEnter", function(self)
		if not self.spell then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.spell)
		GameTooltip:AddLine("Click to cast (out of combat)", 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- spell nil hides the overlay; call after the owner was shown or hidden
	function b:Sync(spell, unit)
		if InCombatLockdown() then return end
		local left, bottom, w, h = owner:GetRect()
		if not spell or ns.unlocked or not owner:IsVisible() or not left then
			self.spell = nil
			self:Hide()
			return
		end
		local s = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
		self:SetFrameStrata(owner:GetFrameStrata())
		self:SetFrameLevel(owner:GetFrameLevel() + 10)
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
		self:SetSize(w * s, h * s)
		local macro = ("/cast [nocombat,@%s] %s"):format(unit or "player", spell)
		if self:GetAttribute("macrotext") ~= macro then self:SetAttribute("macrotext", macro) end
		self.spell = spell
		self:Show()
	end
	return b
end

-- Modules and events ----------------------------------------------------------

ns.modules = {}
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name ~= addonName then return end
	LightboundDB = LightboundDB or {}
	ns.db = LightboundDB
	for k, v in pairs(ns.defaults) do
		if ns.db[k] == nil then ns.db[k] = type(v) == "table" and CopyTable(v) or v end
	end
	if ns.db.point then ns.db.rfPoint, ns.db.point = ns.db.point, nil end -- v1.0 setting
	-- v4.3: the buff timers became wide cards; move Well Fed off the old spot next to Well-Rested
	local wf = ns.db.wfPoint
	if wf and wf[1] == "CENTER" and wf[3] == "CENTER" and wf[4] == 70 and wf[5] == 260 then
		ns.db.wfPoint = CopyTable(ns.defaults.wfPoint)
	end
	if ns.db.pbSource == "PallyPower" then ns.db.pbSource = "Group" end -- v2.4 setting
	self:UnregisterEvent("ADDON_LOADED")
	if not ns.isPaladin then return end
	for _, m in ipairs(ns.modules) do m:Init() end
end)

-- Slash command ---------------------------------------------------------------

local function Print(msg) print("|cffffd100Lightbound:|r " .. msg) end
local function OnOff(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end

local function Refresh()
	for _, m in ipairs(ns.modules) do
		if m.Layout then m:Layout() end
		m:Update()
	end
end
ns.Refresh = Refresh
ns.Print = Print

function ns.ToggleMove()
	if InCombatLockdown() then Print("leave combat first.") return end
	ns.unlocked = not ns.unlocked
	for _, m in ipairs(ns.movers) do m.frame:EnableMouse(ns.unlocked); m.frame:EnableMouseWheel(ns.unlocked) end
	ShowGrid(ns.unlocked)
	Print(ns.unlocked and ("unlocked: drag the frames, scroll on one to resize it. Lock them again when done."
		.. (ns.db.snap and " They snap to the grid (hold Shift to place freely)." or "")) or "locked.")
	Refresh()
end

function ns.ResetPositions()
	if InCombatLockdown() then Print("leave combat first.") return end
	local db = ns.db
	for k, v in pairs(ns.defaults) do
		if k:find("Point$") then db[k] = CopyTable(v) end
	end
	db.scales = nil
	for _, m in ipairs(ns.movers) do ns.ApplyPoint(m.frame, m.key) end
	Print("positions and sizes reset.")
	Refresh()
end

SLASH_LIGHTBOUND1 = "/lb"
SLASH_LIGHTBOUND2 = "/lightbound"
SLASH_LIGHTBOUND3 = "/rfr"
SlashCmdList.LIGHTBOUND = function(msg)
	if not ns.isPaladin then Print("only does something on a paladin.") return end
	local db = ns.db
	local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
	if cmd == "toggle" then
		db.enabled = not db.enabled; Print("Righteous Fury warning " .. OnOff(db.enabled))
	elseif cmd == "sound" then
		db.sound = not db.sound; Print("sound " .. OnOff(db.sound))
	elseif cmd == "rfraid" then
		db.raid = not db.raid; Print("warn in raids " .. OnOff(db.raid))
	elseif cmd == "world" then
		db.world = not db.world; Print("warn in party outside instances " .. OnOff(db.world))
	elseif cmd == "seal" then
		db.seal = not db.seal; Print("seal timer " .. OnOff(db.seal))
	elseif cmd == "empty" then
		db.sealEmptyInCombat = not db.sealEmptyInCombat; Print("show empty seal bar in combat " .. OnOff(db.sealEmptyInCombat))
	elseif cmd == "height" and tonumber(arg) then
		db.sealHeight = math.max(60, math.min(600, tonumber(arg))); Print("seal bar height " .. db.sealHeight)
	elseif cmd == "rested" then
		db.wellRested = not db.wellRested; Print("Well-Rested warning " .. OnOff(db.wellRested))
	elseif cmd == "fed" then
		db.wellFed = not db.wellFed; Print("Well Fed warning " .. OnOff(db.wellFed))
	elseif cmd == "blessings" or cmd == "bless" or cmd == "raid" or cmd == "assign" then
		if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end
		return
	elseif cmd == "minimap" then
		db.minimap = not db.minimap; Print("minimap button " .. OnOff(db.minimap))
	elseif cmd == "ignore" then
		db.clIgnore = db.clIgnore or {}
		if arg and arg ~= "" then
			db.clIgnore[arg] = not db.clIgnore[arg] or nil
			Print("cleanse list " .. (db.clIgnore[arg] and "ignores" or "no longer ignores") .. " '" .. arg .. "'")
		else
			local names = {}
			for n in pairs(db.clIgnore) do names[#names + 1] = n end
			table.sort(names)
			Print("ignored debuffs: " .. (#names > 0 and table.concat(names, ", ") or "none") .. ". /lb ignore <name> toggles one.")
			return
		end
	elseif cmd == "why" then
		if ns.ExplainPartyBuff then ns.ExplainPartyBuff() end
		return
	elseif cmd == "tank" or cmd == "tanks" then
		-- names keep their case: split the original message again
		if ns.ToggleTank then ns.ToggleTank((select(2, strsplit(" ", strtrim(msg or ""), 2)))) end
		return
	elseif cmd == "grid" or cmd == "snap" then
		local n = tonumber(arg)
		if n then
			db.gridSize = math.max(4, math.min(100, math.floor(n))); db.snap = true
			Print("snap to grid on, " .. db.gridSize .. " px")
		else
			db.snap = not db.snap; Print("snap to grid " .. OnOff(db.snap))
		end
		ShowGrid(ns.unlocked)
	elseif cmd == "move" then
		ns.ToggleMove() return
	elseif cmd == "reset" then
		ns.ResetPositions() return
	elseif cmd == "" or cmd == "config" or cmd == "options" then
		if ns.ToggleOptions then ns.ToggleOptions() end
		return
	else
		Print("/lb opens the options window. Commands: toggle " .. OnOff(db.enabled) .. ", sound " .. OnOff(db.sound) .. ", rfraid " .. OnOff(db.raid)
			.. ", world " .. OnOff(db.world) .. ", seal " .. OnOff(db.seal) .. ", empty " .. OnOff(db.sealEmptyInCombat) .. ", height <n>, rested " .. OnOff(db.wellRested) .. ", blessings (window, also /lb raid), minimap " .. OnOff(db.minimap) .. ", ignore <debuff>, tank <name>, why, move, grid [size] " .. OnOff(db.snap) .. ", reset")
		return
	end
	Refresh()
end

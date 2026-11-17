-- Options window (/lb): flat dark style with a sidebar, one page per feature.
-- Also adds a launcher entry in the game's Settings > AddOns list.
local addonName, ns = ...
if not ns.isPaladin then return end -- not a paladin: load nothing (see Core.lua)

-- Style -----------------------------------------------------------------------------
-- Colours, fonts and textures come from the active skin (Skin.lua); ns.UI holds the helpers.
local UI = ns.UI
local C, TEX, MEDIA = UI.C, UI.TEX, UI.MEDIA
local Tex, Font, Title, Hex, Skin, Watermark = UI.Tex, UI.Font, UI.Title, UI.Hex, UI.Skin, UI.Watermark
local WIDTH, HEIGHT, SIDE_W, HEADER_H, FOOTER_H = 760, 620, 170, 44, 52
local PAD = 26
local CONTENT_W = WIDTH - SIDE_W - PAD * 2

local win, controls, pages, navButtons = nil, {}, {}, {}

-- Widgets ---------------------------------------------------------------------------
-- the flat skin's button: a dark box with a 1px edge that lightens under the mouse
local function FlatButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b.bg = Tex(b, "BACKGROUND", C.button); b.bg:SetAllPoints()
	UI.Border(b)
	local fs = b:CreateFontString(nil, "OVERLAY")
	UI.SetFont(fs, "ui", 12)
	b:SetFontString(fs)
	return b
end

local function Button(parent, text, w, h, accent)
	local b = UI.IsFlat() and FlatButton(parent) or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, h or 24)
	b:SetText(text ~= "" and text or " ")
	b.label = b:GetFontString()
	UI.SetFont(b.label, "ui", 12)
	b.label:SetTextColor(unpack(C.accent))
	b.label:SetPoint("LEFT", 6, 0); b.label:SetPoint("RIGHT", -6, 0)
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.SetLabel = function(self, t) self:SetText(t ~= "" and t or " ") end
	b:SetScript("OnEnter", function(self)
		self.label:SetTextColor(1, 1, 1)
		if self.bg then self.bg:SetColorTexture(unpack(C.hover)) end
	end)
	b:SetScript("OnLeave", function(self)
		self.label:SetTextColor(unpack(C.accent))
		if self.bg then self.bg:SetColorTexture(unpack(C.button)) end
	end)
	return b
end

ns.UI.Button = Button

-- Toggle switch with label and optional description. Returns the row and its height.
local function Toggle(page, x, y, w, label, desc, get, set)
	local h = desc and 40 or 26
	local row = CreateFrame("Button", nil, page)
	row:SetPoint("TOPLEFT", x, y)
	row:SetSize(w, h)
	local track, knob
	if UI.IsFlat() then
		-- a 14px box with a 1px edge; checked fills it with the accent
		local box = CreateFrame("Frame", nil, row)
		box:SetSize(14, 14); box:SetPoint("TOPLEFT", 2, -5)
		Tex(box, "BACKGROUND", C.button):SetAllPoints()
		UI.Border(box)
		knob = Tex(box, "ARTWORK", C.accent)
		knob:SetPoint("TOPLEFT", 3, -3); knob:SetPoint("BOTTOMRIGHT", -3, 3)
		local glow = Tex(box, "HIGHLIGHT", C.highlight); glow:SetAllPoints()
		track = CreateFrame("Frame", nil, row) -- the label anchors to the old 26px check area
		track:SetSize(26, 26); track:SetPoint("TOPLEFT", -4, 1)
	else
		track = row:CreateTexture(nil, "ARTWORK")
		track:SetTexture(TEX.check)
		track:SetSize(26, 26)
		track:SetPoint("TOPLEFT", -4, 1)
		knob = row:CreateTexture(nil, "OVERLAY")
		knob:SetTexture(TEX.checkMark)
		knob:SetAllPoints(track)
		local glow = row:CreateTexture(nil, "HIGHLIGHT")
		glow:SetTexture(TEX.checkHighlight)
		glow:SetBlendMode("ADD")
		glow:SetAllPoints(track)
	end
	local text = Font(row, 14, C.text)
	text:SetPoint("TOPLEFT", track, "TOPRIGHT", 4, -6)
	text:SetPoint("RIGHT", row, "RIGHT")
	text:SetText(label)
	if desc then
		local d = Font(row, 12, C.dim)
		d:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
		d:SetPoint("RIGHT", row, "RIGHT")
		d:SetText(desc)
	end
	row.Sync = function()
		knob:SetShown(get() and true or false)
	end
	row:SetScript("OnClick", function()
		local v = not get()
		set(v)
		PlaySound(v and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		row.Sync(); ns.Refresh()
	end)
	row:SetScript("OnEnter", function() text:SetTextColor(1, 1, 1) end)
	row:SetScript("OnLeave", function() text:SetTextColor(unpack(C.text)) end)
	controls[#controls + 1] = row
	return row, h
end

local function DBToggle(page, x, y, w, key, label, desc, onSet)
	return Toggle(page, x, y, w, label, desc,
		function() return ns.db[key] end,
		function(v) ns.db[key] = v; if onSet then onSet(v) end end)
end

-- Thin slider with accent fill and value on the right. Height 46.
local function Slider(page, y, label, key, minV, maxV, step, suffix)
	local title = Font(page, 14, C.text)
	title:SetPoint("TOPLEFT", 0, y)
	title:SetText(label)
	local value = Font(page, 14, C.accent)
	value:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
	value:SetJustifyH("RIGHT")
	local s = CreateFrame("Slider", nil, page, "BackdropTemplate")
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("TOPLEFT", 0, y - 21)
	s:SetSize(CONTENT_W, 17)
	s:SetHitRectInsets(0, 0, -4, -4)
	s:SetBackdrop(TEX.slider)
	s:SetThumbTexture(TEX.sliderThumb)
	if UI.IsFlat() then
		-- a slim track and a small accent block for the thumb
		s:SetBackdropColor(unpack(C.track)); s:SetBackdropBorderColor(unpack(C.border))
		local thumb = s:GetThumbTexture()
		thumb:SetSize(8, 17); thumb:SetVertexColor(unpack(C.accent))
	end
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
	local syncing = false
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		value:SetText(v .. (suffix or ""))
		if syncing then return end
		ns.db[key] = v
		ns.Refresh()
	end)
	s.Sync = function(self)
		syncing = true
		self:SetValue(ns.db[key])
		value:SetText(ns.db[key] .. (suffix or ""))
		syncing = false
	end
	controls[#controls + 1] = s
	return s, 46
end

-- "Label        < Value >" selector. Left-click next, right-click previous.
local function Cycle(page, y, label, values, get, set, note, labelColor)
	local text = Font(page, 14, labelColor or C.text)
	-- with a note, the label sits higher and the note goes under it (beside the button a long
	-- note ran into the label); the row keeps its height so full pages don't grow
	text:SetPoint("TOPLEFT", 0, note and y or (y - 5))
	text:SetText(label)
	local b = Button(page, "", 190, 26)
	b:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local noteText
	if note then
		noteText = Font(page, 12, C.dim)
		noteText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
		noteText:SetWidth(CONTENT_W - 200) -- up to the button; a second anchor would fight the TOPLEFT
		noteText:SetJustifyH("LEFT")
		noteText:SetWordWrap(false)
	end
	b.Sync = function(self)
		self:SetLabel(Hex(C.dim) .. "<|r   " .. (get() or "None") .. "   " .. Hex(C.dim) .. ">|r")
		if noteText then noteText:SetText(note() or "") end
	end
	b:SetScript("OnClick", function(self, mouse)
		local cur, idx = get(), 1
		for i, v in ipairs(values) do if v == cur then idx = i end end
		idx = (mouse == "RightButton") and (idx - 2) % #values + 1 or idx % #values + 1
		set(values[idx])
		self:Sync(); ns.Refresh()
	end)
	controls[#controls + 1] = b
	return b, 34
end

local function Section(page, y, text)
	local fs = Title(page, 11, C.accent)
	fs:SetPoint("TOPLEFT", 0, y)
	fs:SetText(text:upper())
	local line = Tex(page, "ARTWORK", C.border)
	line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -5)
	line:SetSize(CONTENT_W, 1)
	return 26
end

-- Pages -----------------------------------------------------------------------------
local function NewPage(title, subtitle)
	local p = CreateFrame("Frame", nil, win)
	p:SetPoint("TOPLEFT", SIDE_W + PAD, -HEADER_H - 20)
	p:SetSize(CONTENT_W, HEIGHT - HEADER_H - FOOTER_H - 30)
	p:Hide()
	local t = Title(p, 19)
	t:SetPoint("TOPLEFT")
	t:SetText(title)
	local s = Font(p, 13, C.dim)
	s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
	s:SetPoint("RIGHT", p, "RIGHT")
	s:SetText(subtitle)
	p.y = -58
	p.Add = function(self, h) self.y = self.y - h end
	pages[#pages + 1] = { title = title, frame = p }
	return p
end

-- Key binder: label, the key button and a Clear button. Click, then press a key (Esc cancels);
-- the combo goes to ns.db[dbKey] and onSet(combo or nil) runs. `what` names it in chat. Height 40.
local capturers = {} -- key buttons; a capture in progress stops when the window hides
local KEY_MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, LMETA = 1, RMETA = 1 }
local function KeyButton(page, y, label, dbKey, onSet, what)
	local kl = Font(page, 14, C.text)
	kl:SetPoint("TOPLEFT", 0, y - 5)
	kl:SetText(label)
	local clear = Button(page, "Clear", 70, 26)
	clear:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
	local keyBtn = Button(page, "", 190, 26, true)
	keyBtn:SetPoint("RIGHT", clear, "LEFT", -8, 0)
	keyBtn.Sync = function(self)
		if self.capturing then return end
		self:SetLabel(ns.db[dbKey] or "Click to set")
	end
	local function Stop()
		keyBtn.capturing = false
		keyBtn:EnableKeyboard(false)
		keyBtn:SetScript("OnKeyDown", nil)
		keyBtn:Sync()
	end
	keyBtn.Stop = Stop
	keyBtn:SetScript("OnClick", function(self)
		if InCombatLockdown() then ns.Print("leave combat first.") return end
		self.capturing = true
		self:SetLabel("Press a key  (Esc cancels)")
		self:EnableKeyboard(true)
		self:SetPropagateKeyboardInput(false)
		self:SetScript("OnKeyDown", function(_, key)
			if KEY_MODS[key] then return end
			if key ~= "ESCAPE" then
				local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
					.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
				ns.db[dbKey] = combo
				if onSet then onSet(combo) end
				ns.Print((what or label:lower()) .. " set to " .. combo .. ".")
			end
			Stop()
		end)
	end)
	clear:SetScript("OnClick", function() ns.db[dbKey] = nil; if onSet then onSet(nil) end; keyBtn:Sync() end)
	controls[#controls + 1] = keyBtn
	capturers[#capturers + 1] = keyBtn
	return keyBtn, 40
end

-- Other modules add their own options page: ns.optionPages[#ns.optionPages + 1] = function(UI) local p = UI.NewPage(...) ... end
-- Widgets return (widget, height); add the height with p:Add(h). CONTENT_W is the usable width.
ns.optionPages = ns.optionPages or {}
ns.UI.NewPage, ns.UI.DBToggle, ns.UI.Toggle, ns.UI.Slider, ns.UI.Cycle, ns.UI.Section, ns.UI.KeyButton = NewPage, DBToggle, Toggle, Slider, Cycle, Section, KeyButton
ns.UI.CONTENT_W = CONTENT_W

local function BuildRF()
	local p = NewPage("Righteous Fury", "Warns with an icon and a sound when you're grouped without Righteous Fury.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "enabled", "Warn when Righteous Fury is missing")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "world", "Also in party outside instances", "Not while resting in a city or inn.")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "raid", "Also in raids")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "sound", "Play a warning sound")) + 6)
end

local function BuildAura()
	local p = NewPage("Aura", "Warns when no aura is up. The buff key can cast it for you.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "auraWarn", "Warn when no aura is up")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "auraStrict", "Also warn when it isn't the assigned aura")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "auraOnlyGrouped", "Only when in a group")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbAura", "Cast the aura with the buff key")) + 14)
	p:Add(select(2, Cycle(p, p.y, "My aura", ns.AURAS,
		function() return ns.db.auraChoice end,
		function(v) ns.db.auraChoice = v end,
		function() local w = ns.WantedAura and ns.WantedAura(); return w and ("using " .. w) or "" end)))
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y - 4); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("When the buff key uses group assignments, the aura the group assigned you wins.")
end

local function BuildSeal()
	local p = NewPage("Seal timer", "A vertical bar that empties while your seal runs out.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "seal", "Show the seal timer")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "sealEmptyInCombat", "Show an empty bar in combat", "Reminds you to put a seal up when you have none.")) + 16)
	p:Add(select(2, Slider(p, p.y, "Bar height", "sealHeight", 60, 600, 10, " px")) + 8)
	p:Add(select(2, Slider(p, p.y, "Bar width", "sealWidth", 10, 60, 1, " px")))
end

local function BuildBlessings()
	local p = NewPage("My buffs", "Icons with time left for the blessings you want on yourself.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessEnabled", "Show my blessings")) + 6)
	p:Add(Section(p, p.y - 4, "Track") + 6)
	local colW = math.floor(W / 3)
	for i, b in ipairs(ns.BLESSINGS) do
		local col, rowI = (i - 1) % 3, math.floor((i - 1) / 3)
		Toggle(p, col * colW, p.y - rowI * 30, colW - 10, b.key, nil,
			function() return ns.db.blessTrack[b.key] end,
			function(v) ns.db.blessTrack[b.key] = v end)
	end
	p:Add(math.ceil(#ns.BLESSINGS / 3) * 30 + 8)
	p:Add(Section(p, p.y, "When") + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessOnlyProblems", "Only show missing or nearly expired blessings")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessOnlyGrouped", "Only when in a group")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessHideResting", "Hide in cities and inns")) + 12)
	Slider(p, p.y, "Nearly expired at", "blessWarnMinutes", 1, 10, 1, " min")
end

local function BuildKey()
	local p = NewPage("Buff key", "One key, out of combat: Righteous Fury, then your aura, then the blessings in your row of the Blessings window.")
	local W = CONTENT_W
	-- who gets what lives in the Blessings window only; this page is about the key itself
	local rb = Button(p, "Open blessings", 150, 26, true)
	rb:SetPoint("TOPLEFT", 0, p.y)
	rb:SetScript("OnClick", function()
		win:Hide()
		if ns.OpenRaidWindow then ns.OpenRaidWindow() elseif ns.ToggleRaidWindow then ns.ToggleRaidWindow() end
	end)
	p:Add(40)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbEnabled", "Buff the group with one key", nil,
		function() ns.ApplyPartyBuffKey() end)) + 10)

	p:Add(select(2, KeyButton(p, p.y, "Key", "pbKey", function() ns.ApplyPartyBuffKey() end, "buff key")) + 6)

	p:Add(Section(p, p.y, "How it casts") + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbShowNext", "Show what the next press will cast")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbRF", "Cast Righteous Fury first if it's missing")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbGreater", "Greater Blessings in raid", "Needs the spell and Symbol of Kings in your bags.")) + 12)
	Slider(p, p.y, "Rebuff with time left", "pbRefreshMinutes", 0, 4, 1, " min")
end

local function BuildRested()
	local p = NewPage("Extras", "Levelling helpers and the minimap button.")
	local W = CONTENT_W
	-- grid snapping is set on the grid itself while frames are unlocked (and /lb grid)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "minimap", "Minimap button  (left-click options, right-click blessings)")) + 10)
	-- one compact block per buff timer: warn / sound / icon on one line, then the slider
	local function Timer(title, key, test, note)
		local y = p.y - 4
		p:Add(Section(p, y, title) + 2)
		local tb = Button(p, "Test", 70, 20)
		tb:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, y + 4)
		tb:SetScript("OnClick", test)
		if note then
			local n = Font(p, 12, C.dim)
			n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
			n:SetText(note)
			p:Add(20)
		end
		local third = math.floor(W / 3)
		DBToggle(p, 0, p.y, third, key, "Warn")
		DBToggle(p, third, p.y, third, key .. "Sound", "Sound")
		DBToggle(p, third * 2, p.y, third, key .. "Icon", "Countdown icon")
		p:Add(32)
		p:Add(select(2, DBToggle(p, 0, p.y, W, key .. "Keep", "Keep following it after it's gone  (rebuff warning)",
			nil, function() ns.UpdateBuffTimers() end)) + 4)
		p:Add(select(2, Slider(p, p.y, "Warn with time left", key .. "Minutes", 1, 30, 1, " min")) + 8)
	end
	Timer("Well-Rested", "wellRested", function() ns.TestWellRested() end, "Cozy Sleeping Bag buff.")
	Timer("Well Fed", "wellFed", function() ns.TestWellFed() end, "Food buff, also more experience on Forever. Also tells you when it's gone.")
end

local function BuildSkin()
	local p = NewPage("Skin", "How Lightbound's frames look. A new skin applies after a reload.")
	local W = CONTENT_W
	local names, keyOf = {}, {}
	for _, key in ipairs(UI.SkinOrder) do
		local n = UI.Skins[key].name
		names[#names + 1] = n; keyOf[n] = key
	end
	local about = {
		lightbound = "Warm gold frames, the emblem cards with their slow light.",
		blizzard = "The game's own grey and silver tooltips, dialogs and buttons.",
		flat = "Thin black edges on dark grey, plain text. Fits EllesmereUI and ElvUI.",
	}
	local pending = Font(p, 12, C.accent)
	local reload = Button(p, "Reload now", 120, 24)
	p:Add(select(2, Cycle(p, p.y, "Skin", names,
		function() return UI.Skins[ns.db.skin or "lightbound"].name end,
		function(n) ns.db.skin = keyOf[n]; p.skinRow.Sync() end,
		function() return about[ns.db.skin or "lightbound"] end)) + 12)
	reload:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, p.y)
	pending:SetPoint("TOPLEFT", 0, p.y - 5); pending:SetPoint("RIGHT", reload, "LEFT", -10, 0)
	reload:SetScript("OnClick", function() ReloadUI() end)
	-- the reload line shows only when the picked skin differs from the one these frames were built with
	local built = UI.Active().name
	local row = { Sync = function()
		local changed = UI.Skins[ns.db.skin or "lightbound"].name ~= built
		pending:SetText(changed and "Reload to switch to " .. UI.Skins[ns.db.skin or "lightbound"].name .. "." or "")
		reload:SetShown(changed)
	end }
	controls[#controls + 1] = row
	p.skinRow = row
	p:Add(30)
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetWidth(W); n:SetJustifyH("LEFT")
	n:SetText("Colours that carry meaning stay the same in every skin: red for missing or expiring, the debuff type colours in the Cleanse grid, class colours on names.")
end

local function BuildCombat()
	local p = NewPage("Combat", "Shows when Hammer of Wrath or Exorcism can be cast, and your Judgement on the target.")
	local W = CONTENT_W
	p:Add(Section(p, p.y - 4, "Procs") + 2)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "procEnabled", "Hammer of Wrath and Exorcism alert",
		"Hammer of Wrath when the target is under 20%, Exorcism on undead and demons. Only when off cooldown.")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "procSound", "Play a sound when it shows")) + 14)
	p:Add(Section(p, p.y, "Judgement") + 2)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "judgeEnabled", "Show your Judgement on the target", "Icon with seconds left.")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "judgeMissing", "Remind me when it's missing", "A dim icon in combat when your target has no Judgement from you.")) + 4)
end

local function BuildOverview()
	local p = NewPage("Raid overview", "Each class you bless: how many miss it and the shortest time left. Click a row to bless that class.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "ovEnabled", "Show the overview")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "ovOnlyRaid", "Only in raids", "Off: also in a party.")) + 14)
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("Red = someone is missing it, gold = running low. In a raid a click casts the Greater Blessing on the whole class (needs Symbol of Kings). Clicks work out of combat only. Unlock frames to move it.")
end

local function BuildReagents()
	local p = NewPage("Reagents", "Buys reagents at any vendor that sells them, and warns when you run low.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "reagentBuy", "Buy reagents at vendors automatically")) + 10)
	p:Add(select(2, Slider(p, p.y, "Keep Symbol of Kings", "reagentKings", 0, 200, 10, "")) + 6)
	p:Add(select(2, Slider(p, p.y, "Keep Symbol of Divinity", "reagentDivinity", 0, 20, 1, "")) + 6)
	p:Add(select(2, Slider(p, p.y, "Warn below (Symbol of Kings)", "reagentWarn", 0, 100, 5, "")) + 6)
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("Symbol of Kings is bought once you know a Greater Blessing, Symbol of Divinity once you know Divine Intervention. 0 turns one off.")
end

local function Select(i)
	for j, pg in ipairs(pages) do
		pg.frame:SetShown(j == i)
		local nb = navButtons[j]
		nb.bar:SetShown(j == i)
		nb.bg:SetShown(j == i)
		nb.text:SetTextColor(unpack(j == i and C.accent or C.dim))
	end
	ns.db.optionsPage = i
end

local function Build()
	win = CreateFrame("Frame", "LightboundOptions", UIParent)
	win:SetSize(WIDTH, HEIGHT)
	win:SetPoint("CENTER")
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:Hide()
	tinsert(UISpecialFrames, win:GetName()) -- Escape closes it
	Skin(win, "Lightbound")
	local wm = Watermark(win, 300, 0.06)
	wm:SetPoint("CENTER", win, "CENTER", SIDE_W / 2, -10)

	-- header (drag to move)
	local header = CreateFrame("Frame", nil, win)
	header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(HEADER_H)
	Tex(header, "BACKGROUND", C.header):SetAllPoints()
	local hl = Tex(header, "ARTWORK", C.border); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() win:StartMoving() end)
	header:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
	local logo = header:CreateTexture(nil, "ARTWORK"); logo:SetSize(34, 34); logo:SetPoint("LEFT", 8, -2)
	logo:SetTexture(MEDIA .. "Logo64")
	local title = Title(header, 15); title:SetPoint("LEFT", logo, "RIGHT", 6, 0); title:SetText("Paladin buffs")
	local ver = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(addonName, "Version") or ""
	local sub = Font(header, 12, C.dim); sub:SetPoint("RIGHT", -16, -2); sub:SetText("v" .. ver)

	-- sidebar
	local side = CreateFrame("Frame", nil, win)
	side:SetPoint("TOPLEFT", 0, -HEADER_H); side:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
	side:SetWidth(SIDE_W)
	Tex(side, "BACKGROUND", C.side):SetAllPoints()
	local sl = Tex(side, "ARTWORK", C.border); sl:SetPoint("TOPRIGHT"); sl:SetPoint("BOTTOMRIGHT"); sl:SetWidth(1)

	BuildRF(); BuildAura(); BuildSeal(); BuildCombat(); BuildBlessings(); BuildKey()
	BuildOverview(); BuildReagents(); BuildRested(); BuildSkin()
	for _, build in ipairs(ns.optionPages) do build(ns.UI) end

	-- sidebar rows shrink when there are many pages so they all fit
	local step = math.min(36, math.floor((HEIGHT - HEADER_H - FOOTER_H - 20) / #pages))
	for i, pg in ipairs(pages) do
		local nb = CreateFrame("Button", nil, side)
		nb:SetSize(SIDE_W - 1, step - 2)
		nb:SetPoint("TOPLEFT", 0, -10 - (i - 1) * step)
		nb.bg = nb:CreateTexture(nil, "BACKGROUND")
		nb.bg:SetTexture(TEX.navHighlight)
		nb.bg:SetBlendMode("ADD"); nb.bg:SetVertexColor(unpack(C.navGlow))
		if UI.IsFlat() then nb.bg:SetBlendMode("BLEND") end
		nb.bg:SetAllPoints(); nb.bg:Hide()
		nb.bar = Tex(nb, "ARTWORK", C.accent); nb.bar:SetPoint("TOPLEFT"); nb.bar:SetPoint("BOTTOMLEFT"); nb.bar:SetWidth(3); nb.bar:Hide()
		nb.text = Font(nb, step < 30 and 13 or 14, C.dim); nb.text:SetPoint("LEFT", 18, 0); nb.text:SetText(pg.title)
		nb:SetScript("OnClick", function() Select(i) end)
		nb:SetScript("OnEnter", function(self) if not pg.frame:IsShown() then self.text:SetTextColor(unpack(C.text)) end end)
		nb:SetScript("OnLeave", function(self) if not pg.frame:IsShown() then self.text:SetTextColor(unpack(C.dim)) end end)
		navButtons[i] = nb
	end

	-- footer
	local footer = CreateFrame("Frame", nil, win)
	footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(FOOTER_H)
	Tex(footer, "BACKGROUND", C.header):SetAllPoints()
	local fl = Tex(footer, "ARTWORK", C.border); fl:SetPoint("TOPLEFT"); fl:SetPoint("TOPRIGHT"); fl:SetHeight(1)
	local move = Button(footer, "Unlock frames", 150, 28)
	move:SetPoint("LEFT", 16, 0)
	local reset = Button(footer, "Reset positions", 150, 28)
	reset:SetPoint("LEFT", move, "RIGHT", 8, 0)
	reset:SetScript("OnClick", function() ns.ResetPositions() end)
	local hint = Font(footer, 12, C.dim)
	hint:SetPoint("LEFT", reset, "RIGHT", 14, 0)
	hint:SetText("Unlock shows every frame so you can drag it into place.")
	-- remember whether this button unlocked the frames: closing the options relocks only those,
	-- not frames unlocked with /lb move
	move:SetScript("OnClick", function() ns.ToggleMove(); win.unlockedHere = ns.unlocked; win.Sync() end)

	win.Sync = function()
		for _, c in ipairs(controls) do c:Sync() end
		move:SetLabel(ns.unlocked and "Lock frames" or "Unlock frames")
	end
	win:SetScript("OnShow", function()
		win.Sync()
		Select(math.min(ns.db.optionsPage or 1, #pages))
	end)
	win:SetScript("OnHide", function()
		for _, b in ipairs(capturers) do if b.capturing then b.Stop() end end
		if win.unlockedHere and ns.unlocked and not InCombatLockdown() then ns.ToggleMove() end
		win.unlockedHere = nil
	end)
end

function ns.ToggleOptions()
	if not ns.db then return end
	if not win then Build() end
	if win:IsShown() then win:Hide() else win:Show() end
end

-- Launcher in Settings > AddOns ------------------------------------------------
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
	local panel = CreateFrame("Frame")
	local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText("Lightbound")
	local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
	d:SetText("Paladin buffing and self-buff helper. Type /lb in chat to open the options.")
	local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetSize(180, 26)
	b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
	b:SetText("Open options")
	b:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		ns.ToggleOptions()
	end)
	pcall(function()
		local category = Settings.RegisterCanvasLayoutCategory(panel, "Lightbound")
		Settings.RegisterAddOnCategory(category)
	end)
end

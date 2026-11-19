-- Twist bar for Unsealed Wrath (Retribution): stored seal stacks, a swing bar and the moment to swap.
--  * Pips: copies of a seal stored by your swings. Drawn by Blizzard from the Echo buffs themselves
--    (a native AuraContainer writes the true stack count into our bar, in combat too, while Lua can't
--    read it). Where that isn't available, counted pips from TwistLogic.lua are shown instead.
--  * Bar: fills toward your next main-hand swing (PLAYER_SWING). As soon as three copies of the build
--    seal are stored it says TWIST: they last 15 s, so swapping early only makes the burst come sooner.
--  * Judgement and Holy Strike icons with their cooldown.
-- When it's time to change seals (three stored, and again after the burst) TWIST pulses above the bar.
-- Shown in combat for paladins who have Unsealed Wrath.
local _, ns = ...
if not ns.isPaladin then return end -- not a paladin: load nothing (see Core.lua)

local M = {}
ns.modules[#ns.modules + 1] = M
ns.optionPages = ns.optionPages or {}

local L = ns.TwistLogic
local isSecret = ns.IsSecret
local function Clean(v) if isSecret(v) or v == nil then return nil end return v end -- secret first: no compare

local TALENT = "Unsealed Wrath"
local ECHO = { ["Seal of Command"] = 1311703, ["Seal of Righteousness"] = 1311704 } -- Echo of <Seal> buffs
local SEALS = { "Seal of Command", "Seal of Righteousness", "Seal of the Crusader", "Seal of Justice",
	"Seal of Wisdom", "Seal of Light" }
local COLORS = {
	["Seal of Righteousness"] = { 0.95, 0.85, 0.35 },
	["Seal of the Crusader"]  = { 1.00, 0.55, 0.15 },
	["Seal of Command"]       = { 0.90, 0.30, 0.25 },
	["Seal of Justice"]       = { 0.55, 0.55, 0.95 },
	["Seal of Light"]         = { 1.00, 1.00, 0.70 },
	["Seal of Wisdom"]        = { 0.35, 0.65, 1.00 },
}
local CDS = { { name = "Judgement", dur = 10 }, { name = "Holy Strike", dur = 10 } } -- dur until read once
local W, H, ICON, PIP, GAP = 220, 14, 34, 10, 4
-- what the target shows when your swing didn't land (UNIT_COMBAT action); a block or absorb still lands
local AVOIDED = { MISS = true, DODGE = true, PARRY = true, EVADE = true, IMMUNE = true, DEFLECT = true }

local state = L.New()
local f, bar, sealIcon, text, flash, pips, cdIcons
local call -- big pulsing TWIST above the bar, for the two moments you act (one key with /castsequence)
local PIPS_W = L.MAX * (PIP * 2) + (L.MAX - 1) * 3
local echo = {}         -- [seal] = { bar } from the native display, once it is set up
local native = nil      -- nil = not tried yet, true = Blizzard draws the true stacks, false = counted pips
local known = false     -- Unsealed Wrath learned, or its Echo buff seen since the last talent change
local seenEcho = false

local function IsSeal(name) return name and name:find("^Seal of") ~= nil end
local function Short(name) return name and (name:gsub("^Seal of t?h?e? ?", "")) or "" end

local function Texture(spell)
	local ok, tex = pcall(C_Spell.GetSpellTexture, spell)
	return (ok and Clean(tex)) or 134400
end

local function Known(spell)
	local ok, info = pcall(C_Spell.GetSpellInfo, spell)
	return ok and Clean(info) ~= nil
end

local function CheckKnown()
	known = Known(TALENT) or seenEcho
	for _, b in ipairs(cdIcons or {}) do b.known = Known(b.spell.name) end
end


-- the Echo buffs, out of combat only; nil when they can't be read
local function ReadEchoes()
	if ns.InCombat() or not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
	local by = {}
	for seal, id in pairs(ECHO) do
		local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
		if not ok then return nil end
		if type(a) == "table" then
			by[seal] = { n = Clean(a.applications) or 1, expires = Clean(a.expirationTime) }
			seenEcho = true; known = true
		end
	end
	return by
end

-- out of combat the client tells the truth: seal and stacks
local function Sync()
	if ns.InCombat() then return end
	local seal = ns.ActiveSeal and ns.ActiveSeal()
	L.Seal(state, seal)
	local by = ReadEchoes()
	if by then L.Sync(state, by, GetTime()) end
end

-- Cooldown icons --------------------------------------------------------------------
local function MakeIcon(spell)
	local b = CreateFrame("Frame", nil, f)
	b:SetSize(ICON, ICON)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.tex:SetTexture(Texture(spell.name))
	ns.UI.IconBorder(b)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(); b.cd:SetDrawEdge(false)
	b.spell = spell
	b.readyAt = 0
	return b
end

-- the real cooldown (not the global one) when the client lets us read it: start, duration
local function ReadCD(b)
	local ok, cd = pcall(C_Spell.GetSpellCooldown, b.spell.name)
	if not ok or type(cd) ~= "table" then return nil end
	local start, dur = Clean(cd.startTime), Clean(cd.duration)
	if start and dur and dur > 1.5 and start > 0 then return start, dur end
end

local function SetCD(b, start, dur)
	b.readyAt = start + dur
	b.cd:SetCooldown(start, dur)
end

-- after your cast: the real cooldown when readable, else the length learned earlier
local function StartCD(b)
	local start, dur = ReadCD(b)
	if start then b.spell.dur = dur else start, dur = GetTime(), b.spell.dur end
	SetCD(b, start, dur)
end

-- the cooldown often shows up a moment after the cast: correct the guess then
local function RefreshCDs()
	for _, b in ipairs(cdIcons) do
		local start, dur = ReadCD(b) -- also after a reload, with no cast of ours timed yet
		if start and start + dur ~= b.readyAt then b.spell.dur = dur; SetCD(b, start, dur) end
	end
end

local function UpdateIcons()
	local x = ICON + GAP + W + GAP * 2
	for _, b in ipairs(cdIcons) do
		local show = ns.db.twistCDs and (ns.unlocked or b.known)
		b:SetShown(show and true or false)
		if show then
			b:ClearAllPoints(); b:SetPoint("LEFT", f, "LEFT", x, 0)
			x = x + ICON + GAP
			local ready = ns.unlocked or GetTime() >= b.readyAt
			b.tex:SetDesaturated(not ready); b:SetAlpha(ready and 1 or 0.7)
		end
	end
end

-- Drawing ---------------------------------------------------------------------------
local function Call(msg)
	if msg then
		call:SetText(msg)
		if not call:IsShown() then
			call:Show(); call.pulse:Play()
			if ns.db.twistSound and not ns.unlocked then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
		end
	elseif call:IsShown() then
		call.pulse:Stop(); call:SetAlpha(1); call:Hide()
	end
end

local function SetPips(n, seal)
	local c = COLORS[seal] or ns.UI.C.accent
	for i, p in ipairs(pips) do
		if i <= n then
			if n >= L.MAX then p:SetColorTexture(unpack(ns.UI.C.accent)) else p:SetColorTexture(c[1], c[2], c[3], 1) end
		else
			p:SetColorTexture(0.15, 0.15, 0.15, 0.9)
		end
	end
end

-- the true stacks, when the engine-written bars can be read back (nil when they are secret)
local function NativeStacks()
	if not native then return nil end
	local by = {}
	for seal, e in pairs(echo) do
		local ok, v = pcall(e.bar.GetValue, e.bar)
		if not ok or isSecret(v) or type(v) ~= "number" then return nil end
		by[seal] = { n = math.floor(v + 0.5) }
	end
	return by
end

local function Draw(now)
	local db = ns.db
	-- the native bars only know Echo of Command and Righteousness; other seals stay counted
	local covered = not state.stackSeal or ECHO[state.stackSeal] ~= nil
	local truth = NativeStacks()
	if truth then
		local any = false
		for _, e in pairs(truth) do if e.n > 0 then any = true end end
		if any or covered then L.Sync(state, truth, now) end
	end
	local build, burst = db.twistBuild, db.twistBurst
	local mode = L.Advice(state, now, build, burst)
	local nextAt = L.NextSwing(state, now)
	if nextAt and state.swingDur and state.swingDur > 0 then
		bar:SetValue(1 - math.max(0, nextAt - now) / state.swingDur)
	else
		bar:SetValue(0)
	end
	local c = COLORS[state.seal] or { 0.6, 0.6, 0.6 }
	bar:SetStatusBarColor(c[1], c[2], c[3], 0.9)
	sealIcon:SetTexture(state.seal and Texture(state.seal) or Texture(build))
	sealIcon:SetDesaturated(not state.seal)
	-- native: empty slots under Blizzard's fill (counted pips for the seals it doesn't cover)
	if native and (not state.stackSeal or ECHO[state.stackSeal]) then SetPips(0) else SetPips(state.stacks, state.stackSeal) end

	local accent = ns.UI.C.accent
	if mode == "swap" then
		Call("TWIST"); text:SetText("» " .. Short(burst)); text:SetTextColor(unpack(accent))
	else
		Call(mode == "back" and "TWIST" or nil)
		if mode == "burst" then text:SetText("swing!"); text:SetTextColor(unpack(accent))
		elseif mode == "back" then text:SetText("» " .. Short(build)); text:SetTextColor(unpack(accent))
		elseif mode == "noseal" then text:SetText("NO SEAL"); text:SetTextColor(1, 0.25, 0.25)
		elseif mode == "other" then text:SetText(Short(state.seal)); text:SetTextColor(0.7, 0.7, 0.7)
		else text:SetText("") end
	end
	UpdateIcons()
end

local function DrawSample()
	bar:SetValue(0.85); bar:SetStatusBarColor(0.90, 0.30, 0.25, 0.9)
	sealIcon:SetTexture(Texture(ns.db.twistBuild)); sealIcon:SetDesaturated(false)
	SetPips(3, ns.db.twistBuild)
	Call("TWIST"); text:SetText("» " .. Short(ns.db.twistBurst)); text:SetTextColor(unpack(ns.UI.C.accent))
	UpdateIcons()
end

-- Native display -------------------------------------------------------------------
-- One AuraContainer per Echo buff, on the player, with one slot that only takes that buff. Inside
-- initializeFrame (the one moment the AuraButton is ours) a StatusBar is registered as its
-- application bar: from then on Blizzard writes the buff's stacks into it, 0 when it is gone.
local function InitEcho(e, holder, ab, seal)
	ab:ClearAllPoints(); ab:SetAllPoints(holder)
	if ab.SetMouseClickEnabled then ab:SetMouseClickEnabled(false) end
	if ab.SetMouseMotionEnabled then ab:SetMouseMotionEnabled(false) end
	local sb = CreateFrame("StatusBar", nil, ab)
	sb:SetAllPoints(ab)
	sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	local c = COLORS[seal] or { 1, 0.82, 0 }
	local tex = sb:GetStatusBarTexture()
	if tex then tex:SetVertexColor(c[1], c[2], c[3], 1) end
	local opts = { maxApplications = L.MAX }
	if Enum.StatusBarInterpolation then opts.interpolation = Enum.StatusBarInterpolation.Immediate end
	ab:SetApplicationBar(sb, opts)
	-- the gaps between the three pips, above the fill
	local top = CreateFrame("Frame", nil, ab)
	top:SetAllPoints(ab); top:SetFrameLevel(sb:GetFrameLevel() + 2)
	for i = 1, L.MAX - 1 do
		local gap = top:CreateTexture(nil, "OVERLAY")
		gap:SetColorTexture(0, 0, 0, 1)
		gap:SetSize(3, PIP)
		gap:SetPoint("LEFT", ab, "LEFT", i * (PIP * 2) + (i - 1) * 3, 0)
	end
	e.bar = sb -- set last: proves the whole setup ran
end

-- Out of combat only. Any failure falls back to counted pips for the session.
local function SetupNative()
	if native ~= nil or InCombatLockdown() then return end
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	local level = 3
	for seal, id in pairs(ECHO) do
		local e = {}
		local holder = CreateFrame("Frame", nil, f)
		holder:SetPoint("TOPLEFT", f, "TOPLEFT", ICON + GAP, 0)
		holder:SetSize(PIPS_W, PIP)
		holder:SetFrameLevel(f:GetFrameLevel() + level); level = level + 3
		local ok = pcall(function()
			local c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
			c:SetAllPoints(holder)
			c:EnableMouse(false)
			c:AddAuraSlot("LB_ECHO_" .. id, "HELPFUL", {
				sortMethod = 0, sortDirection = 0,
				candidateFilters = { includeSpellIDs = { [id] = true } },
				-- Blizzard runs this through securecall, which swallows errors: e.bar tells
				initializeFrame = function(ab) pcall(InitEcho, e, holder, ab, seal) end,
			})
			c:SetUnit("player")
			c:SetShown(true)
			c:SetEnabled(true)
			e.container = c
		end)
		if not ok or not e.bar then
			if e.container then pcall(e.container.SetEnabled, e.container, false) end
			holder:Hide()
			for _, other in pairs(echo) do if other.holder then other.holder:Hide() end end
			echo, native = {}, false
			return
		end
		e.holder = holder
		echo[seal] = e
	end
	native = true
end

local sealCheck = 0
local function OnUpdate()
	local now = GetTime()
	-- the seal ran out (30 s, or it was never renewed): SealTimer knows from your casts
	if now > sealCheck then
		sealCheck = now + 0.5
		if state.seal and ns.ActiveSeal and not ns.ActiveSeal() then L.Seal(state, nil) end
	end
	L.Settle(state, now) -- a swing with no buff update after it didn't land
	Draw(now)
end

function M:Update(entering)
	if not f then return end
	f:SetScript("OnUpdate", nil)
	if ns.unlocked then f:Show(); DrawSample() return end
	if native == nil then SetupNative() end
	local db = ns.db
	local fighting = entering or ns.InCombat()
	if not db.twist or not known or not fighting or UnitIsDeadOrGhost("player") then
		f:Hide(); Call(nil)
		return
	end
	f:Show()
	f:SetScript("OnUpdate", OnUpdate)
	Draw(GetTime())
end

function M:Init()
	f = CreateFrame("Frame", "LightboundTwistFrame", UIParent)
	f:SetSize(ICON + GAP + W, ICON)
	f:SetFrameStrata("LOW")
	f:Hide()

	sealIcon = f:CreateTexture(nil, "ARTWORK")
	sealIcon:SetSize(ICON, ICON); sealIcon:SetPoint("LEFT")
	sealIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	pips = {}
	for i = 1, L.MAX do
		local p = f:CreateTexture(nil, "ARTWORK")
		p:SetSize(PIP * 2, PIP)
		p:SetPoint("TOPLEFT", f, "TOPLEFT", ICON + GAP + (i - 1) * (PIP * 2 + 3), 0)
		pips[i] = p
	end

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0, 0, 0, 0.7)
	bg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ICON + GAP - 1, -1)
	bg:SetSize(W + 2, H + 2)

	bar = CreateFrame("StatusBar", nil, f)
	bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ICON + GAP, 0)
	bar:SetSize(W, H)
	bar:SetStatusBarTexture(ns.UI.TEX.statusbar)
	bar:SetMinMaxValues(0, 1)

	text = bar:CreateFontString(nil, "OVERLAY")
	ns.UI.SetFont(text, "narrow", 12, "OUTLINE")
	text:SetPoint("CENTER", bar, "CENTER", 0, 0)

	call = f:CreateFontString(nil, "OVERLAY")
	ns.UI.SetFont(call, "narrow", 22, "OUTLINE")
	call:SetPoint("BOTTOM", f, "TOP", 0, 6)
	call:SetTextColor(unpack(ns.UI.C.accent))
	call:Hide()
	call.pulse = call:CreateAnimationGroup()
	call.pulse:SetLooping("BOUNCE")
	local pa = call.pulse:CreateAnimation("Alpha")
	pa:SetFromAlpha(1); pa:SetToAlpha(0.35); pa:SetDuration(0.45)
	local ps = call.pulse:CreateAnimation("Scale")
	if ps.SetScaleFrom then ps:SetScaleFrom(1, 1); ps:SetScaleTo(1.12, 1.12) else ps:SetScale(1.12, 1.12) end
	ps:SetDuration(0.45)

	-- a short flash over the bar when stored copies are used (or Command procs)
	flash = bar:CreateTexture(nil, "OVERLAY", nil, 7)
	flash:SetAllPoints(); flash:SetColorTexture(1, 0.9, 0.5, 1); flash:SetAlpha(0)
	flash.anim = flash:CreateAnimationGroup()
	local a = flash.anim:CreateAnimation("Alpha")
	a:SetFromAlpha(0.6); a:SetToAlpha(0); a:SetDuration(0.35)
	flash.anim:SetScript("OnFinished", function() flash:SetAlpha(0) end)

	cdIcons = {}
	for i, s in ipairs(CDS) do cdIcons[i] = MakeIcon(s) end
	f:SetWidth(ICON + GAP + W + #CDS * (ICON + GAP) + GAP)

	ns.MakeMovable(f, "twistPoint")
	ns.ApplyPoint(f, "twistPoint")

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
		"PLAYER_DEAD", "SPELL_UPDATE_COOLDOWN" }) do ev:RegisterEvent(e) end
	pcall(ev.RegisterEvent, ev, "PLAYER_SWING") -- Forever's own swing event
	pcall(ev.RegisterEvent, ev, "TRAIT_CONFIG_UPDATED")
	pcall(ev.RegisterEvent, ev, "PLAYER_TALENT_UPDATE")
	ev:RegisterUnitEvent("UNIT_AURA", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:RegisterUnitEvent("UNIT_COMBAT", "target")
	local auraAt -- last update of your buffs: a landed swing updates the Echo buff right away
	ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
		local now = GetTime()
		if event == "UNIT_AURA" then
			auraAt = now
			L.Hit(state, now)
		end
		if event == "UNIT_COMBAT" then -- unit, action, flags, amount: only the action is readable in combat
			local action = Clean(a2)
			if action and AVOIDED[action] then L.Avoid(state, now) end
			return
		elseif event == "PLAYER_SWING" then -- duration, swingType (0 = main hand)
			local dur, kind = Clean(a1), Clean(a2)
			if kind ~= 0 or not dur or dur <= 0 then return end
			if L.Swing(state, dur, now) == "burst" then flash.anim:Stop(); flash.anim:Play() end
			if auraAt == now then L.Hit(state, now) end -- the buff update came first, same frame
			return
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then -- unit, castGUID, spellID
			local name = ns.SpellName(a3)
			if not name then return end
			if IsSeal(name) then
				-- a seal's proc comes through here too (Seal of Command 20424): not in your spellbook
				if ns.IsOwnSpell(a3, state.swingAt and now - state.swingAt < 0.3) then
					L.Seal(state, name)
				elseif f:IsShown() then
					flash.anim:Stop(); flash.anim:Play()
				end
			else
				for _, b in ipairs(cdIcons) do if b.spell.name == name then StartCD(b) end end
			end
			return
		elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "TRAIT_CONFIG_UPDATED"
			or event == "PLAYER_TALENT_UPDATE" then
			if event ~= "SPELLS_CHANGED" then seenEcho = false end -- a respec: ask again
			CheckKnown()
		elseif event == "SPELL_UPDATE_COOLDOWN" then
			RefreshCDs()
			return
		elseif event == "PLAYER_DEAD" then
			L.Seal(state, nil)
		end
		if event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then Sync() end
		M:Update(event == "PLAYER_REGEN_DISABLED")
	end)
	CheckKnown()
	Sync()
	RefreshCDs()
	M:Update()
end

-- Options ---------------------------------------------------------------------------
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Twist", "Unsealed Wrath: stored seal copies and when to swap, on a swing bar. Shown in combat when you have the talent.")
	local CW = UI.CONTENT_W
	p:Add(select(2, UI.DBToggle(p, 0, p.y, CW, "twist", "Show the twist bar *",
		"Three pips for the copies your swings store, and TWIST above the bar each time you change seals.")) + 14)
	p:Add(select(2, UI.Cycle(p, p.y, "Build with", SEALS,
		function() return ns.db.twistBuild end, function(v) ns.db.twistBuild = v end)) + 4)
	p:Add(select(2, UI.Cycle(p, p.y, "Swap to", SEALS,
		function() return ns.db.twistBurst end, function(v) ns.db.twistBurst = v end)) + 8)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, CW, "twistCDs", "Judgement and Holy Strike icons")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, CW, "twistSound", "Sound when it's time to twist")) + 6)
	local n = UI.Font(p, 12, UI.C.dim)
	n:SetPoint("TOPLEFT", 0, p.y - 4); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("* Best effort. Forever hides the combat log and your buffs from addons in combat, so TWIST is "
		.. "counted from your swings (leaving out a miss, dodge or parry on your target) and can be one off. "
		.. "The pips are drawn by the game from your Echo buff and are always right: trust them.")
end

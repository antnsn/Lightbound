-- Trackers: a row of small combat helpers in one movable frame, each with its own toggle.
--  * Reckoning: stack count of the Reckoning proc, gold at 4 (the bomb is ready).
--  * Consecration: 8 s countdown from your cast, dim while the spell is still on cooldown.
--  * Holy Shock: cooldown sweep, bright when ready.
--  * Wisdom: low mana in combat and no Judgement of Wisdom from you on the target.
-- Icons that don't apply (toggle off, spell unknown, nothing to show) are left out and the rest close up.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M
ns.optionPages = ns.optionPages or {}

local isSecret = ns.IsSecret -- see Core.lua
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>" -- placeholder the client returns for hidden aura names
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end
local function CleanName(v) v = Clean(v); if v == RESTRICTED then return nil end return v end

local RECKONING_ID, RECKONING_MAX, RECKONING_TIME = 20178, 4, 8
local CONSECRATION_TIME = 8
local HOLY_SHOCK_CD = 15   -- until the real cooldown has been read once
local SIZE, GAP = 40, 6
local ORDER = { "reck", "cons", "shock", "wisdom" }

-- icons for spells the client can't give a texture for (talent procs, spells not learned)
local FALLBACK_ICON = { Reckoning = 135882, Consecration = 135926, ["Holy Shock"] = 135972, ["Seal of Wisdom"] = 135970 }

local frame, icons
local reck            -- { n, icon, at } last readable Reckoning stacks
local reckIcon        -- texture of the Reckoning buff once seen (matches it when the name is hidden)
local reckSounded = false
local cons            -- { at, ends } from your last Consecration cast
local consCD          -- Consecration cooldown length once read
local consSet         -- cast time the countdown sweep was last set with
local hs = { readyAt = 0, dur = 0, at = 0 } -- Holy Shock cooldown, read or inferred from your cast
local hsOnCd = false
local hsSet           -- start time the sweep was last set with
local reckCache       -- { n, icon, hidden } from the last full aura read; cleared on UNIT_AURA
local manaSounded = false

local function Known(spell)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spell) end
		return GetSpellInfo(spell)
	end)
	return ok and info ~= nil
end

local function Texture(spell)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
		return GetSpellTexture(spell)
	end)
	return (ok and Clean(tex)) or FALLBACK_ICON[spell] or 134400
end

local function HostileTarget()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
end

local function Sound(name, fallback)
	PlaySound((SOUNDKIT and SOUNDKIT[name]) or fallback, "Master")
end

-- Cooldown of a spell: readyAt, duration, start. 0, 0 when ready (the global cooldown doesn't count).
-- nil when the client hides it (combat).
local function ReadCooldown(spell)
	local ok, cd = pcall(C_Spell.GetSpellCooldown, spell)
	if not ok or type(cd) ~= "table" then return nil end
	local start, dur = Clean(cd.startTime), Clean(cd.duration)
	if not start or not dur then return nil end
	if dur > 1.5 and start > 0 then return start + dur, dur, start end
	return 0, 0, 0
end

-- Icons ---------------------------------------------------------------------------
local function Set(b, tex, count, label)
	b.tex:SetTexture(tex)
	b.count:SetText(count or "")
	b.label:SetText(label or "")
end

local function ClearCD(b)
	if b.cd.Clear then b.cd:Clear() else b.cd:SetCooldown(0, 0) end
end

local function Stacks(a)
	local n = Clean(a.applications)
	return (n and n >= 1) and n or 1
end

local function Bright(b, bright)
	b.tex:SetDesaturated(not bright)
	b:SetAlpha(bright and 1 or 0.7)
end

local function Arrange()
	local x = 0
	for _, key in ipairs(ORDER) do
		local b = icons[key]
		if b:IsShown() then
			b:ClearAllPoints()
			b:SetPoint("LEFT", frame, "LEFT", x, 0)
			x = x + SIZE + GAP
		end
	end
	frame:SetShown(x > 0)
end

-- Reckoning -----------------------------------------------------------------------
-- stacks, icon of the Reckoning proc; nil when it's not up. Third value true = some buffs were unreadable.
local function ReadReckoningNow()
	if C_UnitAuras.GetPlayerAuraBySpellID then
		local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, RECKONING_ID)
		if ok and type(a) == "table" then return Stacks(a), Clean(a.icon) end
	end
	local hidden = false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok then return nil, nil, true end
		if not a then break end
		local name, id, icon = CleanName(a.name), Clean(a.spellId), Clean(a.icon)
		if name == "Reckoning" or id == RECKONING_ID or (name == nil and reckIcon and icon == reckIcon) then
			return Stacks(a), icon
		end
		if not name then hidden = true end
	end
	return nil, nil, hidden
end

-- cached until your auras change, so the ticker doesn't walk 40 buffs every 0.2 s
local function ReadReckoning()
	if not reckCache then
		local n, icon, hidden = ReadReckoningNow()
		reckCache = { n = n, icon = icon, hidden = hidden }
	end
	return reckCache.n, reckCache.icon, reckCache.hidden
end

local function UpdateReckoning(db)
	local b = icons.reck
	if ns.unlocked then
		Set(b, Texture("Reckoning"), "4", "RECKONING"); b.count:SetTextColor(1, 0.82, 0); Bright(b, true); b:Show() return
	end
	if not db.trEnabled or not db.trReckoning then reck = nil; b:Hide() return end
	local n, icon, hidden = ReadReckoning()
	if n then
		reck = { n = n, icon = icon, at = GetTime() }
		if icon then reckIcon = icon end
	elseif hidden and reck and GetTime() - reck.at < RECKONING_TIME then
		n, icon = reck.n, reck.icon -- hidden in combat: keep the last count for the buff's lifetime
	else
		reck = nil
	end
	if not n then reckSounded = false; b:Hide() return end
	Set(b, icon or reckIcon or Texture("Reckoning"), tostring(n), "RECKONING")
	Bright(b, true)
	if n >= RECKONING_MAX then
		b.count:SetTextColor(1, 0.82, 0)
		if not reckSounded and db.trReckoningSound then Sound("ALARM_CLOCK_WARNING_3", 12889) end
		reckSounded = true
	else
		b.count:SetTextColor(1, 1, 1)
		reckSounded = false
	end
	b:Show()
end

-- Consecration --------------------------------------------------------------------
local function UpdateConsecration(db)
	local b = icons.cons
	if ns.unlocked then
		Set(b, Texture("Consecration"), "8", "CONSECRATE"); Bright(b, true); ClearCD(b); consSet = nil; b:Show() return
	end
	if not db.trEnabled or not db.trConsecration or not Known("Consecration") then b:Hide() return end
	local now = GetTime()
	if cons and now >= cons.ends then cons = nil end
	if not cons then ClearCD(b); b:Hide() return end
	if consSet ~= cons.at then b.cd:SetCooldown(cons.at, CONSECRATION_TIME); consSet = cons.at end
	-- dim while it can't be cast again yet
	local readyAt, dur = ReadCooldown("Consecration")
	if readyAt == nil then readyAt = cons.at + (consCD or CONSECRATION_TIME)
	elseif dur > 0 then consCD = dur end
	Set(b, Texture("Consecration"), ("%d"):format(math.ceil(cons.ends - now)), "CONSECRATE")
	Bright(b, readyAt - now <= 0.3)
	b:Show()
end

-- Holy Shock ----------------------------------------------------------------------
local function UpdateHolyShock(db)
	local b = icons.shock
	if ns.unlocked then
		Set(b, Texture("Holy Shock"), "", "SHOCK"); Bright(b, true); ClearCD(b); hsSet = nil; b:Show() return
	end
	if not db.trEnabled or not db.trHolyShock or not Known("Holy Shock") then hsOnCd = false; b:Hide() return end
	local now = GetTime()
	local readyAt, dur, start = ReadCooldown("Holy Shock")
	if readyAt == nil or (readyAt == 0 and now - hs.at < 0.5) then
		-- hidden in combat (or the cast hasn't started its cooldown yet): go by your own cast
		readyAt, dur, start = hs.readyAt, hs.dur, hs.at
	elseif readyAt > 0 then
		hs.readyAt, hs.dur, hs.at = readyAt, dur, start
	else
		hs.readyAt = 0
	end
	local left = readyAt - now
	Set(b, Texture("Holy Shock"), left > 0 and ("%d"):format(math.ceil(left)) or "", "SHOCK")
	if left > 0 then
		if hsSet ~= start then b.cd:SetCooldown(start, dur); hsSet = start end
		Bright(b, false)
		hsOnCd = true
	else
		if hsSet then ClearCD(b); hsSet = nil end
		Bright(b, true)
		if hsOnCd and db.trHolyShockSound and UnitAffectingCombat("player") then Sound("ALARM_CLOCK_WARNING_2", 12867) end
		hsOnCd = false
	end
	b:Show()
end

-- Low mana: Judgement of Wisdom ---------------------------------------------------
-- mana percent, or nil when the client hides it
local function ManaPct()
	local ok, cur, max = pcall(function() return UnitPower("player", 0), UnitPowerMax("player", 0) end)
	if not ok then return nil end
	cur, max = Clean(cur), Clean(max)
	if not cur or not max or max <= 0 then return nil end
	return cur / max * 100
end

-- true when your Judgement of Wisdom is on the target, false when it isn't, nil when it can't be told
local function HasWisdom()
	local unreadable = false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
		if not ok then unreadable = true break end
		if not a then break end
		local name = CleanName(a.name)
		if not name then unreadable = true
		elseif name == "Judgement of Wisdom" then return true end
	end
	-- hidden, or in combat simply left out: your last Judgement on this mob (Combat.lua, per target and
	-- restarted by your spells on it). Out of combat a readable list without it means it's gone.
	if not unreadable and not InCombatLockdown() then return false end
	local name = ns.LastJudgement and ns.LastJudgement()
	if name then return name == "Judgement of Wisdom" end
	if not unreadable then return false end
	return nil
end

local function UpdateMana(db)
	local b = icons.wisdom
	if ns.unlocked then
		Set(b, Texture("Seal of Wisdom"), "", "WISDOM"); Bright(b, true); b.glow:Show(); b.pulse:Stop(); b:Show() return
	end
	local show = db.trEnabled and db.trMana and UnitAffectingCombat("player") and HostileTarget()
		and Known("Judgement") and Known("Seal of Wisdom")
	if show then
		local pct = ManaPct()
		show = pct ~= nil and pct < db.trManaPct and HasWisdom() ~= true
	end
	if not show then b.pulse:Stop(); b.glow:Hide(); b:Hide() return end
	Set(b, Texture("Seal of Wisdom"), "", "WISDOM")
	Bright(b, true)
	b.glow:Show()
	-- keyed on the pulse, not on being shown: the unlock preview leaves it shown with the pulse stopped
	if not b.pulse:IsPlaying() then
		b:Show(); b.pulse:Play()
		if not manaSounded and db.trManaSound then Sound("RAID_WARNING", 8959) end
		manaSounded = true
	end
end

function M:Update()
	if not frame then return end
	local db = ns.db
	UpdateReckoning(db)
	UpdateConsecration(db)
	UpdateHolyShock(db)
	UpdateMana(db)
	Arrange()
end

local function MakeIcon(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(SIZE, SIZE)
	b.glow = b:CreateTexture(nil, "BACKGROUND")
	b.glow:SetPoint("TOPLEFT", -3, 3); b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
	b.glow:SetColorTexture(1, 0.85, 0.3, 0.35)
	b.glow:Hide()
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints()
	b.cd:SetDrawEdge(false)
	if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
	-- text above the cooldown sweep
	local top = CreateFrame("Frame", nil, b)
	top:SetAllPoints()
	top:SetFrameLevel(b.cd:GetFrameLevel() + 1)
	b.count = top:CreateFontString(nil, "OVERLAY")
	b.count:SetFont("Fonts\\ARIALN.TTF", 20, "OUTLINE")
	b.count:SetPoint("CENTER")
	b.label = top:CreateFontString(nil, "OVERLAY")
	b.label:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.pulse = b:CreateAnimationGroup()
	b.pulse:SetLooping("BOUNCE")
	local a = b.pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1); a:SetToAlpha(0.5); a:SetDuration(0.5)
	b:Hide()
	return b
end

function M:Init()
	frame = CreateFrame("Frame", "LightboundTrackersFrame", UIParent)
	frame:SetSize(#ORDER * (SIZE + GAP) - GAP, SIZE)
	frame:SetFrameStrata("LOW")
	frame:Hide()
	icons = {}
	for _, key in ipairs(ORDER) do icons[key] = MakeIcon(frame) end
	ns.MakeMovable(frame, "trPoint")
	ns.ApplyPoint(frame, "trPoint")

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
		"SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED" }) do ev:RegisterEvent(e) end
	ev:RegisterUnitEvent("UNIT_AURA", "player", "target")
	ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if (event == "UNIT_AURA" and (isSecret(unit) or unit == "player")) or event == "PLAYER_ENTERING_WORLD"
			or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			reckCache = nil -- combat changes what can be read, too
		end
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			manaSounded = false
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			local now = GetTime()
			if name == "Consecration" then
				cons = { at = now, ends = now + CONSECRATION_TIME }
			elseif name == "Holy Shock" then
				hs.dur = hs.dur > 0 and hs.dur or HOLY_SHOCK_CD
				hs.at, hs.readyAt = now, now + hs.dur
			end
		end
		M:Update()
	end)
	-- countdowns and cooldowns move on their own; a light ticker keeps the row honest
	C_Timer.NewTicker(0.2, function()
		if frame:IsShown() or UnitAffectingCombat("player") then M:Update() end
	end)
	M:Update()
end

-- Options -------------------------------------------------------------------------
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Trackers", "A row of small combat helpers. Unlock frames to move it.")
	local W = UI.CONTENT_W
	local half = math.floor(W / 2)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "trEnabled", "Show the trackers",
		"Icons that don't apply are left out and the rest close up.")) + 8)
	local function Row(title, key, label, soundKey, soundLabel)
		p:Add(UI.Section(p, p.y, title) + 4)
		local _, h = UI.DBToggle(p, 0, p.y, soundKey and half - 10 or W, key, label)
		if soundKey then UI.DBToggle(p, half, p.y, half, soundKey, soundLabel) end
		p:Add(h + 8)
	end
	Row("Reckoning", "trReckoning", "Stack count", "trReckoningSound", "Sound at 4 stacks")
	Row("Consecration", "trConsecration", "8 second countdown from your cast")
	Row("Holy Shock", "trHolyShock", "Cooldown", "trHolyShockSound", "Sound when ready in combat")
	Row("Low mana", "trMana", "Judgement of Wisdom reminder", "trManaSound", "Sound once per fight")
	p:Add(select(2, UI.Slider(p, p.y, "Remind below", "trManaPct", 10, 60, 5, " % mana")))
end

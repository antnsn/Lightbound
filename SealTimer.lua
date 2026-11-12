-- Vertical seal timeline: a bar that drains from top to bottom while your seal is up.
-- Starts on the seal cast and syncs with the buff whenever the client lets addons read it,
-- because the active seal can be hidden from addons during combat.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local DEFAULT_DUR = 30
local COLORS = {
	["Seal of Righteousness"] = { 0.95, 0.85, 0.35 },
	["Seal of the Crusader"]  = { 1.00, 0.55, 0.15 },
	["Seal of Command"]       = { 0.90, 0.30, 0.25 },
	["Seal of Justice"]       = { 0.55, 0.55, 0.95 },
	["Seal of Light"]         = { 1.00, 1.00, 0.70 },
	["Seal of Wisdom"]        = { 0.35, 0.65, 1.00 },
	["Seal of Fury"]          = { 0.85, 0.25, 0.85 },
}
local FALLBACK_COLOR = { 0.9, 0.8, 0.4 }

local f, bar, icon, nameText, timeText, ticks
local seal -- { name, icon, duration, expires }

local function IsSeal(name) return name and name:find("^Seal of") ~= nil end

local function SpellIcon(name)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
		return select(3, GetSpellInfo(name))
	end)
	return ok and tex or 135924
end

local function Layout()
	local db = ns.db
	f:SetSize(db.sealWidth, db.sealHeight)
	-- tick marks every 5 seconds of a 30 second seal
	local dur = (seal and seal.duration) or DEFAULT_DUR
	local n = math.floor(dur / 5)
	for i = 1, #ticks do ticks[i]:Hide() end
	for i = 1, n - 1 do
		local t = ticks[i]
		if not t then
			t = bar:CreateTexture(nil, "OVERLAY")
			t:SetColorTexture(0, 0, 0, 0.6)
			ticks[i] = t
		end
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, db.sealHeight * (i * 5 / dur))
		t:SetSize(db.sealWidth, 1)
		t:Show()
	end
end

local function SetSeal(name, tex, duration, expires)
	if duration and duration > 0 and duration < 600 then ns.db.sealDur[name] = duration end
	duration = duration or ns.db.sealDur[name] or DEFAULT_DUR
	seal = { name = name, icon = tex or SpellIcon(name), duration = duration, expires = expires or (GetTime() + duration) }
	local c = COLORS[name] or FALLBACK_COLOR
	bar:SetStatusBarColor(c[1], c[2], c[3])
	bar:SetMinMaxValues(0, duration)
	icon:SetTexture(seal.icon); icon:SetDesaturated(false)
	nameText:SetText((name:gsub("^Seal of t?h?e? ?", "")))
	Layout()
end

local function ClearSeal() seal = nil end

-- The seal you have up, by name ("Seal of Wisdom"), or nil. Kept from the seal cast itself
-- and synced from your buffs when they can be read, so it still works when combat hides them.
-- Judgement tracking (Combat.lua, Judgements.lua) uses it to know which Judgement went out.
function ns.ActiveSeal()
	if seal and seal.expires > GetTime() then return seal.name end
	local buffs, hidden = ns.ReadPlayerBuffs()
	for name in pairs(buffs) do if IsSeal(name) then return name end end
	return nil
end
local updating = false -- true while M:Update runs (guards against re-entry from OnUpdate)

local function OnUpdate()
	if not seal then return end
	local left = seal.expires - GetTime()
	if left <= 0 then
		ClearSeal()
		-- never re-enter Update from inside Update; run it on the next frame instead
		if updating then C_Timer.After(0, function() M:Update() end) else M:Update() end
		return
	end
	bar:SetValue(left)
	timeText:SetText(left >= 10 and string.format("%d", left) or string.format("%.1f", left))
	if left <= 5 then timeText:SetTextColor(1, 0.25, 0.25) else timeText:SetTextColor(1, 1, 1) end
end

local function UpdateNow()
	if not f then return end
	local db = ns.db

	local buffs, hidden = ns.ReadPlayerBuffs()
	local found
	local now = GetTime()
	for name, b in pairs(buffs) do
		-- the client can keep an expired seal in the list for a moment; treat it as gone, or
		-- SetSeal -> OnUpdate (left <= 0) -> M:Update would loop until the stack runs out
		if IsSeal(name) and not (b.expires and b.expires > 0 and b.expires <= now) then found = name
			if b.expires and b.expires > 0 then
				SetSeal(name, b.icon, b.duration, b.expires)
			elseif not seal or seal.name ~= name then
				SetSeal(name, b.icon)
			end
			break
		end
	end
	if not found and not hidden then ClearSeal() end

	f:SetScript("OnUpdate", nil)
	if ns.unlocked then
		f:SetAlpha(1); f:Show()
		if not seal then bar:SetMinMaxValues(0, 1); bar:SetValue(1); timeText:SetText("30"); nameText:SetText("Seal") end
		return
	end
	if not db.seal then f:Hide() return end
	if seal then
		f:SetAlpha(1); f:Show()
		f:SetScript("OnUpdate", OnUpdate); OnUpdate()
	elseif db.sealEmptyInCombat and InCombatLockdown() and not UnitIsDeadOrGhost("player") then
		bar:SetMinMaxValues(0, 1); bar:SetValue(0)
		icon:SetDesaturated(true)
		nameText:SetText("")
		timeText:SetText("NO\nSEAL"); timeText:SetTextColor(1, 0.25, 0.25)
		f:SetAlpha(0.9); f:Show()
	else
		f:Hide()
	end
end

function M:Update()
	if updating then return end
	updating = true
	local ok, err = pcall(UpdateNow)
	updating = false
	if not ok then geterrorhandler()(err) end
end

function M:Layout()
	if f then Layout() end
end

function M:Init()
	f = CreateFrame("Frame", "LightboundSealFrame", UIParent)
	f:SetFrameStrata("LOW")
	f:Hide()

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", -2, 2); bg:SetPoint("BOTTOMRIGHT", 2, -2)
	bg:SetColorTexture(0, 0, 0, 0.75)

	bar = CreateFrame("StatusBar", nil, f)
	bar:SetAllPoints()
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, DEFAULT_DUR)

	icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(30, 30)
	icon:SetPoint("BOTTOM", f, "TOP", 0, 6)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	nameText:SetPoint("BOTTOM", icon, "TOP", 0, 3)

	timeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	timeText:SetPoint("TOP", f, "BOTTOM", 0, -4)

	ticks = {}
	ns.MakeMovable(f, "sealPoint")
	ns.ApplyPoint(f, "sealPoint")
	Layout()

	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD" }) do
		f:RegisterEvent(e)
	end
	f:RegisterUnitEvent("UNIT_AURA", "player")
	f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	f:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			-- On Forever, Judgement does not consume the seal, so only a new seal cast restarts the timer
			if IsSeal(name) then
				SetSeal(name)
			end
		elseif event == "PLAYER_DEAD" then
			ClearSeal()
		end
		M:Update()
	end)
	M:Update()
end

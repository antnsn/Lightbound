-- Buff timers for levelling on Forever: warn before a long buff runs out, with a countdown icon.
--  * Well-Rested (Cozy Sleeping Bag, spell 429959)
--  * Well Fed (food buff; on Forever it also boosts experience). Also says when it is gone.
-- Each timer has its settings under its own prefix in LightboundDB (wellRested*, wellFed*).
-- With <key>Keep on, a missing buff is followed too: a "Buff has run out" card stays up and you get one
-- rebuff warning (out of combat, while alive) until you have the buff again.
local _, ns = ...

local function FormatTime(s)
	s = math.max(0, math.floor(s))
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

local function MakeTimer(cfg)
	local M = {}
	ns.modules[#ns.modules + 1] = M
	local key = cfg.key -- "wellRested" / "wellFed"
	local iconFrame, iconTex, timeText, pulse
	local expires, warned, buffIcon, had = nil, false, nil, false
	local missing, reminded = false, false -- buff known to be gone / rebuff warning already given
	local quietUntil = 0 -- right after login or zoning the aura list may not be filled in yet

	local function Names()
		local n = { cfg.name }
		if cfg.spellID then n[#n + 1] = ns.SpellName(cfg.spellID) end
		return n
	end

	local function Notify(text)
		local msg = ("|T%d:24|t %s"):format(buffIcon or cfg.icon, text)
		if RaidNotice_AddMessage and RaidWarningFrame then
			RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.5, b = 0 })
		end
		ns.Print(msg)
		if ns.db[key .. "Sound"] then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
	end

	local function NotifyLeft(secondsLeft)
		local mins = math.max(1, math.floor(secondsLeft / 60 + 0.5))
		Notify(("%s: %d min left"):format(cfg.label, mins))
	end

	local mode -- what the icon shows: "countdown", "gone" or nil (hidden)

	local function SetMode(m)
		if m == mode then return end
		mode = m
		if m then
			iconFrame:Show()
			if not pulse:IsPlaying() then pulse:Play() end
		else
			pulse:Stop(); iconFrame:Hide()
		end
	end

	local function Following() return ns.db[key] and ns.db[key .. "Keep"] end

	local function Remind()
		if reminded or not missing or not Following() or GetTime() < quietUntil then return end
		if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
		reminded = true
		Notify(cfg.label .. " is gone, rebuff")
	end

	local function UpdateIcon()
		if not iconFrame then return end
		local db = ns.db
		iconTex:SetTexture(buffIcon or cfg.icon)
		if ns.unlocked then
			SetMode("unlocked"); timeText:SetText("5:00 left")
			return
		end
		local left = expires and (expires - GetTime())
		if db[key] and db[key .. "Icon"] and warned and left and left > 0 then
			SetMode("countdown"); timeText:SetText(FormatTime(left) .. " left")
		elseif Following() and missing and not expires and GetTime() >= quietUntil then
			SetMode("gone"); timeText:SetText("Buff has run out")
		else
			SetMode(nil)
		end
	end

	local function Check()
		local db = ns.db
		if not db[key] or not expires then Remind(); UpdateIcon() return end
		local left = expires - GetTime()
		local limit = db[key .. "Minutes"] * 60
		if left <= 0 then
			expires, warned, missing = nil, false, true
		elseif left > limit + 5 then
			warned = false -- refreshed (or the limit was raised): arm again
		elseif not warned then
			warned = true
			NotifyLeft(left)
		end
		Remind()
		UpdateIcon()
	end

	function M:Update()
		if not iconFrame then return end
		local buffs, hidden = ns.ReadPlayerBuffs()
		local b
		for _, n in ipairs(Names()) do b = b or buffs[n] end
		if b then
			had, missing, reminded = true, false, false
			if b.expires and b.expires > 0 then expires = b.expires end
			if b.icon then buffIcon = b.icon end
		elseif not hidden and GetTime() >= quietUntil then
			-- gone (in combat the buff may just be left out of the list: keep the last expiry;
			-- right after a loading screen the list can be empty: wait for quietUntil, and keep
			-- warned so the "min left" alert doesn't fire again)
			-- (when following, Remind gives the warning instead)
			if had and cfg.sayGone and ns.db[key] and not ns.db[key .. "Keep"] and not UnitIsDeadOrGhost("player") then
				Notify(cfg.label .. " is gone")
			end
			had, expires, warned, missing = false, nil, false, true
		end
		Check()
	end

	function M:Init()
		local f = CreateFrame("Frame")
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do f:RegisterEvent(e) end
		f:RegisterUnitEvent("UNIT_AURA", "player")
		f:RegisterEvent("PLAYER_UNGHOST"); f:RegisterEvent("PLAYER_ALIVE")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_ENTERING_WORLD" then
				quietUntil = GetTime() + 5
				C_Timer.After(5.5, function() M:Update() end) -- look again once the quiet time is over
			end
			M:Update()
		end)

		iconFrame = CreateFrame("Frame", cfg.frameName, UIParent)
		-- a small card: dark panel, glowing icon on the left, title and status line on the right
		iconFrame:SetSize(210, 52)
		iconFrame:SetFrameStrata("LOW")
		iconFrame:Hide()
		local edge = iconFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
		edge:SetAllPoints(); edge:SetColorTexture(0.25, 0.25, 0.25, 0.8)
		local bg = iconFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
		bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
		bg:SetColorTexture(0.04, 0.04, 0.05, 0.85)
		local ICON = 38
		local border = iconFrame:CreateTexture(nil, "BORDER")
		border:SetSize(ICON + 4, ICON + 4); border:SetPoint("LEFT", 6, 0)
		border:SetColorTexture(1, 0.78, 0.15, 1)
		iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
		iconTex:SetSize(ICON, ICON); iconTex:SetPoint("CENTER", border)
		iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		iconTex:SetTexture(cfg.icon)
		local glow = iconFrame:CreateTexture(nil, "OVERLAY")
		glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.8, 0.2, 0.9)
		glow:SetSize(ICON * 1.9, ICON * 1.9); glow:SetPoint("CENTER", border)
		local label = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		label:SetPoint("TOPLEFT", border, "TOPRIGHT", 10, -3); label:SetPoint("RIGHT", -8, 0)
		label:SetJustifyH("LEFT"); label:SetTextColor(1, 0.82, 0)
		label:SetText(cfg.label)
		timeText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		timeText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3); timeText:SetPoint("RIGHT", -8, 0)
		timeText:SetJustifyH("LEFT"); timeText:SetTextColor(0.85, 0.85, 0.85)
		-- the glow breathes while the card is up: fades and swells a little, then back
		pulse = glow:CreateAnimationGroup()
		pulse:SetLooping("BOUNCE")
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(1); fade:SetToAlpha(0.2); fade:SetDuration(1.1); fade:SetSmoothing("IN_OUT")
		local swell = pulse:CreateAnimation("Scale")
		swell:SetScale(1.12, 1.12); swell:SetDuration(1.1); swell:SetSmoothing("IN_OUT")
		ns.MakeMovable(iconFrame, cfg.point)
		ns.ApplyPoint(iconFrame, cfg.point)
		local acc = 0
		iconFrame:SetScript("OnUpdate", function(_, elapsed)
			acc = acc + elapsed
			if acc >= 1 then acc = 0; Check() end
		end)
		C_Timer.NewTicker(5, Check)
		quietUntil = GetTime() + 5
		C_Timer.After(5.5, function() M:Update() end)
		M:Update()
	end

	M.Test = function() NotifyLeft(ns.db[key .. "Minutes"] * 60) end
	return M
end

local rested = MakeTimer({ key = "wellRested", name = "Well-Rested", spellID = 429959, icon = 132802,
	label = "Well-Rested", point = "wrPoint", frameName = "LightboundWellRestedFrame" })
local fed = MakeTimer({ key = "wellFed", name = "Well Fed", icon = 136000, sayGone = true,
	label = "Well Fed", point = "wfPoint", frameName = "LightboundWellFedFrame" })

-- Options toggles call this so a change shows at once
function ns.UpdateBuffTimers() rested:Update(); fed:Update() end

-- Test hooks for the options window
function ns.TestWellRested() rested.Test() end
function ns.TestWellFed() fed.Test() end

-- Buff timers for levelling on Forever: warn before a long buff runs out, with a countdown icon.
--  * Well-Rested (Cozy Sleeping Bag, spell 429959)
--  * Well Fed (food buff; on Forever it also boosts experience). Also says when it is gone.
-- Each timer has its settings under its own prefix in LightboundDB (wellRested*, wellFed*).
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

	local function UpdateIcon()
		if not iconFrame then return end
		local db = ns.db
		iconTex:SetTexture(buffIcon or cfg.icon)
		if ns.unlocked then
			pulse:Stop(); iconFrame:SetAlpha(1); iconFrame:Show(); timeText:SetText("5:00")
			return
		end
		local left = expires and (expires - GetTime())
		if db[key] and db[key .. "Icon"] and warned and left and left > 0 then
			timeText:SetText(FormatTime(left))
			if not iconFrame:IsShown() then iconFrame:Show(); pulse:Play() end
		elseif iconFrame:IsShown() then
			pulse:Stop(); iconFrame:Hide()
		end
	end

	local function Check()
		local db = ns.db
		if not db[key] or not expires then UpdateIcon() return end
		local left = expires - GetTime()
		local limit = db[key .. "Minutes"] * 60
		if left <= 0 then
			expires, warned = nil, false
		elseif left > limit + 5 then
			warned = false -- refreshed (or the limit was raised): arm again
		elseif not warned then
			warned = true
			NotifyLeft(left)
		end
		UpdateIcon()
	end

	function M:Update()
		if not iconFrame then return end
		local buffs, hidden = ns.ReadPlayerBuffs()
		local b
		for _, n in ipairs(Names()) do b = b or buffs[n] end
		if b then
			had = true
			if b.expires and b.expires > 0 then expires = b.expires end
			if b.icon then buffIcon = b.icon end
		elseif not hidden then
			-- gone (in combat the buff may just be left out of the list: keep the last expiry)
			if had and cfg.sayGone and ns.db[key] and not UnitIsDeadOrGhost("player") then
				Notify(cfg.label .. " is gone")
			end
			had, expires, warned = false, nil, false
		end
		Check()
	end

	function M:Init()
		local f = CreateFrame("Frame")
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do f:RegisterEvent(e) end
		f:RegisterUnitEvent("UNIT_AURA", "player")
		f:SetScript("OnEvent", function() M:Update() end)

		iconFrame = CreateFrame("Frame", cfg.frameName, UIParent)
		iconFrame:SetSize(48, 48)
		iconFrame:SetFrameStrata("HIGH")
		iconFrame:Hide()
		local border = iconFrame:CreateTexture(nil, "BACKGROUND")
		border:SetPoint("TOPLEFT", -2, 2); border:SetPoint("BOTTOMRIGHT", 2, -2)
		border:SetColorTexture(1, 0.75, 0.1, 0.9)
		iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
		iconTex:SetAllPoints(); iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		iconTex:SetTexture(cfg.icon)
		timeText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		timeText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -4)
		timeText:SetTextColor(1, 0.82, 0)
		local label = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("BOTTOM", iconFrame, "TOP", 0, 4)
		label:SetText(cfg.label)
		pulse = iconFrame:CreateAnimationGroup()
		pulse:SetLooping("BOUNCE")
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(1); fade:SetToAlpha(0.45); fade:SetDuration(0.8)
		ns.MakeMovable(iconFrame, cfg.point)
		ns.ApplyPoint(iconFrame, cfg.point)
		local acc = 0
		iconFrame:SetScript("OnUpdate", function(_, elapsed)
			acc = acc + elapsed
			if acc >= 1 then acc = 0; Check() end
		end)
		C_Timer.NewTicker(5, Check)
		M:Update()
	end

	M.Test = function() NotifyLeft(ns.db[key .. "Minutes"] * 60) end
	return M
end

local rested = MakeTimer({ key = "wellRested", name = "Well-Rested", spellID = 429959, icon = 132802,
	label = "Well-Rested", point = "wrPoint", frameName = "LightboundWellRestedFrame" })
local fed = MakeTimer({ key = "wellFed", name = "Well Fed", icon = 136000, sayGone = true,
	label = "Well Fed", point = "wfPoint", frameName = "LightboundWellFedFrame" })

-- Test hooks for the options window
function ns.TestWellRested() rested.Test() end
function ns.TestWellFed() fed.Test() end

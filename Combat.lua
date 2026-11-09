-- Combat helpers:
--  * Procs: big icon when Hammer of Wrath (target under 20%) or Exorcism (undead/demon target) can be cast.
--  * Judgement: your Judgement on the target with time left, or a dim "Judge" icon when it's missing.
-- The client decides when Hammer of Wrath is usable, so no health reading is needed.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = _G.issecretvalue or function() return false end
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end

local EXORCISM_TYPES = { Undead = true, Demon = true, Untoter = true, ["Dämon"] = true, ["Mort-vivant"] = true, ["Démon"] = true }
local JUDGEMENT_TIME = 10 -- fallback length when the debuff can't be read

local procFrame, procIcons, judgeFrame
local shown = {}        -- spell -> true while its proc icon is up (for the sound)
local lastJudge         -- { guid, name, icon, at } from your last Judgement cast

local function Known(spell)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spell) end
		return GetSpellInfo(spell)
	end)
	return ok and info ~= nil
end

-- icons for spells you may not have learned yet (only spells you know have a texture by name)
local FALLBACK_ICON = { ["Hammer of Wrath"] = 132326, ["Exorcism"] = 135903, ["Judgement"] = 135959 }

local function Texture(spell)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
		return GetSpellTexture(spell)
	end)
	return (ok and tex) or FALLBACK_ICON[spell] or 134400
end

-- true when the spell is usable now and off cooldown (the global cooldown doesn't count)
local function Ready(spell)
	local ok, usable = pcall(function()
		if C_Spell and C_Spell.IsSpellUsable then return C_Spell.IsSpellUsable(spell) end
		return IsUsableSpell(spell)
	end)
	if not ok or isSecret(usable) or not usable then return false end
	local ok2, cd = pcall(C_Spell.GetSpellCooldown, spell)
	if ok2 and type(cd) == "table" then
		local start, dur = Clean(cd.startTime), Clean(cd.duration)
		if start and dur and dur > 1.5 and start + dur - GetTime() > 0.3 then return false end
	end
	return true
end

local function HostileTarget()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
end

-- Procs ---------------------------------------------------------------------------
local function ProcList()
	local list = {}
	if not HostileTarget() then return list end
	if Known("Hammer of Wrath") and Ready("Hammer of Wrath") then list[#list + 1] = "Hammer of Wrath" end
	if Known("Exorcism") then
		local ctype = Clean(UnitCreatureType("target"))
		if ctype and EXORCISM_TYPES[ctype] and Ready("Exorcism") then list[#list + 1] = "Exorcism" end
	end
	return list
end

local function UpdateProcs()
	local db = ns.db
	local list
	if ns.unlocked then list = { "Hammer of Wrath", "Exorcism" }
	elseif db.procEnabled then list = ProcList()
	else list = {} end
	local now = {}
	for i, icon in ipairs(procIcons) do
		local spell = list[i]
		if spell then
			icon.tex:SetTexture(Texture(spell))
			icon.label:SetText(spell == "Hammer of Wrath" and "HAMMER" or "EXORCISM")
			icon:Show()
			if not icon.pulse:IsPlaying() then icon.pulse:Play() end
			now[spell] = true
			if not shown[spell] and db.procSound and not ns.unlocked then
				PlaySound(SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889, "Master")
			end
		else
			icon.pulse:Stop()
			icon:Hide()
		end
	end
	shown = now
	procFrame:SetShown(#list > 0)
end

-- Judgement -----------------------------------------------------------------------
-- your Judgement debuff on the target: name, icon, seconds left; or nil. second value true = unreadable
local function ReadJudgement()
	local unreadable = false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
		if not ok then unreadable = true break end
		if not a then break end
		local name = Clean(a.name)
		if not name then
			unreadable = true
		elseif name:find("^Judgement of") then
			local exp = Clean(a.expirationTime)
			return name, Clean(a.icon), exp and exp > 0 and (exp - GetTime()) or nil
		end
	end
	return nil, nil, nil, unreadable
end

local function UpdateJudgement()
	local db = ns.db
	local f = judgeFrame
	if ns.unlocked then
		f.icon:SetTexture(Texture("Judgement")); f.icon:SetDesaturated(false); f:SetAlpha(1)
		f.time:SetText("8"); f.name:SetText("Wisdom"); f:Show() return
	end
	if not db.judgeEnabled or not HostileTarget() or not Known("Judgement") then f:Hide() return end
	local name, icon, left, unreadable = ReadJudgement()
	if not name and unreadable and lastJudge and lastJudge.guid == UnitGUID("target") then
		local l = JUDGEMENT_TIME - (GetTime() - lastJudge.at)
		if l > 0 then name, icon, left = lastJudge.name, lastJudge.icon, l end
	end
	if name then
		f.icon:SetTexture(icon or Texture("Judgement"))
		f.icon:SetDesaturated(false)
		f:SetAlpha(1)
		f.name:SetText((name:gsub("^Judgement of ", "")))
		if left then
			f.time:SetText(("%d"):format(math.ceil(left)))
			f.time:SetTextColor(left <= 3 and 1 or 1, left <= 3 and 0.3 or 1, left <= 3 and 0.3 or 1)
		else
			f.time:SetText("")
		end
		f:Show()
	elseif db.judgeMissing and UnitAffectingCombat("player") then
		f.icon:SetTexture(Texture("Judgement"))
		f.icon:SetDesaturated(true)
		f:SetAlpha(0.8)
		f.name:SetText("|cffff5555Judge|r")
		f.time:SetText("")
		f:Show()
	else
		f:Hide()
	end
end

function M:Update()
	if not procFrame then return end
	UpdateProcs()
	UpdateJudgement()
end

local function MakeProcIcon(parent, i)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(52, 52)
	b:SetPoint("LEFT", (i - 1) * 60, 0)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local glow = b:CreateTexture(nil, "OVERLAY")
	glow:SetPoint("TOPLEFT", -3, 3); glow:SetPoint("BOTTOMRIGHT", 3, -3)
	glow:SetColorTexture(1, 0.85, 0.3, 0.25)
	b.label = b:CreateFontString(nil, "OVERLAY")
	b.label:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.pulse = b:CreateAnimationGroup()
	b.pulse:SetLooping("BOUNCE")
	local a = b.pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1); a:SetToAlpha(0.55); a:SetDuration(0.45)
	b:Hide()
	return b
end

function M:Init()
	procFrame = CreateFrame("Frame", "LightboundProcFrame", UIParent)
	procFrame:SetSize(112, 52)
	procFrame:SetFrameStrata("HIGH")
	procFrame:Hide()
	procIcons = { MakeProcIcon(procFrame, 1), MakeProcIcon(procFrame, 2) }
	ns.MakeMovable(procFrame, "prPoint")
	ns.ApplyPoint(procFrame, "prPoint")

	judgeFrame = CreateFrame("Frame", "LightboundJudgementFrame", UIParent)
	judgeFrame:SetSize(36, 36)
	judgeFrame:SetFrameStrata("MEDIUM")
	judgeFrame:Hide()
	judgeFrame.icon = judgeFrame:CreateTexture(nil, "ARTWORK")
	judgeFrame.icon:SetAllPoints(); judgeFrame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	judgeFrame.time = judgeFrame:CreateFontString(nil, "OVERLAY")
	judgeFrame.time:SetFont("Fonts\\ARIALN.TTF", 18, "OUTLINE")
	judgeFrame.time:SetPoint("CENTER")
	judgeFrame.name = judgeFrame:CreateFontString(nil, "OVERLAY")
	judgeFrame.name:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
	judgeFrame.name:SetPoint("TOP", judgeFrame, "BOTTOM", 0, -2)
	ns.MakeMovable(judgeFrame, "jdPoint")
	ns.ApplyPoint(judgeFrame, "jdPoint")

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("SPELL_UPDATE_USABLE")
	ev:RegisterUnitEvent("UNIT_AURA", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			if name == "Judgement" then
				-- remember which Judgement went out, in case the debuff is hidden in combat
				local buffs = ns.ReadPlayerBuffs()
				local seal
				for bname in pairs(buffs) do if bname:find("^Seal of") then seal = bname end end
				local jname = seal and seal:gsub("^Seal of ", "Judgement of ") or "Judgement"
				lastJudge = { guid = UnitGUID("target"), name = jname, icon = seal and Texture(seal), at = GetTime() }
			end
		end
		M:Update()
	end)
	-- target health and cooldowns change all the time; a light ticker keeps the icons honest
	C_Timer.NewTicker(0.2, function()
		if procFrame:IsShown() or judgeFrame:IsShown() or HostileTarget() then M:Update() end
	end)
end

-- Combat helpers:
--  * Procs: big icon when Hammer of Wrath (target under 20%) or Exorcism (undead/demon target) can be cast.
--  * Judgement: your Judgement on the target with time left, or a dim "Judge" icon when it's missing.
-- The client decides when Hammer of Wrath is usable, so no health reading is needed.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = ns.IsSecret -- see Core.lua
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>" -- placeholder the client returns for hidden aura names
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end
local function CleanName(v) v = Clean(v); if v == RESTRICTED then return nil end return v end

local EXORCISM_TYPES = { Undead = true, Demon = true, Untoter = true, ["Dämon"] = true, ["Mort-vivant"] = true, ["Démon"] = true }
local JUDGEMENT_TIME = 10 -- fallback length when the debuff can't be read
local LASTING = { ["Seal of Wisdom"] = true, ["Seal of Light"] = true, ["Seal of the Crusader"] = true,
	["Seal of Justice"] = true } -- seals whose Judgement stays on the target as a debuff

local procFrame, procIcons, judgeFrame
local shown = {}        -- spell -> true while its proc icon is up (for the sound)
local lastJudge         -- { name, icon, at } from your last Judgement cast; cleared on target change
                        -- (the target's GUID is a secret value in combat, so it can't be compared)
-- your own casts of the proc spells, for when combat hides their cooldown
local PROC_CD = { ["Hammer of Wrath"] = 6, ["Exorcism"] = 15 } -- until the real cooldown has been read once
local castAt = {}       -- spell -> GetTime() of your last cast

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
	local start, dur
	if ok2 and type(cd) == "table" then start, dur = Clean(cd.startTime), Clean(cd.duration) end
	if start and dur then
		if dur > 1.5 then
			if PROC_CD[spell] then PROC_CD[spell] = dur end -- learn the real length out of combat
			if start + dur - GetTime() > 0.3 then return false end
		end
		return true
	end
	-- hidden in combat: go by your own last cast
	local at, len = castAt[spell], PROC_CD[spell]
	if at and len and at + len - GetTime() > 0.3 then return false end
	return true
end

local function HostileTarget()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
end

-- Undead or demon target. The creature type is a secret value on Forever, so when it can't be read
-- the range check decides: it returns nil for a target the spell can never hit, true/false otherwise.
local function ExorcismTarget()
	local ctype = Clean(UnitCreatureType("target"))
	if ctype then return EXORCISM_TYPES[ctype] or false end
	local ok, r = pcall(C_Spell.IsSpellInRange, "Exorcism", "target")
	if not ok then return false end
	return Clean(r) ~= nil
end

-- Procs ---------------------------------------------------------------------------
local function ProcList()
	local list = {}
	if not HostileTarget() then return list end
	if Known("Hammer of Wrath") and Ready("Hammer of Wrath") then list[#list + 1] = "Hammer of Wrath" end
	if Known("Exorcism") and ExorcismTarget() and Ready("Exorcism") then list[#list + 1] = "Exorcism" end
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
	shown = ns.unlocked and {} or now -- the preview doesn't count, so a real proc after locking still sounds
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
		local name = CleanName(a.name)
		if not name then
			unreadable = true
		elseif name:find("^Judgement of") then
			local exp = Clean(a.expirationTime)
			return name, Clean(a.icon), exp and exp > 0 and (exp - GetTime()) or nil
		end
	end
	return nil, nil, nil, unreadable
end

-- Judgements per mob, by GUID, so swapping back finds the one you left. In combat the GUID can
-- be a secret value; then only the current target is followed (a swap starts over).
local judged = {}
local function TargetKey() return Clean(UnitGUID("target")) end
local function Remember(j)
	local key = TargetKey()
	local now = GetTime()
	for k, v in pairs(judged) do if now - v.at >= JUDGEMENT_TIME then judged[k] = nil end end
	if key then judged[key] = j end
end

-- your spell hit something hostile (heals, seals, blessings and auras don't count)
local HELPFUL = { "^Seal of", "^Blessing of", "^Greater Blessing of", " Aura$", "^Righteous Fury$",
	"^Holy Light$", "^Flash of Light$", "^Lay on Hands$", "^Divine", "^Cleanse$", "^Purify$" }
local function Harmful(spellID, name)
	local ok, h = pcall(function()
		if C_Spell and C_Spell.IsSpellHarmful then return C_Spell.IsSpellHarmful(spellID) end
		if IsHarmfulSpell then return IsHarmfulSpell(name) end
	end)
	if ok and h ~= nil and not isSecret(h) then return h and true or false end
	for _, pat in ipairs(HELPFUL) do if name:find(pat) then return false end end
	return true
end

-- your Judgement on the current target as you last saw it go out: name, seconds left; or nil.
-- Shared with the Judgement assignments (Judgements.lua) for when the debuffs are hidden.
function ns.LastJudgement()
	if not lastJudge then return nil end
	local l = JUDGEMENT_TIME - (GetTime() - lastJudge.at)
	if l <= 0 then return nil end
	return lastJudge.name, l
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
	-- hidden, or in combat simply left out of the list: trust your last cast for its lifetime.
	-- Out of combat the list is complete, so a readable list without it means it expired.
	if not name and (unreadable or InCombatLockdown()) and lastJudge then
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
	procFrame:SetFrameStrata("LOW")
	procFrame:Hide()
	procIcons = { MakeProcIcon(procFrame, 1), MakeProcIcon(procFrame, 2) }
	ns.MakeMovable(procFrame, "prPoint")
	ns.ApplyPoint(procFrame, "prPoint")

	judgeFrame = CreateFrame("Frame", "LightboundJudgementFrame", UIParent)
	judgeFrame:SetSize(36, 36)
	judgeFrame:SetFrameStrata("LOW")
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
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
	-- the server confirms a cast a moment after you press it; cast and swap target quickly and
	-- the confirmation lands after the swap. Only count casts sent at the current target.
	-- The cast's target name (from UNIT_SPELLCAST_SENT) must also be your target: a mouseover or
	-- focus macro hits someone else. With `strict`, a cast without a readable target (Consecration,
	-- or a hidden name) doesn't count either; without it (Judgement, always on a target) it does.
	local sentAt, targetAt, sentTo = 0, 0, nil
	local function AtTarget(strict)
		if sentAt < targetAt then return false end
		local mine = Clean(UnitName("target"))
		if not sentTo or sentTo == "" or not mine then return not strict end
		return sentTo == mine or Ambiguate(sentTo, "none") == mine
	end
	ev:SetScript("OnEvent", function(_, event, _, a2, a3, a4)
		if event == "PLAYER_TARGET_CHANGED" then
			targetAt = GetTime()
			-- back on a mob you judged: pick its Judgement up again (when its GUID can be read)
			local key = TargetKey()
			lastJudge = key and judged[key] or nil
		elseif event == "UNIT_SPELLCAST_SENT" then
			sentAt, sentTo = GetTime(), Clean(a2)
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" and PROC_CD[ns.SpellName(a3) or ""] then
			castAt[ns.SpellName(a3)] = GetTime() -- any target: the cooldown runs either way
		end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and HostileTarget() and AtTarget(false) then
			local name = ns.SpellName(a3)
			if name == "Judgement" then
				-- remember which Judgement went out, in case the debuff is hidden in combat. The seal
				-- comes from the seal timer, which still knows it when combat hides your buffs.
				-- Only these seals leave a Judgement on the target; the others just hit once.
				local seal = ns.ActiveSeal and ns.ActiveSeal()
				if seal and LASTING[seal] then
					lastJudge = { name = (seal:gsub("^Seal of ", "Judgement of ")), icon = Texture(seal), at = GetTime() }
				elseif seal and lastJudge and GetTime() - lastJudge.at < JUDGEMENT_TIME then
					-- a one-hit Judgement (Righteousness...) leaves the old debuff and, being harmful, restarts it
					lastJudge.at = GetTime()
				else
					lastJudge = nil
				end
				Remember(lastJudge)
			elseif lastJudge and name and AtTarget(true) and Harmful(a3, name)
				and GetTime() - lastJudge.at < JUDGEMENT_TIME then
				-- on Forever your spells on the target restart its Judgement. A cast that misses or
				-- is resisted counts too (proving a hit needs the combat log); this guess only
				-- matters while the target's debuffs are hidden.
				lastJudge.at = GetTime()
			end
		end
		M:Update()
	end)
	-- target health and cooldowns change all the time; a light ticker keeps the icons honest
	C_Timer.NewTicker(0.2, function()
		local db = ns.db
		if not ns.unlocked and not db.procEnabled and not db.judgeEnabled then return end -- both off: events still hide them
		if procFrame:IsShown() or judgeFrame:IsShown() or HostileTarget() then M:Update() end
	end)
end

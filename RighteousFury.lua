-- Warns when grouped without Righteous Fury: in dungeons/raids, and in the open world
-- when db.world is on (not while resting in a city or inn).
local _, ns = ...

local SPELL_ID, SPELL_NAME, ICON = 25780, "Righteous Fury", 135962
local M = {}
ns.modules[#ns.modules + 1] = M

local f, pulse
local shown, hasRF = false, nil

local function KnowsSpell()
	if IsPlayerSpell and IsPlayerSpell(SPELL_ID) then return true end
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(SPELL_NAME) end
		return GetSpellInfo(SPELL_NAME)
	end)
	return ok and info ~= nil
end

local function ShouldWarn()
	local db = ns.db
	if not db.enabled or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") or not IsInGroup() then return false end
	local inInstance, instanceType = IsInInstance()
	if inInstance then
		if instanceType ~= "party" and not (db.raid and instanceType == "raid") then return false end
	else
		if not db.world or IsResting() then return false end
		if IsInRaid() and not db.raid then return false end
	end
	if not KnowsSpell() then return false end
	return hasRF == false
end

-- Used by the party buff key: true when the RF warning would show right now
function ns.RFNeeded() return f ~= nil and ShouldWarn() end

function M:Update()
	if not f then return end
	local buffs, hidden = ns.ReadPlayerBuffs()
	if buffs[SPELL_NAME] then
		hasRF = true
	elseif not hidden then
		hasRF = false
	end -- auras hidden and RF not listed: keep the last known state instead of a false alarm

	if ns.unlocked then
		pulse:Stop(); f:SetAlpha(1); f:Show(); shown = false
		return
	end
	if ShouldWarn() then
		if not shown then
			f:Show(); pulse:Play()
			if ns.db.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
			shown = true
		end
	elseif shown or f:IsShown() then
		pulse:Stop(); f:Hide(); shown = false
	end
end

function M:Init()
	f = CreateFrame("Frame", "LightboundRighteousFuryFrame", UIParent)
	f:SetSize(64, 64)
	f:SetFrameStrata("HIGH")
	f:Hide()

	local border = f:CreateTexture(nil, "BACKGROUND")
	border:SetPoint("TOPLEFT", -3, 3); border:SetPoint("BOTTOMRIGHT", 3, -3)
	border:SetColorTexture(1, 0.1, 0.1, 0.9)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(); icon:SetTexture(ICON); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	text:SetPoint("TOP", f, "BOTTOM", 0, -6)
	text:SetText("NO RIGHTEOUS FURY"); text:SetTextColor(1, 0.2, 0.2)

	pulse = f:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1); fade:SetToAlpha(0.35); fade:SetDuration(0.6)

	ns.MakeMovable(f, "rfPoint")
	ns.ApplyPoint(f, "rfPoint")

	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "PLAYER_ALIVE",
		"PLAYER_UNGHOST", "PLAYER_DEAD", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING" }) do
		f:RegisterEvent(e)
	end
	f:RegisterUnitEvent("UNIT_AURA", "player")
	f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	f:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if ns.SpellName(spellID) == SPELL_NAME then hasRF = true end
		end
		M:Update()
	end)
	M:Update()
end

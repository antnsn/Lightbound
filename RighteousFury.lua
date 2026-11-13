-- Warns when grouped without Righteous Fury: in dungeons/raids, and in the open world
-- when db.world is on (not while resting in a city or inn).
local _, ns = ...

local SPELL_ID, SPELL_NAME, ICON = 25780, "Righteous Fury", 135962
local M = {}
ns.modules[#ns.modules + 1] = M

local f, cast -- f: the card (ns.MakeCard)
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

local Sync = function() end

function M:Update()
	if not f then return end
	self:Refresh()
	Sync()
end

function M:Refresh()
	local buffs, hidden = ns.ReadPlayerBuffs()
	if buffs[SPELL_NAME] then
		hasRF = true
	elseif not hidden then
		hasRF = false
	end -- auras hidden and RF not listed: keep the last known state instead of a false alarm

	if ns.unlocked then
		f:Glow(false); f:SetAlpha(1); f:Show(); shown = false
		return
	end
	if ShouldWarn() then
		if not shown then
			f:Show(); f:Glow(true)
			if ns.db.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
			shown = true
		end
	elseif shown or f:IsShown() then
		f:Glow(false); f:Hide(); shown = false
	end
end

function M:Init()
	f = ns.MakeCard("LightboundRighteousFuryFrame")
	f:SetIcon(ICON)
	f:SetTitle(SPELL_NAME)
	f:SetStatus("Not active, click to cast", true)
	cast = ns.CastOverlay(f)
	Sync = function() cast:Sync(f:IsShown() and SPELL_NAME or nil) end

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

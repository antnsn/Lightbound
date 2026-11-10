-- Paladin aura tracking: warns when no aura is up (or the wrong one, if asked), and tells the
-- buff key which aura to cast. The wanted aura comes from /lb or the group aura assignment.
local _, ns = ...

ns.AURAS = { "Devotion", "Retribution", "Concentration", "Shadow Resistance", "Frost Resistance",
	"Fire Resistance", "Sanctity" }

local M = {}
ns.modules[#ns.modules + 1] = M

local f, icon, text
local active          -- key of the aura that is up, false if none, nil if unknown

local function Known(name)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) end
		return GetSpellInfo(name)
	end)
	return ok and info ~= nil
end

local function Texture(name)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
		return GetSpellTexture(name)
	end)
	return ok and tex or 135893
end

-- The aura you should have up, as "Devotion" etc. (nil if none chosen or not learned)
function ns.WantedAura()
	local want
	if ns.PartyBuffSource and ns.PartyBuffSource() == "Group" then
		want = ns.PP_AURA[ns.GetAuraAssign(ns.MyName())]
	end
	want = want or ns.db.auraChoice
	if want and Known(want .. " Aura") then return want end
	-- fall back to any aura you know, so a low-level paladin still gets warned
	for _, k in ipairs(ns.AURAS) do if Known(k .. " Aura") then return k end end
	return nil
end

local function Read()
	local buffs, hidden = ns.ReadPlayerBuffs()
	for _, k in ipairs(ns.AURAS) do
		if buffs[k .. " Aura"] then active = k return end
	end
	if not hidden then active = false end -- hidden in combat: keep the last known state
end

local function Applies()
	local db = ns.db
	if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
	if db.auraOnlyGrouped and not IsInGroup() then return false end
	if IsResting() then return false end
	return true
end

-- Used by the buff key: the aura to cast now, or nil
function ns.AuraNeeded()
	if not ns.db or not ns.db.pbAura or not Applies() then return nil end
	local want = ns.WantedAura()
	if not want then return nil end
	if active == false or (ns.db.auraStrict and active and active ~= want) then return want end
	return nil
end

local cast

function M:Update()
	if not f then return end
	self:Refresh()
	if cast then
		local want = ns.WantedAura()
		cast:Sync(f:IsShown() and want and (want .. " Aura") or nil)
	end
end

function M:Refresh()
	Read()
	local db = ns.db
	local want = ns.WantedAura()
	if ns.unlocked then
		icon:SetTexture(Texture((want or "Devotion") .. " Aura")); icon:SetDesaturated(false)
		text:SetText("NO AURA"); f:Show() return
	end
	local show = db.auraWarn and want and Applies()
		and (active == false or (db.auraStrict and active and active ~= want))
	if show then
		icon:SetTexture(Texture(want .. " Aura"))
		icon:SetDesaturated(active == false)
		text:SetText(active == false and "NO AURA" or (active .. " > " .. want))
		f:Show()
	else
		f:Hide()
	end
end

function M:Init()
	f = CreateFrame("Frame", "LightboundAuraFrame", UIParent)
	f:SetSize(40, 40)
	f:SetFrameStrata("HIGH")
	f:Hide()
	cast = ns.CastOverlay(f)
	local border = f:CreateTexture(nil, "BACKGROUND")
	border:SetPoint("TOPLEFT", -2, 2); border:SetPoint("BOTTOMRIGHT", 2, -2)
	border:SetColorTexture(1, 0.1, 0.1, 0.9)
	icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOP", f, "BOTTOM", 0, -4)
	text:SetTextColor(1, 0.3, 0.3)
	ns.MakeMovable(f, "auPoint")
	ns.ApplyPoint(f, "auPoint")
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
		"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "SPELLS_CHANGED" }) do ev:RegisterEvent(e) end
	ev:RegisterUnitEvent("UNIT_AURA", "player")
	ev:SetScript("OnEvent", function() M:Update() end)
	M:Update()
end

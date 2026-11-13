-- Paladin aura tracking: warns when no aura is up (or the wrong one, if asked), and tells the
-- buff key which aura to cast. The wanted aura comes from /lb or the group aura assignment.
local _, ns = ...

ns.AURAS = { "Devotion", "Retribution", "Concentration", "Shadow Resistance", "Frost Resistance",
	"Fire Resistance", "Sanctity" }

local M = {}
ns.modules[#ns.modules + 1] = M

local f -- the card (ns.MakeCard)
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
	-- the aura from the Blessings window only in a raid where you have assignments (as before
	-- blessings moved to the window for good); otherwise your choice on the Aura page
	if IsInRaid() and ns.HasAssignments and ns.HasAssignments() then
		want = ns.PP_AURA[ns.GetAuraAssign(ns.MyName())]
	end
	want = want or ns.db.auraChoice
	if want and Known(want .. " Aura") then return want end
	-- fall back to any aura you know, so a low-level paladin still gets warned
	for _, k in ipairs(ns.AURAS) do if Known(k .. " Aura") then return k end end
	return nil
end

local castAura -- the aura you cast yourself (UNIT_SPELLCAST_SUCCEEDED), trusted while auras are hidden

local function Read()
	local buffs, hidden = ns.ReadPlayerBuffs()
	for _, k in ipairs(ns.AURAS) do
		-- only your own aura counts (another paladin's aura on you is theirs); an unreadable
		-- source (combat) still counts, so you don't get a false NO AURA mid-fight
		local b = buffs[k .. " Aura"]
		if b and b.mine ~= false then active, castAura = k, nil return end
	end
	if hidden then
		-- in combat the list can leave auras out (Devotion is often secret): the aura you just cast
		-- is the best guess; otherwise keep the last known state
		if castAura then active = castAura end
		return
	end
	active, castAura = false, nil
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
		f:SetIcon(Texture((want or "Devotion") .. " Aura")); f:SetFaded(false)
		f:SetTitle((want or "Devotion") .. " Aura"); f:SetStatus("Not active, click to cast", true)
		f:Glow(false); f:Show() return
	end
	local show = db.auraWarn and want and Applies()
		and (active == false or (db.auraStrict and active and active ~= want))
	if show then
		f:SetIcon(Texture(want .. " Aura"))
		f:SetTitle(want .. " Aura")
		if active == false then
			f:SetStatus("Not active, click to cast", true)
		else
			f:SetStatus(active .. " Aura is up instead", true)
		end
		f:Show(); f:Glow(true)
	else
		f:Glow(false); f:Hide()
	end
end

function M:Init()
	f = ns.MakeCard("LightboundAuraFrame")
	cast = ns.CastOverlay(f)
	ns.MakeMovable(f, "auPoint")
	ns.ApplyPoint(f, "auPoint")
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
		"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "SPELLS_CHANGED" }) do ev:RegisterEvent(e) end
	ev:RegisterUnitEvent("UNIT_AURA", "player")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			local key = name and name:match("^(.+) Aura$")
			if key then
				for _, k in ipairs(ns.AURAS) do if k == key then castAura, active = k, k end end
			end
		end
		M:Update()
	end)
	M:Update()
end

-- One key that buffs the group: each press (out of combat) casts the next needed buff.
-- Order: Righteous Fury on yourself (when the RF warning applies), then the assigned blessing
-- on the next party/raid member, yourself included, who is missing it or close to losing it.
-- Assignments always come from your row in the Blessings window (/lb blessings), like PallyPower.
-- The key is an override binding on a secure button.
local _, ns = ...
if not ns.isPaladin then return end -- not a paladin: load nothing (see Core.lua)

ns.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
ns.CHOICES = { "None", "Might", "Wisdom", "Kings", "Salvation", "Light", "Sanctuary" }
local DURATION, GREATER_DURATION = 300, 900 -- normal 5 min, Greater 15 min
local SYMBOL_OF_KINGS = 21177
local BUTTON = "LightboundPartyBuffButton"

local M = {}
ns.modules[#ns.modules + 1] = M

local btn, status, statusIcon, statusText, owner
local planned            -- { unit, guid, name, spell, key } for the next press
local pending            -- what the last press tried to cast
local recent = {}        -- guid -> { [key] = time cast }; fallback when auras can't be read
local recentLen = {}     -- guid -> { [key] = duration of that cast }: a Greater stays 15 min even
                         -- after the last Symbol of Kings is used up
-- records a landed blessing; `greater` = it was a Greater Blessing
local function Remember(guid, key, greater, at)
	if not guid then return end
	recent[guid] = recent[guid] or {}
	recent[guid][key] = at or GetTime()
	recentLen[guid] = recentLen[guid] or {}
	recentLen[guid][key] = greater and GREATER_DURATION or DURATION
end
-- seconds left from the last cast, or nil; `guess` is the duration to assume for an old record
local function CastLeft(guid, key, guess, now)
	local t = guid and recent[guid] and recent[guid][key]
	if not t then return nil end
	local len = recentLen[guid] and recentLen[guid][key] or guess
	return len - ((now or GetTime()) - t)
end
local isSecret = ns.IsSecret -- see Core.lua

-- Each blessing's ranks (spell IDs, lowest first) and their spell levels (Classic values, not yet
-- checked on Forever). A rank goes only on someone at most 10 levels below its spell level, so a
-- low group member gets the best rank they can take. Kings and Salvation have one rank.
local RANKS = {
	Might = { ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, levels = { 4, 12, 22, 32, 42, 52, 60 } },
	Wisdom = { ids = { 19742, 19850, 19852, 19853, 19854, 25290 }, levels = { 14, 24, 34, 44, 54, 60 } },
	Light = { ids = { 19977, 19978, 19979 }, levels = { 40, 50, 60 } },
	Sanctuary = { ids = { 20911, 20912, 20913, 20914 }, levels = { 30, 40, 50, 60 } },
}
local function Known(id)
	local ok, k = pcall(IsPlayerSpell, id)
	return ok and not isSecret(k) and k and true or false
end
-- for this unit: the rank's spell ID when it must be lower than your best (nil: your best will
-- do), and false when even the first rank is too high for them
local function RankFor(key, unit)
	local r = RANKS[key]
	if not r then return nil end
	local ok, level = pcall(UnitLevel, unit)
	if not ok or isSecret(level) or type(level) ~= "number" or level <= 0 then return nil end
	local best
	for i = #r.ids, 1, -1 do
		if Known(r.ids[i]) then
			best = best or r.ids[i]
			if r.levels[i] <= level + 10 then return r.ids[i] ~= best and r.ids[i] or nil end
		end
	end
	if best then return false end -- known, but every rank is too high for them
	return nil
end

local function Clean(v) if isSecret(v) or v == nil then return nil end return v end -- secret check first

local function SpellKnown(name)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) end
		return GetSpellInfo(name)
	end)
	return ok and info ~= nil
end

local function InRange(spell, unit)
	if UnitIsUnit(unit, "player") then return true end
	local ok, r = pcall(function()
		if C_Spell and C_Spell.IsSpellInRange then return C_Spell.IsSpellInRange(spell, unit) end
		return IsSpellInRange(spell, unit)
	end)
	if not ok or isSecret(r) or r == nil then
		return UnitInRange and Clean((UnitInRange(unit))) ~= false
	end
	return r == true or r == 1
end

-- Seconds left on Blessing/Greater Blessing of <key> on unit; 0 if missing, nil if auras unreadable.
local function TimeLeft(unit, key)
	local now, unreadable = GetTime(), false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
		if not ok then unreadable = true break end
		if not a then break end
		local name = Clean(a.name)
		if not name then
			unreadable = true
		elseif name == "Blessing of " .. key or name == "Greater Blessing of " .. key then
			local exp = Clean(a.expirationTime)
			if not exp or exp == 0 then return math.huge end
			return exp - now
		end
	end
	if unreadable then return nil end
	return 0
end

local function Units()
	local list = { "player" }
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if not UnitIsUnit(u, "player") then list[#list + 1] = u end
		end
	elseif IsInGroup() then
		for i = 1, GetNumSubgroupMembers() do list[#list + 1] = "party" .. i end
	end
	return list
end

-- Group assignments (Group.lua; PallyPower-compatible) ------------------------------
-- The Blessings window is the only source: your row there is what the key casts, solo, in a
-- party and in a raid. (The old own class list was copied into your row once, see Group.lua.)
-- Kept as a function for the callers that still ask.
function ns.PartyBuffSource() return "Group" end

-- Blessing key for a unit, and whether a Greater blessing may be used for it.
-- An empty cell means nothing from you: another paladin covers that class, or nobody does.
local function BaseAssignment(unit, class)
	local me, cid = ns.MyName(), ns.PP_CLASS[class]
	if not cid then return nil end
	local tname = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
	local idx = ns.GetNormalAssign(me, cid, tname or "") or ns.GetNormalAssign(me, cid, UnitName(unit) or "")
	if idx and ns.PP_SPELL[idx] then return ns.PP_SPELL[idx], false end
	idx = ns.GetAssign(me, cid)
	if ns.PP_SPELL[idx] then return ns.PP_SPELL[idx], true end
	return nil
end

-- Same, after Tanks.lua had its say (never Salvation on a tank). Third value: a note for /lb why.
local function Assignment(unit, class, source)
	local key, greaterOK = BaseAssignment(unit, class)
	if ns.TankAssignment then return ns.TankAssignment(unit, class, key, greaterOK) end
	return key, greaterOK
end

-- shared with the raid overview (Overview.lua)
ns.PB = { Units = Units, TimeLeft = TimeLeft, InRange = InRange, SpellKnown = SpellKnown, Assignment = Assignment,
	recent = recent, Remember = Remember, CastLeft = CastLeft, DURATION = DURATION, GREATER_DURATION = GREATER_DURATION, SYMBOL = SYMBOL_OF_KINGS }

local unlearned -- a blessing from your row that Plan skipped because you don't know it yet

-- Pick the next unit + blessing. Returns planned table or nil, plus a reason string.
local function Plan(why)
	unlearned = nil
	local function note(unit, text)
		if why then why[#why + 1] = (UnitName(unit) or unit) .. " (" .. unit .. "): " .. text end
	end
	local db = ns.db
	if db.pbRF and ns.RFNeeded and ns.RFNeeded() and SpellKnown("Righteous Fury") then
		if why then why[#why + 1] = "Righteous Fury first" end
		return { unit = "player", name = UnitName("player"), spell = "Righteous Fury", key = "Righteous Fury" }
	end
	local aura = ns.AuraNeeded and ns.AuraNeeded()
	if aura then
		if why then why[#why + 1] = aura .. " Aura first" end
		return { unit = "player", name = UnitName("player"), spell = aura .. " Aura", key = aura .. " Aura" }
	end
	local refresh = db.pbRefreshMinutes * 60
	local now = GetTime()
	local source = ns.PartyBuffSource()
	local raid = IsInRaid()
	local haveSymbol = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(SYMBOL_OF_KINGS) or GetItemCount and GetItemCount(SYMBOL_OF_KINGS) or 0) > 0
	if why then why[#why + 1] = "from your row in the Blessings window" .. (raid and ", raid" or "") end
	for _, unit in ipairs(Units()) do
		if not UnitExists(unit) then
			note(unit, "doesn't exist")
		elseif not UnitIsConnected(unit) then
			note(unit, "offline")
		elseif UnitIsDeadOrGhost(unit) then
			note(unit, "dead")
		elseif not UnitIsVisible(unit) then
			note(unit, "too far away (not visible)")
		else
			local _, class = UnitClass(unit)
			local key, greaterOK, tankNote = nil, false, nil
			if class then key, greaterOK, tankNote = Assignment(unit, class, source) end
			if not key then
				note(unit, tankNote or ("no blessing assigned for " .. tostring(class)))
			else
				if tankNote then note(unit, tankNote) end
				local spell = "Blessing of " .. key
				local greater = "Greater Blessing of " .. key
				local useGreater = db.pbGreater and raid and greaterOK and haveSymbol and SpellKnown(greater)
				if useGreater then spell = greater end
				local rank -- a Greater Blessing has no lower-level rule here
				if not useGreater then rank = RankFor(key, unit) end
				if not SpellKnown(spell) then
					unlearned = unlearned or spell
					note(unit, spell .. " not known")
				elseif rank == false then
					note(unit, ("too low (level %s) for any rank of %s you know"):format(tostring(UnitLevel(unit)), spell))
				elseif not InRange(spell, unit) then
					note(unit, "out of range for " .. spell)
				else
					local left = TimeLeft(unit, key)
					local guid = Clean(UnitGUID(unit)) -- can be secret in combat (/lb why); never a table key then
					local how = "aura"
					if left == nil then
						how = "auras hidden, using last cast"
						left = CastLeft(guid, key, useGreater and GREATER_DURATION or DURATION, now) or 0
					end
					if left <= refresh then
						note(unit, "NEXT: " .. spell .. (rank and (" (spell " .. rank .. ", a lower rank for their level)") or "") .. " (" .. how .. ")")
						return { unit = unit, guid = guid, name = UnitName(unit), spell = spell, key = key, rank = rank or nil }
					end
					note(unit, key .. " has " .. math.floor(left) .. "s left (" .. how .. ")")
				end
			end
		end
	end
	return nil
end

function ns.ExplainPartyBuff()
	local why = {}
	Plan(why)
	ns.Print("buff key check:")
	for _, line in ipairs(why) do print("  " .. line) end
end

local function Configure()
	if InCombatLockdown() or not btn then return end
	planned = ns.db.pbEnabled and Plan() or nil
	if planned and planned.rank then
		-- a lower rank, by spell ID (a "(Rank 4)" name is not certain to work on Forever); combat
		-- start clears the type (PLAYER_REGEN_DISABLED below), like [nocombat] does for the macro
		btn:SetAttribute("pbtype", "spell")
		btn:SetAttribute("type", "spell")
		btn:SetAttribute("spell", planned.rank)
		btn:SetAttribute("unit", planned.unit)
		btn:SetAttribute("macrotext", nil)
	elseif planned then
		-- [nocombat]: if this setup is still on the button when combat starts, it does nothing
		btn:SetAttribute("pbtype", "macro")
		btn:SetAttribute("type", "macro")
		btn:SetAttribute("macrotext", ("/cast [nocombat,@%s] %s"):format(planned.unit, planned.spell))
		btn:SetAttribute("spell", nil)
		btn:SetAttribute("unit", nil)
	else
		btn:SetAttribute("pbtype", nil)
		btn:SetAttribute("type", nil)
		btn:SetAttribute("macrotext", nil)
		btn:SetAttribute("unit", nil)
	end
end

local function SpellTexture(name)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
		return GetSpellTexture(name)
	end)
	return ok and tex or 135906
end

local function UpdateStatus()
	if not status then return end
	local db = ns.db
	if ns.unlocked then
		statusIcon:SetTexture(SpellTexture("Blessing of Might")); statusText:SetText("Might > Party member")
		status:Show() return
	end
	if not (db.pbEnabled and db.pbShowNext) or InCombatLockdown() or not planned
		or (not IsInGroup() and planned.unit ~= "player") then
		status:Hide() return
	end
	statusIcon:SetTexture(SpellTexture(planned.spell))
	local keyText = db.pbKey and (" |cff999999[" .. db.pbKey .. "]|r") or " |cffff3333[no key set]|r"
	local label = planned.spell:find("^Greater") and ("Greater " .. planned.key) or planned.key
	statusText:SetText(label .. " > " .. (planned.name or "?") .. keyText)
	status:Show()
end

-- Keybinding ----------------------------------------------------------------------
function ns.ApplyPartyBuffKey()
	if not owner then return end
	if InCombatLockdown() then M.keyPending = true return end
	ClearOverrideBindings(owner)
	if ns.db.pbKey and ns.db.pbEnabled then
		SetOverrideBindingClick(owner, true, ns.db.pbKey, BUTTON, "LeftButton")
	end
	M.keyPending = false
end

function M:Update()
	if not btn then return end
	Configure()
	UpdateStatus()
end

function M:Init()
	owner = CreateFrame("Frame")
	btn = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
	-- off in combat, secure: a lower rank is a plain spell action without [nocombat]; pbtype is what
	-- Configure set, put back after the fight
	btn:SetAttribute("_onstate-lbcombat",
		[[ self:SetAttribute("type", (newstate == 1 or newstate == "1") and "none" or self:GetAttribute("pbtype")) ]])
	RegisterStateDriver(btn, "lbcombat", "[combat] 1; 0")
	btn:SetSize(1, 1)
	btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100) -- off screen; used only through the key
	-- both phases, like ns.CastOverlay: the secure handler only acts on the one ActionButtonUseKeyDown
	-- picks (read at click time), so changing that setting needs no /reload and nothing casts twice
	btn:RegisterForClicks("AnyDown", "AnyUp")
	btn:SetAttribute("checkselfcast", false)
	btn:SetAttribute("checkfocuscast", false)
	btn:SetScript("PreClick", function(_, _, down)
		-- PreClick runs on both phases; only plan (and print) on the one that casts
		if (down and true or false) ~= (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false) then return end
		if InCombatLockdown() then return end
		Configure()
		pending = planned
		if not planned and ns.db.pbEnabled then
			ns.Print(unlearned and (unlearned .. " is in your row but not learned yet: change it in /lb blessings.")
				or "everyone in range is buffed.")
		end
	end)

	status = CreateFrame("Frame", "LightboundPartyBuffFrame", UIParent)
	status:SetSize(280, 28)
	status:SetFrameStrata("LOW")
	status:Hide()
	local bg = status:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.55)
	statusIcon = status:CreateTexture(nil, "ARTWORK")
	statusIcon:SetSize(24, 24); statusIcon:SetPoint("LEFT", 2, 0)
	statusIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	statusText = status:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	statusText:SetPoint("LEFT", statusIcon, "RIGHT", 6, 0)
	statusText:SetPoint("RIGHT", -4, 0)
	statusText:SetJustifyH("LEFT")
	ns.MakeMovable(status, "pbPoint")
	ns.ApplyPoint(status, "pbPoint")

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do
		ev:RegisterEvent(e)
	end
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("UNIT_AURA")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "PLAYER_REGEN_DISABLED" then
			-- entering combat: clear the button so a stale target/spell can't fire
			if not InCombatLockdown() then btn:SetAttribute("type", nil) end
			planned = nil
			if status then status:Hide() end
			return
		elseif event == "UNIT_AURA" then
			if unit ~= "player" and not (unit and unit:match("^party%d$")) then return end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local name = ns.SpellName(spellID)
			if pending and name == pending.spell and pending.guid and pending.key ~= "Righteous Fury" and not pending.key:find(" Aura$") then
				Remember(pending.guid, pending.key, pending.spell:find("^Greater") ~= nil)
			end
			pending = nil
		elseif event == "PLAYER_REGEN_ENABLED" and M.keyPending then
			ns.ApplyPartyBuffKey()
		end
		M:Update()
	end)
	C_Timer.NewTicker(2, function() M:Update() end) -- range and timers change without events
	ns.ApplyPartyBuffKey()
	M:Update()
end

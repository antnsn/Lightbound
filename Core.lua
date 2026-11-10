-- Shared setup: saved settings, safe aura reading, movable frames, /lb command.
local addonName, ns = ...

local _, class = UnitClass("player")
ns.isPaladin = class == "PALADIN"

ns.defaults = {
	enabled = true, sound = true, raid = true, world = true,
	rfPoint = { "CENTER", "UIParent", "CENTER", 0, 180 },
	seal = true, sealEmptyInCombat = true, sealHeight = 220, sealWidth = 22,
	sealPoint = { "CENTER", "UIParent", "CENTER", -260, -60 },
	sealDur = {},
	wellRested = true, wellRestedMinutes = 5, wellRestedSound = true, wellRestedIcon = true,
	wrPoint = { "CENTER", "UIParent", "CENTER", 0, 260 },
	wellFed = true, wellFedMinutes = 3, wellFedSound = true, wellFedIcon = true,
	wfPoint = { "CENTER", "UIParent", "CENTER", 70, 260 },
	blessEnabled = true, blessOnlyProblems = false, blessWarnMinutes = 1, blessHideResting = true, blessOnlyGrouped = false,
	blessTrack = { Might = true, Wisdom = false, Kings = true, Salvation = false, Light = false, Sanctuary = false },
	blPoint = { "CENTER", "UIParent", "CENTER", 0, -200 },
	pbEnabled = true, pbShowNext = true, pbRefreshMinutes = 1, pbKey = nil,
	pbSource = "Auto", pbGreater = true, pbRF = true, pbAura = true, freeAssign = false, minimap = true, minimapAngle = 220,
	ovEnabled = true, ovOnlyRaid = true, ovPoint = { "CENTER", "UIParent", "CENTER", -380, 120 },
	reagentBuy = true, reagentKings = 100, reagentDivinity = 5, reagentWarn = 20,
	procEnabled = true, procSound = true, prPoint = { "CENTER", "UIParent", "CENTER", 0, 110 },
	judgeEnabled = true, judgeMissing = true, jdPoint = { "CENTER", "UIParent", "CENTER", -90, 110 },
	trEnabled = true, trReckoning = true, trReckoningSound = false, trConsecration = true, trHolyShock = true,
	trHolyShockSound = false, trMana = true, trManaPct = 30, trManaSound = true,
	trPoint = { "CENTER", "UIParent", "CENTER", 0, 60 },
	jaEnabled = true, jaSound = true, jaOnlyMine = false, jaPoint = { "CENTER", "UIParent", "CENTER", 0, 60 }, judgeAssign = {},
	cdEnabled = true, cdOnlyRaid = false, cdShowSelf = true, cdPoint = { "CENTER", "UIParent", "CENTER", -380, -40 },
	auraWarn = true, auraOnlyGrouped = false, auraStrict = false, auraChoice = "Devotion",
	auPoint = { "CENTER", "UIParent", "CENTER", 80, 180 },
	pbAssign = { WARRIOR = "Might", PALADIN = "Wisdom", HUNTER = "Might", ROGUE = "Might", PRIEST = "Wisdom",
		SHAMAN = "Wisdom", MAGE = "Wisdom", WARLOCK = "Wisdom", DRUID = "Wisdom" },
	pbPoint = { "CENTER", "UIParent", "CENTER", 0, -260 },
	clEnabled = true, clSound = true, clRows = 5, clPets = false, clIgnore = {},
	clPoint = { "CENTER", "UIParent", "CENTER", 380, 120 },
	rqEnabled = true, rqSound = true, rqChat = false, rqGroupOnly = true, rqTTL = 60, rqRows = 4,
	rqPoint = { "CENTER", "UIParent", "CENTER", -380, -60 },
	diEnabled = true, diParty = false, diRows = 6, diAnnounce = true, diWarning = true,
	diPoint = { "CENTER", "UIParent", "CENTER", 300, -60 },
	rezAnnounce = true, rezWhisper = false,
	tankGuard = true, tankList = {},
	tankBless = { WARRIOR = "Might", DRUID = "Might", PALADIN = "Kings", HUNTER = "Kings", ROGUE = "Kings",
		PRIEST = "Kings", SHAMAN = "Kings", MAGE = "Kings", WARLOCK = "Kings" },
}

local isSecret = _G.issecretvalue or function() return false end
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>"

local function Clean(v)
	if v == nil or isSecret(v) then return nil end
	return v
end

-- Reads the player's buffs. Returns a table name -> { icon, duration, expires }
-- and a flag that is true when some auras were hidden from addons (combat restrictions).
function ns.ReadPlayerBuffs()
	local buffs, hidden = {}, false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok then return buffs, true end
		if not a then break end
		local name = Clean(a.name)
		if not name or name == RESTRICTED then
			hidden = true
		else
			buffs[name] = { icon = Clean(a.icon), duration = Clean(a.duration), expires = Clean(a.expirationTime) }
		end
	end
	if InCombatLockdown() then
		-- seals and some self buffs can simply be left out of the list in combat
		hidden = true
	end
	return buffs, hidden
end

function ns.SpellName(spellID)
	if not spellID or isSecret(spellID) then return nil end
	local ok, name = pcall(function()
		if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
		return (GetSpellInfo(spellID))
	end)
	return ok and Clean(name) or nil
end

-- Movable frames ------------------------------------------------------------

ns.movers = {}
ns.unlocked = false

function ns.MakeMovable(frame, key)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		ns.db[key] = { p, "UIParent", rp, x, y }
	end)
	ns.movers[#ns.movers + 1] = { frame = frame, key = key }
end

function ns.ApplyPoint(frame, key)
	local p = ns.db[key]
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end

-- Modules and events ----------------------------------------------------------

ns.modules = {}
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name ~= addonName then return end
	LightboundDB = LightboundDB or {}
	ns.db = LightboundDB
	for k, v in pairs(ns.defaults) do
		if ns.db[k] == nil then ns.db[k] = type(v) == "table" and CopyTable(v) or v end
	end
	if ns.db.point then ns.db.rfPoint, ns.db.point = ns.db.point, nil end -- v1.0 setting
	if ns.db.pbSource == "PallyPower" then ns.db.pbSource = "Group" end -- v2.4 setting
	self:UnregisterEvent("ADDON_LOADED")
	if not ns.isPaladin then return end
	for _, m in ipairs(ns.modules) do m:Init() end
end)

-- Slash command ---------------------------------------------------------------

local function Print(msg) print("|cffffd100Lightbound:|r " .. msg) end
local function OnOff(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end

local function Refresh()
	for _, m in ipairs(ns.modules) do
		if m.Layout then m:Layout() end
		m:Update()
	end
end
ns.Refresh = Refresh
ns.Print = Print

function ns.ToggleMove()
	if InCombatLockdown() then Print("leave combat first.") return end
	ns.unlocked = not ns.unlocked
	for _, m in ipairs(ns.movers) do m.frame:EnableMouse(ns.unlocked) end
	Print(ns.unlocked and "unlocked, drag the frames. Lock them again when done." or "locked.")
	Refresh()
end

function ns.ResetPositions()
	if InCombatLockdown() then Print("leave combat first.") return end
	local db = ns.db
	for k, v in pairs(ns.defaults) do
		if k:find("Point$") then db[k] = CopyTable(v) end
	end
	for _, m in ipairs(ns.movers) do ns.ApplyPoint(m.frame, m.key) end
	Print("positions reset.")
	Refresh()
end

SLASH_LIGHTBOUND1 = "/lb"
SLASH_LIGHTBOUND2 = "/lightbound"
SLASH_LIGHTBOUND3 = "/rfr"
SlashCmdList.LIGHTBOUND = function(msg)
	if not ns.isPaladin then Print("only does something on a paladin.") return end
	local db = ns.db
	local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
	if cmd == "toggle" then
		db.enabled = not db.enabled; Print("Righteous Fury warning " .. OnOff(db.enabled))
	elseif cmd == "sound" then
		db.sound = not db.sound; Print("sound " .. OnOff(db.sound))
	elseif cmd == "rfraid" then
		db.raid = not db.raid; Print("warn in raids " .. OnOff(db.raid))
	elseif cmd == "world" then
		db.world = not db.world; Print("warn in party outside instances " .. OnOff(db.world))
	elseif cmd == "seal" then
		db.seal = not db.seal; Print("seal timer " .. OnOff(db.seal))
	elseif cmd == "empty" then
		db.sealEmptyInCombat = not db.sealEmptyInCombat; Print("show empty seal bar in combat " .. OnOff(db.sealEmptyInCombat))
	elseif cmd == "height" and tonumber(arg) then
		db.sealHeight = math.max(60, math.min(600, tonumber(arg))); Print("seal bar height " .. db.sealHeight)
	elseif cmd == "rested" then
		db.wellRested = not db.wellRested; Print("Well-Rested warning " .. OnOff(db.wellRested))
	elseif cmd == "fed" then
		db.wellFed = not db.wellFed; Print("Well Fed warning " .. OnOff(db.wellFed))
	elseif cmd == "raid" or cmd == "assign" then
		if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end
		return
	elseif cmd == "minimap" then
		db.minimap = not db.minimap; Print("minimap button " .. OnOff(db.minimap))
	elseif cmd == "ignore" then
		db.clIgnore = db.clIgnore or {}
		if arg and arg ~= "" then
			db.clIgnore[arg] = not db.clIgnore[arg] or nil
			Print("cleanse list " .. (db.clIgnore[arg] and "ignores" or "no longer ignores") .. " '" .. arg .. "'")
		else
			local names = {}
			for n in pairs(db.clIgnore) do names[#names + 1] = n end
			table.sort(names)
			Print("ignored debuffs: " .. (#names > 0 and table.concat(names, ", ") or "none") .. ". /lb ignore <name> toggles one.")
			return
		end
	elseif cmd == "why" then
		if ns.ExplainPartyBuff then ns.ExplainPartyBuff() end
		return
	elseif cmd == "tank" or cmd == "tanks" then
		-- names keep their case: split the original message again
		if ns.ToggleTank then ns.ToggleTank((select(2, strsplit(" ", strtrim(msg or ""), 2)))) end
		return
	elseif cmd == "move" then
		ns.ToggleMove() return
	elseif cmd == "reset" then
		ns.ResetPositions() return
	elseif cmd == "" or cmd == "config" or cmd == "options" then
		if ns.ToggleOptions then ns.ToggleOptions() end
		return
	else
		Print("/lb opens the options window. Commands: toggle " .. OnOff(db.enabled) .. ", sound " .. OnOff(db.sound) .. ", rfraid " .. OnOff(db.raid)
			.. ", world " .. OnOff(db.world) .. ", seal " .. OnOff(db.seal) .. ", empty " .. OnOff(db.sealEmptyInCombat) .. ", height <n>, rested " .. OnOff(db.wellRested) .. ", raid (blessings window), minimap " .. OnOff(db.minimap) .. ", ignore <debuff>, tank <name>, why, move, reset")
		return
	end
	Refresh()
end

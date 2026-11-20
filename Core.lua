-- Lightbound's setup on LibBound-1.0 (the shared core of the Bound addons): saved settings and
-- their migrations, the /lb command. Safe aura reading, movable frames, cards, click-to-cast
-- overlays and the module loader come from LibBound. Every other file returns at once on a
-- non-paladin (ns.isPaladin).
local addonName, ns = ...
local Bound = LibStub("LibBound-1.0")

local DEFAULTS = {
	enabled = true, sound = true, raid = true, world = true,
	snap = true, gridSize = 20, -- unlocked frames snap to a grid around the screen centre
	rfPoint = { "CENTER", "UIParent", "CENTER", 0, 230 },
	seal = true, sealEmptyInCombat = true, sealHeight = 220, sealWidth = 22,
	twist = true, twistBuild = "Seal of Command", twistBurst = "Seal of Righteousness",
	twistCDs = true, twistSound = false, twistKnown = {}, -- per character: Unsealed Wrath seen (Twist.lua)
	twistPoint = { "CENTER", "UIParent", "CENTER", 0, -190 },
	sealPoint = { "CENTER", "UIParent", "CENTER", -260, -60 },
	sealDur = {},
	wellRested = true, wellRestedMinutes = 5, wellRestedSound = true, wellRestedIcon = true, wellRestedKeep = false,
	wrPoint = { "CENTER", "UIParent", "CENTER", 0, 350 },
	wellFed = true, wellFedMinutes = 3, wellFedSound = true, wellFedIcon = true, wellFedKeep = false,
	wfPoint = { "CENTER", "UIParent", "CENTER", 0, 290 },
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
	jaEnabled = true, jaSound = true, jaOnlyMine = false, jaPoint = { "CENTER", "UIParent", "CENTER", 0, 10 }, judgeAssign = {},
	cdEnabled = true, cdOnlyRaid = false, cdShowSelf = true, cdPoint = { "CENTER", "UIParent", "CENTER", -380, -80 },
	auraWarn = true, auraOnlyGrouped = false, auraStrict = false, auraChoice = "Devotion",
	auPoint = { "CENTER", "UIParent", "CENTER", 0, 170 },
	-- pbSource and pbAssign (the old own class list) are only read once by MigrateClassList in Group.lua
	pbAssign = { WARRIOR = "Might", PALADIN = "Wisdom", HUNTER = "Might", ROGUE = "Might", PRIEST = "Wisdom",
		SHAMAN = "Wisdom", MAGE = "Wisdom", WARLOCK = "Wisdom", DRUID = "Wisdom" },
	pbPoint = { "CENTER", "UIParent", "CENTER", 0, -260 },
	carrotSwap = false, carrotSlot = "Bottom", carrotPrev = {},
	clEnabled = true, clSolo = true, clSound = true, clRows = 5, clPets = false, clIgnore = {},
	clMode = "Grid", clPerRow = 5, clCell = 22, clNames = false, clRange = true,
	clPoint = { "TOPLEFT", "UIParent", "CENTER", 285, 190 },
	rqEnabled = true, rqSound = true, rqChat = false, rqGroupOnly = true, rqTTL = 60, rqRows = 4,
	rqPoint = { "CENTER", "UIParent", "CENTER", 380, -40 },
	diEnabled = true, diParty = false, diRows = 6, diAnnounce = true, diWarning = true,
	diPoint = { "CENTER", "UIParent", "CENTER", 380, -220 },
	rezAnnounce = true, rezWhisper = false, drinkAnnounce = false, drinkInstanceOnly = true,
	tankGuard = true, tankList = {},
	tankBless = { WARRIOR = "Might", DRUID = "Might", PALADIN = "Kings", HUNTER = "Kings", ROGUE = "Kings",
		PRIEST = "Kings", SHAMAN = "Kings", MAGE = "Kings", WARLOCK = "Kings" },
}

-- settings from earlier versions
local function Migrate(db, defaults)
	if db.point then db.rfPoint, db.point = db.point, nil end -- v1.0 setting
	-- v4.3: the buff timers became wide cards; move Well Fed off the old spot next to Well-Rested
	local wf = db.wfPoint
	if wf and wf[1] == "CENTER" and wf[3] == "CENTER" and wf[4] == 70 and wf[5] == 260 then
		db.wfPoint = CopyTable(defaults.wfPoint)
	end
	-- v4.4: aura and Righteous Fury became cards too; the four cards stack above the proc and
	-- Judgement icons (those sit at y 110). Only frames still at an old default move, so frames you
	-- placed stay where they are. (The second set is from 4.4 test builds.)
	local OLD = {
		rfPoint = { { 0, 180 }, { 0, 160 } }, auPoint = { { 80, 180 }, { 0, 100 } },
		wrPoint = { { 0, 260 }, { 0, 280 } }, wfPoint = { { 0, 200 }, { 0, 220 } },
	}
	for key, spots in pairs(OLD) do
		local p = db[key]
		for _, xy in ipairs(spots) do
			if type(p) == "table" and p[1] == "CENTER" and p[3] == "CENTER" and p[4] == xy[1] and p[5] == xy[2] then
				db[key] = CopyTable(defaults[key])
			end
		end
	end
	if db.pbSource == "PallyPower" then db.pbSource = "Group" end -- v2.4 setting
end

local function OnOff(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end
local function Toggle(key, text) return function() ns.db[key] = not ns.db[key]; ns.Print(text .. " " .. OnOff(ns.db[key])) end end

ns.isPaladin = not Bound:NewAddon(addonName, ns, {
	class = "PALADIN",
	title = "Lightbound",
	prefix = "ffd100",
	db = "LightboundDB",
	defaults = DEFAULTS,
	migrate = Migrate,
	slash = { "/lb", "/lightbound", "/rfr" },
	media = "Interface\\AddOns\\Lightbound\\Media\\",
	commands = {
		toggle = { fn = Toggle("enabled", "Righteous Fury warning"), help = "Righteous Fury warning on/off" },
		sound = { fn = Toggle("sound", "sound"), help = "sound on/off" },
		rfraid = { fn = Toggle("raid", "warn in raids"), help = "Righteous Fury warning in raids on/off" },
		world = { fn = Toggle("world", "warn in party outside instances"), help = "Righteous Fury warning in parties outside instances" },
		seal = { fn = Toggle("seal", "seal timer"), help = "seal timer on/off" },
		empty = { fn = Toggle("sealEmptyInCombat", "show empty seal bar in combat"), help = "empty seal bar in combat on/off" },
		height = { fn = function(arg)
			local n = tonumber(arg)
			if not n then ns.Print("/lb height <number>") return end
			ns.db.sealHeight = math.max(60, math.min(600, n)); ns.Print("seal bar height " .. ns.db.sealHeight)
		end, help = "height <n>: seal bar height" },
		rested = { fn = Toggle("wellRested", "Well-Rested warning"), help = "Well-Rested warning on/off" },
		fed = { fn = Toggle("wellFed", "Well Fed warning"), help = "Well Fed warning on/off" },
		blessings = { fn = function() if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end end, help = "the Blessings window (also /lb raid)" },
		bless = { fn = function() if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end end, help = "the Blessings window" },
		raid = { fn = function() if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end end, help = "the Blessings window" },
		assign = { fn = function() if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end end, help = "the Blessings window" },
		ignore = { fn = function(arg)
			local db = ns.db
			db.clIgnore = db.clIgnore or {}
			if arg and arg ~= "" then
				arg = arg:lower()
				db.clIgnore[arg] = not db.clIgnore[arg] or nil
				ns.Print("cleanse list " .. (db.clIgnore[arg] and "ignores" or "no longer ignores") .. " '" .. arg .. "'")
				if ns.CleanseIgnoreChanged then ns.CleanseIgnoreChanged() end
			else
				local names = {}
				for n in pairs(db.clIgnore) do names[#names + 1] = n end
				table.sort(names)
				ns.Print("ignored debuffs: " .. (#names > 0 and table.concat(names, ", ") or "none") .. ". /lb ignore <name> toggles one.")
			end
		end, help = "ignore <debuff>: the Cleanse list ignores it (again: stops)" },
		why = { fn = function() if ns.ExplainPartyBuff then ns.ExplainPartyBuff() end end, help = "why the buff key does what it does" },
		tank = { fn = function(arg) if ns.ToggleTank then ns.ToggleTank(arg) end end, help = "tank <name>: mark or unmark a tank" },
		tanks = { fn = function(arg) if ns.ToggleTank then ns.ToggleTank(arg) end end, help = "tank list" },
		snap = { fn = function(arg) ns.commands.grid.fn(arg) end, help = "same as grid" },
	},
})

-- true when a cast is a spell from your spellbook, false for something it set off (a seal's proc).
-- When the client won't say, nearSwing decides: right after a swing it was most likely a proc.
function ns.IsOwnSpell(spellID, nearSwing)
	if spellID and not ns.IsSecret(spellID) and IsPlayerSpell then
		local ok, own = pcall(IsPlayerSpell, spellID)
		if ok and not ns.IsSecret(own) and own ~= nil then return own and true or false end
	end
	return not nearSwing
end

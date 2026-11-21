-- Lightbound's option pages (/lb). LibBound builds the window, the widgets, and the shared Extras
-- (Well-Rested, Well Fed, explanations, minimap; Lightbound adds Carrot on a Stick there) and
-- Skin pages. Modules add their own pages through ns.optionPages; these come first.
local _, ns = ...
if not ns.isPaladin then return end -- not a paladin: load nothing (see Core.lua)
local Bound = LibStub("LibBound-1.0")

local UI = ns.UI
local C = UI.C
local Font = UI.Font
local Button, Toggle, DBToggle, Slider, Cycle, Section, NewPage, KeyButton =
	UI.Button, UI.Toggle, UI.DBToggle, UI.Slider, UI.Cycle, UI.Section, UI.NewPage, UI.KeyButton
local CONTENT_W = UI.CONTENT_W

local function BuildRF()
	local p = NewPage("Righteous Fury", "Warns with an icon and a sound when you're grouped without Righteous Fury.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "enabled", "Warn when Righteous Fury is missing")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "world", "Also in party outside instances", "Not while resting in a city or inn.")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "raid", "Also in raids")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "sound", "Play a warning sound")) + 6)
end

local function BuildAura()
	local p = NewPage("Aura", "Warns when no aura is up. The buff key can cast it for you.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "auraWarn", "Warn when no aura is up")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "auraStrict", "Also warn when it isn't the assigned aura")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "auraOnlyGrouped", "Only when in a group")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbAura", "Cast the aura with the buff key")) + 14)
	p:Add(select(2, Cycle(p, p.y, "My aura", ns.AURAS,
		function() return ns.db.auraChoice end,
		function(v) ns.db.auraChoice = v end,
		function() local w = ns.WantedAura and ns.WantedAura(); return w and ("using " .. w) or "" end)))
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y - 4); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("When the buff key uses group assignments, the aura the group assigned you wins.")
end

local function BuildSeal()
	local p = NewPage("Seal timer", "A vertical bar that empties while your seal runs out.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "seal", "Show the seal timer")) + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "sealEmptyInCombat", "Show an empty bar in combat", "Reminds you to put a seal up when you have none.")) + 16)
	p:Add(select(2, Slider(p, p.y, "Bar height", "sealHeight", 60, 600, 10, " px")) + 8)
	p:Add(select(2, Slider(p, p.y, "Bar width", "sealWidth", 10, 60, 1, " px")))
end

local function BuildBlessings()
	local p = NewPage("My buffs", "Icons with time left for the blessings you want on yourself.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessEnabled", "Show my blessings")) + 6)
	p:Add(Section(p, p.y - 4, "Track") + 6)
	local colW = math.floor(W / 3)
	for i, b in ipairs(ns.BLESSINGS) do
		local col, rowI = (i - 1) % 3, math.floor((i - 1) / 3)
		Toggle(p, col * colW, p.y - rowI * 30, colW - 10, b.key, nil,
			function() return ns.db.blessTrack[b.key] end,
			function(v) ns.db.blessTrack[b.key] = v end)
	end
	p:Add(math.ceil(#ns.BLESSINGS / 3) * 30 + 8)
	p:Add(Section(p, p.y, "When") + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessOnlyProblems", "Only show missing or nearly expired blessings")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessOnlyGrouped", "Only when in a group")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "blessHideResting", "Hide in cities and inns")) + 12)
	Slider(p, p.y, "Nearly expired at", "blessWarnMinutes", 1, 10, 1, " min")
end

local function BuildKey()
	local p = NewPage("Buff key", "One key, out of combat: Righteous Fury, then your aura, then the blessings in your row of the Blessings window.")
	local W = CONTENT_W
	-- who gets what lives in the Blessings window only; this page is about the key itself
	local rb = Button(p, "Open blessings", 150, 26, true)
	rb:SetPoint("TOPLEFT", 0, p.y)
	rb:SetScript("OnClick", function()
		if ns.optionsState.win then ns.optionsState.win:Hide() end
		if ns.OpenRaidWindow then ns.OpenRaidWindow() elseif ns.ToggleRaidWindow then ns.ToggleRaidWindow() end
	end)
	p:Add(40)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbEnabled", "Buff the group with one key", nil,
		function() ns.ApplyPartyBuffKey() end)) + 10)

	p:Add(select(2, KeyButton(p, p.y, "Key", "pbKey", function() ns.ApplyPartyBuffKey() end, "buff key")) + 6)

	p:Add(Section(p, p.y, "How it casts") + 6)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbShowNext", "Show what the next press will cast")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbRF", "Cast Righteous Fury first if it's missing")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "pbGreater", "Greater Blessings in raid", "Needs the spell and Symbol of Kings in your bags.")) + 12)
	Slider(p, p.y, "Rebuff with time left", "pbRefreshMinutes", 0, 4, 1, " min")
end

local function BuildCombat()
	local p = NewPage("Combat", "Shows when Hammer of Wrath or Exorcism can be cast, and your Judgement on the target.")
	local W = CONTENT_W
	p:Add(Section(p, p.y - 4, "Procs") + 2)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "procEnabled", "Hammer of Wrath and Exorcism alert",
		"Hammer of Wrath when the target is under 20%, Exorcism on undead and demons. Only when off cooldown.")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "procSound", "Play a sound when it shows")) + 14)
	p:Add(Section(p, p.y, "Judgement") + 2)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "judgeEnabled", "Show your Judgement on the target", "Icon with seconds left.")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "judgeMissing", "Remind me when it's missing", "A dim icon in combat when your target has no Judgement from you.")) + 4)
end

local function BuildOverview()
	local p = NewPage("Raid overview", "Each class you bless: how many miss it and the shortest time left. Click a row to bless that class.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "ovEnabled", "Show the overview")) + 4)
	p:Add(select(2, DBToggle(p, 0, p.y, W, "ovOnlyRaid", "Only in raids", "Off: also in a party.")) + 14)
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("Red = someone is missing it, gold = running low. In a raid a click casts the Greater Blessing on the whole class (needs Symbol of Kings). Clicks work out of combat only. Unlock frames to move it.")
end

local function BuildReagents()
	local p = NewPage("Reagents", "Buys reagents at any vendor that sells them, and warns when you run low.")
	local W = CONTENT_W
	p:Add(select(2, DBToggle(p, 0, p.y, W, "reagentBuy", "Buy reagents at vendors automatically")) + 10)
	p:Add(select(2, Slider(p, p.y, "Keep Symbol of Kings", "reagentKings", 0, 200, 10, "")) + 6)
	p:Add(select(2, Slider(p, p.y, "Keep Symbol of Divinity", "reagentDivinity", 0, 20, 1, "")) + 6)
	p:Add(select(2, Slider(p, p.y, "Warn below (Symbol of Kings)", "reagentWarn", 0, 100, 5, "")) + 6)
	local n = Font(p, 12, C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("Symbol of Kings is bought once you know a Greater Blessing, Symbol of Divinity once you know Divine Intervention. 0 turns one off.")
end

-- Carrot on a Stick, on the shared Extras page
local function Carrot(_, p)
	p:Add(Section(p, p.y - 4, "Carrot on a Stick") + 2)
	-- one row (the page has no room for two): Off, or the trinket slot the carrot goes into
	local CARROT_CHOICES = { "Off", "Top trinket", "Bottom trinket" }
	p:Add(select(2, Cycle(p, p.y, "Wear it while mounted", CARROT_CHOICES,
		function() return ns.db.carrotSwap and (ns.db.carrotSlot .. " trinket") or "Off" end,
		function(v)
			ns.db.carrotSwap = v ~= "Off"
			if v ~= "Off" then ns.db.carrotSlot = v:match("^(%a+)") end
		end,
		function()
			if not ns.db.carrotSwap then return "Your own trinket goes back on when you get off." end
			return "Swaps out: " .. ns.CarrotSlotItem(ns.db.carrotSlot)
		end)))
end

-- before the pages other modules added
local mine = { BuildRF, BuildAura, BuildSeal, BuildCombat, BuildBlessings, BuildKey, BuildOverview, BuildReagents }
for i, build in ipairs(mine) do table.insert(ns.optionPages, i, build) end

-- Blizzard's Cooldown Manager in the Lightbound look (it counts buffs in combat; addons can't)
Bound.InstallCooldownSkin(ns, { suggest = { "Seals", "Holy Shield", "Righteous Fury", "Divine Favor",
	"Vengeance", "Redoubt", "Judgements on your target", "your Blessings and Aura" } })

Bound.InstallOptions(ns, {
	header = "Paladin buffs",
	launcher = "Paladin buffing and self-buff helper.",
	extras = Carrot,
})

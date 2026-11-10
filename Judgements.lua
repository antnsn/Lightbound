-- Judgement assignments: who keeps which Judgement (Wisdom, Light, Crusader, Justice) on the boss.
-- Shared between Lightbound paladins over the LBND prefix (PallyPower never sees it):
--   JUDGE <name> <choice>              one change
--   JUDGEALL name=choice,name=choice   everything, sent when a peer asks for a full sync
-- The leader and assists set anyone; everyone sets their own (or anyone who opted in), like blessings.
-- In combat a small frame shows one icon per assigned Judgement: bright when it's on your target,
-- dim with the responsible paladin's name when it's missing.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local isSecret = _G.issecretvalue or function() return false end
local function Clean(v) if v == nil or isSecret(v) then return nil end return v end
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>" -- placeholder the client returns for hidden aura names

ns.JUDGEMENTS = { "None", "Wisdom", "Light", "Crusader", "Justice" }
local VALID = { None = true, Wisdom = true, Light = true, Crusader = true, Justice = true }
local DEBUFF = { Wisdom = "Judgement of Wisdom", Light = "Judgement of Light", Crusader = "Judgement of the Crusader", Justice = "Judgement of Justice" }
local SEAL = { Wisdom = "Seal of Wisdom", Light = "Seal of Light", Crusader = "Seal of the Crusader", Justice = "Seal of Justice" }
-- icons for seals you may not know (only spells you know have a texture by name)
local FALLBACK_ICON = { Wisdom = 135960, Light = 135917, Crusader = 135924, Justice = 135971 }
local JUDGE_ICON = 135959
local JUDGEMENT_TIME = 10 -- how long your own Judgement is assumed up when the debuff list is hidden
local SOUND_GAP = 10

local frame, icons = nil, {}
local lastSound, lastCast = 0, 0
local lastCastName -- "Judgement of X" from the seal that was up when you last judged (nil when unreadable)
local plan, planMine, planAt = nil, nil, 0 -- cached Plan(); GroupPaladins() rescans talents, so not every tick

local function Texture(spell)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
		return GetSpellTexture(spell)
	end)
	return ok and tex or nil
end
local texCache = {}
function ns.JudgeTexture(choice)
	if not SEAL[choice] then return JUDGE_ICON end
	texCache[choice] = texCache[choice] or Texture(SEAL[choice])
	return texCache[choice] or FALLBACK_ICON[choice]
end

-- Assignments ---------------------------------------------------------------------
local function Table()
	ns.db.judgeAssign = ns.db.judgeAssign or {}
	return ns.db.judgeAssign
end

function ns.GetJudgeAssign(name)
	local v = Table()[name]
	return VALID[v] and v or "None"
end

local function Changed()
	planAt = 0
	if ns.RaidWindowRefresh then ns.RaidWindowRefresh() end
	M:Update()
end

-- Entries this session has authority over: your own, ones you set, ones the group sent you.
-- A full sync only carries these, so joining with stale local state can't erase the group's.
local authoritative = {}
local function Store(name, choice)
	Table()[name] = choice ~= "None" and choice or nil
	authoritative[name] = true
end

-- Set paladin `name` to `choice` and tell the group. Checks who may change whom.
function ns.SetJudgeAssign(name, choice)
	if not VALID[choice] then return end
	if not ns.CanControl(name) then ns.Print("only the leader or an assist can change " .. name .. ".") return end
	Store(name, choice)
	ns.SendLB(("JUDGE %s %s"):format(name, choice))
	Changed()
end

-- Same rule as Group.lua for PLPWR ASSIGN: a paladin may change their own row, the leader/assists
-- anyone's, others only paladins who allow it (you: your setting; others: what they sent).
local function Allowed(sender, name)
	if name == sender or ns.IsGroupLeader(sender) then return true end
	if name == ns.MyName() then return ns.db.freeAssign and true or false end
	local p = ns.pallys[name]
	return p and p.freeassign or false
end

-- PallyPower-style names: the realm is dropped for your own realm (mirrors Group.lua)
local function Normalize(name)
	if name == UnitName("player") then return ns.MyName() end
	local base, realm = strsplit("-", name)
	if realm and realm ~= (GetNormalizedRealmName and GetNormalizedRealmName()) then return name end
	return base
end

local function Receive(sender, name, choice)
	local sp = ns.pallys[sender]
	if sp then sp.lightbound = true end -- only Lightbound sends LBND: the raid window can tell who sees Judgements
	name = Normalize(name)
	if not VALID[choice] or not Allowed(sender, name) then return false end
	local old = ns.GetJudgeAssign(name)
	Store(name, choice)
	if name == ns.MyName() and old ~= choice and sender ~= ns.MyName() then
		ns.Print(sender .. (choice == "None" and " removed your Judgement assignment." or (" assigned you " .. DEBUFF[choice] .. ".")))
	end
	return old ~= choice
end

ns.OnLB("JUDGE", function(sender, rest)
	if sender == ns.MyName() or not ns.UnitForName(sender) then return end
	local name, choice = rest:match("^(%S+)%s+(%a+)$")
	if name and Receive(sender, name, choice) then Changed() end
end)

ns.OnLB("JUDGEALL", function(sender, rest)
	if sender == ns.MyName() or not ns.UnitForName(sender) then return end
	local changed = false
	for name, choice in rest:gmatch("([^=,%s]+)=(%a+)") do
		if Receive(sender, name, choice) then changed = true end
	end
	if changed then Changed() end
end)

-- full state for a peer: every paladin in the group, None included so clears propagate
ns.OnLBSync(function(target)
	local parts, len = {}, 0
	local function flush()
		if #parts > 0 then ns.SendLB("JUDGEALL " .. table.concat(parts, ","), target) end
		parts, len = {}, 0
	end
	for _, name in ipairs(ns.GroupPaladins()) do
		if name == ns.MyName() or authoritative[name] then
			local s = name .. "=" .. ns.GetJudgeAssign(name)
			if len + #s + 1 > 220 then flush() end
			parts[#parts + 1] = s
			len = len + #s + 1
		end
	end
	flush()
end)

-- Target tracker ------------------------------------------------------------------
local function HostileTarget()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
end

-- assigned Judgements in the group: list of { choice, names = {...} }, in ns.JUDGEMENTS order
local function Plan()
	local me, mine = ns.MyName(), nil
	local byChoice = {}
	for _, name in ipairs(ns.GroupPaladins()) do
		local c = ns.GetJudgeAssign(name)
		if c ~= "None" then
			byChoice[c] = byChoice[c] or {}
			byChoice[c][#byChoice[c] + 1] = name
			if name == me then mine = c end
		end
	end
	local list = {}
	for _, c in ipairs(ns.JUDGEMENTS) do
		if byChoice[c] and (not ns.db.jaOnlyMine or c == mine) then
			list[#list + 1] = { choice = c, names = byChoice[c] }
		end
	end
	return list, mine
end

-- Judgement debuffs on the target: name -> seconds left (or true). Second value: some names were
-- hidden; third: nothing at all could be read.
local function ReadTarget()
	local found, hidden, readable = {}, false, false
	for i = 1, 40 do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL")
		if not ok then hidden = true break end
		if not a then break end
		local name = Clean(a.name)
		if not name or name == RESTRICTED then
			hidden = true
		else
			readable = true
			if name:find("^Judgement of") then
				local exp = Clean(a.expirationTime)
				found[name] = (exp and exp > 0) and (exp - GetTime()) or true
			end
		end
	end
	return found, hidden, hidden and not readable
end

local function MakeIcon(i)
	local b = CreateFrame("Frame", nil, frame)
	b:SetSize(32, 32)
	b:SetPoint("LEFT", (i - 1) * 40, 0)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.time = b:CreateFontString(nil, "OVERLAY")
	b.time:SetFont("Fonts\\ARIALN.TTF", 15, "OUTLINE")
	b.time:SetPoint("CENTER")
	b.name = b:CreateFontString(nil, "OVERLAY")
	b.name:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
	b.name:SetPoint("TOP", b, "BOTTOM", 0, -1)
	b.name:SetWidth(56); b.name:SetWordWrap(false)
	b:Hide()
	icons[i] = b
	return b
end

local function Short(names)
	local s = Ambiguate(names[1], "short")
	if #names > 1 then s = s .. " +" .. (#names - 1) end
	return s
end

local function Show(list, state, found, mine)
	for i, entry in ipairs(list) do
		local b = icons[i] or MakeIcon(i)
		b.tex:SetTexture(ns.JudgeTexture(entry.choice))
		local left = found and found[DEBUFF[entry.choice]]
		if state == "unknown" then
			b.tex:SetDesaturated(false); b:SetAlpha(0.6)
			b.time:SetText("?"); b.name:SetText("|cffbbbbbb" .. Short(entry.names) .. "|r")
		elseif left then
			b.tex:SetDesaturated(false); b:SetAlpha(1)
			b.time:SetText(type(left) == "number" and ("%d"):format(math.ceil(left)) or "")
			b.name:SetText("")
		else
			b.tex:SetDesaturated(true); b:SetAlpha(0.85)
			b.time:SetText("")
			b.name:SetText((entry.choice == mine and "|cffff5555" or "|cffffcc66") .. Short(entry.names) .. "|r")
		end
		b:Show()
	end
	for i = #list + 1, #icons do icons[i]:Hide() end
	frame:SetSize(math.max(#list, 1) * 40 - 8, 32)
	frame:Show()
end

function M:Update()
	if not frame then return end
	local db = ns.db
	if ns.unlocked then
		Show({ { choice = "Wisdom", names = { "You" } }, { choice = "Light", names = { "Someone" } } }, "known",
			{ ["Judgement of Wisdom"] = 7 }, "Light")
		return
	end
	if not db.jaEnabled or not UnitAffectingCombat("player") or not HostileTarget() then frame:Hide() return end
	if not plan or GetTime() - planAt > 5 then plan, planMine = Plan(); planAt = GetTime() end
	local list, mine = plan, planMine
	-- no assignment of your own: still show the raid's Judgements unless the list is only yours
	if db.jaOnlyMine and not mine then frame:Hide() return end
	if #list == 0 then frame:Hide() return end
	local found, hidden, unknown = ReadTarget()
	if unknown then Show(list, "unknown", nil, mine) return end
	-- your own Judgement can be left out of a partly hidden list: trust your last cast for a while
	-- (only when the seal you judged with matches your assignment)
	if mine and hidden and not found[DEBUFF[mine]] and lastCastName == DEBUFF[mine] and GetTime() - lastCast < JUDGEMENT_TIME then
		found[DEBUFF[mine]] = JUDGEMENT_TIME - (GetTime() - lastCast)
	end
	Show(list, "known", found, mine)
	if mine and not found[DEBUFF[mine]] and db.jaSound and GetTime() - lastSound > SOUND_GAP then
		lastSound = GetTime()
		PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
	end
end

function M:Init()
	frame = CreateFrame("Frame", "LightboundJudgeAssignFrame", UIParent)
	frame:SetSize(72, 32)
	frame:SetFrameStrata("MEDIUM")
	frame:Hide()
	ns.MakeMovable(frame, "jaPoint")
	ns.ApplyPoint(frame, "jaPoint")

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterUnitEvent("UNIT_AURA", "target")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ev:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if ns.SpellName(spellID) == "Judgement" then
				lastCast = GetTime()
				-- which Judgement that was: from the seal on you right now (read before the client eats it)
				local seal
				local buffs = ns.ReadPlayerBuffs()
				for bname in pairs(buffs) do if bname:find("^Seal of") then seal = bname end end
				lastCastName = seal and (seal:gsub("^Seal of ", "Judgement of ")) or nil
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			lastCast, lastCastName = 0, nil
		elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_DISABLED" then
			planAt = 0
		end
		M:Update()
	end)
	C_Timer.NewTicker(0.5, function()
		if frame:IsShown() or (UnitAffectingCombat("player") and HostileTarget()) then M:Update() end
	end)
end

-- Options page ----------------------------------------------------------------------
ns.optionPages = ns.optionPages or {}
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Judgements", "Who keeps which Judgement on the boss, shared with the other Lightbound paladins.")
	local W = UI.CONTENT_W
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "jaEnabled", "Track the raid's Judgements on my target",
		"In combat: one icon per assigned Judgement, bright when it's on the target, dim with the paladin's name when it's missing.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "jaSound", "Play a sound when my Judgement is missing", "At most every 10 seconds.")) + 6)
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "jaOnlyMine", "Only show my own Judgement")) + 14)
	p:Add(select(2, UI.Cycle(p, p.y, "My Judgement", ns.JUDGEMENTS,
		function() return ns.GetJudgeAssign(ns.MyName()) end,
		function(v) ns.SetJudgeAssign(ns.MyName(), v) end)) + 2)
	local n = UI.Font(p, 12, UI.C.dim)
	n:SetPoint("TOPLEFT", 0, p.y); n:SetPoint("RIGHT", p, "RIGHT")
	n:SetText("Assign the other paladins in the raid blessings window (/lb raid), Judgement column. Only paladins running Lightbound see these; PallyPower doesn't know about Judgements.")
	p:Add(40)
end

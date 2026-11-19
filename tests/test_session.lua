-- A stand-in WoW client that loads Lightbound's files and replays a session (login, a ride, a
-- fight, a relog) in a few client moods, so errors and stuck states in the Lua paths show up
-- outside the game. Run from the addon folder: lua5.1 tests/test_session.lua
-- What the stub can't do: Forever's own API behaviour (secret values, hidden auras) beyond the
-- "secret" mood below, and anything drawn. In-game testing still comes last.
local ADDON = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
local VERBOSE = os.getenv("VERBOSE")

local function Session(scenario)
	local log, errors = {}, {}
	local function say(...)
		local t = {}
		for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
		log[#log + 1] = table.concat(t, " ")
	end
	local function err(where, e) errors[#errors + 1] = where .. ": " .. tostring(e) end
	local G = setmetatable({ print = function(...) say("[print]", ...) end }, { __index = _G })

	-- World state the scenario drives ----------------------------------------------------
	local now = 1000
	local state = { inCombat = false, mounted = false, dead = false, auras = {}, slots = { [13] = 270225 },
		bags = { [11122] = 1 }, known = {}, secret = false }
	local SPELLS = { [20375] = "Seal of Command", [21084] = "Seal of Righteousness", [20271] = "Judgement",
		[1311703] = "Echo of Command", [1311704] = "Echo of Righteousness" }
	local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

	-- Frames ---------------------------------------------------------------------------------
	local frames, timers = {}, {}
	local Frame = {}
	local function newObj(kind, name, parent)
		local o = { __kind = kind, __name = name, __parent = parent, __shown = true, __scripts = {}, __events = {},
			__value = 0, __level = parent and (parent.__level or 1) + 1 or 1, __attr = {}, __text = "" }
		return setmetatable(o, { __index = function(_, k)
			if Frame[k] then return Frame[k] end
			if type(k) == "string" and k:match("^%u") then return function() end end -- unknown method: no-op
			return nil
		end })
	end
	function Frame:Show() self.__shown = true end
	function Frame:Hide() self.__shown = false end
	function Frame:SetShown(v) self.__shown = v and true or false end
	function Frame:IsShown() return self.__shown end
	function Frame:IsVisible() return self.__shown end
	function Frame:SetScript(k, fn) self.__scripts[k] = fn end
	function Frame:GetScript(k) return self.__scripts[k] end
	function Frame:HasScript() return true end
	function Frame:RegisterEvent(e) self.__events[e] = true end
	function Frame:RegisterUnitEvent(e) self.__events[e] = true end
	function Frame:UnregisterEvent(e) self.__events[e] = nil end
	function Frame:UnregisterAllEvents() self.__events = {} end
	function Frame:IsEventRegistered(e) return self.__events[e] or false end
	function Frame:CreateTexture() return newObj("Texture", nil, self) end
	function Frame:CreateFontString() return newObj("FontString", nil, self) end
	function Frame:CreateMaskTexture() return newObj("Mask", nil, self) end
	function Frame:CreateAnimationGroup() return newObj("AnimGroup", nil, self) end
	function Frame:CreateAnimation() return newObj("Anim", nil, self) end
	function Frame:Play() self.__playing = true end
	function Frame:Stop() self.__playing = false end
	function Frame:Pause() self.__playing = false end
	function Frame:IsPlaying() return self.__playing or false end
	function Frame:GetFrameLevel() return self.__level end
	function Frame:SetFrameLevel(l) self.__level = l end
	function Frame:GetFrameStrata() return "LOW" end
	function Frame:GetParent() return self.__parent end
	function Frame:GetName() return self.__name end
	function Frame:GetScale() return 1 end
	function Frame:GetEffectiveScale() return 1 end
	function Frame:GetRect() return 100, 100, 200, 50 end
	function Frame:GetLeft() return 100 end
	function Frame:GetRight() return 300 end
	function Frame:GetTop() return 150 end
	function Frame:GetBottom() return 100 end
	function Frame:GetWidth() return 200 end
	function Frame:GetHeight() return 50 end
	function Frame:GetSize() return 200, 50 end
	function Frame:GetCenter() return 200, 125 end
	function Frame:SetValue(v) self.__value = v end
	function Frame:GetValue() return self.__value end
	function Frame:SetText(t) self.__text = t end
	function Frame:GetText() return self.__text end
	function Frame:GetStringWidth() return 50 end
	function Frame:GetStatusBarTexture() return newObj("Texture", nil, self) end
	function Frame:SetAttribute(k, v) self.__attr[k] = v end
	function Frame:GetAttribute(k) return self.__attr[k] end
	function Frame:GetNumPoints() return 1 end
	function Frame:GetPoint() return "CENTER", G.UIParent, "CENTER", 0, 0 end
	function Frame:IsMouseEnabled() return false end
	function Frame:GetAlpha() return 1 end
	function Frame:GetFont() return "font", 12, "" end
	function Frame:SetFont() return true end
	function Frame:GetChildren() return nil end
	function Frame:GetRegions() return nil end
	function Frame:AddAuraSlot(_, _, opts)
		-- the game calls initializeFrame once with the AuraButton; here at once
		if opts and opts.initializeFrame then opts.initializeFrame(newObj("AuraButton", nil, self)) end
	end

	function G.CreateFrame(kind, name, parent)
		local f = newObj(kind, name, parent)
		frames[#frames + 1] = f
		if name then G[name] = f end
		return f
	end
	G.UIParent = G.CreateFrame("Frame", "UIParent")
	G.GameTooltip = G.CreateFrame("GameTooltip", "GameTooltip")
	G.RaidWarningFrame = G.CreateFrame("Frame", "RaidWarningFrame")
	G.Minimap = G.CreateFrame("Frame", "Minimap")

	-- API -----------------------------------------------------------------------------------
	function G.GetTime() return now end
	function G.UnitClass() return "Paladin", "PALADIN" end
	function G.UnitName() return "Tester" end
	function G.GetRealmName() return "Realm" end
	function G.GetNormalizedRealmName() return "Realm" end
	function G.UnitGUID() return "Player-1-1" end
	function G.UnitIsDeadOrGhost() return state.dead end
	function G.InCombatLockdown() return state.inCombat end
	function G.UnitAffectingCombat() if state.secret and state.inCombat then return SECRET end return state.inCombat end
	function G.IsMounted() return state.mounted end
	function G.IsInInstance() return false, "none" end
	function G.IsInGroup() return false end
	function G.IsInRaid() return false end
	function G.IsResting() return false end
	function G.GetNumGroupMembers() return 0 end
	function G.GetInventoryItemID(_, slot) return state.slots[slot] end
	function G.CursorHasItem() return false end
	function G.PickupInventoryItem() end
	function G.PutItemInBackpack() end
	function G.PutItemInBag() end
	function G.IsPlayerSpell() return true end
	function G.PlaySound() end
	function G.RaidNotice_AddMessage(_, msg) say("[raidwarning]", msg) end
	function G.RegisterStateDriver() end
	function G.CopyTable(t) local o = {} for k, v in pairs(t) do o[k] = type(v) == "table" and G.CopyTable(v) or v end return o end
	function G.strsplit(d, s) local out = {} for p in (s .. d):gmatch("(.-)" .. d:gsub("%p", "%%%0")) do out[#out + 1] = p end return unpack(out) end
	function G.strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	function G.strlower(s) return s:lower() end
	G.tinsert = table.insert
	function G.wipe(t) for k in pairs(t) do t[k] = nil end return t end
	function G.issecretvalue(v) return v == SECRET end
	function G.canaccessvalue(v) return v ~= SECRET end
	function G.CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	function G.GetCVarBool() return false end
	function G.GetSpellInfo(s) if type(s) == "number" then return SPELLS[s] end return s end
	function G.geterrorhandler() return function(e) err("errorhandler", e) end end
	G.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
	G.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.5, b = 0 } }
	G.Enum = { StatusBarInterpolation = { Immediate = 1 } }
	G.SlashCmdList = {}
	G.NUM_BAG_SLOTS = 4
	G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
	G.LOCALIZED_CLASS_NAMES_MALE = {}
	G.C_AddOns = { IsAddOnLoaded = function() return true end, LoadAddOn = function() return true end,
		DisableAddOn = function() end, GetAddOnEnableState = function() return 2 end }
	G.C_Timer = {
		After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end,
		NewTicker = function(d, fn)
			local t = { at = now + d, fn = fn, every = d }
			t.Cancel = function() t.dead = true end
			timers[#timers + 1] = t
			return t
		end,
	}
	G.C_Spell = {
		GetSpellInfo = function(s)
			local n = type(s) == "number" and SPELLS[s] or s
			if state.known[n] == false then return nil end
			return { name = n, spellID = 1 }
		end,
		GetSpellName = function(id) return SPELLS[id] or ("Spell" .. tostring(id)) end,
		GetSpellTexture = function() return 135924 end,
		GetSpellCooldown = function() return { startTime = 0, duration = 0 } end,
	}
	G.C_Item = {
		GetItemCount = function(id) return state.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item" .. id end,
		EquipItemByName = function(item, slot)
			local old = state.slots[slot]
			if (state.bags[item] or 0) <= 0 then say("[equip] not in bags:", item) return end
			state.bags[item] = state.bags[item] - 1
			state.slots[slot] = item
			if old then state.bags[old] = (state.bags[old] or 0) + 1 end
			say("[equip]", item, "into slot", slot, "old", old)
			state.pending = { "PLAYER_EQUIPMENT_CHANGED", slot }
		end,
	}
	G.C_Container = { GetContainerNumFreeSlots = function() return 5, 0 end, ContainerIDToInventoryID = function(b) return 19 + b end }
	local function Secret() if state.secret and state.inCombat then error("aura data is secret in combat") end end
	G.C_UnitAuras = {
		GetAuraDataByIndex = function(_, i) Secret() return state.auras[i] end,
		GetPlayerAuraBySpellID = function(id) Secret() for _, a in ipairs(state.auras) do if a.spellId == id then return a end end return nil end,
	}

	-- Driving ----------------------------------------------------------------------------------
	local function Fire(event, ...)
		for _, f in ipairs(frames) do
			if f.__events[event] and f.__scripts.OnEvent then
				local ok, e = pcall(f.__scripts.OnEvent, f, event, ...)
				if not ok then err(event .. " handler", e) end
			end
		end
		if state.pending then local p = state.pending state.pending = nil Fire(unpack(p)) end
	end
	local function Advance(seconds, step)
		step = step or 0.5
		local target = now + seconds
		while now < target - 1e-9 do
			now = math.min(target, now + step)
			for _, t in ipairs(timers) do
				if not t.dead and t.at <= now then
					local ok, e = pcall(t.fn)
					if not ok then err("timer", e) end
					if t.every then t.at = t.at + t.every else t.dead = true end
				end
			end
			for _, f in ipairs(frames) do
				if f.__shown and f.__scripts.OnUpdate then
					local ok, e = pcall(f.__scripts.OnUpdate, f, step)
					if not ok then err("OnUpdate " .. tostring(f.__name), e) end
				end
			end
		end
	end
	local function Aura(name, id, left, n)
		return { name = name, spellId = id, icon = 1, duration = left or 1800, expirationTime = now + (left or 1800), sourceUnit = "player", applications = n or 1 }
	end
	local function With(base, ...) local l = G.CopyTable(base) for i = 1, select("#", ...) do l[#l + 1] = select(i, ...) end return l end
	local function SetAuras(list) state.auras = list Fire("UNIT_AURA", "player") end
	local function Shown(name) local f = G[name] return f and f.__shown or false end

	-- Load the addon --------------------------------------------------------------------------
	local ns = {}
	for _, file in ipairs({ "Core.lua", "Skin.lua", "SealTimer.lua", "TwistLogic.lua", "Twist.lua", "WellRested.lua", "Carrot.lua" }) do
		local chunk, e = loadfile(ADDON .. "/" .. file)
		if not chunk then error(e) end
		setfenv(chunk, G)
		local ok, e2 = pcall(chunk, "Lightbound", ns)
		if not ok then err("load " .. file, e2) end
	end

	-- The session ----------------------------------------------------------------------------
	G.LightboundDB = { skin = "lightbound", wellRestedKeep = true, wellFedKeep = true, carrotSwap = true, carrotSlot = "Top", twist = true }
	if scenario == "off" then G.LightboundDB.wellRested = false; G.LightboundDB.wellFed = false end
	if scenario == "notalent" then state.known["Unsealed Wrath"] = false end -- the talent can't be looked up by name
	if scenario == "secret" then state.secret = true end -- Forever: aura API throws and combat state is secret in combat
	local base = {}
	if scenario == "buffed" then base = { Aura("Well-Rested", 429959, 7200), Aura("Well Fed", 433, 1800) } end
	local result = {}

	Fire("ADDON_LOADED", "Lightbound")
	Fire("PLAYER_LOGIN")
	state.auras = base
	Fire("PLAYER_ENTERING_WORLD", true, false)
	Advance(7)
	result.cards = Shown("LightboundWellRestedFrame") and Shown("LightboundWellFedFrame")

	-- a ride
	state.mounted = true
	Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	SetAuras(With(base, Aura("Swift Horse", 23229)))
	Advance(1)
	result.carrotOn = state.slots[13] == 11122
	state.mounted = false
	Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	SetAuras(With(base))
	Advance(1)
	result.carrotOff = state.slots[13] == 270225

	-- the first fight after login, with Seal of Command
	local seal = Aura("Seal of Command", 20375, 30)
	SetAuras(With(base, seal))
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 20375)
	Advance(0.5)
	state.inCombat = true
	Fire("PLAYER_REGEN_DISABLED")
	Advance(0.5)
	result.twistFirstFight = Shown("LightboundTwistFrame")
	result.sealBar = Shown("LightboundSealFrame")
	for _ = 1, 3 do Fire("PLAYER_SWING", 3.3, 0); Fire("UNIT_AURA", "player"); Advance(3.3) end
	state.inCombat = false
	Fire("PLAYER_REGEN_ENABLED")
	SetAuras(With(base, seal, Aura("Echo of Command", 1311703, 15, 3))) -- the stored copies, readable again
	Advance(2)
	result.twistHiddenAfter = not Shown("LightboundTwistFrame")

	-- a relog: the client forgets what the addon learned, LightboundDB stays. The talent events
	-- fire while talents load in too, before the lookup can work.
	state.auras = base
	Fire("PLAYER_ENTERING_WORLD", true, false)
	Fire("PLAYER_TALENT_UPDATE")
	Fire("TRAIT_CONFIG_UPDATED")
	Advance(7)
	SetAuras(With(base, seal))
	state.inCombat = true
	Fire("PLAYER_REGEN_DISABLED")
	Advance(0.5)
	result.twistAfterRelog = Shown("LightboundTwistFrame")
	state.inCombat = false
	Fire("PLAYER_REGEN_ENABLED")
	Advance(1)

	-- a respec that drops the talent: the lookup now says no
	state.known["Unsealed Wrath"] = false
	Fire("PLAYER_TALENT_UPDATE")
	state.inCombat = true
	Fire("PLAYER_REGEN_DISABLED")
	Advance(0.5)
	result.twistAfterRespec = Shown("LightboundTwistFrame")
	state.inCombat = false
	Fire("PLAYER_REGEN_ENABLED")
	Advance(1)

	-- and back to the Retribution loadout: the talent is there again
	if scenario ~= "notalent" then state.known["Unsealed Wrath"] = nil end
	Fire("TRAIT_CONFIG_UPDATED")
	SetAuras(With(base, seal))
	state.inCombat = true
	Fire("PLAYER_REGEN_DISABLED")
	Advance(0.5)
	result.twistBackToRet = Shown("LightboundTwistFrame")
	state.inCombat = false
	Fire("PLAYER_REGEN_ENABLED")
	Advance(1)

	-- a second ride
	state.mounted = true
	Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	Advance(1)
	result.carrotAgain = state.slots[13] == 11122

	return result, errors, log
end

local failed = 0
local function Expect(scenario, result, key, want)
	if result[key] ~= want then
		failed = failed + 1
		io.write(("FAIL %-9s %s = %s, wanted %s\n"):format(scenario, key, tostring(result[key]), tostring(want)))
	end
end

for _, scenario in ipairs({ "missing", "off", "buffed", "notalent", "secret" }) do
	local result, errors, log = Session(scenario)
	if VERBOSE then for _, l in ipairs(log) do io.write(scenario, ": ", l, "\n") end end
	for _, e in ipairs(errors) do failed = failed + 1 io.write("FAIL ", scenario, " error: ", e, "\n") end
	Expect(scenario, result, "cards", scenario == "missing" or scenario == "notalent" or scenario == "secret")
	Expect(scenario, result, "carrotOn", true)
	Expect(scenario, result, "carrotOff", true)
	Expect(scenario, result, "carrotAgain", true)
	Expect(scenario, result, "sealBar", true)
	Expect(scenario, result, "twistFirstFight", scenario ~= "notalent") -- the one fight that can't know yet
	Expect(scenario, result, "twistHiddenAfter", true)
	Expect(scenario, result, "twistAfterRelog", true) -- remembered per character
	-- after a respec the bar goes; when the lookup never worked the memory stays (can't tell a respec from login)
	Expect(scenario, result, "twistAfterRespec", scenario == "notalent")
	Expect(scenario, result, "twistBackToRet", true) -- the loadout with the talent again
end

if failed > 0 then io.write(failed, " check(s) failed\n") os.exit(1) end
print("test_session: 5 sessions OK")

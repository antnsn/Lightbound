-- Group blessing and aura assignments, shared with other paladins.
-- Speaks PallyPower's addon-message format (prefix PLPWR), so paladins who still run PallyPower
-- see you, can assign you, and get your assignments. Numbers follow PallyPower on Forever:
--   blessings 1 Wisdom, 2 Might, 3 Kings, 4 Salvation, 5 Light, 6 Sanctuary
--   classes   1 Warrior, 2 Rogue, 3 Priest, 4 Druid, 5 Paladin, 6 Hunter, 7 Mage, 8 Warlock, 9 Shaman
--   auras     1 Devotion, 2 Retribution, 3 Concentration, 4 Shadow, 5 Frost, 6 Fire, 7 Sanctity
-- While PallyPower itself is loaded, Lightbound only reads PallyPower's tables and sends nothing,
-- so you never show up twice. Remove PallyPower and Lightbound takes over.
local _, ns = ...

local PREFIX = "PLPWR"
local LB_PREFIX = "LBND" -- Lightbound-only data (judgements, tanks, extra cooldowns); PallyPower never sees it
local isSecret = ns.IsSecret -- see Core.lua
local NUM_CLASSES, NUM_AURAS = 9, 7
ns.PP_SPELL = { "Wisdom", "Might", "Kings", "Salvation", "Light", "Sanctuary" }
ns.PP_SPELL_ID = { Wisdom = 1, Might = 2, Kings = 3, Salvation = 4, Light = 5, Sanctuary = 6 }
ns.PP_CLASS = { WARRIOR = 1, ROGUE = 2, PRIEST = 3, DRUID = 4, PALADIN = 5, HUNTER = 6, MAGE = 7, WARLOCK = 8, SHAMAN = 9 }
ns.PP_CLASS_NAME = { "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN" }
ns.PP_AURA = { "Devotion", "Retribution", "Concentration", "Shadow Resistance", "Frost Resistance", "Fire Resistance", "Sanctity" }

local M = {}
ns.modules[#ns.modules + 1] = M

ns.pallys = {}        -- name -> { bless = {[i]=true}, auras = {[i]=true}, symbols, freeassign, seen } (this session)
local passive = false -- PallyPower is loaded: read its tables, send nothing

local function Me() return (GetUnitName and GetUnitName("player", true)) or UnitName("player") end
ns.MyName = Me

-- PallyPower drops the realm for same-realm names and keys you by your full name.
local function Normalize(name)
	if not name then return nil end
	if name == UnitName("player") then return Me() end
	local base, realm = strsplit("-", name)
	if realm and realm ~= (GetNormalizedRealmName and GetNormalizedRealmName()) then return name end
	return base
end
local function Wire(name) return (name:gsub(" ", "_")) end
local function Unwire(name) return (name:gsub("_", " ")) end

-- Assignment tables ---------------------------------------------------------------
local function Tables()
	if passive then
		_G.PallyPower_Assignments = _G.PallyPower_Assignments or {}
		_G.PallyPower_NormalAssignments = _G.PallyPower_NormalAssignments or {}
		_G.PallyPower_AuraAssignments = _G.PallyPower_AuraAssignments or {}
		return _G.PallyPower_Assignments, _G.PallyPower_NormalAssignments, _G.PallyPower_AuraAssignments
	end
	local db = ns.db
	db.assign = db.assign or {}
	db.normalAssign = db.normalAssign or {}
	db.auraAssign = db.auraAssign or {}
	return db.assign, db.normalAssign, db.auraAssign
end

-- Blessing number for paladin `name` on class number `cid` (0 = none)
function ns.GetAssign(name, cid)
	local a = Tables()
	local t = a[name]
	return type(t) == "table" and tonumber(t[cid]) or 0
end

-- Per-player override: blessing number for paladin `name` on `target` of class `cid`, or nil
function ns.GetNormalAssign(name, cid, target)
	local _, n = Tables()
	local t = n[name] and n[name][cid]
	return type(t) == "table" and tonumber(t[target]) or nil
end

function ns.GetAuraAssign(name)
	local _, _, au = Tables()
	return tonumber(au[name]) or 0
end

function ns.HasAssignments(name)
	local a = Tables()
	local t = a[name or Me()]
	if type(t) ~= "table" then return false end
	for i = 1, NUM_CLASSES do if (tonumber(t[i]) or 0) > 0 then return true end end
	return false
end

function ns.GroupPassive() return passive end

-- What you can cast -----------------------------------------------------------------
local function Known(spell)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spell) end
		return GetSpellInfo(spell)
	end)
	return ok and info ~= nil
end

local function Rank(spell)
	local ok, sub = pcall(function()
		if C_Spell and C_Spell.GetSpellSubtext then return C_Spell.GetSpellSubtext(spell) end
		return GetSpellSubtext and GetSpellSubtext(spell)
	end)
	local n = ok and type(sub) == "string" and tonumber(sub:match("(%d+)"))
	return math.min(n or 1, 15)
end

-- Talent points in Improved Blessing of Wisdom (1) and Might (2), as PallyPower sends them
local TALENTS = { [1] = "Improved Blessing of Wisdom", [2] = "Improved Blessing of Might" }
local function Talents()
	local out = {}
	pcall(function()
		local tabs = GetNumTalentTabs and GetNumTalentTabs() or 0
		for tab = 1, tabs do
			for i = 1, (GetNumTalents(tab) or 0) do
				local name, _, _, _, rank = GetTalentInfo(tab, i)
				for idx, tname in pairs(TALENTS) do
					if name == tname then out[idx] = tonumber(rank) or 0 end
				end
			end
		end
	end)
	return out
end

-- Lay on Hands (1) and Divine Intervention (2): known, and when it's ready again
local CD_SPELLS = { { 10310, 2800, 633 }, { 19752 } }
ns.CD_SPELLS = CD_SPELLS
local function Cooldowns(old)
	local out = {}
	for i, ids in ipairs(CD_SPELLS) do
		for _, id in ipairs(ids) do
			if IsPlayerSpell and IsPlayerSpell(id) then
				local readyAt, dur = 0, 0
				local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
				local start = ok and type(cd) == "table" and cd.startTime
				local d = ok and type(cd) == "table" and cd.duration
				if start == nil or isSecret(start) or isSecret(d) then
					-- hidden in combat: keep what we knew
					readyAt = old and old[i] and old[i].readyAt or 0
					dur = old and old[i] and old[i].dur or 0
				elseif d and d > 1.5 then
					readyAt, dur = start + d, d
				end
				out[i] = { known = true, readyAt = readyAt, dur = dur }
				break
			end
		end
	end
	return out
end

local function ScanSelf()
	local old = ns.pallys[Me()]
	local me = { bless = {}, auras = {}, ranks = {}, talents = Talents(), auraRanks = {}, lightbound = true }
	me.cd = Cooldowns(old and old.cd)
	for i, key in ipairs(ns.PP_SPELL) do
		local spell = "Blessing of " .. key
		if Known(spell) then me.bless[i] = true; me.ranks[i] = Rank(spell) end
	end
	for i, key in ipairs(ns.PP_AURA) do
		local spell = key .. " Aura"
		if Known(spell) then me.auras[i] = true; me.auraRanks[i] = Rank(spell) end
	end
	me.symbols = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(21177)) or (GetItemCount and GetItemCount(21177)) or 0
	me.freeassign = ns.db.freeAssign and true or false
	me.seen = GetTime()
	ns.pallys[Me()] = me
	return me
end

-- Who may change whose assignments ----------------------------------------------------
local function UnitFor(name)
	if name == Me() then return "player" end
	local n = GetNumGroupMembers()
	for i = 1, n do
		local u = IsInRaid() and ("raid" .. i) or ("party" .. i)
		if UnitExists(u) and Normalize(GetUnitName(u, true)) == name then return u end
	end
	return nil
end
ns.UnitForName = UnitFor

local function IsLeader(name)
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then return false end
	local u = UnitFor(name)
	return u and (UnitIsGroupLeader(u) or UnitIsGroupAssistant(u)) or false
end
ns.IsGroupLeader = IsLeader

function ns.CanControl(name)
	if name == Me() then return true end
	if IsLeader(Me()) then return true end
	local p = ns.pallys[name]
	return p and p.freeassign or false
end

-- Sending ---------------------------------------------------------------------------
local queue, sending = {}, false
local function Channel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	return "PARTY"
end

local function Flush()
	local item = table.remove(queue, 1)
	if not item then sending = false return end
	if IsInGroup() then
		pcall(C_ChatInfo.SendAddonMessage, item.prefix or PREFIX, item.msg, item.target and "WHISPER" or Channel(), item.target)
	end
	C_Timer.After(0.15, Flush)
end

local function Send(msg, target)
	if passive or not IsInGroup() then return end
	for _, q in ipairs(queue) do if q.msg == msg and q.target == target then return end end
	queue[#queue + 1] = { msg = msg, target = target }
	if not sending then sending = true; C_Timer.After(0, Flush) end
end

-- Lightbound-only sync (prefix LBND). Message is "TAG rest"; handlers are keyed by TAG.
-- Other modules: ns.OnLB("TAG", function(sender, rest) ... end) and ns.SendLB("TAG rest"[, target]).
-- Nothing is sent while PallyPower is loaded (passive), same as the PLPWR traffic.
local lbHandlers = {}
function ns.OnLB(tag, handler) lbHandlers[tag] = handler end
function ns.SendLB(msg, target)
	if passive or not IsInGroup() then return end
	for _, q in ipairs(queue) do if q.prefix == LB_PREFIX and q.msg == msg and q.target == target then return end end
	queue[#queue + 1] = { prefix = LB_PREFIX, msg = msg, target = target }
	if not sending then sending = true; C_Timer.After(0, Flush) end
end
local function ParseLB(sender, msg)
	local tag, rest = msg:match("^(%u+)%s*(.*)$")
	local h = tag and lbHandlers[tag]
	if h then h(sender, rest or "") end
end
-- Modules that have Lightbound-only state to share register here; called when a peer asks for a full sync.
ns.lbSyncers = {}
function ns.OnLBSync(fn) ns.lbSyncers[#ns.lbSyncers + 1] = fn end

local function SendSelf(target)
	if passive or not IsInGroup() then return end
	local me, name = ScanSelf(), Me()
	if IsLeader(name) then Send("PPLEADER " .. name) end
	if target and IsLeader(target) then target = nil end
	-- blessing ranks: two characters per blessing (rank, talent), "nn" when not known.
	-- Like PallyPower on Forever, Salvation is not listed.
	local s = ""
	for i = 1, 6 do
		if me.bless[i] and i ~= 4 then
			s = s .. ("%x%x"):format(me.ranks[i], math.min(me.talents[i] or 0, 9))
		else
			s = s .. "nn"
		end
	end
	s = s .. "@"
	for cid = 1, NUM_CLASSES do
		local v = ns.GetAssign(name, cid)
		s = s .. (v > 0 and tostring(v) or "n")
	end
	Send("SELF " .. s, target)
	local a = ""
	for i = 1, NUM_AURAS do
		if me.auras[i] then a = a .. ("%x%x"):format(me.auraRanks[i], 0) else a = a .. "nn" end
	end
	Send("ASELF " .. a .. "@" .. ns.GetAuraAssign(name), target)
	local list = {}
	local _, normal = Tables()
	for cid, targets in pairs(normal[name] or {}) do
		for tname, idx in pairs(targets) do
			list[#list + 1] = ("%s %s %s %s"):format(Wire(name), cid, Wire(tname), idx)
		end
	end
	for i = 1, #list, 5 do
		Send("NASSIGN " .. table.concat(list, "@", i, math.min(i + 4, #list)), target)
	end
	local cds = ""
	for i = 1, 2 do
		local c = me.cd[i]
		if c and c.known then
			cds = cds .. (":%d:%d"):format(c.dur or 0, math.max((c.readyAt or 0) - GetTime(), 0))
		else
			cds = cds .. ":n:n"
		end
	end
	Send("FREEASSIGN " .. (me.freeassign and "YES" or "NO") .. " | SYMCOUNT " .. me.symbols .. " | COOLDOWNS" .. cds, target)
end
ns.SendSelf = SendSelf

function ns.RequestSync()
	if passive then return end
	SendSelf()
	for _, fn in ipairs(ns.lbSyncers) do fn() end
	Send("REQ")
end

-- Changing assignments (sends them to the group) --------------------------------------
local function Changed()
	if ns.RaidWindowRefresh then ns.RaidWindowRefresh() end
	ns.Refresh()
end

function ns.SetAssign(name, cid, idx)
	local a = Tables()
	a[name] = a[name] or {}
	for i = 1, NUM_CLASSES do a[name][i] = a[name][i] or 0 end
	a[name][cid] = idx
	Send(("ASSIGN %s %d %d"):format(name, cid, idx))
	Changed()
end

function ns.SetAllAssign(name, list) -- list[cid] = idx
	local a = Tables()
	a[name] = {}
	local s = ""
	for cid = 1, NUM_CLASSES do
		a[name][cid] = list[cid] or 0
		s = s .. (a[name][cid] > 0 and tostring(a[name][cid]) or "n")
	end
	Send(("PASSIGN %s@%s"):format(name, s))
	Changed()
end

-- Per-player blessing: paladin `name` gives `target` (class number cid) blessing idx; 0 = use the class blessing
function ns.SetNormalAssign(name, cid, target, idx)
	local _, n = Tables()
	n[name] = n[name] or {}
	n[name][cid] = n[name][cid] or {}
	n[name][cid][target] = (idx and idx > 0) and idx or nil
	Send(("NASSIGN %s %d %s %d"):format(Wire(name), cid, Wire(target), idx or 0))
	Changed()
end

-- All per-player blessings of paladin `name` on class cid: { [target] = idx }
function ns.GetNormalAssigns(name, cid)
	local _, n = Tables()
	return (n[name] and n[name][cid]) or {}
end

function ns.SetAuraAssign(name, idx)
	local _, _, au = Tables()
	au[name] = idx
	Send(("AASSIGN %s %d"):format(name, idx))
	Changed()
end

function ns.ClearAssignments()
	local a, n, au = Tables()
	local me = Me()
	if IsLeader(me) then
		for name in pairs(a) do a[name] = nil end
		for name in pairs(n) do n[name] = nil end
		for name in pairs(au) do au[name] = 0 end
		Send("CLEAR")
	else
		-- only your own row, sent as explicit "nothing" so every addon understands it
		for cid, targets in pairs(n[me] or {}) do
			for tname in pairs(targets) do
				Send(("NASSIGN %s %d %s 0"):format(Wire(me), cid, Wire(tname)))
			end
		end
		a[me] = nil; n[me] = nil; au[me] = 0
		Send(("PASSIGN %s@%s"):format(me, ("n"):rep(NUM_CLASSES)))
		Send(("AASSIGN %s 0"):format(me))
	end
	Changed()
end

-- Paladins in the group, you first, then by name
function ns.GroupPaladins()
	local list, seen = { Me() }, { [Me()] = true }
	ScanSelf()
	local n = GetNumGroupMembers()
	for i = 1, n do
		local u = IsInRaid() and ("raid" .. i) or ("party" .. i)
		if UnitExists(u) then
			local _, class = UnitClass(u)
			local name = Normalize(GetUnitName(u, true))
			if class == "PALADIN" and name and not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
	end
	table.sort(list, function(x, y)
		if x == Me() then return true elseif y == Me() then return false end
		return x < y
	end)
	return list
end

-- Receiving -----------------------------------------------------------------------
local function Digits(s, n)
	local t = {}
	for i = 1, n do
		local c = s and s:sub(i, i) or ""
		local v = tonumber(c) or 0
		t[i] = ns.PP_SPELL[v] and v or 0
	end
	return t
end

local function Ranks(s, n)
	local known, ranks, talents = {}, {}, {}
	for i = 1, n do
		local r = s and s:sub(i * 2 - 1, i * 2 - 1) or "n"
		local t = s and s:sub(i * 2, i * 2) or "n"
		if r ~= "n" and r ~= "" then
			known[i] = true
			ranks[i] = tonumber(r, 16) or 1
			talents[i] = tonumber(t) or 0
		end
	end
	return known, ranks, talents
end

local function NotifyMine(sender, text)
	if sender ~= Me() then ns.Print(sender .. " " .. text) end
end

local function Parse(sender, msg)
	if msg:find("^PPLEADER") then return end
	if sender == Me() then return end
	if not UnitFor(sender) then return end -- only people in your group
	local a, normal, au = Tables()
	local leader = IsLeader(sender)
	-- a paladin may change their own row; the leader/assists anyone's; others only
	-- paladins who allow it (you: your own setting, others: what they sent)
	local function allowed(name)
		if name == sender or leader then return true end
		if name == Me() then return ns.db.freeAssign and true or false end
		local tp = ns.pallys[name]
		return tp and tp.freeassign or false
	end
	local function validClass(c) return c and c >= 1 and c <= NUM_CLASSES end
	local function validBless(i) return i and (i == 0 or ns.PP_SPELL[i] ~= nil) end
	local function validAura(i) return i and (i == 0 or ns.PP_AURA[i] ~= nil) end
	local p = ns.pallys[sender]

	if msg == "REQ" then
		local target = sender
		if IsInRaid() and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then target = nil end -- instance chat: broadcast
		SendSelf(target)
		for _, fn in ipairs(ns.lbSyncers) do fn(target) end
		return
	end
	local numbers, assign = msg:match("^SELF ([0-9a-fn]*)@([0-9n]*)")
	if numbers then
		local known, ranks, talents = Ranks(numbers, 6)
		p = { bless = known, ranks = ranks, talents = talents, auras = p and p.auras or {},
			symbols = p and p.symbols or 0, freeassign = p and p.freeassign, cd = p and p.cd, seen = GetTime() }
		ns.pallys[sender] = p
		a[sender] = Digits(assign, NUM_CLASSES)
		Changed()
		return
	end
	local aNumbers, aAssign = msg:match("^ASELF ([0-9a-fn]*)@([0-9n]*)")
	if aNumbers then
		p = p or { bless = {}, symbols = 0, seen = GetTime() }
		ns.pallys[sender] = p
		p.auras = (Ranks(aNumbers, NUM_AURAS))
		local av = tonumber(aAssign) or 0
		au[sender] = validAura(av) and av or 0
		Changed()
		return
	end
	local name, cid, idx = msg:match("^ASSIGN (.+) (%d+) (%d+)$")
	if name then
		name = Normalize(name)
		if not allowed(name) then return end
		cid, idx = tonumber(cid), tonumber(idx)
		if not validClass(cid) or not validBless(idx) then return end
		a[name] = a[name] or {}
		a[name][cid] = idx
		if name == Me() then
			NotifyMine(sender, "assigned you " .. (ns.PP_SPELL[idx] or "nothing") .. " on " .. ns.PP_CLASS_NAME[cid]:lower() .. "s.")
		end
		Changed()
		return
	end
	local pname, passign = msg:match("^PASSIGN (.+)@([0-9n]*)$")
	if pname then
		pname = Normalize(pname)
		if not allowed(pname) then return end
		a[pname] = Digits(passign, NUM_CLASSES)
		if pname == Me() then NotifyMine(sender, "changed your blessing assignments.") end
		Changed()
		return
	end
	local mname, midx = msg:match("^MASSIGN (.+) (%d+)$")
	if mname then
		mname = Normalize(mname)
		if not allowed(mname) then return end
		midx = tonumber(midx)
		if not validBless(midx) then return end
		a[mname] = {}
		for i = 1, NUM_CLASSES do a[mname][i] = midx end
		if mname == Me() then NotifyMine(sender, "assigned you " .. (ns.PP_SPELL[tonumber(midx)] or "nothing") .. " on everyone.") end
		Changed()
		return
	end
	if msg:find("^NASSIGN ") then
		for pn, c, tn, sk in msg:sub(9):gmatch("([^@]*) ([^@]*) ([^@]*) ([^@]*)") do
			pn = Normalize(Unwire(pn))
			if not allowed(pn) then return end
			c, sk = tonumber(c), tonumber(sk)
			if validClass(c) and validBless(sk) then
				normal[pn] = normal[pn] or {}
				normal[pn][c] = normal[pn][c] or {}
				normal[pn][c][Unwire(tn)] = (sk and sk > 0) and sk or nil
			end
		end
		Changed()
		return
	end
	local aname, aidx = msg:match("^AASSIGN (.+) (%d+)$")
	if aname then
		aname = Normalize(aname)
		if not allowed(aname) then return end
		aidx = tonumber(aidx)
		if not validAura(aidx) then return end
		au[aname] = aidx
		if aname == Me() then NotifyMine(sender, "assigned you " .. (ns.PP_AURA[tonumber(aidx)] or "no") .. " aura.") end
		Changed()
		return
	end
	if msg:find("^CLEAR") then
		local skipAuras = msg:find("SKIP")
		if leader then
			for k in pairs(a) do a[k] = nil end
			for k in pairs(normal) do normal[k] = nil end
			if not skipAuras then for k in pairs(au) do au[k] = 0 end end
			NotifyMine(sender, "cleared all blessing assignments.")
		else
			a[sender] = nil; normal[sender] = nil
			if not skipAuras then au[sender] = 0 end
		end
		Changed()
		return
	end
	if p then
		if msg:find("FREEASSIGN YES") then p.freeassign = true elseif msg:find("FREEASSIGN NO") then p.freeassign = false end
		local sym = msg:match("SYMCOUNT (%d+)")
		if sym then p.symbols = tonumber(sym) end
		local cdPart = msg:match("COOLDOWNS(:.*)$")
		if cdPart then
			local _, d1, r1, d2, r2 = strsplit(":", cdPart)
			p.cd = {}
			for i, pair in ipairs({ { d1, r1 }, { d2, r2 } }) do
				local d, r = tonumber(pair[1]), tonumber(pair[2])
				if d and r then p.cd[i] = { known = true, dur = d, readyAt = GetTime() + r } end
			end
		end
		Changed()
	end
end

-- Setup ---------------------------------------------------------------------------
local function Migrate()
	-- one-time copy of your own PallyPower assignments, so removing PallyPower keeps them
	if ns.db.ppMigrated then return end
	local pa, pau = _G.PallyPower_Assignments, _G.PallyPower_AuraAssignments
	if type(pa) ~= "table" then return end
	local me = Me()
	ns.db.assign = ns.db.assign or {}
	ns.db.auraAssign = ns.db.auraAssign or {}
	if type(pa[me]) == "table" then
		ns.db.assign[me] = {}
		for i = 1, NUM_CLASSES do ns.db.assign[me][i] = tonumber(pa[me][i]) or 0 end
	end
	if type(pau) == "table" and tonumber(pau[me]) then ns.db.auraAssign[me] = tonumber(pau[me]) end
	ns.db.ppMigrated = true
end

function M:Update() end

function M:Init()
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	C_ChatInfo.RegisterAddonMessagePrefix(LB_PREFIX)
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_LOGIN")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("GROUP_JOINED")
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterEvent("SPELLS_CHANGED")
	ev:RegisterEvent("CHAT_MSG_ADDON")
	ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	local pendingSelf
	local function SoonSelf(delay)
		if pendingSelf then return end
		pendingSelf = true
		C_Timer.After(delay or 2, function() pendingSelf = false; SendSelf() end)
	end
	ev:SetScript("OnEvent", function(_, event, prefix, message, _, source)
		if event == "PLAYER_LOGIN" then
			local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
			passive = loaded and loaded("PallyPower") and true or false
			Migrate()
			ScanSelf()
		elseif event == "CHAT_MSG_ADDON" then
			if passive or (prefix ~= PREFIX and prefix ~= LB_PREFIX) then return end
			local sender = Normalize(Ambiguate(source or "", "none"))
			if not sender then return end
			if prefix == LB_PREFIX then ParseLB(sender, message) else Parse(sender, message) end
		elseif event == "GROUP_JOINED" or event == "PLAYER_ENTERING_WORLD" then
			if IsInGroup() and not passive then
				C_Timer.After(2, function() ns.RequestSync() end)
			end
		elseif event == "GROUP_ROSTER_UPDATE" then
			if not IsInGroup() then
				for k in pairs(ns.pallys) do if k ~= Me() then ns.pallys[k] = nil end end
			end
			if ns.RaidWindowRefresh then ns.RaidWindowRefresh() end
		elseif event == "SPELLS_CHANGED" then
			SoonSelf(3)
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local spellID = select(3, prefix, message, _, source) -- (unit, castGUID, spellID)
			if spellID == nil or isSecret(spellID) then return end
			for _, ids in ipairs(CD_SPELLS) do
				for _, id in ipairs(ids) do if spellID == id then SoonSelf(1.5) end end
			end
		end
	end)
end

-- Row of icons for the blessings the player wants on themself (chosen in /lb).
-- Each icon shows the time left; a missing blessing is greyed out with a red border.
local _, ns = ...

ns.BLESSINGS = {
	{ key = "Might", spell = 19740 },
	{ key = "Wisdom", spell = 19742 },
	{ key = "Kings", spell = 20217 },
	{ key = "Salvation", spell = 1038 },
	{ key = "Light", spell = 19977 },
	{ key = "Sanctuary", spell = 20911 },
}
local SIZE, GAP = 36, 6

local M = {}
ns.modules[#ns.modules + 1] = M

local f, icons = nil, {}
local known = {} -- key -> { expires, icon } from the last time auras were readable

local function SpellTexture(id)
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
		return GetSpellTexture(id)
	end)
	return ok and tex or 135906
end

local function FormatTime(s)
	if s >= 60 then return ("%dm"):format(math.ceil(s / 60)) end
	return ("%ds"):format(math.max(0, math.floor(s)))
end

local function Read()
	local buffs, hidden = ns.ReadPlayerBuffs()
	for _, b in ipairs(ns.BLESSINGS) do
		local a = buffs["Greater Blessing of " .. b.key] or buffs["Blessing of " .. b.key]
		if a then
			known[b.key] = { expires = (a.expires and a.expires > 0) and a.expires or nil, icon = a.icon }
		elseif not hidden then
			known[b.key] = nil
		end -- auras hidden in combat: keep the last known state
		local k = known[b.key]
		if k and k.expires and k.expires <= GetTime() then known[b.key] = nil end
	end
end

local function Icon(i)
	local b = icons[i]
	if b then return b end
	b = CreateFrame("Frame", nil, f)
	b:SetSize(SIZE, SIZE)
	b.border = b:CreateTexture(nil, "BACKGROUND")
	b.border:SetPoint("TOPLEFT", -2, 2); b.border:SetPoint("BOTTOMRIGHT", 2, -2)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.time:SetPoint("TOP", b, "BOTTOM", 0, -3)
	icons[i] = b
	return b
end

local function Draw()
	local db = ns.db
	local list = {}
	local now = GetTime()
	local limit = db.blessWarnMinutes * 60
	for _, b in ipairs(ns.BLESSINGS) do
		if db.blessTrack[b.key] then
			local k = known[b.key]
			local left = k and k.expires and (k.expires - now)
			local missing = not k
			local low = left and left <= limit
			if ns.unlocked or not db.blessOnlyProblems or missing or low then
				list[#list + 1] = { b = b, k = k, left = left, missing = missing, low = low }
			end
		end
	end
	for i = 1, #icons do icons[i]:Hide() end
	if #list == 0 then f:Hide() return end
	f:SetSize(#list * SIZE + (#list - 1) * GAP, SIZE)
	for i, e in ipairs(list) do
		local ic = Icon(i)
		ic:ClearAllPoints()
		ic:SetPoint("LEFT", f, "LEFT", (i - 1) * (SIZE + GAP), 0)
		ic.tex:SetTexture((e.k and e.k.icon) or SpellTexture(e.b.spell))
		ic.tex:SetDesaturated(e.missing)
		if e.missing then
			ic.border:SetColorTexture(1, 0.1, 0.1, 0.9)
			ic.time:SetText("|cffff3333" .. e.b.key .. "|r")
		elseif e.low then
			ic.border:SetColorTexture(1, 0.75, 0.1, 0.9)
			ic.time:SetText("|cffffd100" .. FormatTime(e.left) .. "|r")
		else
			ic.border:SetColorTexture(0, 0, 0, 0.8)
			ic.time:SetText(e.left and FormatTime(e.left) or "")
		end
		ic:Show()
	end
	f:Show()
end

local function ShouldShow()
	local db = ns.db
	if ns.unlocked then return true end
	if not db.blessEnabled or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
	if db.blessHideResting and IsResting() then return false end
	if db.blessOnlyGrouped and not IsInGroup() then return false end
	return true
end

function M:Update()
	if not f then return end
	Read()
	if ShouldShow() then Draw() else f:Hide() end
end

function M:Init()
	f = CreateFrame("Frame", "LightboundBlessingFrame", UIParent)
	f:SetSize(SIZE, SIZE)
	f:SetFrameStrata("MEDIUM")
	f:Hide()
	ns.MakeMovable(f, "blPoint")
	ns.ApplyPoint(f, "blPoint")
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
		"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do ev:RegisterEvent(e) end
	ev:RegisterUnitEvent("UNIT_AURA", "player")
	ev:SetScript("OnEvent", function() M:Update() end)
	C_Timer.NewTicker(1, function() M:Update() end) -- countdown text
	M:Update()
end

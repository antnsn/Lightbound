-- Reagents: tops up Symbol of Kings (Greater Blessings) and Symbol of Divinity (Divine Intervention)
-- at any vendor that sells them, and warns when Symbols of Kings run low.
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local KINGS, DIVINITY = 21177, 17033
local warned = false

local function Count(id)
	return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0
end

local function Known(spell)
	local ok, info = pcall(function()
		if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spell) end
		return GetSpellInfo(spell)
	end)
	return ok and info ~= nil
end

local function KnowsGreater()
	for _, key in ipairs(ns.PP_SPELL) do
		if Known("Greater Blessing of " .. key) then return true end
	end
	return false
end

-- price of one purchase and how many items it gives
local function MerchantInfo(i)
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
		if ok and type(info) == "table" then return info.price, info.stackCount or 1 end
	end
	local ok, _, _, price, quantity = pcall(GetMerchantItemInfo, i)
	if ok then return price, quantity or 1 end
	return nil
end

-- Buys up to `target` of item `id`. BuyMerchantItem takes a number of items, so everything
-- here counts items; price is per purchase of `perBuy` items.
local function Buy(id, target, label)
	local need = target - Count(id)
	if need <= 0 then return 0 end
	for i = 1, (GetMerchantNumItems() or 0) do
		if GetMerchantItemID(i) == id then
			local price, perBuy = MerchantInfo(i)
			if not price then return 0 end
			perBuy = math.max(perBuy or 1, 1)
			local each = price / perBuy
			if each > 0 then need = math.min(need, math.floor(GetMoney() / each)) end
			if need <= 0 then ns.Print("not enough money for " .. label .. ".") return 0 end
			local maxStack = math.max((GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)) or 20, 1)
			local left = need
			while left > 0 do
				local n = math.min(left, maxStack)
				BuyMerchantItem(i, n)
				left = left - n
			end
			ns.Print(("buying %d %s (%s)."):format(need, label,
				GetCoinTextureString and GetCoinTextureString(math.ceil(each * need)) or ""))
			return need
		end
	end
	return 0
end

local function OnMerchant()
	local db = ns.db
	if not db.reagentBuy then return end
	if KnowsGreater() and db.reagentKings > 0 then Buy(KINGS, db.reagentKings, "Symbol of Kings") end
	if Known("Divine Intervention") and db.reagentDivinity > 0 then Buy(DIVINITY, db.reagentDivinity, "Symbol of Divinity") end
end

local function CheckLow()
	local db = ns.db
	if not db.reagentWarn or db.reagentWarn <= 0 or not KnowsGreater() then return end
	local n = Count(KINGS)
	if n < db.reagentWarn then
		if not warned then
			warned = true
			ns.Print(("|cffff5555only %d Symbol of Kings left.|r Any reagent vendor sells them."):format(n))
		end
	elseif n >= db.reagentWarn then
		warned = false
	end
end

function ns.ReagentCount() return Count(KINGS), Count(DIVINITY) end

function M:Update() end

function M:Init()
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("MERCHANT_SHOW")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "MERCHANT_SHOW" then
			C_Timer.After(0.3, OnMerchant) -- merchant list fills in just after the event
		else
			CheckLow()
		end
	end)
end

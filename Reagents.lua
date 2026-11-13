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

-- Free general-purpose bag slots (special bags like soul pouches can't hold symbols); nil if unknown
local function FreeSlots()
	if not (C_Container and C_Container.GetContainerNumFreeSlots) then return nil end
	local free = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local ok, n, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
		if ok and type(n) == "number" and (family == nil or family == 0) then free = free + n end
	end
	return free
end

local function StackSize(id)
	local ok, n = pcall(function()
		if C_Item and C_Item.GetItemMaxStackSizeByID then return C_Item.GetItemMaxStackSizeByID(id) end
		return select(8, GetItemInfo(id))
	end)
	return (ok and type(n) == "number" and n > 0) and n or 1
end

-- Unused room in the stacks of `id` you already carry (two half stacks = one stack of room)
local function StackRoom(id, stack)
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then
		local have = Count(id)
		return math.ceil(have / stack) * stack - have
	end
	local room = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (ok and type(slots) == "number" and slots or 0) do
			local ok2, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if ok2 and type(info) == "table" and info.itemID == id and type(info.stackCount) == "number" then
				room = room + math.max(stack - info.stackCount, 0)
			end
		end
	end
	return room
end

-- Buys up to `target` of item `id`. BuyMerchantItem takes a number of items, so everything
-- here counts items; price is per purchase of `perBuy` items. `budget` is shared by both
-- reagents in one visit (GetMoney and the bags don't update between two buys): { money, slots }.
local function Buy(id, target, label, budget)
	local have = Count(id)
	local need = target - have
	if need <= 0 then return 0 end
	for i = 1, (GetMerchantNumItems() or 0) do
		if GetMerchantItemID(i) == id then
			local price, perBuy = MerchantInfo(i)
			if not price then return 0 end
			perBuy = math.max(perBuy or 1, 1)
			local each = price / perBuy
			if each > 0 then need = math.min(need, math.floor(budget.money / each)) end
			if need <= 0 then ns.Print("not enough money for " .. label .. " (keeping a reserve).") return 0 end
			if budget.slots then
				-- room left in the stacks you have, plus whole free slots; never "Inventory is full" spam
				local stack = StackSize(id)
				local partial = StackRoom(id, stack)
				need = math.min(need, partial + budget.slots * stack)
				if need <= 0 then ns.Print("no bag space for " .. label .. ".") return 0 end
				budget.slots = budget.slots - math.ceil(math.max(need - partial, 0) / stack)
			end
			budget.money = budget.money - math.ceil(each * need)
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
	-- keep a reserve: 1 gold or 10% of your money, whichever is smaller
	local money = GetMoney() or 0
	local budget = { money = money - math.min(10000, math.floor(money * 0.1)), slots = FreeSlots() }
	if KnowsGreater() and db.reagentKings > 0 then Buy(KINGS, db.reagentKings, "Symbol of Kings", budget) end
	if Known("Divine Intervention") and db.reagentDivinity > 0 then Buy(DIVINITY, db.reagentDivinity, "Symbol of Divinity", budget) end
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

-- Carrot on a Stick: wear it while mounted, in the trinket slot you picked, and put your own
-- trinket back when you get off. Off by default. Only the carrot: no gear sets.
--  * Not in instances (you rarely ride there, and a swap mid-dungeon is unwanted).
--  * Gear can't change in combat: the swap waits until combat ends.
--  * The trinket it took off is saved per character, so a logout while mounted still restores it.
--  * If you change that trinket slot yourself while riding, Lightbound leaves it alone until the
--    next ride. Turning the option off while riding still puts your trinket back.
local _, ns = ...
if not ns.isPaladin then return end -- not a paladin: load nothing (see Core.lua)

local CARROT = 11122
local SLOT_ID = { Top = 13, Bottom = 14 } -- INVSLOT_TRINKET1 / INVSLOT_TRINKET2

local M = {}
ns.modules[#ns.modules + 1] = M

local function Count(item)
	if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(item) or 0 end
	return GetItemCount and GetItemCount(item) or 0
end

local function Equip(item, slot)
	local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
	if f then f(item, slot) end
end

-- Take the carrot off into a bag (the slot was empty before the ride). False when it can't now:
-- no free bag slot, or something already on the cursor.
local function Unequip(slot)
	if not (C_Container and C_Container.GetContainerNumFreeSlots) then return false end
	if CursorHasItem and CursorHasItem() then return false end
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local ok, n, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
		if ok and type(n) == "number" and n > 0 and (family == nil or family == 0) then
			PickupInventoryItem(slot)
			if bag == 0 then
				PutItemInBackpack()
			else
				local toInv = (C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID)
				PutItemInBag(toInv(bag))
			end
			return true
		end
	end
	return false
end

local function CharKey()
	return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
end

-- the trinket the carrot replaced, for this character: { slot = 13|14, item = itemID|nil }
local function Saved() return ns.db.carrotPrev[CharKey()] end
local function Save(v) ns.db.carrotPrev[CharKey()] = v end

function ns.CarrotSlotID() return SLOT_ID[ns.db.carrotSlot] or SLOT_ID.Bottom end

-- name of what is in a trinket slot now, for the options page
function ns.CarrotSlotItem(slotName)
	local id = GetInventoryItemID("player", SLOT_ID[slotName] or SLOT_ID.Bottom)
	if not id then return "empty" end
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	return name or ("item " .. id)
end

local waiting = false -- a swap is due once combat ends
local rideHandled = false -- this ride already got its carrot (or was changed by hand): no second swap

local function Check()
	local db = ns.db
	if not db then return end
	local prev = Saved()
	-- turned off: nothing new, but a trinket still out from an earlier ride goes back
	local mounted = IsMounted and IsMounted()
	if not mounted then rideHandled = false end
	if not db.carrotSwap and not prev then return end
	if InCombatLockdown() or UnitIsDeadOrGhost("player") then waiting = true; return end
	waiting = false
	if db.carrotSwap and mounted and not IsInInstance() then
		if rideHandled then return end
		local slot = ns.CarrotSlotID()
		local other = (slot == 13) and 14 or 13
		local worn = GetInventoryItemID("player", slot)
		if worn == CARROT or GetInventoryItemID("player", other) == CARROT then rideHandled = true; return end
		if Count(CARROT) == 0 then return end
		-- the ride counts as handled once the carrot is seen in a slot (above), so a failed equip
		-- (item locked a moment) is retried on the next aura, equipment or bag change
		if not (prev and prev.slot == slot) then Save({ slot = slot, item = worn }) end
		Equip(CARROT, slot)
	else
		-- turned off or in an instance: the next time it applies counts as a new ride, so
		-- turning it back on (or riding out of the instance) puts the carrot on again
		rideHandled = false
		if not prev then return end
		-- off the mount, in an instance or turned off: put the old trinket back. The record stays
		-- until the slot no longer holds the carrot (done, or changed by hand), so a swap that fails
		-- (item locked a moment) is retried on the next equipment or bag change.
		if GetInventoryItemID("player", prev.slot) ~= CARROT then Save(nil); return end
		if not prev.item then
			Unequip(prev.slot) -- the slot was empty: the carrot goes into a bag
		elseif Count(prev.item) > 0 then
			Equip(prev.item, prev.slot)
		else
			Save(nil) -- that trinket is gone (sold, banked): nothing to put back
		end
	end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_REGEN_ENABLED" then
		if waiting then Check() end
	elseif event == "UNIT_AURA" then
		if unit == "player" then Check() end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
		if ns.db and Saved() then Check() end
	else
		C_Timer.After(0.2, Check) -- IsMounted can lag the display event a moment
	end
end)

function M:Init()
	f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- confirms a swap back, or retries it
	f:RegisterEvent("BAG_UPDATE_DELAYED")
	f:RegisterEvent("PLAYER_UNGHOST")
	f:RegisterEvent("PLAYER_ALIVE")
	f:RegisterUnitEvent("UNIT_AURA", "player") -- fallback: a mount is also an aura
end

-- the options toggle and slot choice call ns.Refresh(): apply the new setting right away
function M:Update() Check() end

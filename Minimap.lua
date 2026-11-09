-- Minimap button: left-click options, right-click raid blessings, drag to move around the minimap.
-- No libraries; the position is an angle around the minimap (ns.db.minimapAngle).
local _, ns = ...

local M = {}
ns.modules[#ns.modules + 1] = M

local btn

local function Place()
	local angle = math.rad(ns.db.minimapAngle or 220)
	local r = (Minimap:GetWidth() / 2) + 5
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
	Place()
end

local function OnClick(_, button)
	if button == "RightButton" then
		if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end
	else
		if ns.ToggleOptions then ns.ToggleOptions() end
	end
end

function M:Update()
	if not btn then return end
	btn:SetShown(ns.db.minimap)
end

function M:Init()
	btn = CreateFrame("Button", "LightboundMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\Lightbound\\Media\\Icon64")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
	btn.icon = icon
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	btn:SetScript("OnClick", OnClick)
	btn:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
	btn:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
	btn:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	btn:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		icon:SetPoint("TOPLEFT", 7, -6)
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Lightbound")
		GameTooltip:AddLine("Left-click: options", 1, 1, 1)
		GameTooltip:AddLine("Right-click: raid blessings", 1, 1, 1)
		GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	Place()
	M:Update()

	-- also list it in the addon compartment (the puzzle-piece menu), where the client has one
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
		pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
			text = "Lightbound",
			icon = "Interface\\AddOns\\Lightbound\\Media\\Icon64",
			notCheckable = true,
			func = function(_, input, _, _, button)
				local b = (type(input) == "table" and input.buttonName) or button
				OnClick(nil, b)
			end,
		})
	end
end

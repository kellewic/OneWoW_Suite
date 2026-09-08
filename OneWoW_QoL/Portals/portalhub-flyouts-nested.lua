local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.NestedFlyouts = ns.NestedFlyouts or {}
local Nested = ns.NestedFlyouts

local activeNested = {}

local function CreateInstanceButton(_, parent, iconSize, yOffset, expansions, config, growLeft)
	local mainButton = CreateFrame("Button", nil, parent)
	mainButton:SetSize(iconSize, iconSize)
	if growLeft then
		mainButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
	else
		mainButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
	end
	ns.PortalHubFlyouts:ApplyButtonIcon(mainButton, config.icon)

	mainButton.text = OneWoW_GUI:CreateFS(mainButton, 8)
	mainButton.text:SetPoint("BOTTOM", mainButton, "BOTTOM", 0, 2)
	mainButton.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	mainButton.text:SetShadowColor(0, 0, 0, 1)
	mainButton.text:SetShadowOffset(1, -1)
	ns.PortalHubFlyouts:ApplyIconLabel(mainButton.text, config.label)

	local expFlyout = CreateFrame("Frame", nil, UIParent)
	expFlyout:SetFrameStrata("FULLSCREEN_DIALOG")
	expFlyout:SetFrameLevel(103)
	expFlyout:SetSize(iconSize * #expansions, iconSize)
	if growLeft then
		expFlyout:SetPoint("TOPRIGHT", mainButton, "TOPLEFT", -2, 0)
	else
		expFlyout:SetPoint("TOPLEFT", mainButton, "TOPRIGHT", 2, 0)
	end

	local expButtons = {}
	local validExpansions = {}
	for _, expData in ipairs(expansions) do
		if #expData.portals > 0 then
			table.insert(validExpansions, expData)
		end
	end

	expFlyout:SetSize(iconSize * math.max(#validExpansions, 1), iconSize)

	for i, expData in ipairs(validExpansions) do
		local expButton = CreateFrame("Button", nil, expFlyout)
		expButton:SetSize(iconSize, iconSize)
		local xPad = (growLeft and (#validExpansions - i) or (i - 1)) * iconSize
		expButton:SetPoint("TOPLEFT", expFlyout, "TOPLEFT", xPad, 0)
		ns.PortalHubFlyouts:ApplyButtonIcon(expButton, expData.icon)

		expButton.text = OneWoW_GUI:CreateFS(expButton, 8)
		expButton.text:SetPoint("BOTTOM", expButton, "BOTTOM", 0, 2)
		expButton.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		expButton.text:SetShadowColor(0, 0, 0, 1)
		expButton.text:SetShadowOffset(1, -1)
		ns.PortalHubFlyouts:ApplyIconLabel(expButton.text, expData.label)

		if #expData.portals > 0 then
			local portalFlyout = CreateFrame("Frame", nil, UIParent)
			portalFlyout:SetFrameStrata("FULLSCREEN_DIALOG")
			portalFlyout:SetFrameLevel(104)

			local numPortals = math.max(#expData.portals, 1)
			portalFlyout:SetSize(iconSize, iconSize * numPortals)
			portalFlyout:SetPoint("TOP", expButton, "BOTTOM", 0, -2)

			local portalButtons = {}
			for j, portal in ipairs(expData.portals) do
				if ns.PortalHubFlyouts then
					local btn = ns.PortalHubFlyouts:CreateFlyoutButton(portalFlyout, portal, 0, -(j-1) * iconSize, iconSize)
					if btn then
						btn:HookScript("PostClick", function(_, mouseButton)
							if mouseButton == "LeftButton" then
								if ns.NestedFlyouts then ns.NestedFlyouts:RecycleAll() end
								if ns.PortalHubFlyouts then ns.PortalHubFlyouts:RecycleAll() end
								if GameMenuFrame then
									C_Timer.After(0.1, function() HideUIPanel(GameMenuFrame) end)
								end
							end
						end)
						table.insert(portalButtons, btn)
					end
				end
			end

			expButton:SetScript("OnEnter", function()
				portalFlyout:Show()
			end)

			expButton:SetScript("OnLeave", function(self)
				C_Timer.After(0.3, function()
					if not portalFlyout:IsMouseOver() and not self:IsMouseOver() then
						portalFlyout:Hide()
					end
				end)
			end)

			portalFlyout:SetScript("OnLeave", function(self)
				C_Timer.After(0.3, function()
					if not self:IsMouseOver() and not expButton:IsMouseOver() then
						self:Hide()
					end
				end)
			end)

			portalFlyout:Hide()
			expButton.portalFlyout = portalFlyout
		end

		table.insert(expButtons, expButton)
	end

	local tipAnchor = growLeft and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
	mainButton:SetScript("OnEnter", function(self)
		expFlyout:Show()
		GameTooltip:SetOwner(self, tipAnchor)
		GameTooltip:SetText(config.tooltip, 1, 1, 1)
		GameTooltip:Show()
	end)

	mainButton:SetScript("OnLeave", function(self)
		C_Timer.After(0.5, function()
			if not expFlyout:IsMouseOver() and not self:IsMouseOver() then
				expFlyout:Hide()
				for _, btn in ipairs(expButtons) do
					if btn.portalFlyout then
						btn.portalFlyout:Hide()
					end
				end
			end
		end)
		GameTooltip:Hide()
	end)

	expFlyout:SetScript("OnLeave", function(self)
		C_Timer.After(0.5, function()
			local mouseOver = false
			if self:IsMouseOver() or mainButton:IsMouseOver() then
				mouseOver = true
			else
				for _, btn in ipairs(expButtons) do
					if btn:IsMouseOver() or (btn.portalFlyout and btn.portalFlyout:IsMouseOver()) then
						mouseOver = true
						break
					end
				end
			end
			if not mouseOver then
				self:Hide()
				for _, btn in ipairs(expButtons) do
					if btn.portalFlyout then
						btn.portalFlyout:Hide()
					end
				end
			end
		end)
	end)

	expFlyout:Hide()
	mainButton:Show()

	table.insert(activeNested, {button = mainButton, flyout = expFlyout, subButtons = expButtons})
	return mainButton
end

function Nested:CreateDungeonsButton(parent, iconSize, yOffset, expansions, growLeft)
	return CreateInstanceButton(self, parent, iconSize, yOffset, expansions, {
		icon = "Interface\\Icons\\Achievement_Boss_Archaedas",
		label = "Dun",
		tooltip = L["SETTINGS_PORTALHUB_DUNGEONS"],
	}, growLeft)
end

function Nested:CreateRaidsButton(parent, iconSize, yOffset, expansions, growLeft)
	return CreateInstanceButton(self, parent, iconSize, yOffset, expansions, {
		icon = 4062765,
		label = "Raid",
		tooltip = L["SETTINGS_PORTALHUB_RAIDS"],
	}, growLeft)
end

function Nested:RecycleAll()
	for _, data in ipairs(activeNested) do
		if data.button then data.button:Hide() end
		if data.flyout then data.flyout:Hide() end
		if data.subButtons then
			for _, btn in ipairs(data.subButtons) do
				if btn.portalFlyout then btn.portalFlyout:Hide() end
				btn:Hide()
			end
		end
	end
	activeNested = {}
end

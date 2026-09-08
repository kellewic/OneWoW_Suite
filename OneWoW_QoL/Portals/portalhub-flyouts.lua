local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.PortalHubFlyouts = ns.PortalHubFlyouts or {}
local Flyouts = ns.PortalHubFlyouts

--- Dedicated ESC overlay size; suite fontSizeOffset must not change these.
---@param fs FontString
---@param text string|nil
function Flyouts:ApplyIconLabel(fs, text)
	if not fs then return end
	local ph = OneWoW:GetPortalHub()
	fs:SetWordWrap(false)
	if fs.SetMaxLines then
		fs:SetMaxLines(1)
	end
	if not ph.escShowIconText or not text or text == "" then
		fs:SetText("")
		fs:Hide()
		OneWoW_GUI:ApplyFontCapped(fs, ph.escIconFontSize, 0)
		return
	end
	fs:Show()
	fs:SetText(text)
	OneWoW_GUI:ApplyFontCapped(fs, ph.escIconFontSize, 0)
end

--- Fill a button with an icon that tracks the button size.
--- SetNormalTexture leaves a default-sized stamp that looks tiny on ESC slots.
---@param button Button
---@param texture number|string|nil
function Flyouts:ApplyButtonIcon(button, texture)
	local icon = button.icon
	if not icon then
		icon = button:CreateTexture(nil, "BACKGROUND")
		icon:SetAllPoints()
		button.icon = icon
	end
	if texture then
		icon:SetTexture(texture)
	end
end

local flyoutFramesPool = {}
local flyoutButtonsPool = {}
local activeFlyouts = {}

function Flyouts:CreateFlyoutFrame(parent, side)
	local flyoutFrame

	if next(flyoutFramesPool) then
		flyoutFrame = table.remove(flyoutFramesPool)
	else
		flyoutFrame = CreateFrame("Frame", nil, UIParent)
		flyoutFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		flyoutFrame:SetFrameLevel(103)

		function flyoutFrame:Recycle()
			self:Hide()
			self:ClearAllPoints()
			self.buttons = {}
			table.insert(flyoutFramesPool, self)
		end
	end

	flyoutFrame:SetParent(parent)
	flyoutFrame.buttons = {}
	flyoutFrame.side = side
	flyoutFrame.parentButton = nil
	flyoutFrame.alwaysExpanded = false

	flyoutFrame:SetScript("OnLeave", function(myself)
		if myself.alwaysExpanded then
			return
		end
		C_Timer.After(0.3, function()
			if myself.alwaysExpanded then
				return
			end
			if not myself:IsMouseOver() and myself.parentButton and not myself.parentButton:IsMouseOver() then
				myself:Hide()
			end
		end)
	end)

	return flyoutFrame
end

function Flyouts:CreateFlyoutButton(flyoutFrame, portalData, xOffset, yOffset, iconSize)
	local button

	if next(flyoutButtonsPool) then
		button = table.remove(flyoutButtonsPool)
	else
		button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
		button.cooldownFrame = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		button.cooldownFrame:SetAllPoints()

		button.icon = button:CreateTexture(nil, "BACKGROUND")
		button.icon:SetAllPoints()

		button.text = OneWoW_GUI:CreateFS(button, 9)
		button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
		button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		button.text:SetShadowColor(0, 0, 0, 1)
		button.text:SetShadowOffset(1, -1)

		function button:Recycle()
			self:ClearAllPoints()
			self:SetParent(nil)
			self:Hide()
			self.text:SetText("")
			self:SetAlpha(1)
			if self.icon then
				self.icon:SetDesaturated(false)
			end
			self:SetAttribute("type", nil)
			self:SetAttribute("spell", nil)
			self:SetAttribute("toy", nil)
			self:SetAttribute("item", nil)
			if self.cooldownFrame then
				self.cooldownFrame:Clear()
			end
			table.insert(flyoutButtonsPool, self)
		end
	end

	button:SetParent(flyoutFrame)
	button:SetSize(iconSize, iconSize)
	button:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", xOffset, yOffset)
	button:EnableMouse(true)
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetAttribute("useOnKeyDown", true)
	button:SetAttribute("type", nil)
	button:SetAttribute("spell", nil)
	button:SetAttribute("toy", nil)
	button:SetAttribute("item", nil)

	local isAvailable = portalData.available ~= false

	if portalData.type == "toy" then
		if isAvailable then
			button:SetAttribute("type", "toy")
			button:SetAttribute("toy", portalData.id)
		end
		local _, _, icon = C_ToyBox.GetToyInfo(portalData.id)
		if icon then
			button.icon:SetTexture(icon)
		else
			local item = Item:CreateFromItemID(portalData.id)
			item:ContinueOnItemLoad(function()
				local itemIcon = item:GetItemIcon()
				if itemIcon then
					button.icon:SetTexture(itemIcon)
				end
			end)
		end
	elseif portalData.type == "item" then
		if isAvailable then
			button:SetAttribute("type", "item")
			button:SetAttribute("item", "item:" .. portalData.id)
		end
		local item = Item:CreateFromItemID(portalData.id)
		item:ContinueOnItemLoad(function()
			local icon = item:GetItemIcon()
			if icon then
				button.icon:SetTexture(icon)
			end
		end)
	elseif portalData.type == "spell" then
		if isAvailable then
			button:SetAttribute("type", "spell")
			button:SetAttribute("spell", portalData.id)
		end
		local icon = C_Spell.GetSpellTexture(portalData.id)
		if icon then
			button.icon:SetTexture(icon)
		end

	end

	local label
	if portalData.type == "spell" then
		label = ns.PortalData:GetShortName(portalData.id)
	end
	self:ApplyIconLabel(button.text, label)

	if isAvailable then
		button:SetAlpha(1)
		button.icon:SetDesaturated(false)
	else
		button:SetAlpha(0.5)
		button.icon:SetDesaturated(true)
	end

	button:SetScript("PostClick", function(_, mouseButton)
		if not isAvailable then
			return
		end
		if mouseButton == "LeftButton" then
			if ns.PortalHubFlyouts then
				ns.PortalHubFlyouts:RecycleAll()
			end
			if ns.NestedFlyouts then
				ns.NestedFlyouts:RecycleAll()
			end
			if GameMenuFrame and GameMenuFrame:IsShown() then
				C_Timer.After(0.1, function()
					HideUIPanel(GameMenuFrame)
				end)
			end
		end
	end)

	button:SetScript("OnEnter", function(myself)
		GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
		if portalData.type == "toy" then
			GameTooltip:SetToyByItemID(portalData.id)
		elseif portalData.type == "item" then
			GameTooltip:SetItemByID(portalData.id)
		elseif portalData.type == "spell" then
			GameTooltip:SetSpellByID(portalData.id)
		end
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	if button.cooldownFrame then
		local ok = pcall(function()
			local start, duration, enabled
			if portalData.type == "toy" or portalData.type == "item" then
				start, duration, enabled = C_Item.GetItemCooldown(portalData.id)
			elseif portalData.type == "spell" then
				local cooldown = C_Spell.GetSpellCooldown(portalData.id)
				if cooldown then
					start = cooldown.startTime
					duration = cooldown.duration
					enabled = true
				end
			end
			if enabled and duration > 0 then
				button.cooldownFrame:SetCooldown(start, duration)
			else
				button.cooldownFrame:Clear()
			end
		end)
		if not ok then
			button.cooldownFrame:Clear()
		end
	end

	button:Show()
	return button
end

function Flyouts:CreateFlyoutParentButton(parent, iconTexture, iconSize, xOffset, yOffset, portals, side, label, layoutGrowLeft, alwaysExpanded)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(iconSize, iconSize)
	if layoutGrowLeft then
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -xOffset, yOffset)
	else
		button:SetPoint("TOPLEFT", parent, "TOPRIGHT", xOffset, yOffset)
	end

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()
	button.icon:SetTexture(iconTexture)

	button.text = OneWoW_GUI:CreateFS(button, 8)
	button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
	button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	button.text:SetShadowColor(0, 0, 0, 1)
	button.text:SetShadowOffset(1, -1)
	self:ApplyIconLabel(button.text, label)

	local flyoutFrame = self:CreateFlyoutFrame(button, side)
	flyoutFrame.alwaysExpanded = alwaysExpanded and true or false
	local maxPerRow = 12
	local iconGap = 2
	local numPortals = #portals
	local numRows = math.ceil(numPortals / maxPerRow)
	local numCols = math.min(numPortals, maxPerRow)

	local frameWidth = iconSize * numCols + iconGap * (numCols - 1) + 4
	local frameHeight = iconSize * numRows + iconGap * (numRows - 1) + 4
	flyoutFrame:SetSize(frameWidth, frameHeight)

	if side == "LEFT" then
		flyoutFrame:SetPoint("TOPRIGHT", button, "TOPLEFT", -2, 0)
	else
		flyoutFrame:SetPoint("TOPLEFT", button, "TOPRIGHT", 2, 0)
	end

	local row = 0
	local col = 0
	for _, portal in ipairs(portals) do
		local btnXOffset = col * (iconSize + iconGap)
		local btnYOffset = -row * (iconSize + iconGap)

		if side == "LEFT" then
			btnXOffset = (numCols - col - 1) * (iconSize + iconGap)
		end

		local flyoutBtn = self:CreateFlyoutButton(flyoutFrame, portal, btnXOffset, btnYOffset, iconSize)
		table.insert(flyoutFrame.buttons, flyoutBtn)

		col = col + 1
		if col >= maxPerRow then
			col = 0
			row = row + 1
		end
	end

	flyoutFrame.parentButton = button

	local tipAnchor = layoutGrowLeft and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
	button:SetScript("OnEnter", function(myself)
		flyoutFrame:Show()
		if not alwaysExpanded then
			GameTooltip:SetOwner(myself, tipAnchor)
			GameTooltip:SetText(L["SETTINGS_PORTALHUB_HOVER_TO_EXPAND"], 1, 1, 1)
			GameTooltip:Show()
		end
	end)

	button:SetScript("OnLeave", function()
		if alwaysExpanded then
			GameTooltip:Hide()
			return
		end
		C_Timer.After(0.5, function()
			if flyoutFrame.alwaysExpanded then
				return
			end
			if not flyoutFrame:IsMouseOver() and not button:IsMouseOver() then
				flyoutFrame:Hide()
			end
		end)
		GameTooltip:Hide()
	end)

	if alwaysExpanded then
		flyoutFrame:Show()
	else
		flyoutFrame:Hide()
	end
	button:Show()

	button.flyoutFrame = flyoutFrame
	table.insert(activeFlyouts, {button = button, flyout = flyoutFrame})

	return button
end

function Flyouts:CreateNestedFlyoutButton(parent, iconTexture, iconSize, xOffset, yOffset, portals, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(iconSize, iconSize)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()
	button.icon:SetTexture(iconTexture)

	button.text = OneWoW_GUI:CreateFS(button, 8)
	button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
	button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	button.text:SetShadowColor(0, 0, 0, 1)
	button.text:SetShadowOffset(1, -1)
	self:ApplyIconLabel(button.text, label)

	local nestedFlyout = self:CreateFlyoutFrame(button, "DOWN")
	nestedFlyout:SetSize(iconSize * #portals, iconSize)
	nestedFlyout:SetPoint("TOP", button, "BOTTOM", 0, -2)

	local col = 0
	for _, portal in ipairs(portals) do
		local flyoutBtn = self:CreateFlyoutButton(nestedFlyout, portal, col * iconSize, 0, iconSize)
		table.insert(nestedFlyout.buttons, flyoutBtn)
		col = col + 1
	end

	nestedFlyout.parentButton = button

	button:SetScript("OnEnter", function(myself)
		nestedFlyout:Show()
		GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
		GameTooltip:SetText(label or L["SETTINGS_PORTALHUB_HOVER"], 1, 1, 1)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		C_Timer.After(0.3, function()
			if not nestedFlyout:IsMouseOver() and not button:IsMouseOver() then
				nestedFlyout:Hide()
			end
		end)
		GameTooltip:Hide()
	end)

	nestedFlyout:Hide()
	button:Show()

	table.insert(activeFlyouts, {button = button, flyout = nestedFlyout})
	return button
end

function Flyouts:CreateExpansionFlyout(parent, iconTexture, iconSize, xOffset, yOffset, expansionData, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(iconSize, iconSize)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()
	button.icon:SetTexture(iconTexture)

	button.text = OneWoW_GUI:CreateFS(button, 8)
	button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
	button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	button.text:SetShadowColor(0, 0, 0, 1)
	button.text:SetShadowOffset(1, -1)
	self:ApplyIconLabel(button.text, label)

	local expFlyout = self:CreateFlyoutFrame(button, "DOWN")
	local maxPerRow = 12
	local numPortals = #expansionData
	local numRows = math.ceil(numPortals / maxPerRow)

	expFlyout:SetSize(iconSize * numPortals, iconSize * numRows)
	expFlyout:SetPoint("TOP", button, "BOTTOM", 0, -2)

	local col = 0
	local row = 0
	for _, portal in ipairs(expansionData) do
		local btnXOffset = col * iconSize
		local btnYOffset = -row * iconSize
		local flyoutBtn = self:CreateFlyoutButton(expFlyout, portal, btnXOffset, btnYOffset, iconSize)
		table.insert(expFlyout.buttons, flyoutBtn)
		col = col + 1
		if col >= maxPerRow then
			col = 0
			row = row + 1
		end
	end

	expFlyout.parentButton = button

	button:SetScript("OnEnter", function(myself)
		expFlyout:Show()
		GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
		GameTooltip:SetText(label or L["SETTINGS_PORTALHUB_HOVER"], 1, 1, 1)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		C_Timer.After(0.3, function()
			if not expFlyout:IsMouseOver() and not button:IsMouseOver() then
				expFlyout:Hide()
			end
		end)
		GameTooltip:Hide()
	end)

	expFlyout:Hide()
	button:Show()

	table.insert(activeFlyouts, {button = button, flyout = expFlyout})
	return button
end

function Flyouts:RecycleAll()
	for _, data in ipairs(activeFlyouts) do
		if data.flyout then
			for _, btn in ipairs(data.flyout.buttons or {}) do
				if btn.Recycle then
					btn:Recycle()
				end
			end
			if data.flyout.Recycle then
				data.flyout:Recycle()
			end
		end
		if data.button then
			data.button:Hide()
		end
	end
	activeFlyouts = {}
end

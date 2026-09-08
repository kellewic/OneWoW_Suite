local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local L = ns.L

ns.PortalHubEsc = ns.PortalHubEsc or {}
local EscMenu = ns.PortalHubEsc

local leftFrame = nil
local rightFrame = nil
local secureButtons = {}
local flyoutButtons = {}
local instanceStatsFrame = nil
local lastAutoUpdatedInstance = nil
local autoUpdateRegistered = false
local iconSizeSlider = nil
local iconFontSlider = nil
local rebuildingStrip = false
local ESC_ICON_SLIDER_WIDTH = 120

local function RecycleStripButtons()
	for _, button in ipairs(secureButtons) do
		if button.Recycle then button:Recycle() end
	end
	for _, button in ipairs(flyoutButtons) do
		if button.Recycle then button:Recycle() end
	end
	secureButtons = {}
	flyoutButtons = {}

	if ns.PortalHubFlyouts then
		ns.PortalHubFlyouts:RecycleAll()
	end
	if ns.NestedFlyouts then
		ns.NestedFlyouts:RecycleAll()
	end
end

function EscMenu:Initialize()
	-- GameMenu OnShow reads portalHub.escEnabled. Keep it aligned with the
	-- Features module toggle so a prior disable still hides the strips.
	OneWoW:GetPortalHub().escEnabled = ns.ModuleRegistry:IsEnabled("escpanel")
	self:HookGameMenu()
	self:RegisterAutoUpdateEvents()
end

function EscMenu:RegisterAutoUpdateEvents()
	if autoUpdateRegistered then return end
	autoUpdateRegistered = true
	-- QoL's own entering-world registry (was core's RegisterCoreEnteringWorldHandler);
	-- registered at login from Initialize, when the core-attached registry exists.
	OneWoW_QoL:RegisterEnteringWorldHandler("portalhub-esc", function()
		C_Timer.After(2, function()
			EscMenu:AutoUpdateCurrentInstance()
		end)
	end)
end

function EscMenu:AutoUpdateCurrentInstance()
	local name, instanceType = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return end
	if not name or name == "" then return end
	if lastAutoUpdatedInstance == name then return end
	lastAutoUpdatedInstance = name

	local journalData = self:GetInstanceJournalData(name)
	if not journalData or not OneWoW.JournalModule then return end

	C_Timer.After(1, function()
		OneWoW.JournalModule:UpdateInstanceItems(journalData.journalInstanceID, journalData.expansion, function() end)
	end)
end

function EscMenu:HookGameMenu()
	-- OnShow covers both ESC (ToggleGameMenu → ShowUIPanel) and the Game Menu
	-- micro button (MainMenuMicroButton → ShowUIPanel directly, no ToggleGameMenu).
	if not GameMenuFrame then return end

	GameMenuFrame:HookScript("OnShow", function()
		if OneWoW.Restriction.IsProtectedActionBlocked() then return end
		if OneWoW:GetPortalHub() and OneWoW:GetPortalHub().escEnabled then
			EscMenu:ShowPortalFrames()
		else
			EscMenu:HidePortalFrames()
		end
		if OneWoW:GetCoreGlobal() and OneWoW:GetCoreGlobal().instanceStatsEsc and OneWoW:GetCoreGlobal().instanceStatsEsc.enabled then
			EscMenu:ShowInstanceStatsFrame()
		else
			EscMenu:HideInstanceStatsFrame()
		end
	end)

	GameMenuFrame:HookScript("OnHide", function()
		EscMenu:HideInstanceStatsFrame()
		-- Portal strips are children of the protected GameMenuFrame, so Hide()
		-- on them is blocked in combat. The menu (their parent) is already
		-- hidden, so defer the state cleanup until restrictions clear; guard
		-- against the menu being reopened before the deferred run fires.
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.eschide", function()
			if GameMenuFrame and GameMenuFrame:IsShown() then return end
			EscMenu:HidePortalFrames()
		end)
	end)
end

local STRIP_GAP = 6
local PADDING_MENU_LEFT = 40
local PADDING_MENU_RIGHT = 10
local STRIP_Y_OFFSET = 0

function EscMenu:GetPortalEdgeOffsetFromMenu(portalsSide, panelsSide)
	local gm = GameMenuFrame
	if not gm then return portalsSide == "left" and -PADDING_MENU_LEFT or PADDING_MENU_RIGHT end
	local pc = ns.EscPanels:GetPanelsContainer()
	local sameSide = (portalsSide == "left" and panelsSide == "left")
		or (portalsSide == "right" and panelsSide == "right")
	local panelsVisible = ns.EscPanels:HasVisiblePanelStack()
	local pcReady = pc and pc:IsShown()

	if portalsSide == "left" then
		if sameSide and panelsVisible and pcReady then
			return (pc:GetLeft() - STRIP_GAP) - gm:GetLeft()
		end
		return -PADDING_MENU_LEFT
	end

	if sameSide and panelsVisible and pcReady then
		return (pc:GetRight() + STRIP_GAP) - gm:GetRight()
	end
	return PADDING_MENU_RIGHT
end

function EscMenu:SyncEscLayout()
	if not GameMenuFrame or not GameMenuFrame:IsShown() then return end
	local ph = OneWoW:GetPortalHub()
	if not ph or not ph.escEnabled then return end

	if ns.EscPanels then
		ns.EscPanels:SyncPanelsContainerPosition(ph)
	end

	local portalsSide = ph.escPortalsSide == "left" and "left" or "right"
	local panelsSide = ph.escPanelsSide == "right" and "right" or "left"
	local ox = self:GetPortalEdgeOffsetFromMenu(portalsSide, panelsSide)

	if ph.escPortalsEnabled then
		if portalsSide == "left" and leftFrame and leftFrame:IsShown() then
			leftFrame:ClearAllPoints()
			leftFrame:SetPoint("TOPRIGHT", GameMenuFrame, "TOPLEFT", ox, STRIP_Y_OFFSET)
		elseif portalsSide == "right" and rightFrame and rightFrame:IsShown() then
			rightFrame:ClearAllPoints()
			rightFrame:SetPoint("TOPLEFT", GameMenuFrame, "TOPRIGHT", ox, STRIP_Y_OFFSET)
		end
	end
end

function EscMenu:HidePortalFrames()
	if iconSizeSlider and GameTooltip:GetOwner() == iconSizeSlider then
		GameTooltip:Hide()
	end
	if iconFontSlider and GameTooltip:GetOwner() == iconFontSlider then
		GameTooltip:Hide()
	end
	if ns.PortalHubFlyouts then
		ns.PortalHubFlyouts:RecycleAll()
	end
	if ns.NestedFlyouts then
		ns.NestedFlyouts:RecycleAll()
	end
	if ns.EscPanels then
		ns.EscPanels:HideAll()
	end
	if leftFrame then leftFrame:Hide() end
	if rightFrame then rightFrame:Hide() end
end

function EscMenu:ShowPortalFrames()
	if not GameMenuFrame then return end

	RecycleStripButtons()

	if not leftFrame then
		leftFrame = CreateFrame("Frame", "OneWoWPortalLeft", GameMenuFrame)
		leftFrame:SetSize(1, 1)
	end
	if not rightFrame then
		rightFrame = CreateFrame("Frame", "OneWoWPortalRight", GameMenuFrame)
		rightFrame:SetSize(1, 1)
	end

	local iconSize = OneWoW:GetPortalHub().escIconSize or 40
	local iconGap = 2

	local ph = OneWoW:GetPortalHub() or {}
	local panelsSide = ph.escPanelsSide == "right" and "right" or "left"
	local portalsSide = ph.escPortalsSide == "left" and "left" or "right"

	leftFrame:Hide()
	rightFrame:Hide()

	self:BuildLeftSide()

	local ox = self:GetPortalEdgeOffsetFromMenu(portalsSide, panelsSide)

	if ph.escPortalsEnabled then
		if portalsSide == "left" then
			leftFrame:ClearAllPoints()
			leftFrame:SetPoint("TOPRIGHT", GameMenuFrame, "TOPLEFT", ox, STRIP_Y_OFFSET)
			self:BuildPortalStrip(leftFrame, iconSize, iconGap, true)
			leftFrame:Show()
		end
		if portalsSide == "right" then
			rightFrame:ClearAllPoints()
			rightFrame:SetPoint("TOPLEFT", GameMenuFrame, "TOPRIGHT", ox, STRIP_Y_OFFSET)
			self:BuildPortalStrip(rightFrame, iconSize, iconGap, false)
			rightFrame:Show()
		end
	end

	local function deferredSync()
		if not GameMenuFrame or not GameMenuFrame:IsShown() then return end
		if OneWoW.Restriction.IsProtectedActionBlocked() then return end
		local hub = OneWoW:GetPortalHub()
		if not hub or not hub.escEnabled then return end
		EscMenu:SyncEscLayout()
	end

	C_Timer.After(0, deferredSync)
	C_Timer.After(0.05, deferredSync)
end

function EscMenu:BuildLeftSide()
	if ns.EscPanels then
		ns.EscPanels:Build()
	end
end

function EscMenu:PlaceIconSizeSlider(parent, yOffset, growLeft)
	local ph = OneWoW:GetPortalHub()
	local size = (ph and ph.escIconSize) or 40

	if not iconSizeSlider or iconSizeSlider:GetParent() ~= parent then
		if iconSizeSlider then
			iconSizeSlider:Hide()
			iconSizeSlider:SetParent(nil)
			iconSizeSlider = nil
		end
		iconSizeSlider = OneWoW_GUI:CreateSlider(parent, {
			width = ESC_ICON_SLIDER_WIDTH,
			minVal = 20,
			maxVal = 64,
			step = 2,
			currentVal = size,
			fmt = "%dpx",
			onChange = function(val)
				local hub = OneWoW:GetPortalHub()
				if not hub or hub.escIconSize == val or rebuildingStrip then
					return
				end
				hub.escIconSize = val
				EscMenu:ReloadStripPreservingSlider()
			end,
		})
		local sl = iconSizeSlider.slider
		OneWoW_GUI:ConfigureOptionsSliderEnds(sl, "", "")
		if sl.Low then sl.Low:Hide() end
		if sl.High then sl.High:Hide() end
		iconSizeSlider:SetScript("OnEnter", function(myself)
			GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
			GameTooltip:SetText(L["PORTAL_ESC_ICON_SIZE"], 1, 1, 1)
			GameTooltip:AddLine(L["PORTAL_ESC_ICON_SIZE_DESC"], nil, nil, nil, true)
			GameTooltip:Show()
		end)
		iconSizeSlider:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	elseif iconSizeSlider.slider:GetValue() ~= size then
		iconSizeSlider.slider:SetValue(size)
	end

	iconSizeSlider:ClearAllPoints()
	if growLeft then
		iconSizeSlider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
	else
		iconSizeSlider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
	end
	iconSizeSlider:Show()
	return iconSizeSlider:GetHeight()
end

function EscMenu:PlaceIconFontSlider(parent, yOffset, growLeft)
	local ph = OneWoW:GetPortalHub()
	local size = ph.escIconFontSize

	if not iconFontSlider or iconFontSlider:GetParent() ~= parent then
		if iconFontSlider then
			iconFontSlider:Hide()
			iconFontSlider:SetParent(nil)
			iconFontSlider = nil
		end
		iconFontSlider = OneWoW_GUI:CreateSlider(parent, {
			width = ESC_ICON_SLIDER_WIDTH,
			minVal = 8,
			maxVal = 18,
			step = 1,
			currentVal = size,
			fmt = "%d",
			onChange = function(val)
				local hub = OneWoW:GetPortalHub()
				if not hub or hub.escIconFontSize == val or rebuildingStrip then
					return
				end
				hub.escIconFontSize = val
				EscMenu:ReloadStripPreservingSlider()
			end,
		})
		local sl = iconFontSlider.slider
		OneWoW_GUI:ConfigureOptionsSliderEnds(sl, "", "")
		if sl.Low then sl.Low:Hide() end
		if sl.High then sl.High:Hide() end
		iconFontSlider:SetScript("OnEnter", function(myself)
			GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
			GameTooltip:SetText(L["PORTAL_ESC_ICON_FONT_SIZE"], 1, 1, 1)
			GameTooltip:AddLine(L["PORTAL_ESC_ICON_FONT_SIZE_DESC"], nil, nil, nil, true)
			GameTooltip:Show()
		end)
		iconFontSlider:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	elseif iconFontSlider.slider:GetValue() ~= size then
		iconFontSlider.slider:SetValue(size)
	end

	iconFontSlider:ClearAllPoints()
	if growLeft then
		iconFontSlider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
	else
		iconFontSlider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
	end
	iconFontSlider:Show()
	return iconFontSlider:GetHeight()
end

function EscMenu:ReloadStripPreservingSlider()
	if not GameMenuFrame or not GameMenuFrame:IsShown() then return end
	if OneWoW.Restriction.IsProtectedActionBlocked() then return end
	local ph = OneWoW:GetPortalHub()
	if not ph or not ph.escEnabled or not ph.escPortalsEnabled then return end

	local portalsSide = ph.escPortalsSide == "left" and "left" or "right"
	local parent = portalsSide == "left" and leftFrame or rightFrame
	if not parent or not parent:IsShown() then
		self:ShowPortalFrames()
		return
	end

	rebuildingStrip = true
	RecycleStripButtons()
	self:SyncEscLayout()
	self:BuildPortalStrip(parent, ph.escIconSize or 40, 2, portalsSide == "left")
	rebuildingStrip = false
end

function EscMenu:BuildPortalStrip(parent, iconSize, iconGap, growLeft)
	local ph = OneWoW:GetPortalHub()
	if not ph or not ph.escPortalsEnabled then
		if iconSizeSlider then iconSizeSlider:Hide() end
		if iconFontSlider then iconFontSlider:Hide() end
		return
	end
	-- Class, profession, mage, and item flyouts stay known-only.
	local showAll = false
	local showUnknown = ph.escShowUnknown ~= false
	local currentSeason = ns.PortalHubDetection:GetCurrentSeasonNumber()
	local flyoutOrient = growLeft and "LEFT" or "RIGHT"
	local yOffset = 0
	local xOffset = 0

	if not ns.PortalHubFlyouts then return end

	local showTopRow = ph.showEscTopRow ~= false
	if showTopRow then
		local hearthButtons = {}
		if ph.showHearthstone ~= false then
			local choice = ns.PortalHubDetection:GetHearthstoneChoice()
			if choice == "none" then
				-- skip ESC hearth button
			elseif choice == "disabled" then
				table.insert(hearthButtons, {type = "hearthdisabled", id = 6948})
			elseif choice == "random" then
				table.insert(hearthButtons, {type = "randomhearth", id = 6948})
			elseif choice == "default" then
				table.insert(hearthButtons, {type = "item", id = 6948})
			else
				table.insert(hearthButtons, {type = "toy", id = choice})
			end
		end
		if ph.showDalaranHearth ~= false then
			if PlayerHasToy(140192) and C_QuestLog.IsQuestFlaggedCompleted(44663) then
				table.insert(hearthButtons, {type = "toy", id = 140192})
			end
		end
		if ph.showGarrisonHearth ~= false then
			if PlayerHasToy(110560) and C_QuestLog.IsQuestFlaggedCompleted(34378) then
				table.insert(hearthButtons, {type = "toy", id = 110560})
			end
		end
		if ph.showFlightWhistle ~= false then
			if C_Item.GetItemCount(141605) > 0 or PlayerHasToy(141605) then
				table.insert(hearthButtons, {type = "item", id = 141605})
			end
		end
		if ph.showHousingPortal ~= false then
			local housingPortal = ns.PortalHubDetection:GetHousingPortal(false)
			if housingPortal then
				table.insert(hearthButtons, housingPortal)
			end
		end

		xOffset = 0
		for _, hearth in ipairs(hearthButtons) do
			local button = self:CreatePortalButton(parent, hearth, xOffset, yOffset, iconSize, growLeft)
			table.insert(secureButtons, button)
			xOffset = xOffset + iconSize + iconGap
		end
		if #hearthButtons > 0 then
			yOffset = yOffset - (iconSize + iconGap)
		end
		xOffset = 0
	end

	local favorites = ns.PortalHubModule:GetFavorites()
	local favAvailable = {}
	for _, fav in ipairs(favorites) do
		if fav.available then
			table.insert(favAvailable, fav)
		end
	end
	if #favAvailable > 0 then
		local keepFavOpen = ph.escFavoritesAlwaysExpanded == true
		local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, 1506458, iconSize, 0, yOffset, favAvailable, flyoutOrient, "Fav", growLeft, keepFavOpen
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	local druid = ns.PortalHubDetection:GetDruidPortals(showAll)
	local dk = ns.PortalHubDetection:GetDeathKnightPortals(showAll)
	local monk = ns.PortalHubDetection:GetMonkPortals(showAll)
	local shaman = ns.PortalHubDetection:GetShamanPortals(showAll)
	local covenant = ns.PortalHubDetection:GetCovenantPortals(showAll)
	local racial = ns.PortalHubDetection:GetRacePortals(showAll)

	local allAbilities = {}
	for _, p in ipairs(druid) do table.insert(allAbilities, p) end
	for _, p in ipairs(dk) do table.insert(allAbilities, p) end
	for _, p in ipairs(monk) do table.insert(allAbilities, p) end
	for _, p in ipairs(shaman) do table.insert(allAbilities, p) end
	for _, p in ipairs(covenant) do table.insert(allAbilities, p) end
	for _, p in ipairs(racial) do table.insert(allAbilities, p) end

	if #allAbilities > 0 then
		local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, "Interface\\Icons\\Achievement_BG_winAB_underXminutes", iconSize, 0, yOffset, allAbilities, flyoutOrient, "Abil", growLeft
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	local wormholes = ns.PortalHubDetection:GetWormholes(showAll)
	local rippers = ns.PortalHubDetection:GetDimensionalRippers(showAll)
	local transporters = ns.PortalHubDetection:GetUltrasafeTransporters(showAll)
	local engOther = ns.PortalHubDetection:GetEngineeringOtherItems(showAll)
	local allEng = {}
	for _, w in ipairs(wormholes) do table.insert(allEng, w) end
	for _, r in ipairs(rippers) do table.insert(allEng, r) end
	for _, t in ipairs(transporters) do table.insert(allEng, t) end
	for _, o in ipairs(engOther) do table.insert(allEng, o) end
	if #allEng > 0 then
		local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, "Interface\\Icons\\Trade_Engineering", iconSize, 0, yOffset, allEng, flyoutOrient, "Prof", growLeft
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	if ph.showMageTeleports then
		local mageT = ns.PortalHubDetection:GetMageTeleports(showAll)
		if #mageT > 0 then
			local icon = C_Spell.GetSpellTexture(mageT[1].id) or C_Spell.GetSpellTexture(3561) or 237509
			local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
				parent, icon, iconSize, 0, yOffset, mageT, flyoutOrient, L["PORTAL_ESC_MAGE_TELEPORT"], growLeft
			)
			table.insert(flyoutButtons, button)
			yOffset = yOffset - (iconSize + iconGap)
		end
	end
	if ph.showMagePortals then
		local mageP = ns.PortalHubDetection:GetMagePortals(showAll)
		if #mageP > 0 then
			local icon = C_Spell.GetSpellTexture(mageP[1].id) or C_Spell.GetSpellTexture(10059) or 237509
			local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
				parent, icon, iconSize, 0, yOffset, mageP, flyoutOrient, L["PORTAL_ESC_MAGE_PORTAL"], growLeft
			)
			table.insert(flyoutButtons, button)
			yOffset = yOffset - (iconSize + iconGap)
		end
	end

	yOffset = yOffset - (iconSize + iconGap)

	if ns.NestedFlyouts then
		local midIcon = C_Spell.GetSpellTexture(1254400) or C_Spell.GetSpellTexture(1254572) or 5872031
		local currentExp = ns.PortalHubDetection:GetCurrentPathExpansion()
		local seasonalOnly = ns.PortalHubDetection:IsSeasonalOnly()
		local dungeonExpansions = {
			{id = "mid", label = "MID", icon = midIcon, portals = ns.PortalHubDetection:GetDungeonPortals("mid", showUnknown)},
			{id = "tww", label = "TWW", icon = 5872031, portals = ns.PortalHubDetection:GetDungeonPortals("tww", showUnknown)},
			{id = "df", label = "DF", icon = 4640496, portals = ns.PortalHubDetection:GetDungeonPortals("df", showUnknown)},
			{id = "sl", label = "SL", icon = 236798, portals = ns.PortalHubDetection:GetDungeonPortals("sl", showUnknown)},
			{id = "bfa", label = "BFA", icon = 1869493, portals = ns.PortalHubDetection:GetDungeonPortals("bfa", showUnknown)},
			{id = "legion", label = "LEG", icon = 1260827, portals = ns.PortalHubDetection:GetDungeonPortals("legion", showUnknown)},
			{id = "wod", label = "WoD", icon = 1413856, portals = ns.PortalHubDetection:GetDungeonPortals("wod", showUnknown)},
			{id = "mop", label = "MoP", icon = 328269, portals = ns.PortalHubDetection:GetDungeonPortals("mop", showUnknown)},
			{id = "cata", label = "CAT", icon = 574788, portals = ns.PortalHubDetection:GetDungeonPortals("cata", showUnknown)},
		}
		if seasonalOnly then
			local filtered = {}
			for _, exp in ipairs(dungeonExpansions) do
				if exp.id == currentExp then
					table.insert(filtered, exp)
				end
			end
			dungeonExpansions = filtered
		end

		local hasDungeons = false
		for _, exp in ipairs(dungeonExpansions) do
			if #exp.portals > 0 then
				hasDungeons = true
				break
			end
		end

		if hasDungeons then
			local dungeonButton = ns.NestedFlyouts:CreateDungeonsButton(parent, iconSize, yOffset, dungeonExpansions, growLeft)
			table.insert(flyoutButtons, dungeonButton)
			yOffset = yOffset - (iconSize + iconGap)
		end

		local raidExpansions = {
			{id = "mid", label = "MID", icon = midIcon, portals = ns.PortalHubDetection:GetRaidPortals("mid", showUnknown)},
			{id = "tww", label = "TWW", icon = 5872031, portals = ns.PortalHubDetection:GetRaidPortals("tww", showUnknown)},
			{id = "df", label = "DF", icon = 4640496, portals = ns.PortalHubDetection:GetRaidPortals("df", showUnknown)},
			{id = "sl", label = "SL", icon = 236798, portals = ns.PortalHubDetection:GetRaidPortals("sl", showUnknown)},
			{id = "bfa", label = "BFA", icon = 1869493, portals = ns.PortalHubDetection:GetRaidPortals("bfa", showUnknown)},
			{id = "legion", label = "LEG", icon = 1260827, portals = ns.PortalHubDetection:GetRaidPortals("legion", showUnknown)},
			{id = "wod", label = "WoD", icon = 1413856, portals = ns.PortalHubDetection:GetRaidPortals("wod", showUnknown)},
			{id = "mop", label = "MoP", icon = 328269, portals = ns.PortalHubDetection:GetRaidPortals("mop", showUnknown)},
			{id = "cata", label = "CAT", icon = 574788, portals = ns.PortalHubDetection:GetRaidPortals("cata", showUnknown)},
		}
		if seasonalOnly then
			local filtered = {}
			for _, exp in ipairs(raidExpansions) do
				if exp.id == currentExp then
					table.insert(filtered, exp)
				end
			end
			raidExpansions = filtered
		end

		local hasRaids = false
		for _, exp in ipairs(raidExpansions) do
			if #exp.portals > 0 then
				hasRaids = true
				break
			end
		end

		if hasRaids then
			local raidButton = ns.NestedFlyouts:CreateRaidsButton(parent, iconSize, yOffset, raidExpansions, growLeft)
			table.insert(flyoutButtons, raidButton)
			yOffset = yOffset - (iconSize + iconGap)
		end
	end

	if ph.showSeason1 ~= false then
		local season1ShowAll = (currentSeason == 1) or showUnknown
		local season1Portals = ns.PortalHubDetection:GetSeasonPortals(1, season1ShowAll)
		local seasonIcon = C_Spell.GetSpellTexture(1254400) or 4062765
		local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, seasonIcon, iconSize, 0, yOffset, season1Portals, flyoutOrient, "S.1", growLeft
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	if ph.showSeason2 ~= false then
		local season2ShowAll = (currentSeason == 2) or showUnknown
		local season2Portals = ns.PortalHubDetection:GetSeasonPortals(2, season2ShowAll)
		local seasonIcon = C_Spell.GetSpellTexture(1286812) or C_Spell.GetSpellTexture(393256) or 4062765
		local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, seasonIcon, iconSize, 0, yOffset, season2Portals, flyoutOrient, "S.2", growLeft
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	if ns.PortalHubItems then
		local allItems = ns.PortalHubItems:GetAllItems(false, true)
		if #allItems > 0 then
			local button = ns.PortalHubFlyouts:CreateFlyoutParentButton(
				parent, "Interface\\Icons\\INV_Misc_Bag_10", iconSize, 0, yOffset, allItems, flyoutOrient, "Item", growLeft
			)
			table.insert(flyoutButtons, button)
			yOffset = yOffset - (iconSize + iconGap)
		end
	end

	yOffset = yOffset - (iconSize + iconGap)

	local openButton = self:CreateOpenHubButton(parent, 0, yOffset, iconSize, growLeft)
	table.insert(secureButtons, openButton)
	yOffset = yOffset - (iconSize + iconGap)
	local sizeH = self:PlaceIconSizeSlider(parent, yOffset, growLeft)
	self:PlaceIconFontSlider(parent, yOffset - sizeH - 8, growLeft)
end

function EscMenu:CreatePortalButton(parent, portalData, xOffset, yOffset, iconSize, growLeft)
	local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	button:SetSize(iconSize, iconSize)

	if growLeft then
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -xOffset, yOffset)
	else
		button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	end

	button.cooldownFrame = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldownFrame:SetAllPoints()
	ns.PortalHubFlyouts:ApplyButtonIcon(button)

	button.text = OneWoW_GUI:CreateFS(button, 8)
	button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
	button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	button.text:SetShadowColor(0, 0, 0, 1)
	button.text:SetShadowOffset(1, -1)

	button:EnableMouse(true)
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetAttribute("useOnKeyDown", true)

	if portalData.type == "hearthdisabled" then
		button:SetAttribute("type", nil)
		button:SetAlpha(0.5)
		local item = Item:CreateFromItemID(6948)
		item:ContinueOnItemLoad(function()
			local icon = item:GetItemIcon()
			if icon then button.icon:SetTexture(icon) end
		end)
	elseif portalData.type == "randomhearth" then
		local hasHearthstoneItem = C_Item.GetItemCount(6948) > 0
		local hearthstones = ns.PortalData_Hearthstones and ns.PortalData_Hearthstones.List or {}
		local availableToys = {}

		for id, condition in pairs(hearthstones) do
			if id ~= 6948 and PlayerHasToy(id) then
				if type(condition) == "function" then
					if condition() then table.insert(availableToys, id) end
				elseif condition == true then
					table.insert(availableToys, id)
				end
			end
		end

		local available = {}
		if hasHearthstoneItem then table.insert(available, 6948) end
		for _, toyID in ipairs(availableToys) do table.insert(available, toyID) end

		if #available == 0 then
			button:SetAttribute("type", "macro")
			button:SetAttribute("macrotext", "/run print('|cFF00FF00OneWoW:|r No hearthstones available!')")
		else
			local selectedID = available[math.random(1, #available)]
			if selectedID == 6948 then
				button:SetAttribute("type", "item")
				button:SetAttribute("item", "item:6948")
			else
				button:SetAttribute("type", "toy")
				button:SetAttribute("toy", selectedID)
			end
		end

		local item = Item:CreateFromItemID(6948)
		item:ContinueOnItemLoad(function()
			local icon = item:GetItemIcon()
			if icon then button.icon:SetTexture(icon) end
		end)
	elseif portalData.type == "toy" then
		button:SetAttribute("type", "toy")
		button:SetAttribute("toy", portalData.id)
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
		if ns.PortalHubEquip and ns.PortalHubEquip:IsItemEquippable(portalData.id) then
			button:SetAttribute("type", "macro")
			if ns.PortalHubEquip:IsItemEquipped(portalData.id) then
				button:SetAttribute("macrotext", "/use " .. portalData.id)
			else
				button:SetAttribute("macrotext", "/equip " .. portalData.id)
			end
		else
			button:SetAttribute("type", "item")
			button:SetAttribute("item", "item:" .. portalData.id)
		end
		local item = Item:CreateFromItemID(portalData.id)
		item:ContinueOnItemLoad(function()
			local icon = item:GetItemIcon()
			if icon then button.icon:SetTexture(icon) end
		end)
	elseif portalData.type == "spell" then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", portalData.id)
		local icon = C_Spell.GetSpellTexture(portalData.id)
		if icon then button.icon:SetTexture(icon) end
	elseif portalData.type == "housing" then
		ns.PortalHubDetection:ApplyHousingTeleportAttributes(button)
	end

	local label
	if portalData.type == "spell" then
		label = ns.PortalData:GetShortName(portalData.id)
	end
	ns.PortalHubFlyouts:ApplyIconLabel(button.text, label)

	button:SetScript("PostClick", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			if portalData.type == "item" and ns.PortalHubEquip then
				if ns.PortalHubEquip:IsItemEquippable(portalData.id) and not ns.PortalHubEquip:IsItemEquipped(portalData.id) then
					return
				end
			end
			if GameMenuFrame and GameMenuFrame:IsShown() then
				C_Timer.After(0.1, function() HideUIPanel(GameMenuFrame) end)
			end
		end
	end)

	button:SetScript("OnEnter", function(myself)
		GameTooltip:SetOwner(myself, growLeft and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
		if portalData.type == "hearthdisabled" then
			GameTooltip:SetText(L["FEATURE_DISABLED"], 1, 1, 1)
			GameTooltip:AddLine(L["PORTAL_HEARTHSTONE_CHOICE_DESC"], 0.8, 0.8, 0.8, true)
		elseif portalData.type == "randomhearth" or portalData.type == "item" then
			GameTooltip:SetItemByID(portalData.id)
		elseif portalData.type == "toy" then
			GameTooltip:SetToyByItemID(portalData.id)
		elseif portalData.type == "spell" then
			GameTooltip:SetSpellByID(portalData.id)
		elseif portalData.type == "housing" then
			if myself._onewowHousingIsReturn then
				GameTooltip:SetText(HOUSING_DASHBOARD_RETURN, 1, 1, 1)
			else
				GameTooltip:SetText(HOUSING_DASHBOARD_TELEPORT_TO_PLOT, 1, 1, 1)
			end
		end
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	self:UpdateCooldown(button, portalData)

	function button:Recycle()
		self:Hide()
		self:ClearAllPoints()
		self:SetParent(nil)
		self.text:SetText("")
	end

	button:Show()
	return button
end

function EscMenu:UpdateCooldown(button, portalData)
	if not button.cooldownFrame then return end

	local start, duration, enabled

	if portalData.type == "randomhearth" or portalData.type == "toy" or portalData.type == "item" then
		start, duration, enabled = C_Item.GetItemCooldown(portalData.id)
	elseif portalData.type == "spell" then
		local cooldown = C_Spell.GetSpellCooldown(portalData.id)
		if cooldown then
			start = cooldown.startTime
			duration = cooldown.duration
			enabled = true
		end
	elseif portalData.type == "housing" then
		if button._onewowHousingIsReturn then
			button.cooldownFrame:Clear()
			return
		end
		local cdInfo = C_Housing.GetVisitCooldownInfo()
		start = cdInfo.startTime
		duration = cdInfo.duration
		enabled = cdInfo.isEnabled
	end

	if enabled and not OneWoW.Restriction.IsSecret(duration) and duration > 0 then
		button.cooldownFrame:SetCooldown(start, duration)
	else
		button.cooldownFrame:Clear()
	end
end

function EscMenu:CreateOpenHubButton(parent, xOffset, yOffset, iconSize, growLeft)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(iconSize, iconSize)
	if growLeft then
		button:SetPoint("RIGHT", parent, "TOPRIGHT", -xOffset, yOffset)
	else
		button:SetPoint("LEFT", parent, "TOPLEFT", xOffset, yOffset)
	end
	ns.PortalHubFlyouts:ApplyButtonIcon(button, "Interface\\Icons\\INV_Misc_Book_09")

	button:SetScript("OnClick", function()
		HideUIPanel(GameMenuFrame)
		C_Timer.After(0.15, function()
			-- This code only runs from the QoL unit, so the qol module tab exists.
			local global = OneWoW:GetCoreGlobal()
			if global then
				if not global.lastSubTabs then global.lastSubTabs = {} end
				global.lastSubTabs.qol = "portals"
			end
			OneWoW.UI:Show("qol")
		end)
	end)

	button:SetScript("OnEnter", function(myself)
		GameTooltip:SetOwner(myself, growLeft and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Open Portal Hub"], 1, 1, 1)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	function button:Recycle()
		self:Hide()
		self:ClearAllPoints()
		self:SetParent(nil)
	end

	button:Show()
	return button
end

function EscMenu:Reload()
	-- Only refresh when ESC menu is actually open; otherwise ShowPortalFrames would display
	-- cards (You, Here) as stray UI outside the menu
	if GameMenuFrame and GameMenuFrame:IsShown() then
		self:ShowPortalFrames()
	end
end

function EscMenu:HideInstanceStatsFrame()
	if instanceStatsFrame then instanceStatsFrame:Hide() end
end

function EscMenu:ShowInstanceStatsFrame()
	local name, instanceType, _, difficultyName, maxPlayers = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then
		self:HideInstanceStatsFrame()
		return
	end
	if not name or name == "" then
		self:HideInstanceStatsFrame()
		return
	end
	self:CreateOrUpdateInstanceStatsFrame(name, instanceType, difficultyName, maxPlayers)
end

function EscMenu:CreateOrUpdateInstanceStatsFrame(instanceName, instanceType, difficultyName, maxPlayers, refreshCount)
	if not instanceName then return end
	refreshCount = refreshCount or 0

	local _, collectiblesStats = self:GetInstanceJournalData(instanceName)
	local statsText = instanceType == "party" and L["SETTINGS_PORTALHUB_DUNGEON"] or L["SETTINGS_PORTALHUB_RAID"]
	if difficultyName and difficultyName ~= "" then
		statsText = statsText .. " - " .. difficultyName
	end
	if maxPlayers and maxPlayers > 0 then
		statsText = statsText .. " (" .. maxPlayers .. " players)"
	end

	if collectiblesStats then
		statsText = statsText .. "\n\n"
		local statLines = {}
		if collectiblesStats.mounts.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_MOUNTS_FORMAT"], collectiblesStats.mounts.collected, collectiblesStats.mounts.total))
		end
		if collectiblesStats.pets.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_PETS_FORMAT"], collectiblesStats.pets.collected, collectiblesStats.pets.total))
		end
		if collectiblesStats.recipes.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_RECIPES_FORMAT"], collectiblesStats.recipes.collected, collectiblesStats.recipes.total))
		end
		if collectiblesStats.tmog.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_TMOGS_FORMAT"], collectiblesStats.tmog.collected, collectiblesStats.tmog.total))
		end
		if collectiblesStats.housing.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_HOUSING_FORMAT"], collectiblesStats.housing.collected, collectiblesStats.housing.total))
		end
		if collectiblesStats.toys.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_TOYS_FORMAT"], collectiblesStats.toys.collected, collectiblesStats.toys.total))
		end
		if #statLines > 0 then
			statsText = statsText .. table.concat(statLines, "\n")
		end
	end

	if not instanceStatsFrame then
		instanceStatsFrame = CreateFrame("Frame", "OneWoWInstanceStatsFrame", UIParent, "BackdropTemplate")
		instanceStatsFrame:SetSize(375, 250)
		instanceStatsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		instanceStatsFrame:SetFrameLevel(1000)
		instanceStatsFrame:EnableMouse(true)
		instanceStatsFrame:SetMovable(true)
		instanceStatsFrame:SetClampedToScreen(true)
		instanceStatsFrame:RegisterForDrag("LeftButton")

		instanceStatsFrame.bgTexture = instanceStatsFrame:CreateTexture(nil, "BACKGROUND")
		instanceStatsFrame.bgTexture:SetAllPoints(instanceStatsFrame)
		instanceStatsFrame.bgTexture:SetAtlas("GarrMissionLocation-Maw-bg-01", true)

		local title = OneWoW_GUI:CreateFS(instanceStatsFrame, 18, "ARTWORK")
		title:SetPoint("TOP", instanceStatsFrame, "TOP", 0, -15)
		title:SetJustifyH("CENTER")
		title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		title:SetShadowColor(0, 0, 0, 1)
		title:SetShadowOffset(2, -2)
		instanceStatsFrame.title = title

		local subtitle = OneWoW_GUI:CreateFS(instanceStatsFrame, 12, "ARTWORK")
		subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
		subtitle:SetJustifyH("CENTER")
		subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
		subtitle:SetShadowColor(0, 0, 0, 1)
		subtitle:SetShadowOffset(1, -1)
		instanceStatsFrame.subtitle = subtitle

		local statsTextObj = OneWoW_GUI:CreateFS(instanceStatsFrame, 12, "ARTWORK")
		statsTextObj:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
		statsTextObj:SetWidth(350)
		statsTextObj:SetJustifyH("CENTER")
		statsTextObj:SetWordWrap(true)
		statsTextObj:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
		statsTextObj:SetShadowColor(0, 0, 0, 1)
		statsTextObj:SetShadowOffset(1, -1)
		statsTextObj:SetSpacing(3)
		instanceStatsFrame.statsText = statsTextObj

		local divider = instanceStatsFrame:CreateTexture(nil, "ARTWORK")
		divider:SetAtlas("Options_HorizontalDivider", true)
		divider:SetPoint("BOTTOM", instanceStatsFrame, "BOTTOM", 0, 48)
		divider:SetSize(350, 8)

		local openJournalButton = CreateFrame("Button", nil, instanceStatsFrame, "UIPanelButtonTemplate")
		openJournalButton:SetSize(150, 30)
		openJournalButton:SetPoint("BOTTOM", instanceStatsFrame, "BOTTOM", 0, 10)
		openJournalButton:SetText(L["SETTINGS_PORTALHUB_UPDATE_DATA"])
		openJournalButton:SetScript("OnClick", function()
			HideUIPanel(GameMenuFrame)
		end)

		instanceStatsFrame:SetScript("OnDragStart", function(myself) myself:StartMoving() end)
		instanceStatsFrame:SetScript("OnDragStop", function(myself)
			myself:StopMovingOrSizing()
			EscMenu:SaveInstanceStatsPosition()
		end)

		EscMenu:RestoreInstanceStatsPosition()
	end

	instanceStatsFrame.title:SetText(instanceName)
	instanceStatsFrame.subtitle:SetText(L["SETTINGS_PORTALHUB_INSTANCE_STATISTICS"])
	instanceStatsFrame.statsText:SetText(statsText)
	instanceStatsFrame:Show()

	if refreshCount < 3 then
		C_Timer.After(0.3, function()
			if instanceStatsFrame and instanceStatsFrame:IsVisible() then
				EscMenu:CreateOrUpdateInstanceStatsFrame(instanceName, instanceType, difficultyName, maxPlayers, refreshCount + 1)
			end
		end)
	end
end

function EscMenu:GetInstanceJournalData(instanceName)
	if not OneWoW.JournalModule then return nil, nil end
	local allInstances, error = OneWoW.JournalModule:GetJournalData()
	if error or not allInstances then return nil, nil end

	for _, instance in ipairs(allInstances) do
		if instance.name and instance.name:lower() == instanceName:lower() then
			local stats = {
				mounts = {collected = 0, total = 0},
				pets = {collected = 0, total = 0},
				recipes = {collected = 0, total = 0},
				tmog = {collected = 0, total = 0},
				housing = {collected = 0, total = 0},
				toys = {collected = 0, total = 0}
			}
			return instance, stats
		end
	end
	return nil, nil
end

function EscMenu:SaveInstanceStatsPosition()
	if not instanceStatsFrame then return end
	local point, _, relativePoint, x, y = instanceStatsFrame:GetPoint()
	local global = OneWoW:GetCoreGlobal()
	if not global then return end
	if not global.instanceStatsPosition then global.instanceStatsPosition = {} end
	global.instanceStatsPosition.point = point
	global.instanceStatsPosition.relativePoint = relativePoint
	global.instanceStatsPosition.x = x
	global.instanceStatsPosition.y = y
end

function EscMenu:RestoreInstanceStatsPosition()
	if not instanceStatsFrame then return end
	local global = OneWoW:GetCoreGlobal()
	local savedPos = global and global.instanceStatsPosition
	if savedPos and savedPos.point then
		instanceStatsFrame:ClearAllPoints()
		instanceStatsFrame:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
	else
		instanceStatsFrame:ClearAllPoints()
		instanceStatsFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
	end
end

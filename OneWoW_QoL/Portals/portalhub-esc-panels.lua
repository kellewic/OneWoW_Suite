local _, ns = ...

-- ============================================================================
-- ESC menu side panels
-- ============================================================================
-- You / Here live on OneWoW.StatusCards. This file owns GameMenu chrome
-- (dim overlay, container, catalog/list open).
-- ============================================================================

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local C_Map = C_Map
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local pairs = pairs

local C = OneWoW_GUI.Constants

ns.EscPanels = ns.EscPanels or {}
local EscPanels = ns.EscPanels

local PANEL_WIDTH = 350
EscPanels.PANEL_WIDTH = PANEL_WIDTH
local PANEL_GAP = 6
local MENU_PANEL_H_GAP = 20

local panelFrames = {}
local dimOverlay = nil
local panelsContainer = nil
local settingsWired = false
local endeavorEvents
local skipEndeavorRequest = false

local function CloseEscMenu()
	if GameMenuFrame and GameMenuFrame:IsShown() then
		HideUIPanel(GameMenuFrame)
	end
end

local function PlaceOpenSpec(panel)
	local spec = panel and panel.openSpec
	if spec then
		return spec
	end
	local mapID = C_Map.GetBestMapForUnit("player")
	if mapID then
		return { mapID = mapID }
	end
	return nil
end

local function OpenPlaceInCatalog(panel)
	local spec = PlaceOpenSpec(panel)
	if not spec then
		return
	end
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:WithAddon("OneWoW_Catalog", function()
			OneWoW_Catalog_API.OpenToInstance(spec)
		end)
	end)
end

local function LoadZonesPackForHere()
	OneWoW:EnsureCatalogPack("journal")
	OneWoW:EnsureCatalogJournalPlaces()
	if GameMenuFrame and GameMenuFrame:IsShown() then
		EscPanels:Build()
	end
end

local function OpenShoppingList(listName)
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:BringUp("OneWoW_ShoppingList")
		local api = OneWoW_ShoppingList_API
		if api and listName and api.ShowList then
			api.ShowList(listName)
		elseif api then
			api.Show()
		end
	end)
end

local function OpenMailWindow()
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:BringUp("OneWoW_Mail")
		if OneWoW_Mail_API then
			OneWoW_Mail_API.Show()
		end
	end)
end

local function OpenCharacterScreen()
	CloseEscMenu()
	C_Timer.After(0.1, function()
		ToggleCharacter("PaperDollFrame", true)
	end)
end

local function OpenAltTrackerAuctions()
	CloseEscMenu()
	C_Timer.After(0.15, function()
		local global = OneWoW:GetCoreGlobal()
		if global then
			if not global.lastSubTabs then
				global.lastSubTabs = {}
			end
			global.lastSubTabs.alttracker = "auctions"
		end
		OneWoW:BringUp("OneWoW_AltTracker")
		OneWoW.UI:Show("alttracker")
	end)
end

local function OpenAlertSource(sourceKey, payload)
	if sourceKey == "shopping" then
		local listName
		local items = payload or {}
		for i = 1, #items do
			local lists = items[i].lists
			if lists and lists[1] then
				listName = lists[1]
				break
			end
		end
		OpenShoppingList(listName)
		return
	end
	if sourceKey == "notes" then
		local first = payload and payload[1]
		if not first or not first.id then
			return
		end
		CloseEscMenu()
		C_Timer.After(0.15, function()
			OneWoW:BringUp("OneWoW_Notes")
			if OneWoW_Notes_API then
				OneWoW_Notes_API.OpenZone(first.id)
			end
		end)
		return
	end
	if sourceKey == "farming" then
		local first = payload and payload[1]
		CloseEscMenu()
		C_Timer.After(0.15, function()
			OneWoW:BringUp("OneWoW_Notes")
			if first and OneWoW_Notes_API then
				OneWoW_Notes_API.OpenJournalNote(first.id)
			end
		end)
		return
	end
	if sourceKey == "trackers" then
		local first = payload and payload[1]
		CloseEscMenu()
		C_Timer.After(0.15, function()
			OneWoW:BringUp("OneWoW_Trackers")
			if first and OneWoW_Trackers_API then
				OneWoW_Trackers_API.ShowList(first.listID)
			end
		end)
	end
end

local function OpenZoneNotesFromPanel(panel)
	local targetId = panel.currentNoteId
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:BringUp("OneWoW_Notes")
		local api = OneWoW_Notes_API
		if not api then
			return
		end
		if not targetId then
			local zone, subzone, mapInfo
			if api.GetCurrentZoneParts then
				zone, subzone, mapInfo = api.GetCurrentZoneParts()
			else
				zone = GetZoneText() or ""
				subzone = ""
				mapInfo = api.GetCurrentMapInfo and api.GetCurrentMapInfo() or nil
			end
			if not zone or zone == "" then
				return
			end
			targetId = api.AddZone({
				zone = zone,
				subzone = subzone or "",
				content = "",
				category = "General",
				storage = "account",
				mapID = mapInfo and mapInfo.mapID,
				parentMapID = mapInfo and mapInfo.parentMapID,
			})
		end
		if targetId then
			api.OpenZone(targetId)
		end
	end)
end

local function AnchorBelow(panel, anchorPanel, hMode, gap)
	panel:ClearAllPoints()
	local y = gap or 0
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 0, -y)
	else
		panel:SetPoint("TOPRIGHT", anchorPanel, "BOTTOMRIGHT", 0, -y)
	end
end

local function EnsureDimOverlay()
	if not dimOverlay then
		dimOverlay = CreateFrame("Frame", "OneWoWEscDimOverlay", UIParent)
		dimOverlay:SetAllPoints(UIParent)
		dimOverlay:SetFrameStrata("DIALOG")
		dimOverlay:SetFrameLevel(0)

		local bg = dimOverlay:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		local r, g, b = unpack(C.OVERLAY_DIM)
		bg:SetColorTexture(r, g, b, 0.6)
	end
	dimOverlay:Show()
end

local function GetPanelsHorizontalMode(ph)
	if ph and ph.escPanelsSide == "right" then
		return "right"
	end
	return "left"
end

function EscPanels:EnsurePanelsContainer(ph)
	if not panelsContainer then
		panelsContainer = CreateFrame("Frame", "OneWoWEscPanelsContainer", UIParent)
		panelsContainer:SetFrameStrata("FULLSCREEN_DIALOG")
		panelsContainer:SetFrameLevel(500)
		OneWoW_GUI:RegisterFontRoot(panelsContainer, function()
			if GameMenuFrame and GameMenuFrame:IsShown() then
				EscPanels:Build()
			end
		end)
	end

	panelsContainer:SetParent(UIParent)
	local gm = GameMenuFrame
	local mode = GetPanelsHorizontalMode(ph)
	panelsContainer:ClearAllPoints()
	panelsContainer:SetWidth(PANEL_WIDTH)

	if gm and gm:IsShown() then
		if mode == "right" then
			panelsContainer:SetPoint("TOPLEFT", gm, "TOPRIGHT", MENU_PANEL_H_GAP, 0)
		else
			panelsContainer:SetPoint("TOPRIGHT", gm, "TOPLEFT", -MENU_PANEL_H_GAP, 0)
		end
		if not panelsContainer:GetHeight() or panelsContainer:GetHeight() < 1 then
			panelsContainer:SetHeight(1)
		end
	else
		local yTop = UIParent:GetHeight()
		local gmLeft = gm and gm.GetLeft and gm:GetLeft()
		local gmRight = gm and gm.GetRight and gm:GetRight()
		if mode == "right" then
			if gmRight then
				panelsContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", gmRight + MENU_PANEL_H_GAP, yTop)
			else
				panelsContainer:SetPoint("TOPLEFT", UIParent, "TOP", 200, 0)
			end
		elseif gmLeft then
			panelsContainer:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", gmLeft - MENU_PANEL_H_GAP, yTop)
		else
			panelsContainer:SetPoint("TOPRIGHT", UIParent, "TOP", -200, 0)
		end
		panelsContainer:SetHeight(UIParent:GetHeight())
	end

	panelsContainer:Show()
	return panelsContainer
end

function EscPanels:GetPanelsContainer()
	return panelsContainer
end

local function EnsureStackBase(container)
	if not container.stackBase then
		container.stackBase = CreateFrame("Frame", "OneWoWEscPanelsStackBase", container)
	end
	local f = container.stackBase
	f:ClearAllPoints()
	f:SetSize(PANEL_WIDTH, 1)
	f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
	f:Show()
	return f
end

local function WireEndeavorEvents()
	if endeavorEvents then
		return
	end
	endeavorEvents = CreateFrame("Frame")
	endeavorEvents:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
	endeavorEvents:SetScript("OnEvent", function()
		if GameMenuFrame and GameMenuFrame:IsShown() then
			skipEndeavorRequest = true
			EscPanels:Build()
			skipEndeavorRequest = false
		end
	end)
end

local function BuildYou(container, anchorPanel, hMode)
	if not panelFrames.charInfo then
		panelFrames.charInfo = OneWoW.StatusCards:CreateYou(container, {
			name = "OneWoWEscPanelCharInfo",
			width = PANEL_WIDTH,
			interactive = true,
			mail = true,
			durability = true,
			vault = true,
			cache = true,
			endeavors = true,
			timer = false,
			onYouClick = OpenCharacterScreen,
			onMailClick = OpenMailWindow,
			onDurabilityClick = OpenCharacterScreen,
			onAuctionsClick = OpenAltTrackerAuctions,
		})
	end
	local panel = panelFrames.charInfo
	AnchorBelow(panel, anchorPanel, hMode, 0)
	panel.showEndeavors = true
	WireEndeavorEvents()
	OneWoW.StatusCards:RefreshYou(panel, OneWoW.StatusCards:CollectYou({
		vault = true,
		cache = true,
		endeavors = true,
		requestEndeavors = not skipEndeavorRequest,
	}))
	return panel
end

local function OpenHereAlert(sourceKey, hits)
	if sourceKey == "notes" and (not hits or not hits[1] or not hits[1].id) then
		OpenZoneNotesFromPanel(panelFrames.place)
		return
	end
	OpenAlertSource(sourceKey, hits)
end

local function BuildHere(container, anchorPanel, hMode, data)
	if not panelFrames.place then
		panelFrames.place = OneWoW.StatusCards:CreateHere(container, {
			name = "OneWoWEscPanelPlace",
			width = PANEL_WIDTH,
			interactive = true,
			collections = true,
			zoneNotes = false,
			onHereClick = OpenPlaceInCatalog,
			onHereRightClick = LoadZonesPackForHere,
			onAlertClick = OpenHereAlert,
		})
	end
	local panel = panelFrames.place
	panel.showZoneNotes = false
	panel.flexHeight = nil
	AnchorBelow(panel, anchorPanel, hMode, PANEL_GAP)
	return OneWoW.StatusCards:RefreshHere(panel, data)
end

local function WireSettings()
	if settingsWired then
		return
	end
	settingsWired = true
	OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", EscPanels, function()
		if GameMenuFrame and GameMenuFrame:IsShown() then
			EscPanels:Build()
		end
	end)
end

function EscPanels:Build()
	local ph = OneWoW:GetPortalHub()
	if not ph or not ph.escEnabled then
		self:HideAll()
		return
	end

	WireSettings()
	EnsureDimOverlay()
	local container = self:EnsurePanelsContainer(ph)
	local hMode = GetPanelsHorizontalMode(ph)

	local hereData = OneWoW.StatusCards:CollectHere()

	local lastPanel = EnsureStackBase(container)
	local usedHeight = 0
	local gapUsed = 0

	local function Consume(panel, gap)
		if not panel then
			return
		end
		if gap then
			gapUsed = gapUsed + PANEL_GAP
		end
		usedHeight = usedHeight + panel:GetHeight()
		lastPanel = panel
	end

	if ph.escShowCharacterInfo ~= false then
		Consume(BuildYou(container, lastPanel, hMode), false)
	elseif panelFrames.charInfo then
		panelFrames.charInfo:Hide()
	end

	if panelFrames.alerts then
		panelFrames.alerts:Hide()
	end

	if ph.escShowHere ~= false then
		local placePanel = BuildHere(container, lastPanel, hMode, hereData)
		if placePanel then
			local hadPrior = lastPanel and lastPanel.GetHeight and lastPanel:GetHeight() > 1
			Consume(placePanel, hadPrior)
		end
	elseif panelFrames.place then
		panelFrames.place:Hide()
	end

	if panelFrames.instanceToast then
		panelFrames.instanceToast:Hide()
	end
	if panelFrames.zoneNotes then
		panelFrames.zoneNotes:Hide()
	end
	if panelFrames.daily then
		panelFrames.daily:Hide()
	end
	if panelFrames.weekly then
		panelFrames.weekly:Hide()
	end

	if not self:HasVisiblePanelStack() then
		if panelsContainer then
			panelsContainer:Hide()
		end
	elseif panelsContainer then
		panelsContainer:SetHeight(math.max(1, usedHeight + gapUsed))
	end
end

function EscPanels:GetUsedHeight()
	if not panelsContainer or not panelsContainer:IsShown() then
		return 0
	end
	return panelsContainer:GetHeight() or 0
end

function EscPanels:GetMenuGap()
	return MENU_PANEL_H_GAP
end

function EscPanels:HasVisiblePanelStack()
	for _, p in pairs(panelFrames) do
		if p and p.IsShown and p:IsShown() then
			return true
		end
	end
	return false
end

function EscPanels:SyncPanelsContainerPosition(ph)
	if not ph or not ph.escEnabled then
		return
	end
	if not panelsContainer or not panelsContainer:IsShown() then
		return
	end
	self:EnsurePanelsContainer(ph)
end

function EscPanels:HideAll()
	for _, panel in pairs(panelFrames) do
		if panel and panel.Hide then
			panel:Hide()
		end
	end
	if dimOverlay then
		dimOverlay:Hide()
	end
	if panelsContainer then
		panelsContainer:Hide()
	end
end

local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

local selectedZone   = nil
local zoneListItems  = {}
local categoryFilter = "All"
local storageFilter  = "All"
local searchFilter   = ""
local currentSort    = { by = "name", ascending = true }

local contentEditBox  = nil
local detailPanel     = nil
local emptyMessage    = nil
local leftStatusText  = nil
local rightStatusText = nil
local scrollChild     = nil
local todoContainer       = nil
local contentUpdateTimer  = nil

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
local Detail = ns.Constants.Detail

local function GetFontColorFromKey(fontColorKey, pinColorKey)
    return ns.Config:GetResolvedFontColor(fontColorKey, pinColorKey)
end

function ns.UI.CreateZonesTab(parent)
    do
        local p = ns.db.global.tabSortPrefs.zones
        currentSort.by        = ns.UI.NormalizeSortBy(p.by) or "name"
        currentSort.ascending = p.ascending ~= false
        if p.by == "manual" then
            ns.db.global.tabSortPrefs.zones = { by = "custom", ascending = p.ascending ~= false }
        end
    end

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(78)

    local addZoneBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_MANUAL_ENTRY"], height = 25, minWidth = 80 })
    addZoneBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)
    addZoneBtn:SetScript("OnClick", function()
        ns.UI.ShowManualZoneEntryDialog(parent)
    end)

    local detectBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_ADD_CURRENT_ZONE"], height = 25, minWidth = 80 })
    detectBtn:SetPoint("LEFT", addZoneBtn, "RIGHT", 6, 0)
    detectBtn:SetScript("OnClick", function()
        if not ns.Zones then return end
        local zone, subzone, mapInfo = ns.Zones:GetCurrentZoneParts()
        if not zone or zone == "" then
            print("|cFFFFD100OneWoW - Zones:|r " .. (L["ZONE_DETECT_FAIL"]))
            return
        end
        local title = ns.Zones:FormatTitle(zone, subzone)
        local existingId = ns.Zones:FindIdByParts(zone, subzone)
        if existingId then
            selectedZone = existingId
            if parent.SelectZone then parent.SelectZone(existingId) end
            print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"], title))
            return
        end
        local zoneData = {
            zone = zone,
            subzone = subzone or "",
            content = "",
            category = "General",
            storage = "account",
            pinColor = "sync",
            fontColor = "match",
        }
        if mapInfo then
            zoneData.mapID = mapInfo.mapID
            zoneData.parentMapID = mapInfo.parentMapID
        end
        local noteId = ns.Zones:AddZone(zoneData)
        selectedZone = noteId
        parent.RefreshZonesList()
        if parent.SelectZone then parent.SelectZone(noteId) end
    end)

    local addParentBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["ZONE_ADD_PARENT"], height = 25, minWidth = 80 })
    addParentBtn:SetPoint("LEFT", detectBtn, "RIGHT", 6, 0)
    addParentBtn:SetScript("OnClick", function()
        if not ns.Zones then return end
        local parentZoneName = ns.Zones:GetParentZoneName()
        if not parentZoneName or parentZoneName == "" then
            print("|cFFFFD100OneWoW - Zones:|r " .. (L["MSG_NO_PARENT_ZONE"]))
            return
        end
        local existingId = ns.Zones:FindIdByParts(parentZoneName, "")
        if existingId then
            selectedZone = existingId
            if parent.SelectZone then parent.SelectZone(existingId) end
            print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"], parentZoneName))
            return
        end
        local mapInfo = ns.Zones:GetCurrentMapInfo()
        local zoneData = {
            zone = parentZoneName,
            subzone = "",
            content = "",
            category = "General",
            storage = "account",
            pinColor = "sync",
            fontColor = "match",
        }
        if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
            local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
            if parentMapInfo then
                zoneData.mapID = mapInfo.parentMapID
                zoneData.parentMapID = parentMapInfo.parentMapID
            end
        elseif mapInfo then
            zoneData.mapID = mapInfo.mapID
            zoneData.parentMapID = mapInfo.parentMapID
        end
        local noteId = ns.Zones:AddZone(zoneData)
        selectedZone = noteId
        parent.RefreshZonesList()
        if parent.SelectZone then parent.SelectZone(noteId) end
    end)

    local categoryDropdown = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    categoryDropdown:SetPoint("LEFT", addParentBtn, "RIGHT", 8, 0)
    local storageDropdown
    local function CountZonesForFilters(ignoreDim)
        local counts = { all = 0, byCategory = {}, byStorage = { All = 0, account = 0, character = 0 } }
        if not ns.Zones then return counts end
        local searchLower = (searchFilter or ""):lower()
        local allZones = ns.Zones:GetAllZones()
        for _, data in pairs(allZones) do
            if type(data) == "table" then
                local title = ns.Zones:FormatTitleFromData(data)
                local ok = true
                if ignoreDim ~= "category" and categoryFilter ~= "All"
                    and data.category ~= categoryFilter then
                    ok = false
                end
                if ignoreDim ~= "storage" and storageFilter ~= "All"
                    and data.storage ~= storageFilter then
                    ok = false
                end
                if searchLower ~= "" then
                    if not title:lower():find(searchLower, 1, true)
                        and not (data.zone and data.zone:lower():find(searchLower, 1, true))
                        and not (data.subzone and data.subzone ~= ""
                            and data.subzone:lower():find(searchLower, 1, true)) then
                        ok = false
                    end
                end
                if ok then
                    counts.all = counts.all + 1
                    local cat = data.category or "General"
                    counts.byCategory[cat] = (counts.byCategory[cat] or 0) + 1
                    local stor = data.storage == "character" and "character" or "account"
                    counts.byStorage[stor] = (counts.byStorage[stor] or 0) + 1
                    counts.byStorage.All = counts.byStorage.All + 1
                end
            end
        end
        return counts
    end
    local function RefreshCatOpts()
        local catCounts = CountZonesForFilters("category")
        local catOpts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(catCounts.all),
        }}
        if ns.Zones then
            for _, c in ipairs(ns.Zones:GetCategories()) do
                catOpts[#catOpts + 1] = {
                    text = c,
                    value = c,
                    rightText = ns.UI.FormatSectionCount(catCounts.byCategory[c] or 0),
                }
            end
        end
        categoryDropdown:SetOptions(catOpts)
        categoryDropdown:SetSelected(categoryFilter)
    end
    RefreshCatOpts()
    categoryDropdown.onSelect = function(value)
        categoryFilter = value
        parent.RefreshZonesList()
    end

    local manageCategoriesBtn = OneWoW_GUI:CreateIconButton(controlPanel, {
        iconTexture = MEDIA .. "icon-gears.png",
        size = 20,
        texCoord = { 0.1, 0.9, 0.1, 0.9 },
        tooltipTitle = L["CATMGR_TITLE"],
        tooltipText = L["UI_MANAGE_CATEGORIES_DESC"],
        onClick = function()
            ns.UI.ShowCategoryManager("zones")
        end,
    })
    manageCategoriesBtn:SetPoint("LEFT", categoryDropdown, "RIGHT", 4, 0)

    storageDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storageDropdown:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    local function RefreshStorageOpts()
        local storCounts = CountZonesForFilters("storage")
        storageDropdown:SetOptions({
            {text = ALL, value = "All",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.All)},
            {text = L["UI_STORAGE_ACCOUNT"], value = "account",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.account)},
            {text = CHARACTER, value = "character",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.character)},
        })
        storageDropdown:SetSelected(storageFilter)
    end
    RefreshStorageOpts()
    storageDropdown.onSelect = function(value)
        storageFilter = value
        parent.RefreshZonesList()
    end

    local zoneSortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = NAME},
            {key = "category", label = CATEGORY},
            {key = "color",    label = COLOR},
            {key = "custom",   label = CUSTOM},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 100,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            ns.db.global.tabSortPrefs.zones = { by = field, ascending = ascending }
            parent.RefreshZonesList()
        end,
    })
    zoneSortHandle.dropdown:SetPoint("LEFT", storageDropdown, "RIGHT", 6, 0)
    zoneSortHandle.dirBtn:SetPoint("LEFT", zoneSortHandle.dropdown, "RIGHT", 4, 0)

    local helpButton = CreateFrame("Button", nil, controlPanel)
    helpButton:SetSize(28, 28)
    helpButton:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -10, -10)
    local helpIcon = helpButton:CreateTexture(nil, "ARTWORK")
    helpIcon:SetSize(24, 24)
    helpIcon:SetPoint("CENTER", helpButton, "CENTER", 0, 0)
    helpIcon:SetAtlas("CampaignActiveQuestIcon")
    helpButton:SetScript("OnClick", function()
        if not ns.UI.notesHelpPanel and ns.UI.CreateNotesHelpPanel then
            ns.UI.notesHelpPanel = ns.UI.CreateNotesHelpPanel()
        end
        if ns.UI.notesHelpPanel then
            if ns.UI.notesHelpPanel:IsShown() then
                ns.UI.notesHelpPanel:Hide()
            else
                ns.UI.notesHelpPanel:Show()
            end
        end
    end)
    helpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["UI_ZONES_HELP_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_ZONES_HELP_HINT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local zoneWindowCb = OneWoW_GUI:CreateCheckbox(controlPanel, {
        label = L["SETTINGS_ZONE_PINNED_WINDOW"],
        checked = ns.Zones:IsPinnedWindowEnabled(),
        onClick = function(myself)
            ns.Zones:SetPinnedWindowEnabled(myself:GetChecked())
        end,
    })
    zoneWindowCb:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -48)

    local listingPanel = ns.UI.CreateThemedPanel(nil, parent)
    listingPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listingPanel:SetWidth(OneWoW_GUI.Constants.GUI.LEFT_PANEL_WIDTH)

    local listingTitle = OneWoW_GUI:CreateFS(listingPanel, 16)
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["TAB_ZONES"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            searchFilter = text
            if parent.RefreshZonesList then parent.RefreshZonesList() end
        end,
    })
    searchBox:SetPoint("TOPLEFT",  listingPanel, "TOPLEFT",  8, -30)
    searchBox:SetPoint("TOPRIGHT", listingPanel, "TOPRIGHT", -8, -30)

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT", listingPanel, "TOPLEFT", 10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    local sectionRowFrames = {}
    local sectionDataBags = {}
    local sectionReorders = {}
    local function GetOrCreateSectionReorder(sectionKey)
        if sectionReorders[sectionKey] then
            return sectionReorders[sectionKey]
        end
        local ctrl = ns.UI.CreateNotesListReorderDrag({
            getItems = function()
                return sectionRowFrames[sectionKey]
            end,
            getScrollFrame = function()
                return listScroll.scrollFrame
            end,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local bag = sectionDataBags[sectionKey]
                if ns.UI.ApplySectionReorder(bag, fromIdx, toIdx, insertBefore) then
                    ns.UI.EnsureCustomSort(zoneSortHandle, currentSort, "zones")
                    parent.RefreshZonesList()
                end
            end,
        })
        sectionReorders[sectionKey] = ctrl
        return ctrl
    end
    local function IsAnyZonesReorderActive()
        for _, ctrl in pairs(sectionReorders) do
            if ctrl:IsActive() or ctrl:ShouldSuppressClick() then
                return true
            end
        end
        return false
    end

    detailPanel = ns.UI.CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT", listingPanel, "TOPRIGHT", 10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["ZONES_SELECT_PROMPT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT", listingPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ZONES"], 0))

    local rightStatusBar = ns.UI.CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    rightStatusText = OneWoW_GUI:CreateFS(rightStatusBar, 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText(READY)

    local function ShowEditor()
        emptyMessage:Hide()

        for _, child in ipairs({detailPanel:GetChildren()}) do
            child:Hide()
        end

        if not detailPanel.editorContent then
            local editorHeader = ns.UI.CreateDetailHeader(detailPanel)

            local zoneTitleFS = OneWoW_GUI:CreateFS(editorHeader, 16)
            zoneTitleFS:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 12, -8)
            zoneTitleFS:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -110, -8)
            zoneTitleFS:SetJustifyH("LEFT")
            zoneTitleFS:SetWordWrap(false)
            zoneTitleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            editorHeader.zoneTitleFS = zoneTitleFS

            local deleteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-trash.png",
            })
            deleteBtn:SetScript("OnClick", function()
                if selectedZone then
                    local zId = selectedZone
                    local zd = ns.Zones and ns.Zones:GetZone(zId)
                    local title = zd and ns.Zones:FormatTitleFromData(zd) or zId
                    local confirmResult = OneWoW_GUI:CreateConfirmDialog({
                        name = "OneWoW_NotesDeleteZoneConfirm",
                        title = L["DIALOG_CONFIRM_DELETE"],
                        message = string.format(L["ZONE_CONFIRM_DELETE"], title),
                        buttons = {
                            {
                                text = DELETE,
                                color = {0.8, 0.2, 0.2},
                                onClick = function(dlg)
                                    if ns.ZonePins then ns.ZonePins:DestroyZonePin(zId) end
                                    if ns.Zones then ns.Zones:RemoveZone(zId) end
                                    selectedZone = nil
                                    if detailPanel.editorContent then
                                        for _, frame in pairs(detailPanel.editorContent) do
                                            if frame and frame.Hide then frame:Hide() end
                                        end
                                    end
                                    emptyMessage:Show()
                                    parent.RefreshZonesList()
                                    dlg:Hide()
                                end,
                            },
                            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
                        },
                    })
                    confirmResult.frame:Show()
                end
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_DELETE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local propertiesBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-gears.png",
                relativeTo = deleteBtn,
            })
            propertiesBtn:SetScript("OnClick", function()
                if selectedZone then
                    ns.UI.ShowZonePropertiesDialog(selectedZone, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_PROPERTIES"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_PROPERTIES_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local pinBtn = CreateFrame("CheckButton", nil, editorHeader)
            pinBtn:SetSize(22, 22)
            pinBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -2, 0)

            local pinNormalTex = pinBtn:CreateTexture(nil, "BACKGROUND")
            pinNormalTex:SetAllPoints()
            pinNormalTex:SetTexture(MEDIA .. "icon-pin.png")
            pinNormalTex:SetDesaturated(true)
            pinNormalTex:SetAlpha(0.3)
            pinBtn:SetNormalTexture(pinNormalTex)

            local pinHighlightTex = pinBtn:CreateTexture(nil, "HIGHLIGHT")
            pinHighlightTex:SetAllPoints()
            pinHighlightTex:SetTexture(MEDIA .. "icon-pin.png")
            pinHighlightTex:SetAlpha(0.5)
            pinBtn:SetHighlightTexture(pinHighlightTex)

            pinBtn:SetScript("OnClick", function(self)
                if selectedZone and ns.ZonePins and ns.Zones then
                    local zoneData = ns.Zones:GetZone(selectedZone)
                    if zoneData then
                        if zoneData.pinEnabled and ns.zonePins and ns.zonePins[selectedZone] then
                            ns.ZonePins:HideZonePin(selectedZone)
                            zoneData.pinEnabled = false
                            self:GetNormalTexture():SetDesaturated(true)
                            self:GetNormalTexture():SetAlpha(0.3)
                            self:SetChecked(false)
                        else
                            zoneData.pinEnabled = true
                            ns.ZonePins:ShowZonePin(selectedZone, zoneData)
                            self:GetNormalTexture():SetDesaturated(false)
                            self:GetNormalTexture():SetAlpha(1.0)
                            self:SetChecked(true)
                        end
                        parent.RefreshZonesList()
                    end
                end
            end)
            pinBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_PIN"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_PIN_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            pinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.pinBtn = pinBtn

            local alertHeaderBtn = CreateFrame("CheckButton", nil, editorHeader)
            alertHeaderBtn:SetSize(22, 22)
            alertHeaderBtn:SetPoint("RIGHT", pinBtn, "LEFT", -2, 0)

            local alertHNormalTex = alertHeaderBtn:CreateTexture(nil, "BACKGROUND")
            alertHNormalTex:SetAllPoints()
            alertHNormalTex:SetTexture(MEDIA .. "icon-alert.png")
            alertHNormalTex:SetDesaturated(true)
            alertHNormalTex:SetAlpha(0.3)
            alertHeaderBtn:SetNormalTexture(alertHNormalTex)

            local alertHHighlightTex = alertHeaderBtn:CreateTexture(nil, "HIGHLIGHT")
            alertHHighlightTex:SetAllPoints()
            alertHHighlightTex:SetTexture(MEDIA .. "icon-alert.png")
            alertHHighlightTex:SetAlpha(0.5)
            alertHeaderBtn:SetHighlightTexture(alertHHighlightTex)

            alertHeaderBtn:SetScript("OnClick", function(self)
                if selectedZone and ns.Zones then
                    local zoneData = ns.Zones:GetZone(selectedZone)
                    if zoneData then
                        local wasEnabled = zoneData.alertEnabled ~= false
                        zoneData.alertEnabled = not wasEnabled
                        if zoneData.alertEnabled then
                            self:GetNormalTexture():SetDesaturated(false)
                            self:GetNormalTexture():SetAlpha(1.0)
                            self:SetChecked(true)
                        else
                            self:GetNormalTexture():SetDesaturated(true)
                            self:GetNormalTexture():SetAlpha(0.3)
                            self:SetChecked(false)
                        end
                        ns.Zones:SaveZone(selectedZone, zoneData)
                        parent.RefreshZonesList()
                    end
                end
            end)
            alertHeaderBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ZONE_ALERT"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ZONE_ALERT_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            alertHeaderBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.alertBtn = alertHeaderBtn

            local favoriteBtn = CreateFrame("CheckButton", nil, editorHeader)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", alertHeaderBtn, "LEFT", -2, 0)

            local favNormalTex = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favNormalTex:SetAllPoints()
            favNormalTex:SetTexture(MEDIA .. "icon-fav.png")
            favNormalTex:SetDesaturated(true)
            favNormalTex:SetAlpha(0.3)
            favoriteBtn:SetNormalTexture(favNormalTex)

            local favCheckedTex = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favCheckedTex:SetAllPoints()
            favCheckedTex:SetTexture(MEDIA .. "icon-fav.png")
            favoriteBtn:SetCheckedTexture(favCheckedTex)

            local favHighlightTex = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
            favHighlightTex:SetAllPoints()
            favHighlightTex:SetTexture(MEDIA .. "icon-fav.png")
            favHighlightTex:SetAlpha(0.5)
            favoriteBtn:SetHighlightTexture(favHighlightTex)

            favoriteBtn:SetScript("OnClick", function(self)
                if selectedZone and ns.Zones then
                    local zoneData = ns.Zones:GetZone(selectedZone)
                    if zoneData then
                        zoneData.favorite = not zoneData.favorite
                        if zoneData.favorite then
                            self:GetNormalTexture():SetDesaturated(false)
                            self:GetNormalTexture():SetAlpha(1.0)
                            self:SetChecked(true)
                        else
                            self:GetNormalTexture():SetDesaturated(true)
                            self:GetNormalTexture():SetAlpha(0.3)
                            self:SetChecked(false)
                        end
                        ns.Zones:SaveZone(selectedZone, zoneData)
                        parent.RefreshZonesList()
                    end
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_FAVORITE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_FAVORITE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local categoryLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_UPPER)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], GENERAL))
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local mapLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            mapLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_LOWER)
            mapLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            mapLine:SetJustifyH("RIGHT")
            editorHeader.mapLine = mapLine

            local body = ns.UI.CreateDetailBody(detailPanel, editorHeader, {
                onTextChanged = function(self, userInput)
                    if userInput and selectedZone and ns.Zones then
                        local d = ns.Zones:GetZone(selectedZone)
                        if d then
                            d.content = self:GetText()
                            d.modified = GetServerTime()
                            ns.Zones:SaveZone(selectedZone, d)

                            if contentUpdateTimer then contentUpdateTimer:Cancel() end
                            contentUpdateTimer = C_Timer.NewTimer(2, function()
                                if selectedZone and ns.zonePins and ns.zonePins[selectedZone] then
                                    local pinFrame = ns.zonePins[selectedZone]
                                    if pinFrame and pinFrame.contentText then
                                        local zone = ns.Zones:GetZone(selectedZone)
                                        if zone then
                                            pinFrame.contentText:SetText(zone.content or "")
                                        end
                                    end
                                end
                                contentUpdateTimer = nil
                            end)
                        end
                    end
                end,
            })
            local contentBg = body.contentBg
            local contentScroll = body.contentScroll
            contentEditBox = body.contentEditBox
            contentEditBox:SetHyperlinksEnabled(true)
            contentEditBox:SetScript("OnHyperlinkClick", function(_, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnReceiveDrag", function(self)
                local cursorType, _, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    self:Insert(itemLink)
                    ClearCursor()
                end
            end)
            contentEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then
                ns.NotesHyperlinks:EnhanceEditBox(contentEditBox)
            end
            contentEditBox._skipGlobalFont = true
            detailPanel.contentEditBox = contentEditBox

            contentBg:SetScript("OnMouseDown", function(_, button)
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetFocus()
                    if button == "LeftButton" then
                        local cursorType, _, itemLink = GetCursorInfo()
                        if cursorType == "item" and itemLink then
                            detailPanel.contentEditBox:Insert(itemLink)
                            ClearCursor()
                        elseif cursorType == "spell" then
                            local spellID = select(2, GetCursorInfo())
                            if spellID then
                                local spellLink = C_Spell.GetSpellLink(spellID)
                                if spellLink then detailPanel.contentEditBox:Insert(spellLink) end
                            end
                            ClearCursor()
                        end
                    elseif button == "RightButton" and ns.NotesContextMenu then
                        ns.NotesContextMenu:ShowEditBoxContextMenu(detailPanel.contentEditBox)
                    end
                end
            end)

            -- Catalog Quests link directly under the note body (same chrome as NPCs)
            local associatedSection = ns.UI.CreateThemedBar(nil, detailPanel)
            associatedSection:SetPoint("TOPLEFT",  contentBg, "BOTTOMLEFT",  0, -Detail.SECTION_GAP)
            associatedSection:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -Detail.SECTION_GAP)
            associatedSection:SetHeight(36)

            local assocLabel = OneWoW_GUI:CreateFS(associatedSection, 12)
            assocLabel:SetPoint("TOPLEFT", associatedSection, "TOPLEFT", 10, -10)
            assocLabel:SetText(L["NOTES_NPC_ASSOC_QUESTS"])
            assocLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local catalogLink = OneWoW_GUI:CreateTextLink(associatedSection, {
                text = L["NOTES_OPEN_QUESTS_IN_CATALOG"],
                fontSize = 12,
                nav = true,
                onClick = function()
                    if not (OneWoW_Catalog_API and OneWoW_Catalog_API.OpenQuestsFiltered) then
                        return
                    end
                    if not selectedZone or not ns.Zones then return end
                    local d = ns.Zones:GetZone(selectedZone)
                    local zoneName = d and ns.Zones:ResolveCatalogZoneName(d)
                    if zoneName and zoneName ~= "" then
                        OneWoW_Catalog_API.OpenQuestsFiltered({ zoneName = zoneName })
                    end
                end,
            })
            catalogLink:SetPoint("LEFT", assocLabel, "RIGHT", 12, 0)
            associatedSection.label = assocLabel
            associatedSection.catalogLink = catalogLink

            local todoSection = CreateFrame("Frame", nil, detailPanel)
            todoSection:SetPoint("TOPLEFT", associatedSection, "BOTTOMLEFT", 0, -Detail.SECTION_GAP)
            todoSection:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 10)
            todoSection:SetClipsChildren(true)

            local todoHeader = CreateFrame("Frame", nil, todoSection)
            todoHeader:SetPoint("TOPLEFT", todoSection, "TOPLEFT", 0, 0)
            todoHeader:SetPoint("TOPRIGHT", todoSection, "TOPRIGHT", -22, 0)
            todoHeader:SetHeight(30)

            local todoLabel = OneWoW_GUI:CreateFS(todoHeader, 12)
            todoLabel:SetPoint("LEFT", todoHeader, "LEFT", 5, 0)
            todoLabel:SetText(L["ZONE_TODO_HEADER"])
            todoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local resetTasksBtn = OneWoW_GUI:CreateIconButton(todoHeader, {
                atlas = "talents-button-undo",
                size = 20,
                tooltipTitle = L["NOTE_RESET_TODOS"],
                tooltipText = L["NOTE_RESET_TODOS_DESC"],
                onClick = function()
                    if selectedZone and ns.Zones then
                        local d = ns.Zones:GetZone(selectedZone)
                        if d and d.todos then
                            for _, todo in ipairs(d.todos) do
                                todo.done = false
                            end
                            ns.Zones:SaveZone(selectedZone, d)
                            if parent.RefreshZoneTodos then parent.RefreshZoneTodos() end
                        end
                    end
                end,
            })
            resetTasksBtn:SetPoint("LEFT", todoLabel, "RIGHT", 5, 0)

            local addTaskBtn = OneWoW_GUI:CreateIconButton(todoHeader, {
                iconTexture = MEDIA .. "icon-add.png",
                size = 24,
            })
            addTaskBtn:SetPoint("RIGHT", todoHeader, "RIGHT", 0, 0)

            local taskInputBox = OneWoW_GUI:CreateEditBox(todoHeader, {
                height = 25,
                placeholderText = "",
            })
            taskInputBox:SetPoint("LEFT", resetTasksBtn, "RIGHT", 5, 0)
            taskInputBox:SetPoint("RIGHT", addTaskBtn, "LEFT", -5, 0)
            taskInputBox:SetScript("OnEnterPressed", function(self)
                local text = self:GetText()
                if text and text ~= "" and selectedZone and ns.Zones then
                    local d = ns.Zones:GetZone(selectedZone)
                    if d then
                        d.todos = d.todos or {}
                        table.insert(d.todos, { text = text, done = false })
                        ns.Zones:SaveZone(selectedZone, d)
                        self:SetText("")
                        if parent.RefreshZoneTodos then parent.RefreshZoneTodos() end
                    end
                end
                self:ClearFocus()
            end)
            addTaskBtn:SetScript("OnClick", function()
                local text = taskInputBox:GetText()
                if text and text ~= "" and selectedZone and ns.Zones then
                    local d = ns.Zones:GetZone(selectedZone)
                    if d then
                        d.todos = d.todos or {}
                        table.insert(d.todos, { text = text, done = false })
                        ns.Zones:SaveZone(selectedZone, d)
                        taskInputBox:SetText("")
                        if parent.RefreshZoneTodos then parent.RefreshZoneTodos() end
                    end
                end
            end)

            local todoScroll, todoScrollChild = OneWoW_GUI:CreateScrollFrame(todoSection, {})
            todoScroll:SetPoint("TOPLEFT", todoHeader, "BOTTOMLEFT", 0, -5)
            todoScroll:SetPoint("BOTTOMRIGHT", todoSection, "BOTTOMRIGHT", -22, 0)

            todoContainer = todoScrollChild
            detailPanel.todoContainer = todoContainer

            todoScroll:SetScript("OnSizeChanged", function(_, width)
                if todoContainer then todoContainer:SetWidth(width - 20) end
            end)

            local separatorLine = OneWoW_GUI:CreateDivider(detailPanel, { yOffset = 0 })
            separatorLine:ClearAllPoints()
            separatorLine:SetPoint("TOPLEFT", associatedSection, "BOTTOMLEFT", 0, -5)
            separatorLine:SetPoint("TOPRIGHT", associatedSection, "BOTTOMRIGHT", 0, -5)

            detailPanel.editorContent = {
                header             = editorHeader,
                contentScroll      = contentScroll,
                contentBg          = contentBg,
                associatedSection  = associatedSection,
                todoSection        = todoSection,
                separatorLine      = separatorLine,
            }
        end

        for _, frame in pairs(detailPanel.editorContent) do
            if frame and frame.Show then frame:Show() end
        end
        ns.UI.activeContentEditBox = detailPanel.contentEditBox

        if selectedZone and ns.Zones then
            local zoneData = ns.Zones:GetZone(selectedZone)
            if zoneData and type(zoneData) == "table" then
                local header = detailPanel.editorContent.header

                if header.zoneTitleFS then
                    header.zoneTitleFS:SetText(ns.Zones:FormatTitleFromData(zoneData))
                end

                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetText(zoneData.content or "")
                end

                local pinColor  = zoneData.pinColor or "sync"
                local fontColor = zoneData.fontColor or "match"
                local fontSize  = zoneData.fontSize or 12

                local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
                local bgColor     = colorConfig.background
                local listItemColor = colorConfig.listItem
                local borderColor = colorConfig.border

                if detailPanel.editorContent.contentBg then
                    detailPanel.editorContent.contentBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], zoneData.opacity or 0.9)
                    detailPanel.editorContent.contentBg:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
                end

                if detailPanel.contentEditBox then
                    local textColor = GetFontColorFromKey(fontColor, pinColor)
                    detailPanel.contentEditBox:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
                    local fontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)
                    detailPanel.contentEditBox:SetFont(fontPath, fontSize, zoneData.fontOutline or "")
                end

                if header then
                    local textColor = GetFontColorFromKey(fontColor, pinColor)
                    header:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4] or 0.9)
                    header:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

                    if header.categoryLine then
                        header.categoryLine:SetTextColor(textColor[1], textColor[2], textColor[3])
                        header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], zoneData.category or GENERAL))
                    end

                    if header.mapLine then
                        header.mapLine:SetTextColor(textColor[1], textColor[2], textColor[3])
                        if zoneData.mapID then
                            local mapInfo = C_Map.GetMapInfo(zoneData.mapID)
                            if mapInfo then
                                header.mapLine:SetText("Map: " .. mapInfo.name .. " (" .. zoneData.mapID .. ")")
                            else
                                header.mapLine:SetText("Map ID: " .. zoneData.mapID)
                            end
                        else
                            header.mapLine:SetText("")
                        end
                    end

                    local assoc = detailPanel.editorContent.associatedSection
                    local todoSec = detailPanel.editorContent.todoSection
                    local sep = detailPanel.editorContent.separatorLine
                    local contentBgFrame = detailPanel.editorContent.contentBg
                    if assoc and todoSec and contentBgFrame then
                        local hasCatalog = OneWoW_Catalog_API and OneWoW_Catalog_API.OpenQuestsFiltered
                        if hasCatalog then
                            assoc:SetHeight(36)
                            assoc:Show()
                            if assoc.label then assoc.label:Show() end
                            if assoc.catalogLink then assoc.catalogLink:Show() end
                            todoSec:ClearAllPoints()
                            todoSec:SetPoint("TOPLEFT", assoc, "BOTTOMLEFT", 0, -Detail.SECTION_GAP)
                            todoSec:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 10)
                            if sep then
                                sep:ClearAllPoints()
                                sep:SetPoint("TOPLEFT", assoc, "BOTTOMLEFT", 0, -5)
                                sep:SetPoint("TOPRIGHT", assoc, "BOTTOMRIGHT", 0, -5)
                            end
                        else
                            assoc:SetHeight(1)
                            assoc:Hide()
                            todoSec:ClearAllPoints()
                            todoSec:SetPoint("TOPLEFT", contentBgFrame, "BOTTOMLEFT", 0, -Detail.SECTION_GAP)
                            todoSec:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 10)
                            if sep then
                                sep:ClearAllPoints()
                                sep:SetPoint("TOPLEFT", contentBgFrame, "BOTTOMLEFT", 0, -5)
                                sep:SetPoint("TOPRIGHT", contentBgFrame, "BOTTOMRIGHT", 0, -5)
                            end
                        end
                    end

                    if header.favoriteBtn then
                        if zoneData.favorite then
                            header.favoriteBtn:GetNormalTexture():SetDesaturated(false)
                            header.favoriteBtn:GetNormalTexture():SetAlpha(1.0)
                            header.favoriteBtn:SetChecked(true)
                        else
                            header.favoriteBtn:GetNormalTexture():SetDesaturated(true)
                            header.favoriteBtn:GetNormalTexture():SetAlpha(0.3)
                            header.favoriteBtn:SetChecked(false)
                        end
                    end

                    if header.pinBtn then
                        local pinEnabled = zoneData.pinEnabled
                        header.pinBtn:GetNormalTexture():SetDesaturated(not pinEnabled)
                        header.pinBtn:GetNormalTexture():SetAlpha(pinEnabled and 1.0 or 0.3)
                        header.pinBtn:SetChecked(pinEnabled and true or false)
                    end

                    if header.alertBtn then
                        local alertEnabled = zoneData.alertEnabled ~= false
                        header.alertBtn:GetNormalTexture():SetDesaturated(not alertEnabled)
                        header.alertBtn:GetNormalTexture():SetAlpha(alertEnabled and 1.0 or 0.3)
                        header.alertBtn:SetChecked(alertEnabled)
                    end
                end

                if parent.RefreshZoneTodos then parent.RefreshZoneTodos() end
            end
        end
    end

    parent.SelectZone = function(zoneName)
        selectedZone = zoneName
        ShowEditor()
        parent.RefreshZonesList()
    end

    function parent.GetNavEntity()
        if selectedZone then
            return "zone", selectedZone
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind == "zone" then
            parent.SelectZone(id)
        end
    end

    parent:HookScript("OnShow", function()
        if ns.pendingZoneSelect then
            local name = ns.pendingZoneSelect
            ns.pendingZoneSelect = nil
            parent.SelectZone(name)
        end
    end)

    function parent.RefreshZoneTodos()
        if not todoContainer or not selectedZone then return end

        for _, child in ipairs({todoContainer:GetChildren()}) do
            child:Hide()
        end

        if not ns.Zones then return end
        local zoneData = ns.Zones:GetZone(selectedZone)
        if not zoneData or not zoneData.todos then return end

        local yOffset = 0
        for i, todo in ipairs(zoneData.todos) do
            local todoFrame = CreateFrame("Frame", nil, todoContainer)
            todoFrame:SetPoint("TOPLEFT", todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetPoint("RIGHT", todoContainer, "RIGHT", 0, 0)
            todoFrame:SetHeight(25)

            local checkbox = CreateFrame("CheckButton", nil, todoFrame, "UICheckButtonTemplate")
            checkbox:SetSize(20, 20)
            checkbox:SetPoint("LEFT", todoFrame, "LEFT", 5, 0)
            checkbox:SetChecked(todo.done)
            checkbox:SetScript("OnClick", function(self)
                local d = ns.Zones:GetZone(selectedZone)
                if d and d.todos and d.todos[i] then
                    d.todos[i].done = self:GetChecked()
                    ns.Zones:SaveZone(selectedZone, d)
                    parent.RefreshZoneTodos()
                end
            end)

            local todoEditBox = CreateFrame("EditBox", nil, todoFrame, "InputBoxTemplate")
            todoEditBox:SetPoint("LEFT", checkbox, "RIGHT", 10, 0)
            todoEditBox:SetPoint("RIGHT", todoFrame, "RIGHT", -35, 0)
            todoEditBox:SetHeight(20)
            todoEditBox:SetAutoFocus(false)
            todoEditBox:SetText(todo.text or "")
            if todo.done then
                todoEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            else
                todoEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            todoEditBox:SetScript("OnEnterPressed", function(self)
                local d = ns.Zones:GetZone(selectedZone)
                if d and d.todos and d.todos[i] then
                    d.todos[i].text = self:GetText()
                    ns.Zones:SaveZone(selectedZone, d)
                    parent.RefreshZoneTodos()
                end
                self:ClearFocus()
            end)
            todoEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            todoEditBox:SetScript("OnEditFocusLost", function(self)
                local d = ns.Zones:GetZone(selectedZone)
                if d and d.todos and d.todos[i] then
                    d.todos[i].text = self:GetText()
                    ns.Zones:SaveZone(selectedZone, d)
                end
            end)
            todoEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then
                ns.NotesHyperlinks:EnhanceEditBox(todoEditBox)
            end

            local deleteTodoBtn = OneWoW_GUI:CreateIconButton(todoFrame, {
                iconTexture = MEDIA .. "icon-minus.png",
                size = 16,
                onClick = function()
                    local d = ns.Zones:GetZone(selectedZone)
                    if d and d.todos then
                        table.remove(d.todos, i)
                        ns.Zones:SaveZone(selectedZone, d)
                        parent.RefreshZoneTodos()
                    end
                end,
            })
            deleteTodoBtn:SetPoint("RIGHT", todoFrame, "RIGHT", -5, 0)

            yOffset = yOffset - 30
        end

        todoContainer:SetHeight(math.abs(yOffset) + 50)
    end

    parent.RefreshZonesList = function()
        if scrollChild then
            scrollChild._onewowZebraSeq = nil
        end
        for _, ctrl in pairs(sectionReorders) do
            ctrl:Cancel()
        end
        for _, item in ipairs(zoneListItems) do
            item:Hide()
        end
        wipe(zoneListItems)
        wipe(sectionRowFrames)
        wipe(sectionDataBags)

        if not ns.Zones then return end

        RefreshCatOpts()
        RefreshStorageOpts()

        local allZones = ns.Zones:GetAllZones()
        local filtered = {}
        for noteId, data in pairs(allZones) do
            if type(data) == "table" then
                local title = ns.Zones:FormatTitleFromData(data)
                local passCategory = (categoryFilter == "All") or (data.category == categoryFilter)
                local passStorage  = (storageFilter == "All") or (data.storage == storageFilter)
                local needle = searchFilter:lower()
                local passSearch = (searchFilter == "")
                    or title:lower():find(needle, 1, true)
                    or (data.zone and data.zone:lower():find(needle, 1, true))
                    or (data.subzone and data.subzone ~= "" and data.subzone:lower():find(needle, 1, true))
                if passCategory and passStorage and passSearch then
                    filtered[#filtered + 1] = { name = noteId, title = title, data = data }
                end
            end
        end

        local czText = GetZoneText() or ""
        local czSub  = GetSubZoneText() or ""
        if czSub == czText then czSub = "" end
        local function isCurrentZoneNote(zone)
            return ns.Zones:NoteMatchesLocation(zone.data, czText, czSub)
        end

        local currentZones = {}
        local favorites = {}
        local regular   = {}
        for _, zone in ipairs(filtered) do
            if isCurrentZoneNote(zone) then
                currentZones[#currentZones + 1] = zone
            elseif zone.data.favorite then
                favorites[#favorites + 1] = zone
            else
                regular[#regular + 1] = zone
            end
        end

        local function sortZones(a, b)
            local nameA = a.title or a.name or ""
            local nameB = b.title or b.name or ""
            if currentSort.by == "category" then
                local ca = a.data.category or ""
                local cb = b.data.category or ""
                if ca == cb then return nameA < nameB end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "color" then
                local ca = a.data.pinColor or ""
                local cb = b.data.pinColor or ""
                if ca == cb then return nameA < nameB end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "modified" then
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            elseif currentSort.by == "custom" then
                local sa = a.data.sortOrder or 0
                local sb = b.data.sortOrder or 0
                if sa == sb then return nameA < nameB end
                if currentSort.ascending then return sa < sb else return sa > sb end
            else
                if currentSort.ascending then return nameA < nameB else return nameA > nameB end
            end
        end
        table.sort(currentZones, sortZones)
        table.sort(favorites, sortZones)
        table.sort(regular,   sortZones)

        local function CreateSectionHeader(title, yOfs, count)
            local section = OneWoW_GUI:CreateSectionHeader(scrollChild, {
                title = title,
                yOffset = yOfs,
                rightText = ns.UI.FormatSectionCount(count),
            })
            table.insert(zoneListItems, section)
            return section
        end

        local function BuildZoneRow(zone, yOfs, sectionKey)
            local resolvedColor = ns.Config:GetResolvedColorConfig(zone.data.pinColor)
            local bg = resolvedColor.background

            local rowOpts = {
                yOffset     = yOfs,
                barColor    = { bg[1], bg[2], bg[3] },
                icon        = ns.UI.ResolveNoteIcon(zone.data.iconKey) or "Interface\\Icons\\INV_Misc_Map_01",
                title       = zone.title or (ns.Zones and ns.Zones:FormatTitleFromData(zone.data)) or zone.name,
                storageText = zone.data.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"],
                selected    = (selectedZone == zone.name),
                shouldSuppressSelect = IsAnyZonesReorderActive,
                onSelect    = function()
                    selectedZone = zone.name
                    ShowEditor()
                    parent.RefreshZonesList()
                end,
                pin = {
                    active  = zone.data.pinEnabled and true or false,
                    tooltip = { title = L["TOOLTIP_ZONE_PIN"], desc = L["TOOLTIP_ZONE_PIN_DESC"] },
                    onToggle = function(state)
                        if not (ns.Zones and ns.ZonePins) then return end
                        local zoneData = ns.Zones:GetZone(zone.name)
                        if not zoneData then return end
                        if state then
                            zoneData.pinEnabled = true
                            ns.ZonePins:ShowZonePin(zone.name, zoneData)
                        else
                            ns.ZonePins:HideZonePin(zone.name)
                            zoneData.pinEnabled = false
                        end
                        ns.Zones:SaveZone(zone.name, zoneData)
                        if selectedZone == zone.name then ShowEditor() end
                    end,
                },
                alert = {
                    active  = zone.data.alertEnabled ~= false,
                    tooltip = { title = L["TOOLTIP_ZONE_ALERT"], desc = L["TOOLTIP_ZONE_ALERT_DESC"] },
                    onToggle = function(state)
                        if not ns.Zones then return end
                        local zoneData = ns.Zones:GetZone(zone.name)
                        if zoneData then
                            zoneData.alertEnabled = state
                            ns.Zones:SaveZone(zone.name, zoneData)
                        end
                    end,
                },
                fav = {
                    active  = zone.data.favorite and true or false,
                    tooltip = { title = L["TOOLTIP_ZONE_FAVORITE"], desc = L["TOOLTIP_ZONE_FAVORITE_DESC"] },
                    onToggle = function(state)
                        if not ns.Zones then return end
                        local zoneData = ns.Zones:GetZone(zone.name)
                        if zoneData then
                            zoneData.favorite = state
                            ns.Zones:SaveZone(zone.name, zoneData)
                            parent.RefreshZonesList()
                        end
                    end,
                },
                delete = {
                    tooltip = { title = L["TOOLTIP_ZONE_DELETE"], desc = L["TOOLTIP_ZONE_DELETE_DESC"] },
                    onClick = function()
                        local zId = zone.name
                        local title = zone.title
                            or (ns.Zones and ns.Zones:FormatTitleFromData(zone.data))
                            or zId
                        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_ZONE"] = {
                            text = string.format(L["ZONE_CONFIRM_DELETE"], title),
                            button1 = DELETE,
                            button2 = CANCEL,
                            OnAccept = function()
                                if ns.ZonePins then ns.ZonePins:DestroyZonePin(zId) end
                                if ns.Zones then ns.Zones:RemoveZone(zId) end
                                if selectedZone == zId then
                                    selectedZone = nil
                                    if emptyMessage then emptyMessage:Show() end
                                    if detailPanel.editorContent then
                                        for _, frame in pairs(detailPanel.editorContent) do
                                            if frame and frame.Hide then frame:Hide() end
                                        end
                                    end
                                end
                                parent.RefreshZonesList()
                            end,
                            timeout = 0, whileDead = true, hideOnEscape = true,
                        }
                        StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_ZONE")
                    end,
                },
            }

            local row = ns.UI.CreateNotesListRow(scrollChild, rowOpts)
            table.insert(zoneListItems, row)
            local frames = sectionRowFrames[sectionKey]
            frames[#frames + 1] = row
            GetOrCreateSectionReorder(sectionKey):Attach(row, #frames)
        end

        local function PaintSection(sectionKey, title, bag, yOffset)
            if #bag == 0 then
                return yOffset
            end
            sectionDataBags[sectionKey] = bag
            sectionRowFrames[sectionKey] = {}
            CreateSectionHeader(title, yOffset, #bag)
            yOffset = yOffset - 30
            for _, zone in ipairs(bag) do
                BuildZoneRow(zone, yOffset, sectionKey)
                yOffset = yOffset - ns.UI.LIST_ROW_SPACING
            end
            return yOffset
        end

        local yOffset = 0
        yOffset = PaintSection("current", L["ZONES_CURRENT_SECTION"], currentZones, yOffset)
        yOffset = PaintSection("favorites", FAVORITES, favorites, yOffset)
        yOffset = PaintSection("regular", L["TAB_ZONES"], regular, yOffset)

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ZONES"],
                #currentZones + #favorites + #regular))
        end
    end

    parent.RefreshZonesList()

    -- Keep the "Current Zone(s)" section live: re-list on zone change while the
    -- Zones tab is visible.
    if not parent._zoneWatch then
        parent._zoneWatch = CreateFrame("Frame")
        parent._zoneWatch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        parent._zoneWatch:RegisterEvent("ZONE_CHANGED")
        parent._zoneWatch:RegisterEvent("ZONE_CHANGED_INDOORS")
        parent._zoneWatch:SetScript("OnEvent", function()
            if not parent:IsVisible() or not parent.RefreshZonesList then return end
            C_Timer.After(0.2, function()
                if parent:IsVisible() then parent.RefreshZonesList() end
            end)
        end)
    end
end

local function MakeZoneLabel(parent, text, x, y)
    local lbl = OneWoW_GUI:CreateFS(parent, 12)
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return lbl
end

local function MakeZoneInput(parent, x, y, w)
    local box = OneWoW_GUI:CreateEditBox(parent, {
        width = w,
        height = 26,
        placeholderText = "",
    })
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetText("")
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end)
    return box
end

local function MakeZoneSlider(parent, _, x, y, w, minV, maxV, defV, fmt)
    local step = (fmt == "pct") and 0.05 or 1
    local fmtStr = (fmt == "pct") and "%d%%" or "%d"
    local container = OneWoW_GUI:CreateSlider(parent, {
        minVal = minV,
        maxVal = maxV,
        step = step,
        currentVal = defV,
        onChange = function() end,
        width = w,
        fmt = fmtStr,
    })
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return container, nil, container
end

function ns.UI.ShowManualZoneEntryDialog(refreshParent)
    local COL1_X = 10
    local COL2_X = 300
    local COL_W  = 260
    local ROW_H   = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesManualZoneEntry",
        title           = L["BUTTON_ADD_CURRENT_ZONE"],
        width           = 580,
        height          = 640,
        destroyOnClose  = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"],
                onClick = function(dlg)
                    local zone = dlg._zoneInput and dlg._zoneInput:GetText() or ""
                    local subzone = dlg._subzoneInput and dlg._subzoneInput:GetText() or ""
                    if zone == "" then
                        print("|cFFFFD100OneWoW - Zones:|r " .. (L["ZONE_ERROR_NAME_REQUIRED"]))
                        return
                    end
                    if subzone == zone then subzone = "" end

                    local existingId = ns.Zones and ns.Zones:FindIdByParts(zone, subzone)
                    if existingId then
                        local title = ns.Zones:FormatTitle(zone, subzone)
                        print("|cFFFFD100OneWoW - Zones:|r " .. string.format(L["MSG_ZONE_EXISTS"], title))
                        return
                    end

                    local cat        = dlg._catDD      and dlg._catDD:GetValue()      or "General"
                    local store      = dlg._storeDD    and dlg._storeDD:GetValue()    or "account"
                    local pinColor   = dlg._colorDD    and dlg._colorDD:GetValue()    or "hunter"
                    local fontCol    = dlg._fontColDD  and dlg._fontColDD:GetValue()  or "match"
                    local fontFamily = dlg._fontFamily or nil
                    local fontSize   = dlg._fontSize   or 12
                    local opacity    = dlg._opacity    or 0.9

                    local noteContent = dlg._noteEditBox and dlg._noteEditBox:GetText() or ""

                    local mapID = dlg._validatedMapID
                    if ns.Zones then
                        local noteId = ns.Zones:AddZone({
                            zone = zone,
                            subzone = subzone,
                            content = noteContent, category = cat, storage = store,
                            pinColor = pinColor, fontColor = fontCol,
                            fontFamily = fontFamily,
                            fontSize = fontSize, opacity = opacity,
                            mapID = mapID,
                        })
                        dlg:Hide()
                        if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
                        if refreshParent and refreshParent.SelectZone then refreshParent.SelectZone(noteId) end
                    end
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    MakeZoneLabel(content, ZONE_COLON, COL1_X, yPos)
    dialog._zoneInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    dialog._zoneInput:SetAutoFocus(true)

    MakeZoneLabel(content, L["LABEL_SUBZONE"], COL2_X, yPos)
    dialog._subzoneInput = MakeZoneInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_MAP_ID_OPTIONAL"], COL1_X, yPos)
    local mapIDInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, 120)
    mapIDInput:SetNumeric(true)
    dialog._validatedMapID = nil

    local validateBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["ITEM_VALIDATE"], height = 26, minWidth = 70 })
    validateBtn:SetPoint("LEFT", mapIDInput, "RIGHT", 6, 0)

    local validationFS = OneWoW_GUI:CreateFS(content, 10)
    validationFS:SetPoint("LEFT", validateBtn, "RIGHT", 8, 0)
    validationFS:SetText(L["ZONE_VALIDATE_HINT"])
    validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    validateBtn:SetScript("OnClick", function()
        local mapID = tonumber(mapIDInput:GetText())
        if not mapID or mapID <= 0 then
            validationFS:SetText(L["ZONE_INVALID_MAP_ID"])
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            dialog._validatedMapID = nil
            return
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then
            validationFS:SetText(mapInfo.name)
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            dialog._validatedMapID = mapID
            -- Prefill zone from map name when empty; never overwrite subzone.
            if dialog._zoneInput and (dialog._zoneInput:GetText() or "") == "" then
                dialog._zoneInput:SetText(mapInfo.name)
            end
        else
            validationFS:SetText(L["ZONE_MAP_NOT_FOUND"])
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            dialog._validatedMapID = nil
        end
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.Zones then
        for _, c in ipairs(ns.Zones:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog._catDD = catDD

    MakeZoneLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_COLOR"], COL1_X, yPos)
    local colorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    colorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local colorOpts = {}
    for key, colorData in pairs(ns.Config.PIN_COLORS) do
        colorOpts[#colorOpts + 1] = {text = colorData.name, value = key}
    end
    table.sort(colorOpts, function(a, b) return a.text < b.text end)
    colorDD:SetOptions(colorOpts)
    colorDD:SetSelected("hunter")
    dialog._colorDD = colorDD

    MakeZoneLabel(content, L["LABEL_FONT_COLOR"], COL2_X, yPos)
    local fontColDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    fontColDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontColDD:SetOptions({
        {text = "OneWoW Sync",                value = "sync"},
        {text = L["FONT_COLOR_MATCHING"],    value = "match"},
        {text = L["FONT_COLOR_WHITE"],      value = "white"},
        {text = L["FONT_COLOR_BLACK"],      value = "black"},
    })
    fontColDD:SetSelected("match")
    dialog._fontColDD = fontColDD
    yPos = yPos - ROW_H

    MakeZoneLabel(content, FONT_SIZE, COL1_X, yPos)
    dialog._fontSize = 12
    local fontSizeSlider, fontSizeTxt, fontSizeContainer = MakeZoneSlider(content, "OneWoW_ZoneAddFontSize", COL1_X, yPos - LBL_GAP, COL_W, 10, 20, 12, "int")
    if fontSizeContainer then
        local sliderChild = select(1, fontSizeContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(_, value)
                local val = math.floor(value + 0.5)
                dialog._fontSize = val
            end)
        end
    elseif fontSizeSlider.SetScript then
        fontSizeSlider:SetScript("OnValueChanged", function(_, value)
            local val = math.floor(value + 0.5)
            if fontSizeTxt then fontSizeTxt:SetText(tostring(val)) end
            dialog._fontSize = val
        end)
    end

    MakeZoneLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    dialog._fontFamily = nil
    local addPreviewEditBox = nil
    local addFontOpts = ns.Config:GetFontOptions()
    local addFontDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    addFontDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    addFontDD:SetOptions(addFontOpts)
    addFontDD:SetSelected("default")
    addFontDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        dialog._fontFamily = fontValue
        if addPreviewEditBox then
            local fp = ns.Config:ResolveFontPath(fontValue)
            addPreviewEditBox:SetFont(fp, dialog._fontSize or 12, dialog._fontOutline or "")
        end
    end
    dialog._fontFamilyDD = addFontDD
    yPos = yPos - ROW_H

    MakeZoneLabel(content, "Font Outline", COL2_X, yPos)
    dialog._fontOutline = ""
    local addOutlineDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    addOutlineDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    addOutlineDD:SetOptions({
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
    })
    addOutlineDD:SetSelected("")
    addOutlineDD.onSelect = function(value)
        dialog._fontOutline = value
        if addPreviewEditBox then
            local fp = ns.Config:ResolveFontPath(dialog._fontFamily)
            addPreviewEditBox:SetFont(fp, dialog._fontSize or 12, value)
        end
    end
    dialog._outlineDD = addOutlineDD

    MakeZoneLabel(content, OPACITY, COL1_X, yPos)
    dialog._opacity = 0.9
    local opacitySlider, opacityTxt, opacityContainer = MakeZoneSlider(content, "OneWoW_ZoneAddOpacity", COL1_X, yPos - LBL_GAP, COL_W, 0.5, 1.0, 0.9, "pct")
    if opacityContainer then
        local sliderChild = select(1, opacityContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(_, value)
                dialog._opacity = value
            end)
        end
    elseif opacitySlider.SetScript then
        opacitySlider:SetScript("OnValueChanged", function(_, value)
            local val = math.floor(value * 100 + 0.5)
            if opacityTxt then opacityTxt:SetText(val .. "%") end
            dialog._opacity = value
        end)
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_CONTENT"], COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    noteBg:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    noteBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    noteBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local noteScroll, noteEditBox = OneWoW_GUI:CreateScrollEditBox(noteBg, {
        font = ns.Config:ResolveFontPath(dialog._fontFamily),
        fontSize = dialog._fontSize or 12,
        fontFlags = dialog._fontOutline or "",
    })
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)
    noteEditBox._skipGlobalFont = true
    addPreviewEditBox = noteEditBox
    dialog._noteEditBox = noteEditBox

    dialog:Show()
end

function ns.UI.ShowZonePropertiesDialog(noteId, refreshParent)
    if not noteId or not ns.Zones then return end
    local zoneData = ns.Zones:GetZone(noteId)
    if not zoneData then return end

    local COL1_X  = 10
    local COL2_X  = 300
    local COL_W   = 260
    local ROW_H   = 50
    local LBL_GAP = 18

    local title = ns.Zones:FormatTitleFromData(zoneData)
    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesZoneProperties",
        title           = (L["DIALOG_ZONE_PROPERTIES"]) .. ": " .. title,
        width           = 580,
        height          = 600,
        destroyOnClose  = true,
        buttons = {
            { text = CLOSE, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    local function SaveField(field, value)
        local d = ns.Zones:GetZone(noteId)
        if d then
            d[field] = value
            ns.Zones:SaveZone(noteId, d)
        end
        if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
    end

    local function RefreshEditor()
        if refreshParent and refreshParent.SelectZone then
            refreshParent.SelectZone(noteId)
        end
        if ns.ZonePins and ns.ZonePins.RefreshZonePinColors then
            ns.ZonePins:RefreshZonePinColors(noteId)
        end
    end

    MakeZoneLabel(content, ZONE_COLON, COL1_X, yPos)
    local zoneInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, COL_W)
    zoneInput:SetText(zoneData.zone or "")
    zoneInput:SetScript("OnEnterPressed", function(self)
        local newZone = self:GetText() or ""
        if newZone ~= "" then
            SaveField("zone", newZone)
            RefreshEditor()
        end
        self:ClearFocus()
    end)

    MakeZoneLabel(content, L["LABEL_SUBZONE"], COL2_X, yPos)
    local subzoneInput = MakeZoneInput(content, COL2_X, yPos - LBL_GAP, COL_W)
    subzoneInput:SetText(zoneData.subzone or "")
    subzoneInput:SetScript("OnEnterPressed", function(self)
        local newSub = self:GetText() or ""
        SaveField("subzone", newSub)
        RefreshEditor()
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_MAP_ID_OPTIONAL"], COL1_X, yPos)
    local mapIDInput = MakeZoneInput(content, COL1_X, yPos - LBL_GAP, 120)
    mapIDInput:SetNumeric(true)
    mapIDInput:SetText(zoneData.mapID and tostring(zoneData.mapID) or "")

    local validateBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["ITEM_VALIDATE"], height = 26, minWidth = 70 })
    validateBtn:SetPoint("LEFT", mapIDInput, "RIGHT", 6, 0)

    local validationFS = OneWoW_GUI:CreateFS(content, 10)
    validationFS:SetPoint("LEFT", validateBtn, "RIGHT", 8, 0)
    if zoneData.mapID then
        local mapInfo = C_Map.GetMapInfo(zoneData.mapID)
        if mapInfo then
            validationFS:SetText(mapInfo.name)
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            validationFS:SetText(L["ZONE_MAP_NOT_FOUND"])
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
    else
        validationFS:SetText(L["ZONE_VALIDATE_HINT"])
        validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    validateBtn:SetScript("OnClick", function()
        local mapID = tonumber(mapIDInput:GetText())
        if not mapID or mapID <= 0 then
            validationFS:SetText(L["ZONE_INVALID_MAP_ID"])
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            return
        end
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then
            validationFS:SetText(mapInfo.name)
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            SaveField("mapID", mapID)
            RefreshEditor()
        else
            validationFS:SetText(L["ZONE_MAP_NOT_FOUND"])
            validationFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
    end)
    yPos = yPos - ROW_H

    MakeZoneLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.Zones then
        for _, c in ipairs(ns.Zones:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(zoneData.category or "General")
    catDD.onSelect = function(value) SaveField("category", value) end

    MakeZoneLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected(zoneData.storage or "account")
    storeDD.onSelect = function(value)
        local d = ns.Zones:GetZone(noteId)
        if d then d.storage = value ns.Zones:SaveZone(noteId, d) end
        if refreshParent and refreshParent.RefreshZonesList then refreshParent.RefreshZonesList() end
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_NOTE_COLOR"], COL1_X, yPos)
    local colorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    colorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local colorOpts = {}
    for key, colorData in pairs(ns.Config.PIN_COLORS) do
        colorOpts[#colorOpts + 1] = {text = colorData.name, value = key}
    end
    table.sort(colorOpts, function(a, b) return a.text < b.text end)
    colorDD:SetOptions(colorOpts)
    colorDD:SetSelected(zoneData.pinColor or "hunter")
    colorDD.onSelect = function(value)
        SaveField("pinColor", value)
        RefreshEditor()
    end

    MakeZoneLabel(content, L["LABEL_FONT_COLOR"], COL2_X, yPos)
    local fontColorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    fontColorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontColorDD:SetOptions({
        {text = "OneWoW Sync",                value = "sync"},
        {text = L["FONT_COLOR_MATCHING"],    value = "match"},
        {text = L["FONT_COLOR_WHITE"],      value = "white"},
        {text = L["FONT_COLOR_BLACK"],      value = "black"},
    })
    fontColorDD:SetSelected(zoneData.fontColor or "match")
    fontColorDD.onSelect = function(value)
        SaveField("fontColor", value)
        RefreshEditor()
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, FONT_SIZE, COL1_X, yPos)
    local propFontSizeSlider, propFontSizeTxt, propFontSizeContainer = MakeZoneSlider(content, "OneWoW_ZonePropFontSize", COL1_X, yPos - LBL_GAP, COL_W, 10, 20, zoneData.fontSize or 12, "int")
    if propFontSizeContainer then
        local sliderChild = select(1, propFontSizeContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(_, value)
                local val = math.floor(value + 0.5)
                SaveField("fontSize", val)
                RefreshEditor()
            end)
        end
    elseif propFontSizeSlider.SetScript then
        propFontSizeSlider:SetScript("OnValueChanged", function(_, value)
            local val = math.floor(value + 0.5)
            if propFontSizeTxt then propFontSizeTxt:SetText(tostring(val)) end
            SaveField("fontSize", val)
            RefreshEditor()
        end)
    end

    MakeZoneLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    local propPreviewEditBox = nil
    local propFontOpts = ns.Config:GetFontOptions()
    local propFontDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    propFontDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    propFontDD:SetOptions(propFontOpts)
    propFontDD:SetSelected(zoneData.fontFamily or "default")
    propFontDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        SaveField("fontFamily", fontValue)
        RefreshEditor()
        if propPreviewEditBox then
            local fp = ns.Config:ResolveFontPath(fontValue)
            local d = ns.Zones:GetZone(noteId)
            propPreviewEditBox:SetFont(fp, d and d.fontSize or 12, d and d.fontOutline or "")
        end
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, "Font Outline", COL2_X, yPos)
    local propOutlineDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    propOutlineDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    propOutlineDD:SetOptions({
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
    })
    propOutlineDD:SetSelected(zoneData.fontOutline or "")
    propOutlineDD.onSelect = function(value)
        SaveField("fontOutline", value)
        RefreshEditor()
        if propPreviewEditBox then
            local d = ns.Zones:GetZone(noteId)
            local fp = ns.Config:ResolveFontPath(d and d.fontFamily)
            propPreviewEditBox:SetFont(fp, d and d.fontSize or 12, value)
        end
    end

    MakeZoneLabel(content, OPACITY, COL1_X, yPos)
    local propOpacitySlider, propOpacityTxt, propOpacityContainer = MakeZoneSlider(content, "OneWoW_ZonePropOpacity", COL1_X, yPos - LBL_GAP, COL_W, 0.5, 1.0, zoneData.opacity or 0.9, "pct")
    if propOpacityContainer then
        local sliderChild = select(1, propOpacityContainer:GetChildren())
        if sliderChild then
            sliderChild:SetScript("OnValueChanged", function(_, value)
                SaveField("opacity", value)
                RefreshEditor()
            end)
        end
    elseif propOpacitySlider.SetScript then
        propOpacitySlider:SetScript("OnValueChanged", function(_, value)
            local val = math.floor(value * 100 + 0.5)
            if propOpacityTxt then propOpacityTxt:SetText(val .. "%") end
            SaveField("opacity", value)
            RefreshEditor()
        end)
    end
    yPos = yPos - ROW_H

    MakeZoneLabel(content, L["LABEL_ICON"], COL1_X, yPos)
    local iconPicker = ns.UI.CreateIconPicker(content, {
        selectedKey = zoneData.iconKey or "map",
        onSelect = function(key) SaveField("iconKey", key) end,
    })
    iconPicker:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    yPos = yPos - LBL_GAP - iconPicker:GetHeight() - 10

    MakeZoneLabel(content, L["LABEL_NOTE_PREVIEW"], COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    noteBg:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    noteBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    noteBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local noteScroll, noteEditBox = OneWoW_GUI:CreateScrollEditBox(noteBg, {
        font = ns.Config:ResolveFontPath(zoneData.fontFamily),
        fontSize = zoneData.fontSize or 12,
        fontFlags = zoneData.fontOutline or "",
    })
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)
    noteEditBox:SetText(zoneData.content or "")
    noteEditBox._skipGlobalFont = true
    propPreviewEditBox = noteEditBox
    noteEditBox:EnableMouse(false)

    dialog:Show()
end

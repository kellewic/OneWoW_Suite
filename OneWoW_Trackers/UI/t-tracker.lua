local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location

ns.UI = ns.UI or {}

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local ipairs, format, tinsert, wipe = ipairs, format, tinsert, wipe

-- Tracker steps store coordinates as 0-100, so the waypoint call declares that
-- rather than letting Location guess from the magnitude.
local PERCENT_COORDS = { format = "percent" }

local LIST_TYPE_ICONS = {
    guide     = "Interface\\Icons\\INV_Misc_Book_09",
    daily     = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    weekly    = "Interface\\Icons\\Achievement_General_100kQuests",
    todo      = "Interface\\Icons\\INV_Misc_Note_01",
    repeating = "Interface\\Icons\\Spell_Nature_TimeStop",
    farmvalue = "Interface\\Icons\\INV_Misc_Coin_01",
}

local LIST_TYPE_COLORS = {
    guide     = { 0.4, 0.8, 1.0 },
    daily     = { 1.0, 0.82, 0.0 },
    weekly    = { 0.6, 0.4, 1.0 },
    todo      = { 0.8, 0.8, 0.8 },
    repeating = { 0.4, 1.0, 0.6 },
    farmvalue = { 1.0, 0.84, 0.0 },
}

function ns.UI.CreateTrackerTab(parent)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    local TP = ns.TrackerPresets

    local selectedListID = nil
    local filterType = "all"
    local filterCategory = "All"
    local searchFilter = ""
    local hideCompleted = false
    local visibleLists = {}
    local listAPI
    local detailRows = {}
    local detailProgressBar
    local ClearDetail

    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP = ns.Constants.GUI.PANEL_GAP
    local HDR_H = 86
    local DD_W = math.floor((LEFT_W - 16 - 6) / 2)

    local leftHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    leftHeader:ClearAllPoints()
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)

    local rightHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    rightHeader:ClearAllPoints()
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, {
        text = L["CLEAR"],
        height = 26,
        minWidth = 34,
    })
    clearBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
        height = 26,
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            searchFilter = text or ""
            if parent.RefreshList then
                parent.RefreshList()
            end
        end,
    })
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    local typeDropdown, typeText = OneWoW_GUI:CreateDropdown(leftHeader, {
        width = DD_W,
        height = 26,
        text = L["TRACKER_ALL_TYPES"],
    })
    typeDropdown:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -38)

    OneWoW_GUI:AttachFilterMenu(typeDropdown, {
        buildItems = function()
            local items = {
                { text = L["TRACKER_ALL_TYPES"], value = "all" },
            }
            local types = TD:GetListTypes()
            for _, lt in ipairs(types) do
                tinsert(items, { text = TE:GetListTypeDisplayName(lt), value = lt })
            end
            return items
        end,
        onSelect = function(value)
            filterType = value
            typeText:SetText(value == "all" and (L["TRACKER_ALL_TYPES"]) or TE:GetListTypeDisplayName(value))
            parent.RefreshList()
        end,
        getActiveValue = function() return filterType end,
    })

    local catDropdown, catText = OneWoW_GUI:CreateDropdown(leftHeader, {
        width = DD_W,
        height = 26,
        text = L["TRACKER_ALL_CATEGORIES"],
    })
    catDropdown:SetPoint("TOPLEFT", typeDropdown, "TOPRIGHT", 6, 0)

    OneWoW_GUI:AttachFilterMenu(catDropdown, {
        buildItems = function()
            local items = {
                { text = L["TRACKER_ALL_CATEGORIES"], value = "All" },
            }
            for _, opt in ipairs(TD:GetCategoryOptions()) do
                tinsert(items, { text = opt.text, value = opt.value })
            end
            return items
        end,
        onSelect = function(value)
            filterCategory = value
            catText:SetText(value == "All" and (L["TRACKER_ALL_CATEGORIES"]) or TD:GetCategoryDisplayName(value))
            parent.RefreshList()
        end,
        getActiveValue = function() return filterCategory end,
    })

    local hideCompletedCheck = OneWoW_GUI:CreateCheckbox(leftHeader, {
        label = L["TRACKER_HIDE_DONE"],
        onClick = function(myself)
            hideCompleted = myself:GetChecked()
            parent.RefreshList()
        end,
    })
    hideCompletedCheck:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -64)

    clearBtn:SetScript("OnClick", function()
        searchFilter = ""
        filterType = "all"
        filterCategory = "All"
        hideCompleted = false
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchBox:RestorePlaceholder()
        typeText:SetText(L["TRACKER_ALL_TYPES"])
        catText:SetText(L["TRACKER_ALL_CATEGORIES"])
        hideCompletedCheck:SetChecked(false)
        parent.RefreshList()
    end)

    local newBtn = OneWoW_GUI:CreateFitTextButton(rightHeader, {
        text = NEW,
        height = 26,
    })
    newBtn:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -8)

    local importBtn = OneWoW_GUI:CreateFitTextButton(rightHeader, {
        text = L["TRACKER_IMPORT"],
        height = 26,
    })
    importBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    local restoreBtn = OneWoW_GUI:CreateFitTextButton(rightHeader, {
        text = L["TRACKER_RESTORE"],
        height = 26,
    })
    restoreBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)

    local listPanel = OneWoW_GUI:CreateFrame(parent, {
        width    = LEFT_W,
        backdrop = BACKDROP_INNER_NO_INSETS,
        borderColor = "BORDER_SUBTLE",
    })
    listPanel:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    local listScrollFrame, listScrollChild = OneWoW_GUI:CreateScrollFrame(listPanel, {})
    listScrollFrame:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 6, -6)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -6, 4)

    local detailPanel = OneWoW_GUI:CreateFrame(parent, {
        backdrop = BACKDROP_INNER_NO_INSETS,
        borderColor = "BORDER_SUBTLE",
    })
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", GAP, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local detailTitle = OneWoW_GUI:CreateFS(detailPanel, 12)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetWordWrap(false)
    detailTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    detailTitle:Hide()

    local pinBtn = OneWoW_GUI:CreateFavoriteToggleButton(detailPanel, {
        size     = 18,
        atlasOn  = "friends-icon-pinned",
        atlasOff = "friends-icon-pinned-dis",
        favorite = false,
        onClick = function()
            local list = selectedListID and TD:GetList(selectedListID)
            if not list then return end
            if list.pinned then
                TE:DestroyPinnedWindow(list.id)
            else
                TE:CreatePinnedWindow(list.id)
            end
            parent.RefreshList()
            parent.ShowDetail(list.id)
        end,
    })
    pinBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -7)
    pinBtn:Hide()
    local function RefreshPinIcon(pinned)
        pinBtn:SetFavorite(pinned and true or false)
    end
    pinBtn:SetScript("OnEnter", function(myself)
        local list = selectedListID and TD:GetList(selectedListID)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText((list and list.pinned) and L["TRACKER_UNPIN"] or L["TRACKER_PIN"], 1, 1, 1)
        GameTooltip:Show()
    end)
    pinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local actionBar = OneWoW_GUI:CreateLayoutFrame(detailPanel, { height = 28 })
    actionBar:Hide()
    local actionBarButtons = {}

    local hideStepsCheck = OneWoW_GUI:CreateCheckbox(actionBar, {
        label = L["TRACKER_PIN_HIDE_COMPLETED"],
        labelSide = "left",
        onClick = function(myself)
            local list = selectedListID and TD:GetList(selectedListID)
            if not list then return end
            list.pinnedHideCompleted = myself:GetChecked() and true or false
            parent.ShowDetail(list.id)
            TE:RefreshAllPinnedWindows()
        end,
    })
    hideStepsCheck:SetPoint("RIGHT", actionBar, "RIGHT", -2, 0)
    hideStepsCheck:Hide()
    local function HideStepsTooltip(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        GameTooltip:SetText(L["TRACKER_PIN_HIDE_COMPLETED"], 1, 1, 1)
        GameTooltip:AddLine(L["TRACKER_PIN_HIDE_COMPLETED_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    hideStepsCheck:SetScript("OnEnter", HideStepsTooltip)
    hideStepsCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hideStepsCheck.label:SetScript("OnEnter", HideStepsTooltip)
    hideStepsCheck.label:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local detailScrollFrame, detailScrollChild = OneWoW_GUI:CreateScrollFrame(detailPanel, {})
    local function LayoutDetailScroll()
        detailScrollFrame:ClearAllPoints()
        -- Pin/title row plus the action strip below it (~62px). Farm value
        -- still uses both rows; it only hides Hide completed on the strip.
        if pinBtn:IsShown() then
            detailScrollFrame:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 6, -62)
            actionBar:Show()
        else
            detailScrollFrame:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 6, -6)
            actionBar:Hide()
        end
        detailScrollFrame:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -6, 4)
        local aboveScroll = (detailScrollFrame:GetFrameLevel() or 0) + 5
        pinBtn:SetFrameLevel(aboveScroll)
        actionBar:SetFrameLevel(aboveScroll)
        actionBar:ClearAllPoints()
        actionBar:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 6, -32)
        actionBar:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -6, -32)
        detailTitle:ClearAllPoints()
        detailTitle:SetPoint("LEFT", pinBtn, "RIGHT", 6, 0)
        detailTitle:SetPoint("RIGHT", detailPanel, "RIGHT", -8, 0)
    end
    LayoutDetailScroll()

    local SCROLL_GUTTER = OneWoW_GUI.Constants.GUI.SCROLLBAR_CONTENT_GUTTER or 24
    local layingOutDetail = false
    local lastDetailLayoutW = 0
    local pendingDetailLayout = false
    -- Wrap width must be SetWidth'd; LEFT+RIGHT anchors are not laid out until
    -- a later size pass (resize grabber), so GetStringHeight stays one line.
    local function DetailContentWidth()
        local w = detailScrollFrame:GetWidth() or 0
        if w < 50 then
            w = detailPanel:GetWidth() or 0
        end
        if w >= 50 then
            return math.max(1, w - SCROLL_GUTTER)
        end
        return detailScrollChild:GetWidth() or 0
    end

    local emptyLabel = OneWoW_GUI:CreateFS(detailPanel, 12)
    emptyLabel:SetPoint("CENTER", detailPanel, "CENTER", 0, 0)
    emptyLabel:SetText(L["TRACKER_SELECT"])
    emptyLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local LIST_ROW_HEIGHT = 56
    local LIST_ROW_PAD = 8

    local function CreateListRow(content)
        local row = OneWoW_GUI:CreateListRowBasic(content, {
            height = LIST_ROW_HEIGHT,
            favoriteToggle = {
                size = 18,
                isFavorite = false,
                tooltipTitle = L["TRACKER_FAV"],
                tooltipText = L["TRACKER_FAV_TT"],
                onChange = function(isFav)
                    local id = row._listID
                    if not id then return end
                    TD:UpdateList(id, { favorite = isFav })
                    parent.RefreshList()
                end,
            },
        })

        local typeIcon = row:CreateTexture(nil, "ARTWORK")
        typeIcon:SetSize(24, 24)
        typeIcon:SetPoint("TOPLEFT", row, "TOPLEFT", LIST_ROW_PAD, -LIST_ROW_PAD)
        row._typeIcon = typeIcon

        local favAnchor = row.favoriteBtn
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", typeIcon, "TOPRIGHT", LIST_ROW_PAD, 0)
        if favAnchor then
            row.label:SetPoint("RIGHT", favAnchor, "LEFT", -LIST_ROW_PAD, 0)
            favAnchor:SetFrameLevel((row:GetFrameLevel() or 0) + 15)
        else
            row.label:SetPoint("RIGHT", row, "RIGHT", -LIST_ROW_PAD, 0)
        end
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("TOP")
        row.label:SetWordWrap(false)

        local metaLabel = OneWoW_GUI:CreateFS(row, 10)
        metaLabel:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        if favAnchor then
            metaLabel:SetPoint("RIGHT", favAnchor, "LEFT", -LIST_ROW_PAD, 0)
        else
            metaLabel:SetPoint("RIGHT", row, "RIGHT", -LIST_ROW_PAD, 0)
        end
        metaLabel:SetJustifyH("LEFT")
        metaLabel:SetWordWrap(false)
        metaLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row._meta = metaLabel

        local progressLabel = OneWoW_GUI:CreateFS(row, 10)
        progressLabel:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -LIST_ROW_PAD, LIST_ROW_PAD)
        progressLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row._progressLabel = progressLabel

        local progressBar = OneWoW_GUI:CreateProgressBar(row, {
            height = 3,
            min = 0,
            max = 1,
            value = 0,
        })
        progressBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", LIST_ROW_PAD, LIST_ROW_PAD)
        progressBar:SetPoint("RIGHT", progressLabel, "LEFT", -LIST_ROW_PAD, 0)
        progressBar._text:Hide()
        row._progressBar = progressBar

        row:HookScript("OnEnter", function(myself)
            if not myself._titleTrunc and not myself._metaTrunc then return end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(myself._titlePlain or L["TRACKER_UNTITLED"], 1, 1, 1)
            if myself._metaTrunc and myself._metaPlain then
                GameTooltip:AddLine(myself._metaPlain, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        row:HookScript("OnLeave", GameTooltip_Hide)

        return row
    end

    local function BindListRow(row, _, listData, rowState)
        row._listID = listData.id
        row._titlePlain = listData.title or L["TRACKER_UNTITLED"]
        row._typeIcon:SetTexture(LIST_TYPE_ICONS[listData.listType] or LIST_TYPE_ICONS.todo)
        row.label:SetText(row._titlePlain)

        local typeColor = LIST_TYPE_COLORS[listData.listType] or { 0.7, 0.7, 0.7 }
        local typeName = TE:GetListTypeDisplayName(listData.listType)
        local category = TD:GetCategoryDisplayName(listData.category)
        local author = listData.author
        local metaRest = category
        if author and author ~= "" then
            metaRest = category .. " | " .. author
        end
        row._metaPlain = typeName .. " | " .. metaRest
        row._meta:SetText(format("|cFF%02x%02x%02x%s|r | %s",
            typeColor[1] * 255, typeColor[2] * 255, typeColor[3] * 255,
            typeName, metaRest))

        if row.favoriteBtn then
            row.favoriteBtn:SetFavorite(listData.favorite == true)
        end

        local done, total = TD:GetListCompletion(listData.id)
        if total > 0 then
            row._progressLabel:SetText(format("%d/%d", done, total))
            row._progressLabel:Show()
            row._progressBar:Show()
            row._progressBar:UpdateProgress(done, total)
            row._progressBar._text:Hide()
        else
            row._progressLabel:Hide()
            row._progressBar:Hide()
        end

        row:SetActive(rowState and rowState.selected)
        row._titleTrunc = row.label:IsTruncated()
        row._metaTrunc = row._meta:IsTruncated()
    end

    listAPI = OneWoW_GUI:CreateVirtualizer(listPanel, {
        name = "OneWoWTrackersList",
        rowHeight = LIST_ROW_HEIGHT,
        numVisibleRows = 16,
        rowInset = 4,
        scrollFrame = listScrollFrame,
        content = listScrollChild,
        getCount = function()
            return #visibleLists
        end,
        getEntry = function(index)
            return visibleLists[index]
        end,
        onSelect = function(_, entry)
            if not entry or selectedListID == entry.id then return end
            selectedListID = entry.id
            parent.ShowDetail(entry.id)
        end,
        createRow = CreateListRow,
        bindRow = BindListRow,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })

    function parent.RefreshList()
        wipe(visibleLists)

        local lists = TD:GetSortedLists(
            filterType ~= "all" and filterType or nil,
            filterCategory ~= "All" and filterCategory or nil,
            searchFilter ~= "" and searchFilter or nil
        )

        if hideCompleted then
            for _, listData in ipairs(lists) do
                local skip = false
                if listData.listType ~= "farmvalue" then
                    local done, total = TD:GetListCompletion(listData.id)
                    skip = total > 0 and done >= total
                end
                if not skip then
                    tinsert(visibleLists, listData)
                end
            end
        else
            for _, listData in ipairs(lists) do
                tinsert(visibleLists, listData)
            end
        end

        if #visibleLists == 0 then
            if not listPanel.emptyText then
                listPanel.emptyText = OneWoW_GUI:CreateFS(listPanel, 12)
                listPanel.emptyText:SetPoint("CENTER", listPanel, "CENTER", 0, 0)
                listPanel.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                listPanel.emptyText:SetWidth(LEFT_W - 40)
                listPanel.emptyText:SetWordWrap(true)
            end
            listPanel.emptyText:SetText(L["TRACKER_EMPTY"])
            listPanel.emptyText:Show()
            selectedListID = nil
            TE:SetObservedList(nil)
            if ClearDetail then ClearDetail() end
            listAPI.Refresh()
            return
        end

        if listPanel.emptyText then
            listPanel.emptyText:Hide()
        end

        local selIdx
        for i, listData in ipairs(visibleLists) do
            if listData.id == selectedListID then
                selIdx = i
                break
            end
        end
        if not selIdx then
            selectedListID = visibleLists[1].id
            listAPI.SetSelectedIndex(1)
            if parent.ShowDetail then
                parent.ShowDetail(selectedListID)
            end
        elseif listAPI.GetSelectedIndex() ~= selIdx then
            listAPI.SetSelectedIndex(selIdx)
        else
            listAPI.Refresh()
        end
    end

    local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
    local ICON_BTN = OneWoW_GUI.Constants.GUI.ICON_BUTTON_SIZE
    local sectionReorderFrames = {}
    local stepReorderFrames = {}
    local sectionReorder, stepReorder

    local function ApplySectionReorderVisual(header, picked, hovered)
        if picked then
            header:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        elseif hovered then
            header:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            header:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    local function RestoreStepRowBorder(row)
        if row._trackerComplete then
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    local function AfterReorder()
        TE:RebuildIndices()
        parent.RefreshList()
        if selectedListID then
            parent.ShowDetail(selectedListID)
        end
        TE:RefreshAllPinnedWindows()
    end

    local function EnsureReorder()
        if sectionReorder then return end
        local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
        local dropColor = { r, g, b, 1 }
        local autoScroll = {
            getFrame = function() return detailScrollFrame end,
            edgeZone = 40,
            maxSpeed = 14,
            minSpeed = 2,
        }
        sectionReorder = OneWoW_GUI:CreateReorderDrag({
            getItems = function() return sectionReorderFrames end,
            dropIndicator = { thickness = 2, horizontalPadding = 4, color = dropColor },
            autoScroll = autoScroll,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local destIdx = insertBefore and toIdx or (toIdx + 1)
                if destIdx > fromIdx then destIdx = destIdx - 1 end
                if destIdx == fromIdx then return end
                local src = sectionReorderFrames[fromIdx]
                if not src or not src._trackerSectionKey then return end
                if TD:ReorderSection(selectedListID, src._trackerSectionKey, destIdx) then
                    AfterReorder()
                end
            end,
            onPickup = function(item)
                ApplySectionReorderVisual(item, true, false)
            end,
            onRestore = function(item)
                ApplySectionReorderVisual(item, false, false)
            end,
            onHover = function(item)
                ApplySectionReorderVisual(item, false, true)
            end,
            onUnhover = function(item)
                ApplySectionReorderVisual(item, false, false)
            end,
        })
        stepReorder = OneWoW_GUI:CreateReorderDrag({
            getItems = function() return stepReorderFrames end,
            dropIndicator = { thickness = 2, horizontalPadding = 6, color = dropColor },
            autoScroll = autoScroll,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local src = stepReorderFrames[fromIdx]
                local tgt = stepReorderFrames[toIdx]
                if not src or not tgt or src._trackerKind ~= "step" then return end
                if tgt == src then return end
                local destSection, destIdx
                if tgt._trackerKind == "header" then
                    destSection = tgt._trackerSectionKey
                    destIdx = 1
                else
                    destSection = tgt._trackerSectionKey
                    destIdx = insertBefore and tgt._trackerStepIndex or (tgt._trackerStepIndex + 1)
                end
                if TD:MoveStepToSection(selectedListID, src._trackerSectionKey, src._trackerStepKey, destSection, destIdx) then
                    AfterReorder()
                end
            end,
            onPickup = function(item)
                stepReorder:SetIndicatorVisible(true)
                item:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end,
            onRestore = function(item)
                RestoreStepRowBorder(item)
            end,
            onHover = function(target)
                if target._trackerKind == "header" then
                    stepReorder:SetIndicatorVisible(false)
                    target:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                else
                    stepReorder:SetIndicatorVisible(true)
                    target:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                end
            end,
            onUnhover = function(target)
                if target._trackerKind == "header" then
                    ApplySectionReorderVisual(target, false, false)
                else
                    RestoreStepRowBorder(target)
                end
            end,
        })
    end

    local function ReorderIsActive()
        return (sectionReorder and sectionReorder:IsActive())
            or (stepReorder and stepReorder:IsActive())
    end

    local function SetRowActionsShown(row, shown)
        if ReorderIsActive() then return end
        local btns = row._trackerActionBtns
        if not btns then return end
        for i = 1, #btns do
            btns[i]:SetShown(shown)
        end
    end

    local function ScheduleHideRowActions(row)
        C_Timer.After(0, function()
            if not row:IsShown() then return end
            if row:IsMouseOver() then return end
            SetRowActionsShown(row, false)
        end)
    end

    ClearDetail = function()
        if sectionReorder then sectionReorder:Cancel() end
        if stepReorder then stepReorder:Cancel() end
        wipe(sectionReorderFrames)
        wipe(stepReorderFrames)
        for _, row in ipairs(detailRows) do
            if row.Hide then row:Hide() end
        end
        wipe(detailRows)
        for _, btn in ipairs(actionBarButtons) do
            btn:Hide()
        end
        wipe(actionBarButtons)
        detailProgressBar = nil
        emptyLabel:Show()
        detailTitle:Hide()
        pinBtn:Hide()
        hideStepsCheck:Hide()
        actionBar:Hide()
        LayoutDetailScroll()
    end

    function parent.ShowDetail(listID)
        if layingOutDetail then return end
        layingOutDetail = true

        ClearDetail()
        EnsureReorder()

        local list = TD:GetList(listID)
        if not list then
            TE:SetObservedList(nil)
            layingOutDetail = false
            return
        end
        TE:SetObservedList(listID)

        if not list.pinned then
            TE:EvaluateList(listID)
        end

        emptyLabel:Hide()
        detailTitle:SetText(list.title or L["TRACKER_UNTITLED"])
        detailTitle:Show()
        RefreshPinIcon(list.pinned)
        pinBtn:Show()
        hideStepsCheck:SetChecked(list.pinnedHideCompleted and true or false)
        if list.listType ~= "farmvalue" then
            hideStepsCheck:Show()
        else
            hideStepsCheck:Hide()
        end
        LayoutDetailScroll()

        local iconGap = 4
        local prevAction
        local function PlaceListAction(btn)
            if prevAction then
                btn:SetPoint("LEFT", prevAction, "RIGHT", iconGap, 0)
            else
                btn:SetPoint("LEFT", actionBar, "LEFT", 2, 0)
            end
            prevAction = btn
            tinsert(actionBarButtons, btn)
            return btn
        end

        PlaceListAction(OneWoW_GUI:CreateIconButton(actionBar, {
            iconTexture = MEDIA .. "icon-gears.png",
            size = ICON_BTN,
            tooltipTitle = EDIT,
            onClick = function()
                ns.TrackerEditor:ShowListEditor(list.id, function()
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end)
            end,
        }))

        PlaceListAction(OneWoW_GUI:CreateIconButton(actionBar, {
            iconTexture = MEDIA .. "icon-flag.png",
            size = ICON_BTN,
            tooltipTitle = L["TRACKER_EXPORT"],
            onClick = function()
                ns.TrackerEditor:ShowExportDialog(list.id)
            end,
        }))

        PlaceListAction(OneWoW_GUI:CreateIconButton(actionBar, {
            atlas = "communities-icon-addgroupplus",
            size = ICON_BTN,
            tint = true,
            tooltipTitle = L["DUPLICATE"],
            onClick = function()
                local copy = TD:DuplicateList(list.id)
                if copy then
                    selectedListID = copy.id
                    parent.RefreshList()
                    parent.ShowDetail(copy.id)
                end
            end,
        }))

        if list.listType ~= "farmvalue" then
            PlaceListAction(OneWoW_GUI:CreateIconButton(actionBar, {
                atlas = "talents-button-undo",
                size = ICON_BTN,
                tooltipTitle = RESET,
                onClick = function()
                    TD:ResetProgress(list.id)
                    TE:FullScan()
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end,
            }))
        end

        PlaceListAction(OneWoW_GUI:CreateIconButton(actionBar, {
            iconTexture = MEDIA .. "icon-trash.png",
            size = ICON_BTN,
            tooltipTitle = DELETE,
            onClick = function()
                if list._bundledID then
                    TP:OnBundledDeleted(list._bundledID)
                end
                TE:DestroyPinnedWindow(list.id)
                TD:RemoveList(list.id)
                selectedListID = nil
                parent.RefreshList()
            end,
        }))

        if list.listType ~= "farmvalue" then
            PlaceListAction(OneWoW_GUI:CreateIconButton(actionBar, {
                iconTexture = MEDIA .. "icon-add.png",
                size = ICON_BTN,
                tooltipTitle = L["TRACKER_ADD_SECTION"],
                onClick = function()
                    ns.TrackerEditor:ShowSectionEditor(list.id, nil, function()
                        TE:RebuildIndices()
                        parent.RefreshList()
                        parent.ShowDetail(list.id)
                    end)
                end,
            }))
        end

        local yOffset = 0

        if list.description and list.description ~= "" then
            local descFrame = CreateFrame("Frame", nil, detailScrollChild)
            descFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            descFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            tinsert(detailRows, descFrame)

            local descText = OneWoW_GUI:CreateFS(descFrame, 12)
            descText:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -4)
            descText:SetWidth(math.max(50, DetailContentWidth() - 28))
            descText:SetJustifyH("LEFT")
            descText:SetWordWrap(true)
            descText:SetText(list.description)
            descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local descH = descText:GetStringHeight() + 12
            descFrame:SetHeight(descH)
            yOffset = yOffset - descH
        end

        if list.accountWide then
            local awFrame = CreateFrame("Frame", nil, detailScrollChild)
            awFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            awFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            tinsert(detailRows, awFrame)

            local awText = OneWoW_GUI:CreateFS(awFrame, 10)
            awText:SetPoint("TOPLEFT", awFrame, "TOPLEFT", 10, -2)
            awText:SetPoint("RIGHT", awFrame, "RIGHT", -10, 0)
            awText:SetJustifyH("LEFT")
            awText:SetWordWrap(true)
            awText:SetText(L["TRACKER_ACCOUNT_WIDE"])
            awText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local awH = math.max(16, awText:GetStringHeight() + 6)
            awFrame:SetHeight(awH)
            yOffset = yOffset - awH
        end

        if list.listType ~= "farmvalue" then
            local done, total = TD:GetListCompletion(list.id)
            local progFrame = CreateFrame("Frame", nil, detailScrollChild)
            progFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            progFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            progFrame:SetHeight(22)
            tinsert(detailRows, progFrame)

            local progressBar = OneWoW_GUI:CreateProgressBar(progFrame, {
                height = 14,
                min = 0,
                max = math.max(total, 1),
                value = done,
            })
            progressBar:SetPoint("TOPLEFT", progFrame, "TOPLEFT", 10, -4)
            progressBar:SetPoint("RIGHT", progFrame, "RIGHT", -10, 0)
            progressBar._text:SetText(total > 0 and format("%d / %d", done, total) or "")
            detailProgressBar = progressBar

            yOffset = yOffset - 26
        end

        -- Hub/editor shows every section and step so a master list stays
        -- editable. Faction / profession / event gates apply on the pin only.
        local hasVisibleSections = false
        if list.listType ~= "farmvalue" then
            for _, sec in ipairs(list.sections or {}) do
                if not list.pinnedHideCompleted or TE:HasIncompleteStep(list.id, sec) then
                    hasVisibleSections = true
                    break
                end
            end
        end
        if hasVisibleSections then
            local hintFrame = CreateFrame("Frame", nil, detailScrollChild)
            hintFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            hintFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            tinsert(detailRows, hintFrame)

            local hintText = OneWoW_GUI:CreateFS(hintFrame, 10)
            hintText:SetPoint("TOPLEFT", hintFrame, "TOPLEFT", 10, -2)
            hintText:SetWidth(math.max(50, DetailContentWidth() - 28))
            hintText:SetJustifyH("LEFT")
            hintText:SetWordWrap(true)
            hintText:SetText(L["TRACKER_HOVER_ACTIONS"])
            hintText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local hintH = hintText:GetStringHeight() + 8
            hintFrame:SetHeight(hintH)
            yOffset = yOffset - hintH

            local ruleFrame = OneWoW_GUI:CreateLayoutFrame(detailScrollChild, { height = 1 })
            ruleFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            ruleFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            tinsert(detailRows, ruleFrame)
            OneWoW_GUI:CreateDivider(ruleFrame, { yOffset = 0 })
            yOffset = yOffset - 10
        end

        if list.listType == "farmvalue" and ns.TrackerFarmValue then
            yOffset = ns.TrackerFarmValue:RenderDetailEditor(list, detailScrollChild, detailRows, yOffset, parent)
        end

        for _, sec in ipairs(list.sections) do
          if not list.pinnedHideCompleted or TE:HasIncompleteStep(list.id, sec) then
            yOffset = yOffset - 8

            local secHeader = CreateFrame("Button", nil, detailScrollChild, "BackdropTemplate")
            secHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            secHeader:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            secHeader:SetHeight(32)
            secHeader:SetBackdrop(BACKDROP_SIMPLE)
            secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            secHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailRows, secHeader)

            local accentLine = secHeader:CreateTexture(nil, "ARTWORK")
            accentLine:SetSize(3, 32)
            accentLine:SetPoint("TOPLEFT", secHeader, "TOPLEFT", 0, 0)
            accentLine:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local collapseIcon = secHeader:CreateTexture(nil, "ARTWORK")
            collapseIcon:SetSize(12, 12)
            collapseIcon:SetPoint("LEFT", accentLine, "RIGHT", 6, 0)
            collapseIcon:SetTexture(sec.collapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")

            local secLabel = OneWoW_GUI:CreateFS(secHeader, 12)
            secLabel:SetPoint("LEFT", collapseIcon, "RIGHT", 4, 0)
            secLabel:SetText(sec.label or L["TRACKER_SECTION_FALLBACK"])
            secLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local secDone, secTotal = TD:GetSectionCompletion(list.id, sec.key)

            local addStepBtn = OneWoW_GUI:CreateIconButton(secHeader, {
                iconTexture = MEDIA .. "icon-add.png",
                size = ICON_BTN,
                tooltipTitle = L["TRACKER_ADD_STEP"],
                onClick = function()
                    ns.TrackerEditor:ShowStepEditor(list.id, sec.key, nil, function()
                        TE:RebuildIndices()
                        parent.RefreshList()
                        parent.ShowDetail(list.id)
                    end)
                end,
            })
            local secCount = OneWoW_GUI:CreateFS(secHeader, 10)
            secCount:SetPoint("RIGHT", secHeader, "RIGHT", -8, 0)
            secCount:SetText(secTotal > 0 and format("%d/%d", secDone, secTotal) or "")
            secCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            secHeader._secCount = secCount
            addStepBtn:SetPoint("RIGHT", secCount, "LEFT", -4, 0)

            local secEditBtn = OneWoW_GUI:CreateIconButton(secHeader, {
                iconTexture = MEDIA .. "icon-gears.png",
                size = ICON_BTN,
                tooltipTitle = L["TRACKER_EDIT_SECTION"],
                onClick = function()
                    ns.TrackerEditor:ShowSectionEditor(list.id, sec.key, function()
                        TE:RebuildIndices()
                        parent.RefreshList()
                        parent.ShowDetail(list.id)
                    end)
                end,
            })
            secEditBtn:SetPoint("RIGHT", addStepBtn, "LEFT", -2, 0)

            local secDeleteBtn = OneWoW_GUI:CreateIconButton(secHeader, {
                iconTexture = MEDIA .. "icon-trash.png",
                size = ICON_BTN,
                tooltipTitle = DELETE,
                onClick = function()
                    TD:RemoveSection(list.id, sec.key)
                    TE:RebuildIndices()
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end,
            })
            secDeleteBtn:SetPoint("RIGHT", secEditBtn, "LEFT", -2, 0)
            addStepBtn:Hide()
            secEditBtn:Hide()
            secDeleteBtn:Hide()
            secHeader._trackerActionBtns = { addStepBtn, secEditBtn, secDeleteBtn }

            secLabel:SetPoint("RIGHT", secDeleteBtn, "LEFT", -6, 0)
            secLabel:SetJustifyH("LEFT")
            secLabel:SetWordWrap(false)

            secHeader:EnableMouse(true)
            secHeader:RegisterForClicks("LeftButtonUp")
            secHeader:SetScript("OnClick", function()
                if sectionReorder:ShouldSuppressClick() then return end
                sec.collapsed = not sec.collapsed
                parent.ShowDetail(list.id)
            end)
            secHeader:SetScript("OnEnter", function(self)
                SetRowActionsShown(self, true)
            end)
            secHeader:SetScript("OnLeave", function(self)
                ScheduleHideRowActions(self)
            end)

            secHeader._trackerKind = "header"
            secHeader._trackerSectionKey = sec.key
            tinsert(sectionReorderFrames, secHeader)
            tinsert(stepReorderFrames, secHeader)
            sectionReorder:Attach(secHeader)

            yOffset = yOffset - 36

          if not sec.collapsed then
            for stepIdx, step in ipairs(sec.steps or {}) do
              if not (list.pinnedHideCompleted and TD:IsStepComplete(list.id, sec.key, step.key)) then
                local sp = TD:GetStepProgress(list.id, sec.key, step.key)
                local rosterCompleters = step.rosterMode and TD:GetRosterCompleters(list.id, step.key) or nil
                local isComplete
                if step.rosterMode then
                    isComplete = TD:IsRosterCompleter(list.id, step.key, TD:GetCurrentCharKey())
                else
                    isComplete = sp.completed or false
                end

                local depsMet = TD:AreStepDependenciesMet(list.id, step)

                local stepRow = CreateFrame("Button", nil, detailScrollChild, "BackdropTemplate")
                stepRow:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yOffset)
                stepRow:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -10, yOffset)
                stepRow:SetBackdrop(BACKDROP_SIMPLE)
                tinsert(detailRows, stepRow)

                if isComplete then
                    stepRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    stepRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                elseif not depsMet then
                    stepRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    stepRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                else
                    stepRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    stepRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end

                stepRow._trackerKind = "step"
                stepRow._trackerSectionKey = sec.key
                stepRow._trackerStepKey = step.key
                stepRow._trackerStepIndex = stepIdx
                stepRow._trackerComplete = isComplete

                local stepEditBtn = OneWoW_GUI:CreateIconButton(stepRow, {
                    iconTexture = MEDIA .. "icon-gears.png",
                    size = ICON_BTN,
                    tooltipTitle = L["TRACKER_EDIT_STEP"],
                    onClick = function()
                        ns.TrackerEditor:ShowStepEditor(list.id, sec.key, step.key, function()
                            TE:RebuildIndices()
                            parent.RefreshList()
                            parent.ShowDetail(list.id)
                            TE:RefreshAllPinnedWindows()
                        end)
                    end,
                })
                local stepProgress = OneWoW_GUI:CreateFS(stepRow, 10)
                stepProgress:SetPoint("TOPRIGHT", stepRow, "TOPRIGHT", -4, -7)
                stepProgress:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                stepEditBtn:SetPoint("RIGHT", stepProgress, "LEFT", -4, 0)
                stepEditBtn:Hide()
                stepRow._trackerActionBtns = { stepEditBtn }

                local checkSize = 16
                local checkBtn
                if step.optional then
                    checkBtn = CreateFrame("Frame", nil, stepRow)
                    checkBtn:SetSize(checkSize, checkSize)
                    checkBtn:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 6, -7)
                    local infoTex = checkBtn:CreateTexture(nil, "ARTWORK")
                    infoTex:SetAllPoints()
                    infoTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")
                else
                    checkBtn = OneWoW_GUI:CreateCheckbox(stepRow, {})
                    checkBtn:SetSize(checkSize, checkSize)
                    checkBtn:ClearAllPoints()
                    checkBtn:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 6, -7)
                    checkBtn:SetChecked(isComplete)

                    if step.rosterMode then
                        checkBtn:SetScript("OnClick", function(myself)
                            if TD:IsRosterCompleter(list.id, step.key, TD:GetCurrentCharKey()) then
                                TD:RemoveRosterCompleter(list.id, step.key, TD:GetCurrentCharKey())
                            else
                                if not TE:TryUserComplete(list.id, sec.key, step.key) then
                                    myself:SetChecked(false)
                                    return
                                end
                                TD:RecordRosterCompletion(list.id, step.key)
                            end
                            parent.RefreshList()
                            parent.ShowDetail(list.id)
                            TE:RefreshAllPinnedWindows()
                        end)
                    elseif step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                        checkBtn:SetScript("OnClick", function(myself)
                            if not isComplete and not TE:TryUserComplete(list.id, sec.key, step.key) then
                                myself:SetChecked(false)
                                return
                            end
                            TD:ToggleStepComplete(list.id, sec.key, step.key)
                            parent.RefreshList()
                            parent.RefreshDetailProgress()
                            TE:RefreshAllPinnedWindows()
                        end)
                    else
                        checkBtn:EnableMouse(false)
                    end
                end

                local stepLabel = OneWoW_GUI:CreateFS(stepRow, 12)
                stepLabel:SetPoint("LEFT", checkBtn, "RIGHT", 6, 0)
                stepLabel:SetPoint("RIGHT", stepEditBtn, "LEFT", -6, 0)
                stepLabel:SetJustifyH("LEFT")
                stepLabel:SetWordWrap(false)
                stepLabel:SetText(step.label or L["TRACKER_STEP_FALLBACK"])
                stepRow._checkBtn = checkBtn
                stepRow._stepLabel = stepLabel
                stepRow._stepProgress = stepProgress
                stepRow._isOptional = step.optional and true or false
                stepRow._objChecks = {}

                if step.optional then
                    stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                elseif isComplete then
                    stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                elseif not depsMet then
                    stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end

                local progressStr = ns.TrackerEvaluators.FormatStepProgress(
                    step, sp, rosterCompleters and #rosterCompleters or nil)
                stepProgress:SetText(progressStr)

                local rowHeight = 30

                if step.description and step.description ~= "" then
                    local descFS = OneWoW_GUI:CreateFS(stepRow, 10)
                    descFS:SetPoint("TOPLEFT", stepLabel, "BOTTOMLEFT", 0, -2)
                    descFS:SetWidth(math.max(50, DetailContentWidth() - 128))
                    descFS:SetJustifyH("LEFT")
                    descFS:SetWordWrap(true)
                    descFS:SetText(step.description)
                    descFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    rowHeight = rowHeight + descFS:GetStringHeight() + 4
                end

                if step.objectives and #step.objectives > 0 then
                    local objY = -rowHeight
                    for _, obj in ipairs(step.objectives) do
                        local objComplete = TD:GetObjectiveProgress(list.id, sec.key, step.key, obj.key)

                        local objCheck = OneWoW_GUI:CreateCheckbox(stepRow, {})
                        objCheck:SetSize(14, 14)
                        objCheck:ClearAllPoints()
                        objCheck:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 30, objY)
                        objCheck:SetChecked(objComplete)

                        if obj.type == "manual" then
                            objCheck:SetScript("OnClick", function()
                                local nowComplete = TD:GetObjectiveProgress(list.id, sec.key, step.key, obj.key)
                                TD:SetObjectiveComplete(list.id, sec.key, step.key, obj.key, not nowComplete)
                                TE:EvaluateStep(list.id, sec.key, step)
                                parent.RefreshList()
                                parent.RefreshDetailProgress()
                                TE:RefreshAllPinnedWindows()
                            end)
                        else
                            objCheck:EnableMouse(false)
                        end

                        local objLabel = OneWoW_GUI:CreateFS(stepRow, 10)
                        objLabel:SetPoint("LEFT", objCheck, "RIGHT", 4, 0)
                        objLabel:SetWidth(math.max(50, DetailContentWidth() - 148))
                        objLabel:SetJustifyH("LEFT")
                        objLabel:SetWordWrap(true)
                        objLabel:SetText(format("[%s] %s", TE:GetTrackTypeDisplayName(obj.type), obj.description or ""))

                        if objComplete then
                            objLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                        else
                            objLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        end
                        tinsert(stepRow._objChecks, { check = objCheck, label = objLabel, objKey = obj.key })

                        local objH = math.max(18, objLabel:GetStringHeight() + 4)
                        objY = objY - objH
                        rowHeight = rowHeight + objH
                    end
                end

                if rosterCompleters then
                    local rosterY = -rowHeight
                    if #rosterCompleters == 0 then
                        local emptyFS = OneWoW_GUI:CreateFS(stepRow, 10)
                        emptyFS:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 30, rosterY)
                        emptyFS:SetText(L["TRACKER_ROSTER_NOBODY"])
                        emptyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                        rowHeight = rowHeight + 18
                    else
                        for _, c in ipairs(rosterCompleters) do
                            local nameFS = OneWoW_GUI:CreateFS(stepRow, 10)
                            nameFS:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 30, rosterY)
                            nameFS:SetPoint("RIGHT", stepRow, "RIGHT", -80, 0)
                            nameFS:SetJustifyH("LEFT")
                            nameFS:SetText(c.realm and (c.name .. "-" .. c.realm) or c.name)
                            local color = c.class and RAID_CLASS_COLORS[c.class]
                            if color then
                                nameFS:SetTextColor(color.r, color.g, color.b)
                            else
                                nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                            end
                            local nameH = math.max(18, nameFS:GetStringHeight() + 4)
                            rosterY = rosterY - nameH
                            rowHeight = rowHeight + nameH
                        end
                    end
                end

                if step.mapID and step.coordX and step.coordY then
                    local coordFS = OneWoW_GUI:CreateFS(stepRow, 10)
                    coordFS:SetPoint("BOTTOMLEFT", stepRow, "BOTTOMLEFT", 30, 4)
                    local mapInfo = C_Map.GetMapInfo(tonumber(step.mapID))
                    local mapName = mapInfo and mapInfo.name or tostring(step.mapID)
                    coordFS:SetText(format("%s (%.1f, %.1f)", mapName, step.coordX, step.coordY))
                    coordFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    rowHeight = rowHeight + 16
                end

                stepRow:SetHeight(math.max(30, rowHeight))

                stepRow:SetScript("OnEnter", function(self)
                    SetRowActionsShown(self, true)
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    TE:BuildStepTooltip(GameTooltip, list.id, sec.key, step)
                    GameTooltip:Show()
                end)
                stepRow:SetScript("OnLeave", function(self)
                    ScheduleHideRowActions(self)
                    GameTooltip_Hide()
                end)

                stepRow:RegisterForClicks("AnyUp")
                stepRow:SetScript("OnClick", function(_, button)
                    if stepReorder:ShouldSuppressClick() then return end
                    if button == "LeftButton" then
                        local hasCoords = step.mapID and step.coordX and step.coordY and tonumber(step.mapID) and tonumber(step.coordX) and tonumber(step.coordY)
                        if hasCoords then
                            if Location.SetWaypoint(step.mapID, step.coordX, step.coordY, PERCENT_COORDS) then
                                print(format("%s %s", L["ADDON_CHAT_PREFIX"], format(L["TRACKER_WAYPOINT_SET"], step.label or L["TRACKER_STEP_FALLBACK"], tonumber(step.coordX), tonumber(step.coordY))))
                            else
                                print(format("%s %s", L["ADDON_CHAT_PREFIX"], L["MSG_CANNOT_SET_WAYPOINT"]))
                            end
                        elseif not step.optional and step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                            if not isComplete and not TE:TryUserComplete(list.id, sec.key, step.key) then
                                return
                            end
                            TD:ToggleStepComplete(list.id, sec.key, step.key)
                            parent.RefreshList()
                            parent.RefreshDetailProgress()
                            TE:RefreshAllPinnedWindows()
                        end
                    elseif button == "RightButton" then
                        MenuUtil.CreateContextMenu(stepRow, function(_, rootDescription)
                            rootDescription:CreateTitle(step.label or L["TRACKER_STEP_FALLBACK"])
                            rootDescription:CreateButton(EDIT, function()
                                ns.TrackerEditor:ShowStepEditor(list.id, sec.key, step.key, function()
                                    TE:RebuildIndices()
                                    parent.RefreshList()
                                    parent.ShowDetail(list.id)
                                    TE:RefreshAllPinnedWindows()
                                end)
                            end)
                            if not step.optional and step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                                rootDescription:CreateDivider()
                                rootDescription:CreateButton(stepRow._trackerComplete and (L["TRACKER_MARK_INCOMPLETE"]) or (L["TRACKER_MARK_COMPLETE"]), function()
                                    if not stepRow._trackerComplete and not TE:TryUserComplete(list.id, sec.key, step.key) then
                                        return
                                    end
                                    TD:ToggleStepComplete(list.id, sec.key, step.key)
                                    parent.RefreshList()
                                    parent.RefreshDetailProgress()
                                    TE:RefreshAllPinnedWindows()
                                end)
                            end
                            rootDescription:CreateDivider()
                            rootDescription:CreateButton("|cFFFF4444" .. (DELETE) .. "|r", function()
                                TD:RemoveStep(list.id, sec.key, step.key)
                                TE:RebuildIndices()
                                parent.RefreshList()
                                parent.ShowDetail(list.id)
                                TE:RefreshAllPinnedWindows()
                            end)
                        end)
                    end
                end)

                tinsert(stepReorderFrames, stepRow)
                stepReorder:Attach(stepRow)

                yOffset = yOffset - (math.max(30, rowHeight) + 4)
              end
            end
          end
          end
        end

        detailScrollChild:SetHeight(math.max(1, math.abs(yOffset) + 20))
        lastDetailLayoutW = detailScrollFrame:GetWidth() or lastDetailLayoutW
        layingOutDetail = false
    end

    local function ApplyStepRowProgress(row, list)
        local secKey = row._trackerSectionKey
        local stepKey = row._trackerStepKey
        local step = TD:GetStep(list.id, secKey, stepKey)
        if not step then return false end
        local sp = TD:GetStepProgress(list.id, secKey, stepKey)
        local rosterCompleters = step.rosterMode and TD:GetRosterCompleters(list.id, stepKey) or nil
        local isComplete
        if step.rosterMode then
            isComplete = TD:IsRosterCompleter(list.id, stepKey, TD:GetCurrentCharKey())
        else
            isComplete = sp.completed or false
        end
        local depsMet = TD:AreStepDependenciesMet(list.id, step)
        row._trackerComplete = isComplete

        if isComplete then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        elseif not depsMet then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        else
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end

        if row._checkBtn and row._checkBtn.SetChecked then
            row._checkBtn:SetChecked(isComplete)
        end

        local stepLabel = row._stepLabel
        if stepLabel then
            if row._isOptional then
                stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            elseif isComplete then
                stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            elseif not depsMet then
                stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            else
                stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end

        if row._stepProgress then
            row._stepProgress:SetText(ns.TrackerEvaluators.FormatStepProgress(
                step, sp, rosterCompleters and #rosterCompleters or nil))
        end

        for _, entry in ipairs(row._objChecks or {}) do
            local objComplete = TD:GetObjectiveProgress(list.id, secKey, stepKey, entry.objKey)
            if entry.check.SetChecked then
                entry.check:SetChecked(objComplete)
            end
            if objComplete then
                entry.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                entry.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        end
        return true
    end

    function parent.RefreshDetailProgress()
        if not selectedListID then return end
        local list = TD:GetList(selectedListID)
        if not list then return end
        if list.listType == "farmvalue" or list.pinnedHideCompleted then
            parent.ShowDetail(selectedListID)
            return
        end
        for _, sec in ipairs(list.sections or {}) do
            for _, step in ipairs(sec.steps or {}) do
                if step.rosterMode then
                    parent.ShowDetail(selectedListID)
                    return
                end
            end
        end
        if not list.pinned then
            TE:EvaluateList(list.id)
        end
        if detailProgressBar then
            local done, total = TD:GetListCompletion(list.id)
            detailProgressBar:UpdateProgress(done, math.max(total, 1))
            detailProgressBar._text:SetText(total > 0 and format("%d / %d", done, total) or "")
        end
        for _, header in ipairs(sectionReorderFrames) do
            if header._trackerKind == "header" and header._secCount then
                local secDone, secTotal = TD:GetSectionCompletion(list.id, header._trackerSectionKey)
                header._secCount:SetText(secTotal > 0 and format("%d/%d", secDone, secTotal) or "")
            end
        end
        for _, row in ipairs(stepReorderFrames) do
            if row._trackerKind == "step" then
                if not ApplyStepRowProgress(row, list) then
                    parent.ShowDetail(selectedListID)
                    return
                end
            end
        end
    end

    detailScrollFrame:HookScript("OnSizeChanged", function(myself, w)
        w = tonumber(w) or myself:GetWidth() or 0
        if layingOutDetail or pendingDetailLayout then return end
        if math.abs(w - lastDetailLayoutW) < 1 then return end
        pendingDetailLayout = true
        C_Timer.After(0, function()
            pendingDetailLayout = false
            if layingOutDetail then return end
            local nw = detailScrollFrame:GetWidth() or 0
            if math.abs(nw - lastDetailLayoutW) < 1 then return end
            if selectedListID then
                parent.ShowDetail(selectedListID)
            end
        end)
    end)

    newBtn:SetScript("OnClick", function()
        ns.TrackerEditor:ShowNewListDialog(function(newList)
            if newList then
                selectedListID = newList.id
                TE:RebuildIndices()
                parent.RefreshList()
                parent.ShowDetail(newList.id)
            end
        end)
    end)

    importBtn:SetScript("OnClick", function()
        ns.TrackerEditor:ShowImportDialog(function(imported)
            if imported then
                selectedListID = imported.id
                TE:RebuildIndices()
                parent.RefreshList()
                parent.ShowDetail(imported.id)
            end
        end)
    end)

    restoreBtn:SetScript("OnClick", function()
        TP:RestoreBundledContent()
        parent.RefreshList()
    end)

    TE:RegisterCallback("OnScanComplete", function()
        parent.RefreshList()
        if selectedListID then
            parent.RefreshDetailProgress()
        end
    end)

    TE:RegisterCallback("OnProgressChanged", function()
        parent.RefreshList()
        if selectedListID then
            parent.RefreshDetailProgress()
        end
    end)

    ns.UI.RefreshTab = function()
        parent.RefreshList()
        if selectedListID then
            parent.ShowDetail(selectedListID)
        end
    end

    function parent.SelectList(listID)
        if not listID or not TD:GetList(listID) then
            return
        end
        selectedListID = listID
        parent.RefreshList()
        parent.ShowDetail(listID)
    end

    parent:HookScript("OnShow", function()
        if ns.pendingListSelect then
            local listID = ns.pendingListSelect
            ns.pendingListSelect = nil
            parent.SelectList(listID)
        end
    end)

    parent.RefreshList()
end

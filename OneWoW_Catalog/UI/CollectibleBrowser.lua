local _, ns = ...
local L = ns.L

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local ipairs, wipe, tinsert = ipairs, wipe, tinsert
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

-- ============================================================================
-- Shared Collectibles / Housing list + detail
-- ============================================================================
-- Same chrome as Item Search: filter bar, collected dropdown, split list,
-- CardChrome rows, 50/100 cap, clickable CatDB source lines. Data walks stay
-- in CollectibleBrowse.
-- ============================================================================

local SOURCE_BTN_PAD_X = 10
local SOURCE_BTN_GAP = 3

local function ApplyRowChrome(row, index, selected, hover)
    ns.CardChrome.ApplyRowChrome(row, {
        selected = selected,
        hover = hover,
        borderKey = row._borderKey or "default",
        zebraIndex = index,
    })
end

local function ApplyFilterButtonResting(btn, currentKey)
    if btn.filterKey == currentKey then
        btn:SetAlpha(1)
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn.highlight:Show()
    else
        btn:SetAlpha(1)
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        btn.highlight:Hide()
    end
end

--- Build a Collectibles-style split list + detail tab.
---@param parent Frame
---@param spec table
---@return table session
function ns.UI.CreateCollectibleBrowser(parent, spec)
    local GUI = ns.Constants.GUI
    local ROW_H = GUI.COLLECTIBLE_ROW_HEIGHT
    local HEADER_H = GUI.COLLECTIBLE_HEADER_H
    local SOURCE_BTN_H = GUI.COLLECTIBLE_SOURCE_BTN_H
    local LEFT_W = GUI.LEFT_PANEL_WIDTH
    local GAP = GUI.PANEL_GAP

    local Browse = ns.CollectibleBrowse
    local currentFilter = spec.defaultFilter or "all"
    local currentCollectedFilter = "all"
    local currentSearch = ""
    local collectedFilterText
    local selectedEntry
    local listResults = {}
    local detailElements = {}
    local filterButtons = {}
    local listAPI
    local searchBox
    local emptyList
    local emptyDetail
    local searchTimer
    local suppressSearchBoxChange = false
    local panels

    local function HasListFilter()
        return ns.CatalogListHasSearchText(currentSearch)
            or currentFilter ~= spec.defaultFilter
            or currentCollectedFilter ~= "all"
    end

    local function ClearDetailElements()
        for _, el in ipairs(detailElements) do
            if el.Hide then
                el:Hide()
            end
            if el.SetParent then
                el:SetParent(nil)
            end
        end
        wipe(detailElements)
    end

    local function UpdateFilterButtons()
        for _, btn in ipairs(filterButtons) do
            ApplyFilterButtonResting(btn, currentFilter)
        end
    end

    local ShowDetail

    local function BindRow(row, index, result, state)
        if ns.BindCatalogListCapRow(row, result) then
            return
        end
        row.result = result
        row._rowSelected = state.selected and true or false
        row._borderKey = "default"
        ApplyRowChrome(row, index, row._rowSelected, false)

        if result.iconAtlas and not result.icon then
            row.icon:SetAtlas(result.iconAtlas)
        else
            row.icon:SetTexture(result.icon or 134400)
        end

        ns.CollectibleBrowse.RefreshCollected(result)

        row.nameText:SetText(result.name or result.key or "")
        if result.quality then
            row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))
        else
            row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local status
        if result.kind == "pet" and result.numLimit then
            status = (result.numCollected or 0) .. "/" .. result.numLimit
        elseif result.kind == "decor" and result.numOwned then
            status = "x" .. result.numOwned
        elseif result.collected then
            status = COLLECTED
        else
            status = NOT_COLLECTED
        end
        row.statusText:SetText(status)
        if result.collected then
            row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            row.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        local listBtn
        if result.itemID then
            listBtn = ns.AttachListButton(row, result.itemID, {
                name = result.name,
                point = "RIGHT",
                relativeTo = row.statusText,
                relativePoint = "LEFT",
                x = -6,
                y = 0,
            })
        elseif row._listBtn then
            row._listBtn:Hide()
        end
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row.iconFrame, "RIGHT", 6, 0)
        row.nameText:SetPoint("RIGHT", listBtn or row.statusText, "LEFT", -6, 0)

        if result.itemID and (not result.name or not result.icon) then
            ns.GetItemDataLoader():LoadItemData(result.itemID, function(_, itemData)
                if row.result ~= result or not itemData then
                    return
                end
                result.name = itemData.name or result.name
                result.icon = itemData.icon or result.icon
                result.quality = itemData.quality or result.quality
                row.icon:SetTexture(result.icon or 134400)
                row.nameText:SetText(result.name or result.key or "")
                if result.quality then
                    row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))
                end
                if selectedEntry and selectedEntry.key == result.key then
                    ShowDetail(selectedEntry)
                end
            end)
        end
    end

    local function CreateRow(rowParent)
        local row = CreateFrame("Button", nil, rowParent, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        ns.CardChrome.Attach(row, { skipBackground = true })
        row._borderKey = "default"
        ns.CardChrome.ApplyRowChrome(row, {
            selected = false,
            borderKey = "default",
            fillTheme = "BG_SECONDARY",
        })

        local iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
        iconFrame:SetSize(22, 22)
        iconFrame:SetPoint("LEFT", 4, 0)
        iconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon = icon
        row.iconFrame = iconFrame

        local statusText = OneWoW_GUI:CreateFS(row, 10)
        statusText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        statusText:SetJustifyH("RIGHT")
        row.statusText = statusText

        local nameText = OneWoW_GUI:CreateFS(row, 10)
        nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        nameText:SetPoint("RIGHT", statusText, "LEFT", -6, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        row:SetScript("OnEnter", function(myself)
            ApplyRowChrome(myself, myself.entryIndex or 0, myself._rowSelected, true)
            local result = myself.result
            if not result then
                return
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if result.itemID then
                GameTooltip:SetItemByID(result.itemID)
            elseif result.spellID then
                GameTooltip:SetSpellByID(result.spellID)
            else
                GameTooltip:SetText(result.name or result.key or "")
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(myself)
            ApplyRowChrome(myself, myself.entryIndex or 0, myself._rowSelected, false)
            GameTooltip:Hide()
        end)

        return row
    end

    ShowDetail = function(entry)
        if not panels or not entry then
            return
        end
        selectedEntry = entry
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:Hide()
        end

        ns.CollectibleBrowse.RefreshCollected(entry)

        local child = panels.detailScrollChild
        local yOffset = -8

        local headerFrame = CreateFrame("Frame", nil, child, "BackdropTemplate")
        headerFrame:SetHeight(50)
        headerFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        headerFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        headerFrame:SetBackdrop(BACKDROP_SIMPLE)
        headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        headerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailElements, headerFrame)

        local hIconFrame = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
        hIconFrame:SetSize(40, 40)
        hIconFrame:SetPoint("LEFT", 8, 0)
        hIconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        hIconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        hIconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local hIcon = hIconFrame:CreateTexture(nil, "ARTWORK")
        hIcon:SetPoint("TOPLEFT", 1, -1)
        hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
        hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if entry.iconAtlas and not entry.icon then
            hIcon:SetAtlas(entry.iconAtlas)
        else
            hIcon:SetTexture(entry.icon or 134400)
        end

        hIconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if entry.itemID then
                GameTooltip:SetItemByID(entry.itemID)
            elseif entry.spellID then
                GameTooltip:SetSpellByID(entry.spellID)
            else
                GameTooltip:SetText(entry.name or entry.key or "")
            end
            GameTooltip:Show()
        end)
        hIconFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local itemName = OneWoW_GUI:CreateFS(headerFrame, 16)
        itemName:SetPoint("TOPLEFT", hIconFrame, "TOPRIGHT", 8, -2)
        itemName:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
        itemName:SetJustifyH("LEFT")
        itemName:SetWordWrap(false)
        itemName:SetText(entry.name or entry.key or "")
        if entry.quality then
            itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(entry.quality))
        else
            itemName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local typeLine = OneWoW_GUI:CreateFS(headerFrame, 10)
        typeLine:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -2)
        local collectedLabel = entry.collected and COLLECTED or NOT_COLLECTED
        typeLine:SetText(Browse.TypeLabel(entry.kind) .. "  -  " .. collectedLabel)
        typeLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        yOffset = yOffset - 58

        local function AddSectionHeader(title)
            local sec = CreateFrame("Frame", nil, child, "BackdropTemplate")
            sec:SetHeight(24)
            sec:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
            sec:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
            sec:SetBackdrop(BACKDROP_SIMPLE)
            sec:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            sec:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailElements, sec)

            local titleFS = OneWoW_GUI:CreateFS(sec, 12)
            titleFS:SetPoint("LEFT", 8, 0)
            titleFS:SetText(title)
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            yOffset = yOffset - 28
        end

        local function AddTextRow(text, indent, colorKey)
            local r = CreateFrame("Frame", nil, child)
            r:SetHeight(18)
            r:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 12, yOffset)
            r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            tinsert(detailElements, r)

            local fs = OneWoW_GUI:CreateFS(r, 10)
            fs:SetPoint("LEFT", 0, 0)
            fs:SetPoint("RIGHT", 0, 0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetText(text)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey or "TEXT_PRIMARY"))
            local h = fs:GetStringHeight()
            if h < 18 then
                h = 18
            end
            r:SetHeight(h)
            yOffset = yOffset - h
        end

        local function AddClickableRow(text, indent, onClick)
            local btn = CreateFrame("Button", nil, child)
            btn:SetHeight(18)
            btn:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 12, yOffset)
            btn:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            tinsert(detailElements, btn)

            local fs = OneWoW_GUI:CreateFS(btn, 10)
            fs:SetPoint("LEFT", 0, 0)
            fs:SetText(text)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_IDLE"))

            btn:SetScript("OnEnter", function()
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_HOVER"))
                SetCursor("Interface\\CURSOR\\Point")
            end)
            btn:SetScript("OnLeave", function()
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_IDLE"))
                ResetCursor()
            end)
            btn:SetScript("OnClick", onClick)

            yOffset = yOffset - 18
        end

        if entry.itemID then
            AddTextRow(L["ITEMSEARCH_ITEM_ID"] .. ": " .. entry.itemID, 12, "TEXT_SECONDARY")
        end
        if entry.factionName then
            AddTextRow(FACTION .. "  " .. entry.factionName, 12, "TEXT_SECONDARY")
        end
        if entry.itemType or entry.itemSubType then
            local typeText = entry.itemType or ""
            if entry.itemSubType and entry.itemSubType ~= "" then
                if typeText ~= "" then
                    typeText = typeText .. "  -  " .. entry.itemSubType
                else
                    typeText = entry.itemSubType
                end
            end
            AddTextRow(typeText, 12, "TEXT_SECONDARY")
        end
        if entry.kind == "decor" and entry.numOwned then
            AddTextRow(string.format(
                L["HOUSING_OWNED_COUNTS"],
                entry.numOwned or 0,
                entry.numStored or 0,
                entry.numPlaced or 0
            ), 12, "TEXT_PRIMARY")
        end
        if entry.description then
            yOffset = yOffset - 6
            AddSectionHeader(DESCRIPTION)
            AddTextRow(entry.description, 12, "TEXT_PRIMARY")
        end
        if entry.sourceText then
            yOffset = yOffset - 6
            AddSectionHeader(SOURCE)
            AddTextRow(entry.sourceText, 12, "TEXT_PRIMARY")
        end

        local function PaintSources(sources)
            if selectedEntry ~= entry then
                return
            end

            if sources.rare then
                yOffset = yOffset - 6
                AddSectionHeader(L["COLLECTIBLES_RARE_SECTION"])
                local rareLock = sources.rare
                local rareName = rareLock.name
                    or string.format(L["QUESTS_NPC_UNNAMED"], rareLock.npcID)
                AddClickableRow(rareName, 12, function()
                    Browse.JumpToRare(rareLock)
                end)
            end

            if entry.itemID then
                yOffset = yOffset - 6
                AddSectionHeader(L["ITEMSEARCH_SECTION_DROPS"])
                if #sources.drops > 0 then
                    for _, drop in ipairs(sources.drops) do
                        local thisDrop = drop
                        local inst = thisDrop.instanceName
                        local enc = thisDrop.encounterName
                        if not inst or inst == "" or inst == "?" or inst == "???" then
                            inst = nil
                        end
                        if not enc or enc == "" or enc == "?" or enc == "???" then
                            enc = nil
                        end
                        local line
                        if inst and enc then
                            line = inst .. "  -  " .. enc
                        else
                            line = inst or enc or BATTLE_PET_SOURCE_1
                        end
                        if Browse.DropCanJump(thisDrop) then
                            AddClickableRow(line, 12, function()
                                Browse.JumpToPlace(thisDrop)
                            end)
                        else
                            AddTextRow(line, 12, "TEXT_PRIMARY")
                        end
                    end
                else
                    local notice = OneWoW:GetCatalogUnavailableNotice("journal")
                    if notice then
                        AddTextRow(notice, 12, "TEXT_WARNING")
                    else
                        AddTextRow(L["ITEMSEARCH_NO_DROPS"], 12, "TEXT_MUTED")
                    end
                end

                yOffset = yOffset - 6
                AddSectionHeader(L["ITEMSEARCH_SECTION_VENDORS"])
                if #sources.vendors > 0 then
                    for _, v in ipairs(sources.vendors) do
                        local thisVendor = v
                        local line = thisVendor.name or L["VENDORS_UNKNOWN"]
                        if thisVendor.zone and thisVendor.zone ~= "" then
                            line = line .. "  (" .. thisVendor.zone .. ")"
                        end
                        if thisVendor.npcID then
                            AddClickableRow(line, 12, function()
                                Browse.JumpToVendor(thisVendor.npcID)
                            end)
                        else
                            AddTextRow(line, 12, "TEXT_PRIMARY")
                        end
                    end
                else
                    local notice = OneWoW:GetCatalogUnavailableNotice("vendors")
                    if notice then
                        AddTextRow(notice, 12, "TEXT_WARNING")
                    else
                        AddTextRow(L["ITEMSEARCH_NO_VENDORS"], 12, "TEXT_MUTED")
                    end
                end

                yOffset = yOffset - 6
                AddSectionHeader(L["ITEMSEARCH_SECTION_QUESTS"])
                if #sources.quests > 0 then
                    for _, qr in ipairs(sources.quests) do
                        local thisQuest = qr
                        local qname = thisQuest.questName
                            or string.format(L["QUESTS_UNNAMED"], thisQuest.questID)
                        AddClickableRow(qname, 12, function()
                            Browse.JumpToQuest(thisQuest.questID)
                        end)
                    end
                else
                    local notice = OneWoW:GetCatalogUnavailableNotice("quests")
                    if notice then
                        AddTextRow(notice, 12, "TEXT_WARNING")
                    else
                        AddTextRow(L["ITEMSEARCH_NO_QUESTS"], 12, "TEXT_MUTED")
                    end
                end

                if #sources.achievements > 0 then
                    yOffset = yOffset - 6
                    AddSectionHeader(ACHIEVEMENTS)
                    for _, ach in ipairs(sources.achievements) do
                        local thisAch = ach
                        local aname = thisAch.name or tostring(thisAch.achievementID)
                        AddClickableRow(aname, 12, function()
                            Browse.JumpToAchievement(thisAch.achievementID)
                        end)
                    end
                end
            end

            yOffset = yOffset - 10
            child:SetHeight(math.abs(yOffset) + 20)
        end

        PaintSources(Browse.BuildSources(entry))
    end

    local function SyncListAndStatus(loading)
        if not listAPI then
            return
        end
        local hasFilter = HasListFilter()
        local keep
        local dataN = ns.CatalogListDataCount(listResults, hasFilter)
        if selectedEntry and selectedEntry.key then
            for i = 1, dataN do
                if listResults[i].key == selectedEntry.key then
                    keep = i
                    break
                end
            end
        end
        if keep then
            listAPI.SetSelectedIndex(keep)
        else
            listAPI.SetSelectedIndex(nil)
            listAPI.Refresh()
        end
        if panels.leftStatusText then
            local n = ns.CatalogListDataCount(listResults, hasFilter)
            if loading then
                panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_LOADING"], n))
            elseif n == 0 then
                panels.leftStatusText:SetText("")
            elseif not hasFilter then
                panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_BROWSE_DEFAULT"], n))
            else
                panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_RESULTS"], n))
            end
        end
    end

    local function FinishList(hitCap)
        if not panels or not listAPI then
            return
        end
        local hasFilter = HasListFilter()
        if ns.CapCatalogList(listResults, hasFilter) or hitCap then
            ns.AppendCatalogListCapNotice(listResults)
        end
        if #listResults == 0 then
            panels.listScrollChild:SetHeight(100)
            listAPI.SetSelectedIndex(nil)
            listAPI.Refresh()
            if emptyList then
                emptyList:SetText(
                    ns.CatalogListHasSearchText(currentSearch) and L[spec.noResultsKey] or L[spec.emptyKey]
                )
                emptyList:Show()
            end
            if panels.leftStatusText then
                panels.leftStatusText:SetText("")
            end
            return
        end
        if emptyList then
            emptyList:Hide()
        end
        SyncListAndStatus(false)
    end

    local function RefreshList()
        if not panels or not listAPI then
            return
        end
        Browse.CancelQuery()
        wipe(listResults)
        panels.listScrollFrame:SetVerticalScroll(0)
        listAPI.SetSelectedIndex(nil)
        listAPI.Refresh()

        if emptyList then
            emptyList:SetText(
                ns.CatalogListHasSearchText(currentSearch) and L[spec.noResultsKey] or L[spec.emptyKey]
            )
            emptyList:Show()
        end
        if panels.leftStatusText then
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_LOADING"], 0))
        end

        spec.startQuery(currentFilter, currentSearch, listResults, {
            collectedFilter = currentCollectedFilter,
            onProgress = function()
                if not panels or not listAPI then
                    return
                end
                if #listResults > 0 and emptyList then
                    emptyList:Hide()
                end
                listAPI.Refresh()
                if panels.leftStatusText then
                    panels.leftStatusText:SetText(string.format(
                        L["ITEMSEARCH_LOADING"],
                        ns.CatalogListDataCount(listResults, HasListFilter())
                    ))
                end
            end,
            onComplete = FinishList,
        })
    end

    local searchHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local filterHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    filterHeader:ClearAllPoints()
    filterHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    filterHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = OneWoW_GUI:CreateSplitPanel(contentArea, { hideTitles = true })

    local function CreateFilterButton(btnParent, def)
        local btn = CreateFrame("Button", nil, btnParent, "BackdropTemplate")
        btn:SetHeight(SOURCE_BTN_H)
        btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local label = OneWoW_GUI:CreateFS(btn, 10)
        label:SetPoint("CENTER", 0, 0)
        label:SetText(def.label)
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        btn:SetWidth(math.max(36, label:GetStringWidth() + SOURCE_BTN_PAD_X * 2))

        btn.filterKey = def.key
        btn.highlight = btn:CreateTexture(nil, "OVERLAY")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        btn.highlight:SetAlpha(0.15)
        btn.highlight:Hide()

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(def.label, 1, 1, 1)
            GameTooltip:AddLine(L[def.descKey], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            ApplyFilterButtonResting(self, currentFilter)
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function(self)
            currentFilter = self.filterKey
            selectedEntry = nil
            UpdateFilterButtons()
            ClearDetailElements()
            if emptyDetail then
                emptyDetail:SetText(L[spec.selectKey])
                emptyDetail:Show()
            end
            RefreshList()
        end)
        return btn
    end

    for _, def in ipairs(spec.filters) do
        tinsert(filterButtons, CreateFilterButton(filterHeader, def))
    end

    local containerWidth = filterHeader:GetWidth()
    if containerWidth < 100 then
        containerWidth = 900
    end
    local padLeft = 6
    local padTop = 5
    local xOff = padLeft
    local btnRow = 0
    for _, btn in ipairs(filterButtons) do
        local btnWidth = btn:GetWidth()
        if xOff + btnWidth + SOURCE_BTN_GAP > containerWidth - padLeft and xOff > padLeft then
            btnRow = btnRow + 1
            xOff = padLeft
        end
        local yOff = -padTop - (btnRow * (SOURCE_BTN_H + SOURCE_BTN_GAP))
        btn:SetPoint("TOPLEFT", filterHeader, "TOPLEFT", xOff, yOff)
        xOff = xOff + btnWidth + SOURCE_BTN_GAP
    end
    UpdateFilterButtons()

    local clearBtn = OneWoW_GUI:CreateFitTextButton(searchHeader, {
        text = L["ITEMSEARCH_FILTER_CLEAR"],
        height = 26,
        minWidth = 34,
    })
    clearBtn:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -8)

    searchBox = OneWoW_GUI:CreateEditBox(searchHeader, {
        height = 26,
        maxLetters = 50,
        placeholderText = L[spec.searchKey],
        onTextChanged = function(text)
            if suppressSearchBoxChange then
                return
            end
            if searchTimer then
                searchTimer:Cancel()
            end
            searchTimer = C_Timer.NewTimer(0.3, function()
                currentSearch = text
                selectedEntry = nil
                ClearDetailElements()
                if emptyDetail then
                    emptyDetail:SetText(L[spec.selectKey])
                    emptyDetail:Show()
                end
                RefreshList()
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    local collectedDropdown
    collectedDropdown, collectedFilterText = OneWoW_GUI:CreateDropdown(searchHeader, {
        width = 10,
        height = 26,
        text = L["JOURNAL_FILTER_SHOW_ALL"],
    })
    collectedDropdown:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -38)
    collectedDropdown:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -38)

    OneWoW_GUI:AttachFilterMenu(collectedDropdown, {
        searchable = false,
        getActiveValue = function() return currentCollectedFilter end,
        buildItems = function()
            return {
                { value = "all", text = L["JOURNAL_FILTER_SHOW_ALL"] },
                { value = "collected", text = L["JOURNAL_FILTER_COLLECTED"] },
                { value = "notcollected", text = L["JOURNAL_FILTER_NOT_COLLECTED"] },
            }
        end,
        onSelect = function(value, text)
            currentCollectedFilter = value
            collectedFilterText:SetText(value == "all" and L["JOURNAL_FILTER_SHOW_ALL"] or text)
            selectedEntry = nil
            ClearDetailElements()
            if emptyDetail then
                emptyDetail:SetText(L[spec.selectKey])
                emptyDetail:Show()
            end
            RefreshList()
        end,
    })

    clearBtn:SetScript("OnClick", function()
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        currentSearch = ""
        currentFilter = spec.defaultFilter or "all"
        currentCollectedFilter = "all"
        collectedFilterText:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        selectedEntry = nil
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L[spec.selectKey])
            emptyDetail:Show()
        end
        UpdateFilterButtons()
        suppressSearchBoxChange = true
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchBox:RestorePlaceholder()
        suppressSearchBoxChange = false
        RefreshList()
    end)

    listAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = spec.listName,
        rowHeight = ROW_H,
        numVisibleRows = 24,
        rowInset = 0,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            return ns.CatalogListVisibleCount(listResults, HasListFilter())
        end,
        getEntry = function(index)
            return ns.CatalogListVisibleEntry(listResults, index, HasListFilter())
        end,
        isSelectable = function(_, entry)
            return entry ~= nil and not ns.IsCatalogListCap(entry)
        end,
        onSelect = function(_, entry)
            if ns.IsCatalogListCap(entry) then
                return
            end
            local same = selectedEntry and entry and selectedEntry.key == entry.key
            selectedEntry = entry
            if not same then
                ShowDetail(entry)
            end
        end,
        createRow = CreateRow,
        bindRow = BindRow,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })
    panels.virtualizedList = listAPI

    emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetText(L[spec.emptyKey])
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    emptyDetail = OneWoW_GUI:CreateFS(panels.detailScrollChild, 12)
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L[spec.selectKey])
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    panels.detailScrollChild:SetHeight(100)

    Browse.Defer(function()
        if not panels or not listAPI then
            return
        end
        RefreshList()
    end)

    function parent.GetNavEntity()
        if selectedEntry and selectedEntry.key then
            return spec.navKind, selectedEntry.key
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind ~= spec.navKind then
            return
        end
        local dataN = ns.CatalogListDataCount(listResults, HasListFilter())
        for i = 1, dataN do
            if listResults[i].key == id then
                listAPI.SetSelectedIndex(i)
                return
            end
        end
    end

    return {
        Refresh = RefreshList,
        panels = panels,
    }
end

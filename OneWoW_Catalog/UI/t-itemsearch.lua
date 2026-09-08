local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

local selectedItem   = nil
local currentSearch  = ""
local currentSource  = "all"
local panels         = nil
local listResults    = {}
local detailElements = {}
local sourceButtons  = {}
local searchBox      = nil
local emptyList      = nil
local emptyDetail    = nil
local searchTimer    = nil
local suppressSearchBoxChange = false
local dataReadyWatchersRegistered = false
local listAPI        = nil

local function ItemSearchHasListFilter()
    return #currentSearch >= 2 or currentSource ~= "all"
end

local function OpenItemNoteFromResult(result)
    if not result or not result.itemID or not ns.Navigation or not ns.Navigation.OpenItemNote then
        return false
    end

    return ns.Navigation:OpenItemNote(result.itemID, {
        name     = result.name,
        link     = result.link,
        icon     = result.icon,
        quality  = result.quality,
        rarity   = result.rarity or result.quality,
        category = "General",
        storage  = "account",
    })
end

local function JumpToVendor(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return
    end
    local packName = ns.EnsureCatalogPack("vendors")
    local function open()
        ns.UI.OpenToVendor(npcID)
    end
    if ns.GetCatalogPackAPI("vendors") then
        open()
        return
    end
    if packName then
        OneWoW:WithAddon(packName, open)
    end
end

local function JumpToQuest(questID)
    questID = tonumber(questID)
    if not questID then
        return
    end
    local packName = ns.EnsureCatalogPack("quests")
    local function open()
        ns.UI.OpenQuest(questID)
    end
    if ns.GetCatalogPackAPI("quests") then
        open()
        return
    end
    if packName then
        OneWoW:WithAddon(packName, open)
    end
end

local function JumpToPlace(drop)
    if not drop then
        return
    end
    local packName = ns.EnsureCatalogPack("journal")
    local function open()
        ns.UI.OpenToInstance({
            placeKey = drop.placeKey,
            instanceID = drop.instanceID,
            mapID = drop.uiMapID,
            encounterID = drop.encounterID,
        })
    end
    if ns.GetCatalogPackAPI("journal") then
        open()
        return
    end
    if packName then
        OneWoW:WithAddon(packName, open)
    end
end

---@param drop table
---@return boolean
local function DropCanJump(drop)
    if drop.placeKey or (drop.instanceID and drop.instanceID > 0) or drop.uiMapID then
        return true
    end
    return false
end

local ITEM_ROW_HEIGHT  = 30
local SOURCE_BTN_H     = 22
local SOURCE_BTN_PAD_X = 10
local SOURCE_BTN_GAP   = 3
local HEADER_H         = 58

local SOURCE_DEFS = {
    { key = "all",     labelKey = "TT_IS_FILTER_ALL",     descKey = "TT_IS_FILTER_ALL_DESC"     },
    { key = "drops",   labelKey = "TT_IS_FILTER_DROPS",   descKey = "TT_IS_FILTER_DROPS_DESC"   },
    { key = "vendors", labelKey = "TT_IS_FILTER_VENDORS", descKey = "TT_IS_FILTER_VENDORS_DESC" },
    { key = "crafted", labelKey = "TT_IS_FILTER_CRAFTED", descKey = "TT_IS_FILTER_CRAFTED_DESC" },
    { key = "owned",   labelKey = "TT_IS_FILTER_OWNED",   descKey = "TT_IS_FILTER_OWNED_DESC"   },
    { key = "quests",  labelKey = "TT_IS_FILTER_QUESTS",  descKey = "TT_IS_FILTER_QUESTS_DESC"  },
}

local RefreshItemList
local ShowItemDetail

local function SelectVisibleItemResult(itemID)
    itemID = tonumber(itemID)
    if not itemID or not listAPI then
        return false
    end

    local dataN = ns.CatalogListDataCount(listResults, ItemSearchHasListFilter())
    for i = 1, dataN do
        local result = listResults[i]
        if tonumber(result.itemID) == itemID then
            listAPI.SetSelectedIndex(i)
            return true
        end
    end

    return false
end

local function ApplyLoadedItemData(result, itemData)
    if not result or not itemData then
        return
    end

    result.name = itemData.name or result.name
    result.icon = itemData.icon or result.icon
    result.quality = itemData.quality or result.quality
    result.link = itemData.link or result.link
end

local function ClearDetailElements()
    for _, el in ipairs(detailElements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    wipe(detailElements)
end

local function ApplyItemRowBackdrop(row, index, selected, hover)
    ns.CardChrome.ApplyRowChrome(row, {
        selected = selected,
        hover = hover,
        borderKey = row._borderKey or "default",
        zebraIndex = index,
    })
end

-- Resting (non-hovered) appearance for a single button, honoring availability
-- and active selection. Shared by UpdateSourceButtonStates and OnLeave so the
-- two never diverge.
local function ApplySourceButtonResting(btn)
    if not btn.available then
        btn:SetAlpha(0.4)
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        btn.highlight:Hide()
    elseif btn.sourceKey == currentSource then
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

-- Recomputes each button's availability and resting style. Returns true if any
-- button's availability changed, so callers can refresh the list once data
-- becomes (un)available mid-session.
local function UpdateSourceButtonStates()
    local availabilityChanged = false
    for _, btn in ipairs(sourceButtons) do
        local available = (not ns.ItemSearch) or ns.ItemSearch:IsSourceAvailable(btn.sourceKey)
        if btn.available ~= available then
            btn.available = available
            availabilityChanged = true
        end
        ApplySourceButtonResting(btn)
    end
    return availabilityChanged
end

local function CreateSourceButton(parent, def)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(SOURCE_BTN_H)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local label = OneWoW_GUI:CreateFS(btn, 10)
    label:SetPoint("CENTER", 0, 0)
    label:SetText(L[def.labelKey])
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local textWidth = label:GetStringWidth()
    btn:SetWidth(math.max(36, textWidth + SOURCE_BTN_PAD_X * 2))

    btn.label     = label
    btn.sourceKey = def.key
    btn.available = true

    btn.highlight = btn:CreateTexture(nil, "OVERLAY")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    btn.highlight:SetAlpha(0.15)
    btn.highlight:Hide()

    btn:SetScript("OnEnter", function(self)
        if self.available then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L[def.labelKey], 1, 1, 1)
        if self.available then
            GameTooltip:AddLine(L[def.descKey], 0.7, 0.7, 0.7, true)
        else
            GameTooltip:AddLine(L["ITEMSEARCH_SOURCE_UNAVAIL"], 1, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        ApplySourceButtonResting(self)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        ns.ItemSearch.EnsureFilterPacks(self.sourceKey)
        UpdateSourceButtonStates()
        if not ns.ItemSearch:IsSourceAvailable(self.sourceKey) then
            return
        end
        currentSource = self.sourceKey
        selectedItem  = nil
        UpdateSourceButtonStates()
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
            emptyDetail:Show()
        end
        RefreshItemList()
    end)

    return btn
end

local function CreateItemListRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ITEM_ROW_HEIGHT)
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

    local rightCluster = CreateFrame("Frame", nil, row)
    rightCluster:SetHeight(ITEM_ROW_HEIGHT)
    rightCluster:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.rightCluster = rightCluster

    local favBtn
    if ns.Favorites then
        favBtn = OneWoW_GUI:CreateFavoriteToggleButton(rightCluster, {
            size = 16,
            favorite = false,
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText = L["CATALOG_FAVORITE_TT"],
            onClick = function(_, on)
                local result = row.result
                if not result or not result.itemID then
                    return
                end
                ns.Favorites:SetFavorite("itemSearch", result.itemID, on)
                RefreshItemList()
            end,
        })
        favBtn:SetPoint("RIGHT", rightCluster, "RIGHT", 0, 0)
        row.favBtn = favBtn
    end

    local qtyBadge = OneWoW_GUI:CreateFS(rightCluster, 10)
    qtyBadge:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    row.qtyBadge = qtyBadge

    local nameText = OneWoW_GUI:CreateFS(row, 10)
    nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Shift-click opens a note; normal click selection is wired by Virtualizer.
    row:SetScript("OnClick", function(myself)
        if IsShiftKeyDown() and OpenItemNoteFromResult(myself.result) then
            return
        end
    end)

    row:SetScript("OnEnter", function(myself)
        ApplyItemRowBackdrop(myself, myself.entryIndex or 0, myself._rowSelected, true)
        local result = myself.result
        if result and result.itemID then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(result.itemID)
            GameTooltip:AddLine(L["QUESTS_TT_ITEM_ADD_NOTES"], 0, 1, 0)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(myself)
        ApplyItemRowBackdrop(myself, myself.entryIndex or 0, myself._rowSelected, false)
        GameTooltip:Hide()
    end)

    return row
end

local function BindItemListRow(row, index, result, state)
    if ns.BindCatalogListCapRow(row, result) then
        return
    end
    row.result = result
    row._rowSelected = state.selected and true or false
    row._borderKey = "default"
    ApplyItemRowBackdrop(row, index, row._rowSelected, false)

    row.icon:SetTexture(result.icon or 134400)
    row.nameText:SetText(result.name or string.format(L["QUESTS_ITEM_UNNAMED"], result.itemID))
    row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))

    if row.listBtn and result.itemID then
        ns.AttachListButton(row.rightCluster, result.itemID, {
            name = result.name,
            point = "RIGHT",
            relativeTo = row.favBtn or row.rightCluster,
            relativePoint = row.favBtn and "LEFT" or "RIGHT",
            x = row.favBtn and -4 or 0,
            y = 0,
        })
    elseif row.listBtn then
        row.listBtn:Hide()
    end

    local hasOwned = result.ownedCount and result.ownedCount > 0
    local showFav = row.favBtn and result.itemID
    local useRightChrome = hasOwned or showFav or (row.listBtn and row.listBtn:IsShown())

    if useRightChrome then
        row.rightCluster:Show()
        if row.favBtn then
            if showFav then
                row.favBtn:SetFavorite(ns.Favorites:IsFavorite("itemSearch", result.itemID))
                row.favBtn:Show()
            else
                row.favBtn:Hide()
            end
        end
        if hasOwned then
            row.qtyBadge:SetText("x" .. result.ownedCount)
            row.qtyBadge:ClearAllPoints()
            if row.favBtn and row.favBtn:IsShown() then
                row.qtyBadge:SetPoint("RIGHT", row.favBtn, "LEFT", -4, 0)
            else
                row.qtyBadge:SetPoint("RIGHT", row.rightCluster, "RIGHT", 0, 0)
            end
            row.qtyBadge:Show()
        else
            row.qtyBadge:Hide()
        end

        local clusterW = 4
        if row.favBtn and row.favBtn:IsShown() then
            clusterW = clusterW + 20
        end
        if hasOwned then
            clusterW = clusterW + math.max(22, row.qtyBadge:GetStringWidth() + 4)
        end
        row.rightCluster:SetWidth(math.max(clusterW, 28))
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row.iconFrame, "RIGHT", 6, 0)
        row.nameText:SetPoint("RIGHT", row.rightCluster, "LEFT", -6, 0)
    else
        row.rightCluster:Hide()
        if row.favBtn then
            row.favBtn:Hide()
        end
        row.qtyBadge:Hide()
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row.iconFrame, "RIGHT", 6, 0)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    end

    if result.itemID and (not result.name or not result.icon) then
        ns.GetItemDataLoader():LoadItemData(result.itemID, function(_, itemData)
            if row.result ~= result then
                return
            end

            ApplyLoadedItemData(result, itemData)
            row.icon:SetTexture(result.icon or 134400)
            row.nameText:SetText(result.name or string.format(L["QUESTS_ITEM_UNNAMED"], result.itemID))
            row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))

            if selectedItem and selectedItem.itemID == result.itemID then
                ApplyLoadedItemData(selectedItem, itemData)
                ShowItemDetail(selectedItem)
            end
        end)
    end
end

ShowItemDetail = function(result)
    if not panels or not result then return end

    selectedItem = result
    ClearDetailElements()
    if emptyDetail then emptyDetail:Hide() end

    local child   = panels.detailScrollChild
    local yOffset = -8
    local needsItemRefresh = result.itemID and (not result.name or not result.icon)

    local headerFrame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    headerFrame:SetHeight(50)
    headerFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    headerFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    headerFrame:SetBackdrop(BACKDROP_SIMPLE)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    headerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    table.insert(detailElements, headerFrame)

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
    hIcon:SetTexture(result.icon or 134400)

    hIconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(result.itemID)
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
    itemName:SetText(result.name or string.format(L["QUESTS_ITEM_UNNAMED"], result.itemID))
    itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))

    local itemIDText = OneWoW_GUI:CreateFS(headerFrame, 10)
    itemIDText:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -2)
    itemIDText:SetText(L["ITEMSEARCH_ITEM_ID"] .. ": " .. result.itemID)
    itemIDText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    if needsItemRefresh then
        ns.GetItemDataLoader():LoadItemData(result.itemID, function(_, itemData)
            if not selectedItem or selectedItem.itemID ~= result.itemID then
                return
            end

            ApplyLoadedItemData(result, itemData)
            ApplyLoadedItemData(selectedItem, itemData)
            hIcon:SetTexture(result.icon or 134400)
            itemName:SetText(result.name or string.format(L["QUESTS_ITEM_UNNAMED"], result.itemID))
            itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))
            RefreshItemList()
        end)
    end

    yOffset = yOffset - 58

    local detail = ns.ItemSearch and ns.ItemSearch:GetDetail(result.itemID)
        or { drops = {}, vendors = {}, crafted = {}, owned = {} }

    local function AddSectionHeader(titleKey)
        local sec = CreateFrame("Frame", nil, child, "BackdropTemplate")
        sec:SetHeight(24)
        sec:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        sec:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        sec:SetBackdrop(BACKDROP_SIMPLE)
        sec:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        sec:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        table.insert(detailElements, sec)

        local title = OneWoW_GUI:CreateFS(sec, 12)
        title:SetPoint("LEFT", 8, 0)
        title:SetText(L[titleKey])
        title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        yOffset = yOffset - 28
    end

    local function AddTextRow(text, indent, colorKey)
        local r = CreateFrame("Frame", nil, child)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 12, yOffset)
        r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        table.insert(detailElements, r)

        local fs = OneWoW_GUI:CreateFS(r, 10)
        fs:SetPoint("LEFT", 0, 0)
        fs:SetText(text)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey or "TEXT_PRIMARY"))

        yOffset = yOffset - 18
    end

    local function AddClickableRow(text, indent, onClick)
        local btn = CreateFrame("Button", nil, child)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 12, yOffset)
        btn:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        table.insert(detailElements, btn)

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

    AddSectionHeader("ITEMSEARCH_SECTION_DROPS")
    if #detail.drops > 0 then
        for _, drop in ipairs(detail.drops) do
            local inst = drop.instanceName
            local enc = drop.encounterName
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
            if DropCanJump(drop) then
                AddClickableRow(line, 12, function()
                    JumpToPlace(drop)
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

    AddSectionHeader("ITEMSEARCH_SECTION_VENDORS")
    if #detail.vendors > 0 then
        for _, v in ipairs(detail.vendors) do
            local line = v.name or L["VENDORS_UNKNOWN"]
            if v.zone and v.zone ~= "" then
                line = line .. "  (" .. v.zone .. ")"
            end
            if v.npcID then
                AddClickableRow(line, 12, function()
                    JumpToVendor(v.npcID)
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

    if detail.isRecipe then
        AddSectionHeader("ITEMSEARCH_SECTION_KNOWNBY")
        if detail.recipeKnownBy and #detail.recipeKnownBy > 0 then
            for _, charKey in ipairs(detail.recipeKnownBy) do
                local charName = charKey:match("^([^%-]+)") or charKey
                AddTextRow(charName, 12, "TEXT_PRIMARY")
            end
        else
            AddTextRow(L["ITEMSEARCH_NO_KNOWNBY"], 12, "TEXT_MUTED")
        end
    else
        AddSectionHeader("ITEMSEARCH_SECTION_CRAFTED")
        if #detail.crafted > 0 then
            for _, c in ipairs(detail.crafted) do
                AddTextRow(c.profName or "", 12, "TEXT_PRIMARY")
                if c.knownBy and #c.knownBy > 0 then
                    for _, charKey in ipairs(c.knownBy) do
                        AddTextRow(charKey, 24, "TEXT_SECONDARY")
                    end
                else
                    AddTextRow(L["TRADESKILLS_NOT_SCANNED"], 24, "TEXT_MUTED")
                end
            end
        else
            local notice = OneWoW:GetCatalogUnavailableNotice("tradeskills")
            if notice then
                AddTextRow(notice, 12, "TEXT_WARNING")
            else
                AddTextRow(L["ITEMSEARCH_NO_CRAFTED"], 12, "TEXT_MUTED")
            end
        end
    end

    yOffset = yOffset - 6

    local locLabels = {
        bags    = L["ITEMSEARCH_LOC_BAGS"],
        bank    = BANK,
        mail    = L["MAIL"],
        warband = L["ITEMSEARCH_LOC_WARBAND"],
        guild   = GUILD_BANK,
        ah      = L["ITEMSEARCH_LOC_AH"],
    }

    AddSectionHeader("ITEMSEARCH_SECTION_INVENTORY")
    if #detail.owned > 0 then
        for _, owned in ipairs(detail.owned) do
            local locLabel = locLabels[owned.locLabel] or owned.locLabel
            local line = owned.charName .. "  -  " .. locLabel .. "  x" .. owned.count
            AddTextRow(line, 12, "TEXT_PRIMARY")
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_INVENTORY"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_QUESTS")
    if #detail.questRewards > 0 then
        for _, qr in ipairs(detail.questRewards) do
            local qname = qr.questName or string.format(L["QUESTS_UNNAMED"], qr.questID)
            AddClickableRow(qname, 12, function()
                JumpToQuest(qr.questID)
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

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_VALUE")

    local _, itemLink, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(result.itemID)
    local vendorSellPrice = sellPrice or 0

    if vendorSellPrice > 0 then
        AddTextRow(L["ITEMSEARCH_VENDOR_PRICE"] .. ":  " .. OneWoW.Format.FormatGold(vendorSellPrice), 12, "TEXT_PRIMARY")
    else
        AddTextRow(L["ITEMSEARCH_NOT_SELLABLE"], 12, "TEXT_MUTED")
    end

    local ahPrice, ahMeta
    local ow = OneWoW
    if ow and ow.ItemPrices then
        ahPrice, ahMeta = ow.ItemPrices:GetUnitAHPrice(result.itemID, itemLink)
    end
    if ahPrice and ahPrice > 0 then
        local ageText
        if ahMeta and ahMeta.timestamp and ahMeta.timestamp > 0 then
            local ageSeconds = GetServerTime() - ahMeta.timestamp
            if ageSeconds < 3600 then
                ageText = math.max(1, math.floor(ageSeconds / 60)) .. "m " .. L["ITEMSEARCH_AH_AGO"]
            elseif ageSeconds < 86400 then
                ageText = math.floor(ageSeconds / 3600) .. "h " .. L["ITEMSEARCH_AH_AGO"]
            else
                ageText = math.floor(ageSeconds / 86400) .. "d " .. L["ITEMSEARCH_AH_AGO"]
            end
        elseif ahMeta and ahMeta.ageDays ~= nil then
            ageText = string.format(L["ITEMSEARCH_AH_AGE_DAYS"], ahMeta.ageDays) .. " " .. L["ITEMSEARCH_AH_AGO"]
        end
        local row = L["ITEMSEARCH_AH_PRICE"] .. ":  " .. OneWoW.Format.FormatGold(ahPrice)
        if ageText then
            row = row .. "  |cFF888888(" .. ageText .. ")|r"
        end
        AddTextRow(row, 12, "TEXT_PRIMARY")
    else
        AddTextRow(L["ITEMSEARCH_NO_AH_DATA"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 10
    child:SetHeight(math.abs(yOffset) + 20)
end

local function ApplyFavoritesOrder(results, shouldYield)
    if not (ns.Favorites and #results > 0) then
        return
    end
    local origOrder = {}
    for i, r in ipairs(results) do
        if r.itemID then
            origOrder[tostring(r.itemID)] = i
        end
    end
    OneWoW.ChunkedJob.Sort(results, function(a, b)
        local fa = ns.Favorites:IsFavorite("itemSearch", a.itemID)
        local fb = ns.Favorites:IsFavorite("itemSearch", b.itemID)
        if fa ~= fb then
            return fa
        end
        local oa = a.itemID and origOrder[tostring(a.itemID)] or 0
        local ob = b.itemID and origOrder[tostring(b.itemID)] or 0
        return oa < ob
    end, shouldYield)
end

local function SyncListSelectionAndStatus(hasFilter, loading)
    if not listAPI then
        return
    end

    local keepSelection = nil
    local dataN = ns.CatalogListDataCount(listResults, hasFilter)
    if selectedItem and selectedItem.itemID then
        for i = 1, dataN do
            local result = listResults[i]
            if result.itemID == selectedItem.itemID then
                keepSelection = i
                break
            end
        end
    end

    if keepSelection then
        listAPI.SetSelectedIndex(keepSelection)
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

RefreshItemList = function()
    if not panels or not listAPI then
        return
    end

    wipe(listResults)
    panels.listScrollFrame:SetVerticalScroll(0)
    listAPI.SetSelectedIndex(nil)
    listAPI.Refresh()

    if not ns.ItemSearch then
        panels.listScrollChild:SetHeight(100)
        if emptyList then
            emptyList:SetText(L["ITEMSEARCH_EMPTY"])
            emptyList:Show()
        end
        if panels.leftStatusText then
            panels.leftStatusText:SetText("")
        end
        return
    end

    -- Single path: a <2 char term browses all available sources; >=2 filters.
    local hasTextFilter = #currentSearch >= 2
    local hasFilter = ItemSearchHasListFilter()

    if emptyList then
        emptyList:SetText(hasTextFilter and L["ITEMSEARCH_NO_RESULTS"] or L["ITEMSEARCH_EMPTY"])
        emptyList:Show()
    end
    if panels.leftStatusText then
        panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_LOADING"], 0))
    end

    ns.ItemSearch:StartQuery(currentSearch, currentSource, listResults, {
        finalize = function(results, shouldYield)
            ApplyFavoritesOrder(results, shouldYield)
        end,
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
                    ns.CatalogListDataCount(listResults, hasFilter)
                ))
            end
        end,
        onComplete = function()
            if not panels or not listAPI then
                return
            end

            if #listResults == 0 then
                panels.listScrollChild:SetHeight(100)
                listAPI.SetSelectedIndex(nil)
                listAPI.Refresh()
                if emptyList then
                    emptyList:SetText(hasTextFilter and L["ITEMSEARCH_NO_RESULTS"] or L["ITEMSEARCH_EMPTY"])
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

            SyncListSelectionAndStatus(hasFilter, false)

            local exactItemID = hasTextFilter and tonumber(currentSearch) or nil
            if exactItemID and not selectedItem then
                SelectVisibleItemResult(exactItemID)
            end
        end,
    })
end

function ns.UI.CreateItemSearchTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP

    -- Rebuilt fresh each construction (the tab can be rebuilt placeholder->real
    -- when a data source loads); drop any buttons from a prior build.
    wipe(sourceButtons)

    local searchHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local filterHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    filterHeader:ClearAllPoints()
    filterHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    filterHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local noticeBar = OneWoW_GUI:CreateFilterBar(parent, { height = 28, offset = 0 })
    noticeBar:ClearAllPoints()
    noticeBar:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    noticeBar:SetPoint("TOPRIGHT", filterHeader, "BOTTOMRIGHT", 0, -2)

    local noticeText = OneWoW_GUI:CreateFS(noticeBar, 12)
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMSEARCH_NOTICE"])
    noticeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", noticeBar, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = OneWoW_GUI:CreateSplitPanel(contentArea, { hideTitles = true })

    for _, def in ipairs(SOURCE_DEFS) do
        local btn = CreateSourceButton(filterHeader, def)
        table.insert(sourceButtons, btn)
    end

    local containerWidth = filterHeader:GetWidth()
    if containerWidth < 100 then containerWidth = 900 end
    local padLeft = 6
    local padTop  = 5
    local xOff    = padLeft
    local btnRow  = 0
    for _, btn in ipairs(sourceButtons) do
        local btnWidth = btn:GetWidth()
        if xOff + btnWidth + SOURCE_BTN_GAP > containerWidth - padLeft and xOff > padLeft then
            btnRow = btnRow + 1
            xOff   = padLeft
        end
        local yOff = -padTop - (btnRow * (SOURCE_BTN_H + SOURCE_BTN_GAP))
        btn:SetPoint("TOPLEFT", filterHeader, "TOPLEFT", xOff, yOff)
        xOff = xOff + btnWidth + SOURCE_BTN_GAP
    end

    local clearBtn = OneWoW_GUI:CreateFitTextButton(searchHeader, {
        text = L["ITEMSEARCH_FILTER_CLEAR"],
        height = 26,
        minWidth = 34,
    })
    clearBtn:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -8)

    searchBox = OneWoW_GUI:CreateEditBox(searchHeader, {
        height = 26,
        maxLetters = 50,
        placeholderText = L["ITEMSEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if suppressSearchBoxChange then
                return
            end
            if searchTimer then searchTimer:Cancel() end
            searchTimer = C_Timer.NewTimer(0.3, function()
                currentSearch = text
                selectedItem = nil
                ClearDetailElements()
                if emptyDetail then
                    emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
                    emptyDetail:Show()
                end
                RefreshItemList()

                -- An ID search can race the item cache: Query's exact-ID
                -- injection requires GetItemNameByID, which returns nil until
                -- the async item data arrives. Re-run the search once it does
                -- (mirrors the OpenItemSearch path below).
                local typedItemID = tonumber(text)
                if typedItemID then
                    ns.GetItemDataLoader():LoadItemData(typedItemID, function()
                        if currentSearch == text then
                            RefreshItemList()
                        end
                    end)
                end
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    clearBtn:SetScript("OnClick", function()
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        currentSearch = ""
        currentSource = "all"
        selectedItem = nil
        ns.ItemSearch.EnsureFilterPacks(currentSource)
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
            emptyDetail:Show()
        end
        UpdateSourceButtonStates()
        suppressSearchBoxChange = true
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchBox:RestorePlaceholder()
        suppressSearchBoxChange = false
        RefreshItemList()
    end)

    listAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = "CatalogItemSearchList",
        rowHeight = ITEM_ROW_HEIGHT,
        numVisibleRows = 24,
        rowInset = 0,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            return ns.CatalogListVisibleCount(listResults, ItemSearchHasListFilter())
        end,
        getEntry = function(index)
            return ns.CatalogListVisibleEntry(listResults, index, ItemSearchHasListFilter())
        end,
        isSelectable = function(_, entry)
            return entry ~= nil and not ns.IsCatalogListCap(entry)
        end,
        onSelect = function(_, entry)
            if ns.IsCatalogListCap(entry) then
                return
            end
            local same = selectedItem and entry and selectedItem.itemID == entry.itemID
            selectedItem = entry
            if not same then
                ShowItemDetail(entry)
            end
        end,
        createRow = CreateItemListRow,
        bindRow = BindItemListRow,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })
    panels.virtualizedList = listAPI

    emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetText(L["ITEMSEARCH_EMPTY"])
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    emptyDetail = OneWoW_GUI:CreateFS(panels.detailScrollChild, 12)
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    panels.detailScrollChild:SetHeight(100)

    ns.ItemSearch.EnsureFilterPacks(currentSource)
    UpdateSourceButtonStates()
    if emptyList then
        emptyList:SetText(L["ITEMSEARCH_EMPTY"])
        emptyList:Show()
    end
    if panels.leftStatusText then
        panels.leftStatusText:SetText(L["ITEMSEARCH_MIN_CHARS"])
    end
    -- Tab create/show must not walk ZoneDB/ItemDB/NPCDB on this frame.
    C_Timer.After(0, function()
        if not panels or not listAPI then
            return
        end
        RefreshItemList()
    end)

    -- A data source becoming queryable mid-session changes which filters are
    -- usable. Watch the data boundary (OneWoW:SignalDataReady, fired after the
    -- provider's OnPlayerLogin registers its data) rather than the load boundary
    -- (ns.FeatureStateChanged, which fires before registration). Registered here
    -- (not at file scope) because ns.ItemSearch is only populated once m-itemsearch
    -- has parsed; the once-flag keeps a single set of watchers across tab rebuilds,
    -- and they reference the module-level panels/refresh upvalues which always point
    -- at the live tab. The build-time UpdateSourceButtonStates above covers a tab
    -- opened after sources were ready, so a catch-up landing while panels==nil is a
    -- safe no-op.
    if not dataReadyWatchersRegistered then
        dataReadyWatchersRegistered = true
        for _, addon in ipairs(ns.ItemSearch.GetSourceAddons()) do
            OneWoW:RegisterDataReadyWatcher(addon, function()
                if not panels then return end
                if UpdateSourceButtonStates() then
                    RefreshItemList()
                end
            end)
        end
    end

    ns.UI.RefreshItemSearchList = RefreshItemList

    function ns.UI.OpenItemSearch(itemID, itemName, retryCount)
        if not searchBox or not panels then
            -- The tab can be mid-construction when another tab links here;
            -- retry briefly, then give up rather than polling forever.
            retryCount = (retryCount or 0) + 1
            if retryCount <= 10 then
                C_Timer.After(0.05, function()
                    ns.UI.OpenItemSearch(itemID, itemName, retryCount)
                end)
            end
            return
        end

        itemID = tonumber(itemID)
        if itemID then
            OneWoW.UI:CommitNavEntity("item", itemID)
        end
        local query = itemID and tostring(itemID) or itemName or ""

        currentSource = "all"
        currentSearch = query
        selectedItem = nil
        ns.ItemSearch.EnsureFilterPacks(currentSource)

        UpdateSourceButtonStates()
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        suppressSearchBoxChange = true
        searchBox:SetText(query)
        suppressSearchBoxChange = false
        RefreshItemList()

        if itemID then
            SelectVisibleItemResult(itemID)
            ns.GetItemDataLoader():LoadItemData(itemID, function(_, itemData)
                if currentSearch ~= tostring(itemID) then
                    return
                end
                if selectedItem and selectedItem.itemID == itemID then
                    ApplyLoadedItemData(selectedItem, itemData)
                end
                RefreshItemList()
                SelectVisibleItemResult(itemID)
            end)
            C_Timer.After(0.05, function()
                if currentSearch == tostring(itemID) then
                    SelectVisibleItemResult(itemID)
                end
            end)
        end
    end

    function parent.Activate()
        ns.ItemSearch.EnsureFilterPacks(currentSource)
        if UpdateSourceButtonStates() then
            RefreshItemList()
        end
    end

    function parent.GetNavEntity()
        if selectedItem and selectedItem.itemID then
            return "item", selectedItem.itemID
        end
    end

    function parent.RestoreNavEntity(kind, id)
        if kind ~= "item" then
            return
        end
        SelectVisibleItemResult(id)
    end
end

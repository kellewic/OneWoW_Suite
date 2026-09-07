local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local SE = OneWoW.SearchExpand

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function MatchesShoppingSearch(searchText, itemID, itemLink, displayName, quantity)
    if not searchText or searchText == "" then return true end
    if itemID then
        local itemInfo = {
            hyperlink = itemLink,
            count = quantity or 1,
            quality = C_Item.GetItemQualityByID(itemID)
        }
        local ok, matched = pcall(SE.CheckItem, SE, searchText, itemID, nil, nil, itemInfo)
        if ok then return matched == true end
    end
    return displayName and displayName:lower():find(searchText:lower(), 1, true) ~= nil
end

ns.MainWindow = {}
local MainWindow = ns.MainWindow

local C = ns.Constants

local POOL_SIZE   = 32
local listRowPool = {}
local itemRows    = {}

local mainFrame
local sidebarPanel
local contentPanel
local settingsPanel
local searchBox
local searchAltsBtn
local statusLabel
local searchFilter   = ""
local searchAltsOn   = false
local inSettingsView = false
local contentHeaderFrame
local addButtonRowFrame
local newListBtn
local windowMode = "shopping"
local selectedFarmItemID
local tabShoppingBtn
local tabFarmingBtn
local farmAddByIdBtn
local shoppingSidebarScroll
local farmSidebarScrollContainer
local farmDetailPanel
local farmDetail
local farmRowPool = {}
local farmHeaderPool = {}
local FARM_POOL_SIZE = 48
local FARM_HEADER_POOL_SIZE = 16

local function GetDB()
    return ns.db
end

local function GetSettings()
    return GetDB().global.settings
end

local function HideAllRows(pool)
    for _, row in ipairs(pool) do
        row:Hide()
        row:ClearAllPoints()
    end
end

local function PaintShoppingSidebarRow(row, hover)
    if row.data and row.data.isSelected then
        OneWoW_GUI:ApplyListRowFill(row, { selected = true })
    elseif hover then
        OneWoW_GUI:ApplyListRowFill(row, { hover = true })
    else
        OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = row._zebraIndex })
    end
end

local function CreateListRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(32)
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row._zebraIndex = 1
    OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = 1 })
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    row.starBtn = CreateFrame("Button", nil, row)
    row.starBtn:SetSize(16, 16)
    row.starBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.starTex = row.starBtn:CreateTexture(nil, "OVERLAY")
    row.starTex:SetAllPoints()
    row.starTex:SetAtlas("VignetteKill")
    row.starTex:SetAlpha(0.3)
    row.starBtn:SetNormalTexture(row.starTex)
    row.starBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OWSL_TT_DEFAULT_LIST"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_DEFAULT_LIST_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    row.starBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.favBtn = OneWoW_GUI:CreateFavoriteToggleButton(row, {
        size = 16,
        favorite = false,
        tooltipTitle = L["OWSL_TT_FAVORITE_LIST"],
        tooltipText = L["OWSL_TT_FAVORITE_LIST_DESC"],
        onClick = function(btn, isFav)
            local r = btn:GetParent()
            if r and r.data and r.data.listName then
                ns.ShoppingList:SetListFavorite(r.data.listName, isFav)
                MainWindow:RefreshSidebar()
            end
        end,
    })
    row.favBtn:SetPoint("LEFT", row.starBtn, "RIGHT", 2, 0)

    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(14, 14)
    row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    local delTex = row.deleteBtn:CreateTexture(nil, "OVERLAY")
    delTex:SetAllPoints()
    delTex:SetAtlas("common-icon-redx")
    row.deleteBtn:SetNormalTexture(delTex)
    row.deleteBtn:GetNormalTexture():SetAlpha(0.5)
    row.deleteBtn:SetScript("OnEnter", function(self) self:GetNormalTexture():SetAlpha(1.0) end)
    row.deleteBtn:SetScript("OnLeave", function(self)
        self:GetNormalTexture():SetAlpha(0.5)
        if not row:IsMouseOver() then
            self:Hide()
            if not row.data or not row.data.isSelected then
                PaintShoppingSidebarRow(row, false)
            end
        end
    end)
    row.deleteBtn:Hide()

    row.nameText = OneWoW_GUI:CreateFS(row, 12)
    row.nameText:SetPoint("LEFT",  row, "LEFT",  40, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    row.countText = OneWoW_GUI:CreateFS(row, 10)
    row.countText:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    row.countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    row.selectedBar = row:CreateTexture(nil, "ARTWORK")
    row.selectedBar:SetWidth(3)
    row.selectedBar:SetPoint("LEFT",   row, "LEFT",   0, 0)
    row.selectedBar:SetPoint("TOP",    row, "TOP",    0, 0)
    row.selectedBar:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
    row.selectedBar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    row.selectedBar:Hide()

    row:SetScript("OnEnter", function(self)
        PaintShoppingSidebarRow(self, true)
    end)
    row:SetScript("OnLeave", function(self)
        PaintShoppingSidebarRow(self, false)
    end)

    row.data = {}
    return row
end

local function PaintFarmRow(row, hover)
    if row.data and row.data.isSelected then
        OneWoW_GUI:ApplyListRowFill(row, { selected = true })
    elseif hover then
        OneWoW_GUI:ApplyListRowFill(row, { hover = true })
    else
        OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = row._zebraIndex })
    end
end

local function CreateFarmGroupHeader(parent)
    local h = OneWoW_GUI:CreateFrame(parent, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    h:SetHeight(26)
    h.title = OneWoW_GUI:CreateFS(h, 12)
    h.title:SetPoint("LEFT", 8, 0)
    h.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    h.count = OneWoW_GUI:CreateFS(h, 10)
    h.count:SetPoint("RIGHT", -8, 0)
    h.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    h:Hide()
    return h
end

local function CreateFarmItemRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(28)
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row._zebraIndex = 1
    OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = 1 })
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.statusBar = row:CreateTexture(nil, "ARTWORK")
    row.statusBar:SetWidth(4)
    row.statusBar:SetPoint("LEFT",   row, "LEFT",   0, 0)
    row.statusBar:SetPoint("TOP",    row, "TOP",    0, 0)
    row.statusBar:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.statusBar, "RIGHT", 4, 0)

    row.nameText = OneWoW_GUI:CreateFS(row, 11)
    row.nameText:SetPoint("LEFT",  row.icon, "RIGHT", 6, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -36, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    row.qtyText = OneWoW_GUI:CreateFS(row, 10)
    row.qtyText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.qtyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    row:SetScript("OnEnter", function(myself)
        PaintFarmRow(myself, true)
    end)
    row:SetScript("OnLeave", function(myself)
        PaintFarmRow(myself, false)
    end)

    row.data = {}
    row:Hide()
    return row
end

local function ConfigureListRow(row, listName, isSelected, isDefault, childCount, zebraIndex)
    row:Show()
    row.data.listName   = listName
    row.data.isSelected = isSelected
    row.data.isDefault  = isDefault
    row._zebraIndex     = zebraIndex or 1

    local list = ns.ShoppingList:GetList(listName)
    local displayName = listName

    if list and list.isCraftOrder then
        local prefix = "Craft: "
        displayName = listName:sub(#prefix + 1)
    end

    row.nameText:SetText(displayName)
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local totalItems = 0
    if list and list.items then
        for _ in pairs(list.items) do totalItems = totalItems + 1 end
    end
    if list and list.unresolvedItems then
        for _ in pairs(list.unresolvedItems) do totalItems = totalItems + 1 end
    end

    if childCount and childCount > 0 then
        row.countText:SetText(string.format("(%d+%d)", totalItems, childCount))
    else
        row.countText:SetText(tostring(totalItems))
    end

    if isSelected then
        PaintShoppingSidebarRow(row, false)
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        row.selectedBar:Show()
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        PaintShoppingSidebarRow(row, false)
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.selectedBar:Hide()
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    row.starTex:Show()
    row.starTex:SetAlpha(isDefault and 1.0 or 0.3)

    if row.favBtn then
        row.favBtn:SetFavorite(ns.ShoppingList:IsListFavorite(listName))
    end

    if list and list.isCraftOrder then
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
    end
end

function MainWindow:Create()
    if mainFrame then return end

    mainFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name     = "OneWoW_ShoppingList_MainFrame",
        width    = C.GUI.WINDOW_WIDTH,
        height   = C.GUI.WINDOW_HEIGHT,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    mainFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    mainFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    if not OneWoW_GUI:RestoreWindowPosition(mainFrame, GetDB().global.mainFramePosition) then
        mainFrame:SetPoint("CENTER")
    end
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(myself) myself:StartMoving() end)
    mainFrame:SetScript("OnDragStop",  function(myself) myself:StopMovingOrSizing() end)
    mainFrame:SetScript("OnHide", function()
        OneWoW_GUI:SaveWindowPosition(mainFrame, GetDB().global.mainFramePosition)
    end)
    mainFrame:Hide()

    tinsert(UISpecialFrames, "OneWoW_ShoppingList_MainFrame")

    local titleBar = OneWoW_GUI:CreateTitleBar(mainFrame, {
        title     = L["OWSL_WINDOW_TITLE"],
        showBrand = true,
        onClose   = function() mainFrame:Hide() end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() mainFrame:StopMovingOrSizing() end)

    local settingsToggleBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = SETTINGS, height = 16 })
    settingsToggleBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -6, 0)
    settingsToggleBtn:SetScript("OnClick", function() MainWindow:ToggleSettings() end)

    local tabBar = CreateFrame("Frame", nil, mainFrame)
    tabBar:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  4, -28)
    tabBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -28)
    tabBar:SetHeight(C.GUI.TAB_STRIP_HEIGHT)

    tabShoppingBtn = OneWoW_GUI:CreateFitTextButton(tabBar, { text = L["OWSL_TAB_SHOPPING"], height = 22 })
    tabShoppingBtn:SetPoint("LEFT", tabBar, "LEFT", 0, 0)
    tabShoppingBtn:SetScript("OnClick", function() MainWindow:SetWindowMode("shopping") end)
    tabShoppingBtn:SetScript("OnLeave", function(myself)
        if windowMode == "shopping" then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    tabFarmingBtn = OneWoW_GUI:CreateFitTextButton(tabBar, { text = L["FARMING"], height = 22 })
    tabFarmingBtn:SetPoint("LEFT", tabShoppingBtn, "RIGHT", 6, 0)
    tabFarmingBtn:SetScript("OnClick", function() MainWindow:SetWindowMode("farming") end)
    tabFarmingBtn:SetScript("OnLeave", function(myself)
        if windowMode == "farming" then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    local sidebarW = C.GUI.SIDEBAR_WIDTH
    local dividerX = sidebarW + 4

    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT",    tabBar,    "BOTTOMLEFT", dividerX - 4, -2)
    divider:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", dividerX,      4)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    sidebarPanel = CreateFrame("Frame", nil, mainFrame)
    sidebarPanel:SetPoint("TOPLEFT",    tabBar,    "BOTTOMLEFT",  0, -2)
    sidebarPanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT",  4,  4)
    sidebarPanel:SetWidth(sidebarW)

    local sidebarHeader = OneWoW_GUI:CreateFrame(sidebarPanel, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    sidebarHeader:SetHeight(34)
    sidebarHeader:SetPoint("TOPLEFT",  sidebarPanel, "TOPLEFT",  0, 0)
    sidebarHeader:SetPoint("TOPRIGHT", sidebarPanel, "TOPRIGHT", 0, 0)

    newListBtn = OneWoW_GUI:CreateFitTextButton(sidebarHeader, { text = L["OWSL_BTN_NEW_LIST"], height = 22 })
    newListBtn:SetPoint("LEFT", sidebarHeader, "LEFT", 6, 0)
    newListBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_NEW_LIST"], "", function(name)
            if name == "" then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_LIST_NAME"])
                return
            end
            local ok, err = ns.ShoppingList:CreateList(name)
            if not ok then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. (err or ""))
            else
                ns.ShoppingList:SetActiveList(name)
                MainWindow:RefreshSidebar()
                MainWindow:RefreshItemList()
            end
        end)
    end)

    farmAddByIdBtn = OneWoW_GUI:CreateFitTextButton(sidebarHeader, { text = L["ADD_BY_ID"], height = 22 })
    farmAddByIdBtn:SetPoint("LEFT", sidebarHeader, "LEFT", 6, 0)
    farmAddByIdBtn:Hide()
    farmAddByIdBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_ADD_BY_ID"], "", function(val)
            local id = tonumber(val)
            if not id or id <= 0 then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
                return
            end
            local ok = ns.FarmList:AddItem(id, "farming")
            if ok then
                selectedFarmItemID = id
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, L["FARMING"]))
                MainWindow:RefreshFarmSidebar()
                MainWindow:RefreshFarmDetail()
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_INVALID_ITEM"])
            end
        end, L["OWSL_BTN_ADD"])
    end)

    shoppingSidebarScroll = CreateFrame("Frame", nil, sidebarPanel)
    shoppingSidebarScroll:SetPoint("TOPLEFT",     sidebarPanel, "TOPLEFT",     0, -34)
    shoppingSidebarScroll:SetPoint("BOTTOMRIGHT", sidebarPanel, "BOTTOMRIGHT", 0,   0)

    local sidebarScrollFrame, sidebarScrollContent = OneWoW_GUI:CreateScrollFrame(shoppingSidebarScroll, {})
    sidebarPanel.scrollFrame   = sidebarScrollFrame
    sidebarPanel.scrollContent = sidebarScrollContent

    for i = 1, POOL_SIZE do
        listRowPool[i] = CreateListRow(sidebarScrollContent)
    end

    farmSidebarScrollContainer = CreateFrame("Frame", nil, sidebarPanel)
    farmSidebarScrollContainer:SetPoint("TOPLEFT",     sidebarPanel, "TOPLEFT",     0, -34)
    farmSidebarScrollContainer:SetPoint("BOTTOMRIGHT", sidebarPanel, "BOTTOMRIGHT", 0,   0)
    farmSidebarScrollContainer:Hide()

    local farmScrollFrame, farmScrollContent = OneWoW_GUI:CreateScrollFrame(farmSidebarScrollContainer, {})
    sidebarPanel.farmScrollFrame   = farmScrollFrame
    sidebarPanel.farmScrollContent = farmScrollContent

    for i = 1, FARM_HEADER_POOL_SIZE do
        farmHeaderPool[i] = CreateFarmGroupHeader(farmScrollContent)
    end
    for i = 1, FARM_POOL_SIZE do
        farmRowPool[i] = CreateFarmItemRow(farmScrollContent)
    end

    contentPanel = CreateFrame("Frame", nil, mainFrame)
    contentPanel:SetPoint("TOPLEFT",     tabBar,    "BOTTOMLEFT",  dividerX - 3, -2)
    contentPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)

    local contentHeader = OneWoW_GUI:CreateFrame(contentPanel, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    contentHeader:SetHeight(34)
    contentHeader:SetPoint("TOPLEFT",  contentPanel, "TOPLEFT",  0, 0)
    contentHeader:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", 0, 0)

    local importBtn = OneWoW_GUI:CreateFitTextButton(contentHeader, { text = L["OWSL_BTN_IMPORT"], height = 22 })
    importBtn:SetPoint("RIGHT", contentHeader, "RIGHT", -4, 0)
    importBtn:SetScript("OnClick", function()
        ns.Dialogs:ImportDialog(function(text)
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok, count, nameOnly = ns.ShoppingList:ImportTextFormat(text, activeList)
            if ok then
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_IMPORTED_SUMMARY"], count - (nameOnly or 0), nameOnly or 0))
                if nameOnly and nameOnly > 0 then
                    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_BY_NAME_NOTE"], nameOnly))
                end
                MainWindow:RefreshItemList()
                if nameOnly and nameOnly > 0 then
                    C_Timer.After(0.5, function()
                        ns.ShoppingList:ScanUnresolvedItems(activeList)
                        MainWindow:RefreshItemList()
                    end)
                end
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. (count or L["OWSL_MSG_NO_VALID_ITEMS"]))
            end
        end, mainFrame)
    end)

    local scanBtn = OneWoW_GUI:CreateFitTextButton(contentHeader, { text = L["OWSL_BTN_SCAN_ALL"], height = 22 })
    scanBtn:SetPoint("RIGHT", importBtn, "LEFT", -4, 0)
    scanBtn:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["OWSL_TT_SCAN_ALL_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_SCAN_ALL_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["OWSL_TT_SCAN_ALL_AUTO"], 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine(L["OWSL_TT_SCAN_ALL_IMPORTANT"], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    scanBtn:SetScript("OnClick", function()
        local activeList = ns.ShoppingList:GetActiveListName()
        ns.ShoppingList:ScanUnresolvedItems(activeList)
        MainWindow:RefreshItemList()
    end)

    searchAltsBtn = OneWoW_GUI:CreateCheckbox(contentHeader, {})
    searchAltsBtn:SetPoint("RIGHT", scanBtn, "LEFT", -24, 0)
    searchAltsBtn:SetChecked(searchAltsOn)
    if searchAltsBtn.label then
        searchAltsBtn.label:ClearAllPoints()
        searchAltsBtn.label:SetPoint("RIGHT", searchAltsBtn, "LEFT", -2, 0)
        searchAltsBtn.label:SetText(L["OWSL_LABEL_SEARCH_ALTS"])
    end
    searchAltsBtn:SetScript("OnClick", function(myself)
        searchAltsOn = myself:GetChecked()
        local activeList = ns.ShoppingList:GetActiveListName()
        local list = ns.ShoppingList:GetList(activeList)
        if list then list.searchAlts = searchAltsOn end
        MainWindow:RefreshItemList()
    end)
    searchAltsBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["OWSL_LABEL_SEARCH_ALTS"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_SEARCH_ALTS_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    searchAltsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local searchRightAnchor = searchAltsBtn.label or searchAltsBtn
    local shopHelpBtn
    if OneWoW_GUI.CreateKeywordHelpButton then
        shopHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(contentHeader, { size = 20 })
        shopHelpBtn:SetPoint("RIGHT", searchRightAnchor, "LEFT", -8, 0)
        searchRightAnchor = shopHelpBtn
    end

    local searchLabel = OneWoW_GUI:CreateFS(contentHeader, 10)
    searchLabel:SetPoint("LEFT", contentHeader, "LEFT", 8, 0)
    searchLabel:SetText(L["OWSL_LABEL_SEARCH"])
    searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    searchBox = OneWoW_GUI:CreateEditBox(contentHeader, { name = "OWSL_SearchBox", height = 22 })
    searchBox:SetPoint("LEFT",  searchLabel,       "RIGHT", 4,  0)
    searchBox:SetPoint("RIGHT", searchRightAnchor, "LEFT",  -8, 0)
    searchBox:SetScript("OnTextChanged", function(myself, userInput)
        if userInput then
            searchFilter = myself:GetText():lower()
            MainWindow:RefreshItemList()
        end
    end)
    if OneWoW_GUI.AttachSearchTooltip then
        OneWoW_GUI:AttachSearchTooltip(searchBox)
    end

    if shopHelpBtn then
        shopHelpBtn:SetScript("OnClick", function()
            OneWoW_GUI:ShowKeywordHelp(searchBox)
        end)
    end

    contentHeaderFrame = contentHeader

    local addButtonRow = OneWoW_GUI:CreateFrame(contentPanel, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    addButtonRow:SetHeight(32)
    addButtonRow:SetPoint("BOTTOMLEFT",  contentPanel, "BOTTOMLEFT",  0, 0)
    addButtonRow:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", 0, 0)
    addButtonRowFrame = addButtonRow

    statusLabel = OneWoW_GUI:CreateFS(addButtonRow, 10)
    statusLabel:SetPoint("LEFT", addButtonRow, "LEFT", 8, 0)
    statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local dragBtn = OneWoW_GUI:CreateFitTextButton(addButtonRow, { text = L["DRAG_ITEM_HERE"], height = 24 })
    dragBtn:SetPoint("RIGHT", addButtonRow, "RIGHT", -4, 0)

    local function HandleDrop()
        local dragType, id = GetCursorInfo()
        if dragType == "item" then
            ClearCursor()
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = id and C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            end
        end
    end

    dragBtn:SetScript("OnReceiveDrag", HandleDrop)
    dragBtn:SetScript("OnClick",       HandleDrop)

    local addByIdBtn = OneWoW_GUI:CreateFitTextButton(addButtonRow, { text = L["ADD_BY_ID"], height = 24 })
    addByIdBtn:SetPoint("RIGHT", dragBtn, "LEFT", -4, 0)
    addByIdBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_ADD_BY_ID"], "", function(val)
            local id = tonumber(val)
            if not id or id <= 0 then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
                return
            end
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_INVALID_ITEM"])
            end
        end, L["OWSL_BTN_ADD"])
    end)

    local listContainer = CreateFrame("Frame", nil, contentPanel)
    listContainer:SetPoint("TOPLEFT",     contentHeader,  "BOTTOMLEFT",  0,  -2)
    listContainer:SetPoint("BOTTOMRIGHT", addButtonRow,   "TOPRIGHT",    0,   2)

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(listContainer, {})
    contentPanel.listContainer  = listContainer
    contentPanel.scrollFrame    = scrollFrame
    contentPanel.scrollContent  = scrollContent

    self:BuildSettingsPanel()
    self:BuildFarmDetailPanel()
    self:RegisterDragDrop(mainFrame)
    self:ApplyWindowMode()

    ns.ShoppingList:SetActiveList(ns.ShoppingList:GetActiveListName())
end

function MainWindow:BuildSettingsPanel()
    settingsPanel = OneWoW_GUI:CreateFrame(contentPanel, {
        backdrop    = OneWoW_GUI.Constants.BACKDROP_SOFT,
        bgColor     = "BG_PRIMARY",
        borderColor = "BORDER_DEFAULT",
    })
    settingsPanel:SetAllPoints(contentPanel)
    settingsPanel:Hide()

    local settingsTitle = OneWoW_GUI:CreateFS(settingsPanel, 16)
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 12, -12)
    settingsTitle:SetText(SETTINGS)
    settingsTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local backBtn = OneWoW_GUI:CreateFitTextButton(settingsPanel, { text = BACK, height = 24 })
    backBtn:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -12)
    backBtn:SetScript("OnClick", function() MainWindow:ToggleSettings() end)

    local settingsScrollContainer = CreateFrame("Frame", nil, settingsPanel)
    settingsScrollContainer:SetPoint("TOPLEFT",     settingsPanel, "TOPLEFT",     0, -40)
    settingsScrollContainer:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", 0,   0)

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(settingsScrollContainer, {})

    local pad  = 12
    local yOff = -pad

    local curS = GetSettings()

    local tooltipCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_ENABLE_TOOLTIP"] })
    tooltipCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    tooltipCb:SetChecked(curS.enableTooltips)
    tooltipCb:SetScript("OnClick", function(myself)
        GetSettings().enableTooltips = myself:GetChecked()
    end)
    yOff = yOff - 26

    local wrapNamesCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_WRAP_NAMES"] })
    wrapNamesCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    wrapNamesCb:SetChecked(curS.wrapItemNames ~= false)
    wrapNamesCb:SetScript("OnClick", function(myself)
        GetSettings().wrapItemNames = myself:GetChecked()
        MainWindow:RefreshItemList()
    end)
    wrapNamesCb:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OWSL_SETTINGS_WRAP_NAMES"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_SETTINGS_WRAP_NAMES_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    wrapNamesCb:HookScript("OnLeave", function() GameTooltip:Hide() end)
    yOff = yOff - 26

    local bagBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_BAG_BUTTONS"] })
    bagBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    bagBtnCb:SetChecked(curS.showBagButtons ~= false)
    bagBtnCb:SetScript("OnClick", function(myself)
        GetSettings().showBagButtons = myself:GetChecked()
        ns.BagButton:UpdateVisibility()
    end)
    yOff = yOff - 26

    local profBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_PROF_BUTTONS"] })
    profBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    profBtnCb:SetChecked(curS.showProfessionButtons ~= false)
    profBtnCb:SetScript("OnClick", function(myself)
        GetSettings().showProfessionButtons = myself:GetChecked()
        ns.ProfessionUI:UpdateVisibility()
    end)
    yOff = yOff - 26

    local ordersBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_ORDERS_BUTTONS"] })
    ordersBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    ordersBtnCb:SetChecked(curS.showOrdersButtons ~= false)
    ordersBtnCb:SetScript("OnClick", function(myself)
        GetSettings().showOrdersButtons = myself:GetChecked()
        if ns.OrdersUI and ns.OrdersUI.UpdateVisibility then
            ns.OrdersUI:UpdateVisibility()
        end
    end)
    yOff = yOff - 26

    local ahBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_AH_BUTTON"] })
    ahBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    ahBtnCb:SetChecked(curS.showAHButton ~= false)
    ahBtnCb:SetScript("OnClick", function(myself)
        GetSettings().showAHButton = myself:GetChecked()
        ns.BagButton:UpdateAHVisibility()
    end)
    yOff = yOff - 30

    local function AddSectionHeader(text, y)
        local h = OneWoW_GUI:CreateFS(scrollContent, 11)
        h:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        h:SetText(text)
        h:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        return h
    end

    AddSectionHeader(L["OWSL_SETTINGS_CONFIRMATIONS"], yOff)
    yOff = yOff - 22

    local confirmItemCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_CONFIRM_ITEM_DELETE"] })
    confirmItemCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    confirmItemCb:SetChecked(curS.confirmItemDelete ~= false)
    confirmItemCb:SetScript("OnClick", function(myself)
        GetSettings().confirmItemDelete = myself:GetChecked()
    end)
    yOff = yOff - 26

    local confirmListCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_CONFIRM_LIST_DELETE"] })
    confirmListCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    confirmListCb:SetChecked(curS.confirmListDelete ~= false)
    confirmListCb:SetScript("OnClick", function(myself)
        GetSettings().confirmListDelete = myself:GetChecked()
    end)
    yOff = yOff - 30

    local function SetStatusText(status, detected)
        if detected then
            status:SetText(L["OWSL_SETTINGS_DETECTED"])
            status:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            status:SetText(L["OWSL_SETTINGS_NOT_DETECTED"])
            status:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    local function AddStatusRow(labelText, detected, y)
        local lbl = OneWoW_GUI:CreateFS(scrollContent, 12)
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local status = OneWoW_GUI:CreateFS(scrollContent, 12)
        status:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 220, y)
        SetStatusText(status, detected)
        return status
    end

    AddSectionHeader(L["OWSL_SETTINGS_ADDON_STATUS"], yOff)
    yOff = yOff - 22

    local altStatus = AddStatusRow(L["OWSL_SETTINGS_ALT_ACCESS"], ns.DataAccess:HasAltData(), yOff); yOff = yOff - 20
    local warbandStatus = AddStatusRow(L["OWSL_SETTINGS_WARBAND_ACCESS"], ns.DataAccess:HasAltData(), yOff); yOff = yOff - 20
    local recipeStatus = AddStatusRow(L["OWSL_SETTINGS_RECIPE_DATA"], ns.DataAccess:HasRecipeData(), yOff); yOff = yOff - 24

    function MainWindow:RefreshAddonStatus()
        if not altStatus then return end
        local hasAlt = ns.DataAccess:HasAltData()
        SetStatusText(altStatus, hasAlt)
        SetStatusText(warbandStatus, hasAlt)
        SetStatusText(recipeStatus, ns.DataAccess:HasRecipeData())
    end

    AddSectionHeader(L["OWSL_SETTINGS_KEYBINDS"], yOff)
    yOff = yOff - 22

    local function AddKeybindRow(labelText, bindingName, y)
        local lbl = OneWoW_GUI:CreateFS(scrollContent, 12)
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local binding = GetBindingKey(bindingName)
        local bVal = OneWoW_GUI:CreateFS(scrollContent, 12)
        bVal:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 220, y)
        bVal:SetText(binding or NOT_BOUND)
        if binding then
            bVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            bVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    AddKeybindRow(L["OWSL_SETTINGS_TOGGLE_KEY"],   "ONEWOW_SHOPPING_LIST_TOGGLE",   yOff); yOff = yOff - 20
    AddKeybindRow(L["OWSL_SETTINGS_ADD_ITEM_KEY"], "ONEWOW_SHOPPING_LIST_ADD_ITEM", yOff); yOff = yOff - 20

    local bindInfoLabel = OneWoW_GUI:CreateFS(scrollContent, 10)
    bindInfoLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    bindInfoLabel:SetText(L["OWSL_SETTINGS_KEYBIND_INFO"])
    bindInfoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    scrollContent:SetHeight(math.abs(yOff) + 20)
end

function MainWindow:Rebuild()
    if mainFrame then mainFrame:Hide() end
    mainFrame          = nil
    sidebarPanel       = nil
    contentPanel       = nil
    settingsPanel      = nil
    contentHeaderFrame = nil
    addButtonRowFrame  = nil
    newListBtn         = nil
    tabShoppingBtn     = nil
    tabFarmingBtn      = nil
    farmAddByIdBtn     = nil
    shoppingSidebarScroll = nil
    farmSidebarScrollContainer = nil
    farmDetailPanel    = nil
    farmDetail         = nil
    farmHeaderPool     = {}
    searchBox          = nil
    searchAltsBtn      = nil
    statusLabel        = nil
    inSettingsView     = false
    listRowPool        = {}
    itemRows           = {}
    farmRowPool        = {}
end

function MainWindow:ShowSettings()
    self:Show()
    if not inSettingsView then self:ToggleSettings() end
end

function MainWindow:ToggleSettings()
    inSettingsView = not inSettingsView
    if inSettingsView then
        settingsPanel:Show()
        if self.RefreshAddonStatus then
            self:RefreshAddonStatus()
        end
        if contentPanel.listContainer then contentPanel.listContainer:Hide() end
        if contentPanel.scrollFrame   then contentPanel.scrollFrame:Hide() end
        if contentHeaderFrame         then contentHeaderFrame:Hide() end
        if addButtonRowFrame          then addButtonRowFrame:Hide() end
        if farmDetailPanel            then farmDetailPanel:Hide() end
    else
        settingsPanel:Hide()
        self:ApplyWindowMode()
    end
end

function MainWindow:RegisterDragDrop(frame)
    frame:SetScript("OnReceiveDrag", function()
        local dragType, id = GetCursorInfo()
        if dragType ~= "item" then return end
        ClearCursor()
        if windowMode == "farming" then
            local ok = ns.FarmList:AddItem(id, "farming")
            if ok then
                selectedFarmItemID = id
                local name = id and C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, L["FARMING"]))
                MainWindow:RefreshFarmSidebar()
                MainWindow:RefreshFarmDetail()
            end
            return
        end
        local activeList = ns.ShoppingList:GetActiveListName()
        local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
        if ok then
            local name = id and C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
            print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
            MainWindow:RefreshItemList()
        end
    end)
end

function MainWindow:RefreshSidebar()
    if windowMode == "farming" then
        self:RefreshFarmSidebar()
        return
    end
    if not sidebarPanel then return end

    HideAllRows(listRowPool)

    local allLists    = ns.ShoppingList:GetAllLists()
    local activeList  = ns.ShoppingList:GetActiveListName()
    local defaultList = ns.ShoppingList:GetDefaultListName()

    local parentLists = {}
    local childrenOf  = {}

    for listName, listData in pairs(allLists) do
        if listData.parentList then
            childrenOf[listData.parentList] = childrenOf[listData.parentList] or {}
            table.insert(childrenOf[listData.parentList], listName)
        else
            table.insert(parentLists, listName)
        end
    end

    table.sort(parentLists, function(a, b)
        if a == defaultList then return true end
        if b == defaultList then return false end
        local fa = ns.ShoppingList:IsListFavorite(a)
        local fb = ns.ShoppingList:IsListFavorite(b)
        if fa ~= fb then return fa end
        if a == ns.MAIN_LIST_KEY then return true end
        if b == ns.MAIN_LIST_KEY then return false end
        return a < b
    end)

    local scrollContent = sidebarPanel.scrollContent
    local rowIdx  = 1
    local yOff    = 0

    local INDENT   = { [0] = 0,  [1] = 16, [2] = 28, [3] = 40 }
    local HEIGHT   = { [0] = 32, [1] = 28, [2] = 26, [3] = 24 }
    local YADVANCE = { [0] = 34, [1] = 30, [2] = 28, [3] = 26 }
    local MAX_DEPTH = 3

    local function RenderListEntry(listName, depth)
        if rowIdx > POOL_SIZE then return end

        local row        = listRowPool[rowIdx]
        local isSelected = (listName == activeList)
        local isDefault  = (depth == 0) and (listName == defaultList)
        local childCount = childrenOf[listName] and #childrenOf[listName] or 0
        ConfigureListRow(row, listName, isSelected, isDefault, childCount, rowIdx)

        local indent   = INDENT[depth]   or 40
        local height   = HEIGHT[depth]   or 24
        local yAdvance = YADVANCE[depth] or 26

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  indent, -yOff)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0,      -yOff)
        row:SetHeight(height)

        if depth > 0 then
            row.starBtn:Hide()
            row.favBtn:ClearAllPoints()
            row.favBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.nameText:SetPoint("LEFT", row, "LEFT", 24, 0)
        else
            row.starBtn:Show()
            row.favBtn:ClearAllPoints()
            row.favBtn:SetPoint("LEFT", row.starBtn, "RIGHT", 2, 0)
            row.nameText:SetPoint("LEFT", row, "LEFT", 40, 0)
        end

        local capturedName = listName

        row:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then
                MainWindow:ShowListContextMenu(capturedName)
            else
                ns.ShoppingList:SetActiveList(capturedName)
                local curList = ns.ShoppingList:GetList(capturedName)
                searchAltsOn = curList and curList.searchAlts or false
                if searchAltsBtn then searchAltsBtn:SetChecked(searchAltsOn) end
                MainWindow:RefreshSidebar()
                MainWindow:RefreshItemList()
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        if depth == 0 then
            row.starBtn:SetScript("OnClick", function()
                ns.ShoppingList:SetDefaultList(capturedName)
                MainWindow:RefreshSidebar()
            end)
        end

        if capturedName ~= ns.MAIN_LIST_KEY then
            row.deleteBtn:SetScript("OnClick", function()
                if GetSettings().confirmListDelete == false then
                    ns.ShoppingList:DeleteList(capturedName)
                    MainWindow:RefreshSidebar()
                    MainWindow:RefreshItemList()
                    return
                end
                ns.Dialogs:ConfirmDialog(
                    string.format(L["OWSL_DIALOG_DELETE_CONFIRM"], capturedName),
                    L["OWSL_DIALOG_DELETE_CONFIRM2"],
                    function()
                        ns.ShoppingList:DeleteList(capturedName)
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    end,
                    DELETE,
                    mainFrame,
                    {
                        showDontAskAgain = true,
                        onDontAskAgain = function()
                            GetSettings().confirmListDelete = false
                        end,
                    }
                )
            end)
        else
            row.deleteBtn:SetScript("OnClick", nil)
        end

        row:SetScript("OnEnter", function(myself)
            PaintShoppingSidebarRow(myself, true)
            if myself.deleteBtn and capturedName ~= ns.MAIN_LIST_KEY then
                myself.deleteBtn:Show()
            end
        end)
        row:SetScript("OnLeave", function(myself)
            PaintShoppingSidebarRow(myself, false)
            if myself.deleteBtn and not myself.deleteBtn:IsMouseOver() then
                myself.deleteBtn:Hide()
            end
        end)

        row:Show()
        rowIdx = rowIdx + 1
        yOff   = yOff + yAdvance

        if depth < MAX_DEPTH then
            local children = childrenOf[listName]
            if children then
                table.sort(children)
                for _, childName in ipairs(children) do
                    RenderListEntry(childName, depth + 1)
                end
            end
        end
    end

    for _, listName in ipairs(parentLists) do
        RenderListEntry(listName, 0)
    end

    scrollContent:SetHeight(math.max(yOff + 4, 1))
end

function MainWindow:RefreshItemList()
    if windowMode == "farming" then
        self:RefreshFarmSidebar()
        self:RefreshFarmDetail()
        return
    end
    local scrollContent = contentPanel and contentPanel.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(itemRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(itemRows)

    local activeList = ns.ShoppingList:GetActiveListName()
    local list       = ns.ShoppingList:GetList(activeList)

    if not list then
        scrollContent:SetHeight(1)
        return
    end

    local items = {}

    for itemID, itemInfo in pairs(list.items or {}) do
        local displayName = C_Item.GetItemNameByID(itemID)
        if not displayName then
            C_Item.RequestLoadItemDataByID(itemID)
            displayName = string.format(L["OWSL_ITEM_PREFIX"], itemID)
        end
        local _, itemLink, _, _, _, _, _, _, _, iconFile = C_Item.GetItemInfo(itemID)
        if MatchesShoppingSearch(searchFilter, itemID, itemLink, displayName, itemInfo.quantity) then
            local status               = ns.ShoppingList:GetItemStatus(itemID, activeList)
            local isCraftable, recipes = ns.ShoppingList:IsItemCraftable(itemID)
            table.insert(items, {
                key          = tostring(itemID),
                itemID       = itemID,
                displayName  = displayName,
                quantity     = itemInfo.quantity,
                icon         = iconFile,
                itemLink     = itemLink,
                status       = status,
                isCraftable  = isCraftable,
                recipes      = recipes,
                isUnresolved = false,
            })
        end
    end

    for uid, unresolvedItem in pairs(list.unresolvedItems or {}) do
        local name = unresolvedItem.itemName
        if searchFilter == "" or (name and name:lower():find(searchFilter, 1, true)) then
            table.insert(items, {
                key          = uid,
                itemID       = nil,
                displayName  = name,
                quantity     = unresolvedItem.quantity,
                icon         = "Interface\\Icons\\INV_Misc_QuestionMark",
                status       = nil,
                isCraftable  = false,
                isUnresolved = true,
            })
        end
    end

    table.sort(items, function(a, b)
        if a.isUnresolved ~= b.isUnresolved then return b.isUnresolved end
        if a.status and b.status then
            local priority = { red = 0, yellow = 1, blue = 2, green = 3 }
            local pa = priority[a.status.status] or 0
            local pb = priority[b.status.status] or 0
            if pa ~= pb then return pa < pb end
        end
        return (a.displayName or "") < (b.displayName or "")
    end)

    local rowHeight = 32
    local rowGap    = 2
    local yOffset   = -2
    local wrapNames = GetSettings().wrapItemNames ~= false

    local function RepositionAllRows()
        local y = -2
        for _, r in ipairs(itemRows) do
            local rH = r.customHeight or rowHeight
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, y)
            r:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
            y = y - (rH + rowGap)
            if r.isExpanded and r.expandedFrame and r.expandedFrame:IsShown() then
                y = y - (r.expandedFrame:GetHeight() + rowGap)
            end
        end
        scrollContent:SetHeight(math.abs(y) + 10)
    end

    for i, itemData in ipairs(items) do
        local capturedData  = itemData
        local capturedListN = activeList

        local row = OneWoW_GUI:CreateFrame(scrollContent, {
            bgColor     = "BG_TERTIARY",
        })
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        row:SetHeight(rowHeight)
        row:EnableMouse(true)
        row._zebraIndex = i
        OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = i })

        local statusBar = CreateFrame("Button", nil, row)
        statusBar:SetWidth(6)
        statusBar:SetPoint("LEFT",   row, "LEFT",   0, 0)
        statusBar:SetPoint("TOP",    row, "TOP",    0, 0)
        statusBar:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
        local statusBarTex = statusBar:CreateTexture(nil, "ARTWORK")
        statusBarTex:SetAllPoints()

        local iconFrame = CreateFrame("Button", nil, row)
        iconFrame:SetSize(rowHeight - 4, rowHeight - 4)
        iconFrame:SetPoint("LEFT", statusBar, "RIGHT", 4, 0)

        local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        iconTex:SetTexture(itemData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        if capturedData.itemLink then
            iconFrame:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(capturedData.itemLink)
                GameTooltip:Show()
            end)
            iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        local nameText = OneWoW_GUI:CreateFS(row, 12)
        nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        nameText:SetWidth(150)
        nameText:SetJustifyH("LEFT")
        if wrapNames then
            nameText:SetWordWrap(true)
            nameText:SetNonSpaceWrap(true)
            nameText:SetMaxLines(2)
        else
            nameText:SetWordWrap(false)
            nameText:SetNonSpaceWrap(false)
        end
        nameText:SetText(itemData.displayName)

        if wrapNames then
            local nameH      = nameText:GetStringHeight() or 0
            local neededRowH = math.ceil(nameH) + 8
            if neededRowH > rowHeight then
                row:SetHeight(neededRowH)
                row.customHeight = neededRowH
            end
        end

        local qtyBox = OneWoW_GUI:CreateEditBox(row, { width = 45, height = 20 })
        qtyBox:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
        qtyBox:SetNumeric(true)
        qtyBox:SetMaxLetters(5)
        qtyBox:SetJustifyH("CENTER")
        qtyBox:SetText(tostring(itemData.quantity or 1))

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(18, 18)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        local removeTex = removeBtn:CreateTexture(nil, "OVERLAY")
        removeTex:SetAllPoints()
        removeTex:SetAtlas("common-icon-redx")
        removeBtn:SetNormalTexture(removeTex)
        removeBtn:GetNormalTexture():SetAlpha(0.5)
        removeBtn:SetScript("OnEnter", function(myself) myself:GetNormalTexture():SetAlpha(1.0) end)
        removeBtn:SetScript("OnLeave", function(myself) myself:GetNormalTexture():SetAlpha(0.5) end)

        if itemData.isUnresolved then
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            statusBarTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local idLabel = OneWoW_GUI:CreateFS(row, 10)
            idLabel:SetPoint("LEFT", qtyBox, "RIGHT", 6, 0)
            idLabel:SetText(L["ID"])
            idLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local idBox = OneWoW_GUI:CreateEditBox(row, { width = 55, height = 20 })
            idBox:SetPoint("LEFT", idLabel, "RIGHT", 4, 0)
            idBox:SetNumeric(true)
            idBox:SetMaxLetters(6)
            idBox:SetScript("OnEnterPressed", function(myself)
                local idVal = tonumber(myself:GetText())
                if idVal and idVal > 0 then
                    local ok, name = ns.ShoppingList:ConvertUnresolvedToResolved(
                        capturedListN, capturedData.key, idVal)
                    if ok then
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_RESOLVED"], capturedData.displayName, name, idVal))
                        MainWindow:RefreshItemList()
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
                    end
                else
                    print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
                end
                myself:ClearFocus()
            end)

            qtyBox:SetScript("OnEnterPressed", function(myself)
                local qty = tonumber(myself:GetText()) or 0
                if qty > 0 then
                    ns.ShoppingList:UpdateUnresolvedQuantity(capturedListN, capturedData.key, qty)
                    myself:ClearFocus()
                    MainWindow:RefreshItemList()
                else
                    myself:SetText(tostring(capturedData.quantity))
                    myself:ClearFocus()
                end
            end)
            removeBtn:SetScript("OnClick", function()
                ns.ShoppingList:RemoveUnresolvedItem(capturedListN, capturedData.key)
                MainWindow:RefreshItemList()
            end)
        else
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local status = itemData.status
            if status then
                local r, g, b = unpack(status.statusColor)
                statusBarTex:SetColorTexture(r, g, b, 1)
            else
                statusBarTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end

            local locations = status and status.locations or {}

            local statusBtn = CreateFrame("Button", nil, row)
            statusBtn:SetHeight(rowHeight)
            statusBtn:SetPoint("LEFT",  qtyBox,     "RIGHT", 4,    0)
            statusBtn:SetPoint("RIGHT", removeBtn,  "LEFT",  -60,  0)
            local statusText = OneWoW_GUI:CreateFS(statusBtn, 10)
            statusText:SetPoint("LEFT", statusBtn, "LEFT", 4, 0)
            statusText:SetJustifyH("LEFT")
            if status then
                local r, g, b = unpack(status.statusColor)
                statusText:SetTextColor(r, g, b)
                if searchAltsOn then
                    statusText:SetText(string.format(L["OWSL_STATUS_ALTS"], status.totalOwned, status.needed))
                else
                    statusText:SetText(string.format(L["OWSL_STATUS_TOTAL"], status.owned, status.needed))
                end
            end

            if #locations > 0 then
                statusBtn:SetScript("OnEnter", function(myself)
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(capturedData.displayName, 1, 0.82, 0)
                    for _, locStr in ipairs(locations) do
                        GameTooltip:AddLine(locStr, 1, 1, 1)
                    end
                    GameTooltip:Show()
                end)
                statusBtn:SetScript("OnLeave", function()
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    GameTooltip:Hide()
                end)
            end

            local function ToggleExpanded()
                if #locations == 0 then return end
                row.isExpanded = not row.isExpanded
                if row.isExpanded then
                    if not row.expandedFrame then
                        row.expandedFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
                        row.expandedFrame:SetPoint("TOPLEFT",  row, "BOTTOMLEFT",  6, -2)
                        row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                        row.expandedFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
                        row.expandedFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

                        local locY = -6
                        for _, locStr in ipairs(locations) do
                            local locText = OneWoW_GUI:CreateFS(row.expandedFrame, 10)
                            locText:SetPoint("TOPLEFT", row.expandedFrame, "TOPLEFT", 12, locY)
                            locText:SetText(locStr)
                            locText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                            locY = locY - 16
                        end
                        row.expandedFrame:SetHeight(math.abs(locY) + 6)
                    end
                    row.expandedFrame:Show()
                else
                    if row.expandedFrame then row.expandedFrame:Hide() end
                end
                RepositionAllRows()
            end

            statusBar:SetScript("OnClick", ToggleExpanded)
            if #locations > 0 then
                statusBtn:SetScript("OnClick", ToggleExpanded)
            end

            if itemData.isCraftable then
                local craftBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["OWSL_BTN_CRAFT"], height = 20 })
                craftBtn:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
                craftBtn:SetScript("OnClick", function()
                    local recipes = capturedData.recipes or {}
                    if #recipes == 1 then
                        MainWindow:StartCraftOrder(capturedListN, capturedData.itemID, capturedData.quantity, recipes[1])
                    elseif #recipes > 1 then
                        local knownByData = {}
                        for _, r in ipairs(recipes) do
                            knownByData[r.recipeID] = ns.ShoppingList:GetRecipeKnownBy(r.recipeID)
                        end
                        ns.Dialogs:RecipeSelectDialog(recipes, knownByData, function(recipe)
                            MainWindow:StartCraftOrder(capturedListN, capturedData.itemID, capturedData.quantity, recipe)
                        end, mainFrame)
                    end
                end)
            end

            qtyBox:SetScript("OnEnterPressed", function(myself)
                local qty = tonumber(myself:GetText()) or 0
                if qty > 0 then
                    ns.ShoppingList:UpdateItemQuantity(capturedListN, capturedData.itemID, qty)
                    myself:ClearFocus()
                    MainWindow:RefreshItemList()
                else
                    myself:SetText(tostring(capturedData.quantity))
                    myself:ClearFocus()
                end
            end)
            removeBtn:SetScript("OnClick", function()
                if GetSettings().confirmItemDelete == false then
                    ns.ShoppingList:RemoveItemFromList(capturedListN, capturedData.itemID)
                    MainWindow:RefreshItemList()
                    return
                end
                ns.Dialogs:ConfirmDialog(
                    L["OWSL_DIALOG_DELETE_CONFIRM"]:format(capturedData.displayName),
                    L["OWSL_DIALOG_DELETE_CONFIRM2"],
                    function()
                        ns.ShoppingList:RemoveItemFromList(capturedListN, capturedData.itemID)
                        MainWindow:RefreshItemList()
                    end,
                    DELETE,
                    mainFrame,
                    {
                        showDontAskAgain = true,
                        onDontAskAgain = function()
                            GetSettings().confirmItemDelete = false
                        end,
                    }
                )
            end)
            row:SetScript("OnMouseDown", function(_, btn)
                if btn == "RightButton" then
                    MainWindow:ShowItemContextMenu(capturedData.itemID, capturedListN)
                elseif btn == "LeftButton" and IsShiftKeyDown() and capturedData.itemLink then
                    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
                        AuctionHouseFrame.SearchBar:SetSearchText(capturedData.displayName)
                        AuctionHouseFrame.SearchBar:StartSearch()
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_AH"], capturedData.displayName))
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_OPEN_AH_FIRST"])
                    end
                elseif btn == "LeftButton" then
                    ToggleExpanded()
                end
            end)
            iconFrame:SetScript("OnMouseDown", function(_, btn)
                if btn == "LeftButton" and IsShiftKeyDown() and capturedData.itemLink then
                    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
                        AuctionHouseFrame.SearchBar:SetSearchText(capturedData.displayName)
                        AuctionHouseFrame.SearchBar:StartSearch()
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_OPEN_AH_FIRST"])
                    end
                elseif btn == "LeftButton" then
                    ToggleExpanded()
                end
            end)
        end

        row:SetScript("OnEnter", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
        row:SetScript("OnLeave", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) end)

        row:Show()
        table.insert(itemRows, row)
        yOffset = yOffset - ((row.customHeight or rowHeight) + rowGap)
    end

    RepositionAllRows()

    if statusLabel then
        local totalItems     = 0
        local completedItems = 0
        for _, item in ipairs(items) do
            if not item.isUnresolved and item.status then
                totalItems = totalItems + 1
                if item.status.status == "green" or item.status.status == "blue" then
                    completedItems = completedItems + 1
                end
            end
        end
        statusLabel:SetText(string.format(L["OWSL_STATUS_ITEMS_SUMMARY"], totalItems, completedItems))
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

function MainWindow:StartCraftOrder(listName, itemID, quantity, recipe)
    local ingredients, _ = ns.ShoppingList:CalculateCraftIngredients(recipe.recipeID, quantity)

    if not ingredients or #ingredients == 0 then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_NO_INGREDIENTS"])
        return
    end

    local ok, craftOrderName, merged = ns.ShoppingList:CreateCraftOrder(
        listName, itemID, quantity, recipe.recipeID, recipe.name)

    if not ok then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_FAILED"])
        return
    end

    for _, ingredient in ipairs(ingredients) do
        ns.ShoppingList:AddItemToList(craftOrderName, ingredient.itemID, ingredient.baseQuantity)
    end

    local s = #ingredients ~= 1 and "s" or ""
    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"],
        craftOrderName, #ingredients, s, merged and " (merged)" or ""))

    MainWindow:RefreshSidebar()
    MainWindow:RefreshItemList()
end

function MainWindow:ShowItemContextMenu(itemID, listName)
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(L["OWSL_TT_ITEM_TITLE"])

        local moveToMenu = rootDescription:CreateButton(L["OWSL_MENU_MOVE_TO"])
        for _, otherListName in ipairs(ns.ShoppingList:GetParentLists()) do
            if otherListName ~= listName then
                local capturedOther = otherListName
                moveToMenu:CreateButton(otherListName, function()
                    local ok, err = ns.ShoppingList:MoveItem(itemID, listName, capturedOther)
                    if ok then
                        local name = C_Item.GetItemNameByID(itemID) or tostring(itemID)
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_MOVED_ITEM"], name, listName, capturedOther))
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. (err or L["OWSL_MSG_MOVE_FAILED"]:format("")))
                    end
                end)
            end
        end

        rootDescription:CreateButton(L["OWSL_SEND_TO_FARM"], function()
            ns.FarmList:AddFromShoppingList(itemID, listName, "farming")
            local name = C_Item.GetItemNameByID(itemID) or tostring(itemID)
            print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, L["FARMING"]))
        end)

        rootDescription:CreateButton(L["OWSL_MENU_CREATE_CRAFT_ORDER"], function()
            local recipes = ns.ShoppingList:GetCraftableRecipes(itemID)
            if #recipes == 0 then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_NO_RECIPES"])
                return
            end
            if #recipes == 1 then
                local status = ns.ShoppingList:GetItemStatus(itemID, listName)
                local qty    = status and status.needed or 1
                MainWindow:StartCraftOrder(listName, itemID, qty, recipes[1])
            else
                local knownByData = {}
                for _, r in ipairs(recipes) do
                    knownByData[r.recipeID] = ns.ShoppingList:GetRecipeKnownBy(r.recipeID)
                end
                ns.Dialogs:RecipeSelectDialog(recipes, knownByData, function(recipe)
                    local status = ns.ShoppingList:GetItemStatus(itemID, listName)
                    local qty    = status and status.needed or 1
                    MainWindow:StartCraftOrder(listName, itemID, qty, recipe)
                end, mainFrame)
            end
        end)
    end)
end

function MainWindow:ShowListContextMenu(listName)
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(listName)

        if listName ~= ns.MAIN_LIST_KEY then
            rootDescription:CreateButton(L["OWSL_MENU_RENAME_LIST"], function()
                ns.Dialogs:InputDialog(
                    string.format(L["OWSL_DIALOG_RENAME"], listName),
                    listName,
                    function(newName)
                        if newName == "" then return end
                        local ok, err = ns.ShoppingList:RenameList(listName, newName)
                        if not ok then
                            print(L["ADDON_CHAT_PREFIX"] .. " " .. (err or ""))
                        else
                            MainWindow:RefreshSidebar()
                            MainWindow:RefreshItemList()
                        end
                    end,
                    L["RENAME"]
                )
            end)
        end

        rootDescription:CreateButton(L["OWSL_MENU_EXPORT_LIST"], function()
            local exportText = ns.ShoppingList:ExportList(listName)
            if exportText then
                ns.Dialogs:ExportDialog(string.format(L["OWSL_EXPORT_TITLE"], listName), exportText, mainFrame)
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_EXPORT_FAILED"])
            end
        end)

        if not ns.ShoppingList:GetDefaultListName() == listName then
            rootDescription:CreateButton(L["OWSL_TT_SET_DEFAULT"], function()
                ns.ShoppingList:SetDefaultList(listName)
                MainWindow:RefreshSidebar()
            end)
        end

        if listName ~= ns.MAIN_LIST_KEY then
            rootDescription:CreateButton(L["OWSL_MENU_DELETE_LIST"], function()
                if GetSettings().confirmListDelete == false then
                    ns.ShoppingList:DeleteList(listName)
                    MainWindow:RefreshSidebar()
                    MainWindow:RefreshItemList()
                    return
                end
                local childCount = #ns.ShoppingList:GetChildLists(listName)
                local bodyText   = L["OWSL_DIALOG_DELETE_CONFIRM2"]
                if childCount > 0 then
                    bodyText = string.format(L["OWSL_TT_DELETE_CRAFT_ORDERS"], childCount) .. "\n" .. bodyText
                end
                ns.Dialogs:ConfirmDialog(
                    string.format(L["OWSL_DIALOG_DELETE_CONFIRM"], listName),
                    bodyText,
                    function()
                        ns.ShoppingList:DeleteList(listName)
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    end,
                    DELETE,
                    mainFrame,
                    {
                        showDontAskAgain = true,
                        onDontAskAgain = function()
                            GetSettings().confirmListDelete = false
                        end,
                    }
                )
            end)
        end
    end)
end

local function PaintModeTab(btn, selected)
    if not btn then return end
    if selected then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

function MainWindow:ApplyWindowMode()
    local farming = windowMode == "farming"
    PaintModeTab(tabShoppingBtn, not farming)
    PaintModeTab(tabFarmingBtn, farming)

    if inSettingsView then return end

    if newListBtn then
        if farming then newListBtn:Hide() else newListBtn:Show() end
    end
    if farmAddByIdBtn then
        if farming then farmAddByIdBtn:Show() else farmAddByIdBtn:Hide() end
    end
    if shoppingSidebarScroll then
        if farming then shoppingSidebarScroll:Hide() else shoppingSidebarScroll:Show() end
    end
    if farmSidebarScrollContainer then
        if farming then farmSidebarScrollContainer:Show() else farmSidebarScrollContainer:Hide() end
    end
    if contentHeaderFrame then
        if farming then contentHeaderFrame:Hide() else contentHeaderFrame:Show() end
    end
    if addButtonRowFrame then
        if farming then addButtonRowFrame:Hide() else addButtonRowFrame:Show() end
    end
    if contentPanel and contentPanel.listContainer then
        if farming then contentPanel.listContainer:Hide() else contentPanel.listContainer:Show() end
    end
    if farmDetailPanel then
        if farming then farmDetailPanel:Show() else farmDetailPanel:Hide() end
    end
end

function MainWindow:SetWindowMode(mode)
    if mode ~= "farming" then
        mode = "shopping"
    end
    windowMode = mode
    if not mainFrame then return end
    self:ApplyWindowMode()
    if mainFrame:IsShown() then
        self:RefreshSidebar()
        self:RefreshItemList()
    end
end

local function SearchAuctionHouse(displayName)
    if not displayName or displayName == "" then
        return
    end
    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
        AuctionHouseFrame.SearchBar:SetSearchText(displayName)
        AuctionHouseFrame.SearchBar:StartSearch()
        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_AH"], displayName))
        return
    end
    print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_OPEN_AH_FIRST"])
end

function MainWindow:BuildFarmDetailPanel()
    farmDetailPanel = OneWoW_GUI:CreateFrame(contentPanel, {
        backdrop    = OneWoW_GUI.Constants.BACKDROP_SOFT,
        bgColor     = "BG_PRIMARY",
        borderColor = "BORDER_SUBTLE",
    })
    farmDetailPanel:SetAllPoints(contentPanel)
    farmDetailPanel:Hide()

    local d = {}
    farmDetail = d

    d.emptyHint = OneWoW_GUI:CreateFS(farmDetailPanel, 12)
    d.emptyHint:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", 16, -16)
    d.emptyHint:SetPoint("TOPRIGHT", farmDetailPanel, "TOPRIGHT", -16, -16)
    d.emptyHint:SetJustifyH("LEFT")
    d.emptyHint:SetText(L["OWSL_FARM_SELECT_ITEM"])
    d.emptyHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    d.icon = OneWoW_GUI:CreateSkinnedIcon(farmDetailPanel, { size = 36, itemID = 6948 })
    d.icon:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", 12, -12)

    d.nameText = OneWoW_GUI:CreateFS(farmDetailPanel, 14)
    d.nameText:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, 0)
    d.nameText:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -12, 0)
    d.nameText:SetJustifyH("LEFT")
    d.nameText:SetWordWrap(true)
    d.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    d.idText = OneWoW_GUI:CreateFS(farmDetailPanel, 10)
    d.idText:SetPoint("TOPLEFT", d.nameText, "BOTTOMLEFT", 0, -2)
    d.idText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    d.statusText = OneWoW_GUI:CreateFS(farmDetailPanel, 11)
    d.statusText:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10)
    d.statusText:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -12, 0)
    d.statusText:SetJustifyH("LEFT")

    d.buyInsteadHeader = OneWoW_GUI:CreateFS(farmDetailPanel, 12)
    d.buyInsteadHeader:SetText(L["OWSL_BUY_INSTEAD"])
    d.buyInsteadHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    d.buyInsteadText = OneWoW_GUI:CreateFS(farmDetailPanel, 11)
    d.buyInsteadText:SetJustifyH("LEFT")
    d.buyInsteadText:SetWordWrap(true)
    d.buyInsteadText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    d.whereIsHeader = OneWoW_GUI:CreateFS(farmDetailPanel, 12)
    d.whereIsHeader:SetText(L["WHERE_IT_IS"])
    d.whereIsHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    d.whereIsLines = {}
    for i = 1, 12 do
        local fs = OneWoW_GUI:CreateFS(farmDetailPanel, 11)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        d.whereIsLines[i] = fs
    end

    d.whereGetHeader = OneWoW_GUI:CreateFS(farmDetailPanel, 12)
    d.whereGetHeader:SetText(L["WHERE_TO_GET"])
    d.whereGetHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    d.whereGetLines = {}
    for i = 1, 16 do
        local fs = OneWoW_GUI:CreateFS(farmDetailPanel, 11)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        d.whereGetLines[i] = fs
    end

    d.noteLabel = OneWoW_GUI:CreateFS(farmDetailPanel, 11)
    d.noteLabel:SetText(NOTE_COLON)
    d.noteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    d.noteBox = OneWoW_GUI:CreateEditBox(farmDetailPanel, { height = 22 })
    d.noteBox:SetScript("OnEditFocusLost", function(myself)
        if selectedFarmItemID then
            ns.FarmList:SetNotes(selectedFarmItemID, myself:GetText() or "")
        end
    end)

    d.qtyLabel = OneWoW_GUI:CreateFS(farmDetailPanel, 11)
    d.qtyLabel:SetText(L["OWSL_LABEL_QTY"])
    d.qtyLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    d.qtyBox = OneWoW_GUI:CreateEditBox(farmDetailPanel, { width = 56, height = 22 })
    d.qtyBox:SetNumeric(true)
    d.qtyBox:SetMaxLetters(4)
    d.qtyBox:SetJustifyH("CENTER")
    local function CommitFarmQty(myself)
        local qty = tonumber(myself:GetText()) or 0
        if selectedFarmItemID and qty > 0 then
            ns.FarmList:SetQuantity(selectedFarmItemID, qty)
            myself:ClearFocus()
            MainWindow:RefreshFarmSidebar()
            MainWindow:RefreshFarmDetail()
        elseif selectedFarmItemID then
            local row = ns.FarmList:GetItem(selectedFarmItemID)
            myself:SetText(tostring(row and row.quantity or 1))
            myself:ClearFocus()
        end
    end
    d.qtyBox:SetScript("OnEnterPressed", CommitFarmQty)
    d.qtyBox:SetScript("OnEditFocusLost", CommitFarmQty)

    d.ahBtn = OneWoW_GUI:CreateFitTextButton(farmDetailPanel, { text = L["OWSL_SEARCH_AH"], height = 22 })
    d.sendBtn = OneWoW_GUI:CreateFitTextButton(farmDetailPanel, { text = L["OWSL_SEND_TO_SHOPPING"], height = 22 })
    d.removeBtn = OneWoW_GUI:CreateFitTextButton(farmDetailPanel, { text = DELETE, height = 22 })

    d.ahBtn:SetScript("OnClick", function()
        if not selectedFarmItemID then return end
        local row = ns.FarmList:GetItem(selectedFarmItemID)
        local name = C_Item.GetItemNameByID(selectedFarmItemID) or (row and row.name) or ""
        SearchAuctionHouse(name)
    end)

    d.sendBtn:SetScript("OnClick", function()
        if not selectedFarmItemID then return end
        MainWindow:ShowSendToShoppingMenu(selectedFarmItemID)
    end)

    d.removeBtn:SetScript("OnClick", function()
        if not selectedFarmItemID then return end
        local itemID = selectedFarmItemID
        local name = C_Item.GetItemNameByID(itemID) or string.format(L["OWSL_ITEM_PREFIX"], itemID)
        local function DoRemove()
            ns.FarmList:RemoveItem(itemID)
            selectedFarmItemID = nil
            MainWindow:RefreshFarmSidebar()
            MainWindow:RefreshFarmDetail()
        end
        if GetSettings().confirmItemDelete == false then
            DoRemove()
            return
        end
        ns.Dialogs:ConfirmDialog(
            L["OWSL_DIALOG_DELETE_CONFIRM"]:format(name),
            L["OWSL_DIALOG_DELETE_CONFIRM2"],
            DoRemove,
            DELETE,
            mainFrame,
            {
                showDontAskAgain = true,
                onDontAskAgain = function()
                    GetSettings().confirmItemDelete = false
                end,
            }
        )
    end)
end

local function MeasureOr(fs, fallback)
    local h = fs:GetStringHeight()
    if h and h > 0 then return h end
    return fallback
end

function MainWindow:RefreshFarmSidebar()
    if not sidebarPanel or not sidebarPanel.farmScrollContent then return end
    if windowMode ~= "farming" then return end

    HideAllRows(farmRowPool)
    HideAllRows(farmHeaderPool)

    local groups = ns.FarmList:GetPlaceGroups()
    local scrollContent = sidebarPanel.farmScrollContent
    local yOff = 0
    local rowIdx = 1
    local headerIdx = 1
    local rowH = 28
    local rowGap = 2

    local function PlaceHeader(title, count)
        if headerIdx > FARM_HEADER_POOL_SIZE then return end
        local header = farmHeaderPool[headerIdx]
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, -yOff)
        header:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, -yOff)
        header.title:SetText(title)
        header.count:SetText(tostring(count))
        header:Show()
        headerIdx = headerIdx + 1
        yOff = yOff + 28
    end

    local function PlaceRows(items)
        for i = 1, #items do
            if rowIdx > FARM_POOL_SIZE then break end
            local item = items[i]
            local row = farmRowPool[rowIdx]
            local capturedID = item.itemID
            local isSelected = selectedFarmItemID == capturedID
            row.data.itemID = capturedID
            row.data.isSelected = isSelected
            row._zebraIndex = rowIdx

            local icon = C_Item.GetItemIconByID(capturedID)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(item.name)
            row.qtyText:SetText(tostring(item.quantity or 1))

            local status = ns.FarmList:GetItemStatus(capturedID)
            if status then
                local r, g, b = unpack(status.statusColor)
                row.statusBar:SetColorTexture(r, g, b, 1)
            else
                row.statusBar:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end

            if isSelected then
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            PaintFarmRow(row, false)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, -yOff)
            row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, -yOff)
            row:SetHeight(rowH)

            row:SetScript("OnClick", function(_, btn)
                if btn == "RightButton" then
                    selectedFarmItemID = capturedID
                    MainWindow:RefreshFarmSidebar()
                    MainWindow:RefreshFarmDetail()
                    MainWindow:ShowFarmItemContextMenu(capturedID)
                else
                    selectedFarmItemID = capturedID
                    MainWindow:RefreshFarmSidebar()
                    MainWindow:RefreshFarmDetail()
                end
            end)

            row:Show()
            rowIdx = rowIdx + 1
            yOff = yOff + rowH + rowGap
        end
    end

    for i = 1, #groups do
        local group = groups[i]
        PlaceHeader(group.title, #group.items)
        PlaceRows(group.items)
    end

    scrollContent:SetHeight(math.max(yOff + 4, 1))
end

function MainWindow:RefreshFarmDetail()
    if not farmDetailPanel or not farmDetail then return end
    if windowMode ~= "farming" then return end

    local d = farmDetail
    local row = selectedFarmItemID and ns.FarmList:GetItem(selectedFarmItemID)
    if not row then
        d.emptyHint:Show()
        d.icon:Hide()
        d.nameText:Hide()
        d.idText:Hide()
        d.statusText:Hide()
        d.buyInsteadHeader:Hide()
        d.buyInsteadText:Hide()
        d.whereIsHeader:Hide()
        d.whereGetHeader:Hide()
        d.noteLabel:Hide()
        d.noteBox:Hide()
        d.qtyLabel:Hide()
        d.qtyBox:Hide()
        d.ahBtn:Hide()
        d.sendBtn:Hide()
        d.removeBtn:Hide()
        for i = 1, #d.whereIsLines do d.whereIsLines[i]:Hide() end
        for i = 1, #d.whereGetLines do d.whereGetLines[i]:Hide() end
        return
    end

    d.emptyHint:Hide()
    d.icon:Show()
    d.nameText:Show()
    d.idText:Show()
    d.statusText:Show()
    d.noteLabel:Show()
    d.noteBox:Show()
    d.qtyLabel:Show()
    d.qtyBox:Show()
    d.ahBtn:Show()
    d.sendBtn:Show()
    d.removeBtn:Show()

    local itemID = row.itemID
    local displayName = C_Item.GetItemNameByID(itemID) or row.name or string.format(L["OWSL_ITEM_PREFIX"], itemID)
    local iconTex = C_Item.GetItemIconByID(itemID)
    OneWoW_GUI:UpdateIconTexture(d.icon, iconTex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local quality = C_Item.GetItemQualityByID(itemID)
    OneWoW_GUI:UpdateIconQuality(d.icon, quality)

    local itemLink = select(2, C_Item.GetItemInfo(itemID))
    if itemLink then
        d.icon:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)
        d.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        d.icon:SetScript("OnEnter", nil)
        d.icon:SetScript("OnLeave", nil)
        C_Item.RequestLoadItemDataByID(itemID)
    end

    d.nameText:SetText(displayName)
    d.idText:SetText(L["ITEM_ID"] .. " " .. tostring(itemID))

    local status = ns.FarmList:GetItemStatus(itemID)
    if status then
        local r, g, b = unpack(status.statusColor)
        d.statusText:SetTextColor(r, g, b)
        d.statusText:SetText(string.format(L["OWSL_STATUS_ALTS"], status.totalOwned, status.needed))
    else
        d.statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        d.statusText:SetText("")
    end

    d.noteBox:SetText(row.notes or "")
    d.qtyBox:SetText(tostring(row.quantity or 1))

    local pad = 12
    local y = -12
    d.icon:ClearAllPoints()
    d.icon:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    local nameH = MeasureOr(d.nameText, 16)
    local idH = MeasureOr(d.idText, 12)
    y = y - math.max(36, nameH + idH + 6) - 10

    d.statusText:ClearAllPoints()
    d.statusText:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    d.statusText:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
    y = y - MeasureOr(d.statusText, 14) - 12

    local buy = ns.FarmList:GetBuyInstead(itemID)
    d.buyInsteadHeader:Show()
    d.buyInsteadHeader:ClearAllPoints()
    d.buyInsteadHeader:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    y = y - MeasureOr(d.buyInsteadHeader, 14) - 4
    d.buyInsteadText:Show()
    if buy.hasVendor then
        d.buyInsteadText:SetText(string.format(L["OWSL_SOLD_BY_VENDOR"], buy.vendorName))
        d.buyInsteadText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        d.buyInsteadText:SetText(L["OWSL_SEARCH_AH"])
        d.buyInsteadText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    d.buyInsteadText:ClearAllPoints()
    d.buyInsteadText:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    d.buyInsteadText:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
    y = y - MeasureOr(d.buyInsteadText, 12) - 12

    local locations = status and status.locations or {}
    d.whereIsHeader:Show()
    d.whereIsHeader:ClearAllPoints()
    d.whereIsHeader:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    y = y - MeasureOr(d.whereIsHeader, 14) - 4
    if #locations == 0 then
        d.whereIsLines[1]:Show()
        d.whereIsLines[1]:SetText(NONE)
        d.whereIsLines[1]:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        d.whereIsLines[1]:ClearAllPoints()
        d.whereIsLines[1]:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
        d.whereIsLines[1]:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
        y = y - MeasureOr(d.whereIsLines[1], 12) - 2
        for i = 2, #d.whereIsLines do d.whereIsLines[i]:Hide() end
    else
        for i = 1, #d.whereIsLines do
            local fs = d.whereIsLines[i]
            if locations[i] then
                fs:Show()
                fs:SetText(locations[i])
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
                fs:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
                y = y - MeasureOr(fs, 12) - 2
            else
                fs:Hide()
            end
        end
    end
    y = y - 8

    local sources = ns.FarmList:GetCatalogSources(itemID)
    if #sources == 0 then
        d.whereGetHeader:Hide()
        for i = 1, #d.whereGetLines do d.whereGetLines[i]:Hide() end
    else
        d.whereGetHeader:Show()
        d.whereGetHeader:ClearAllPoints()
        d.whereGetHeader:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
        y = y - MeasureOr(d.whereGetHeader, 14) - 4
        local lineIdx = 1
        for g = 1, #sources do
            local group = sources[g]
            local headerFS = d.whereGetLines[lineIdx]
            if headerFS then
                headerFS:Show()
                headerFS:SetText(group.header)
                headerFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
                headerFS:ClearAllPoints()
                headerFS:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
                headerFS:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
                y = y - MeasureOr(headerFS, 12) - 2
                lineIdx = lineIdx + 1
            end
            for li = 1, #group.lines do
                local fs = d.whereGetLines[lineIdx]
                if not fs then break end
                fs:Show()
                fs:SetText(group.lines[li])
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad + 8, y)
                fs:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
                y = y - MeasureOr(fs, 12) - 2
                lineIdx = lineIdx + 1
            end
        end
        for i = lineIdx, #d.whereGetLines do
            d.whereGetLines[i]:Hide()
        end
    end
    y = y - 10

    d.noteLabel:ClearAllPoints()
    d.noteLabel:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    y = y - MeasureOr(d.noteLabel, 12) - 4
    d.noteBox:ClearAllPoints()
    d.noteBox:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    d.noteBox:SetPoint("RIGHT", farmDetailPanel, "RIGHT", -pad, 0)
    y = y - 28

    d.qtyLabel:ClearAllPoints()
    d.qtyLabel:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    d.qtyBox:ClearAllPoints()
    d.qtyBox:SetPoint("LEFT", d.qtyLabel, "RIGHT", 6, 0)
    y = y - 30

    d.ahBtn:ClearAllPoints()
    d.ahBtn:SetPoint("TOPLEFT", farmDetailPanel, "TOPLEFT", pad, y)
    d.sendBtn:ClearAllPoints()
    d.sendBtn:SetPoint("LEFT", d.ahBtn, "RIGHT", 6, 0)
    d.removeBtn:ClearAllPoints()
    d.removeBtn:SetPoint("LEFT", d.sendBtn, "RIGHT", 6, 0)
end

function MainWindow:ShowSendToShoppingMenu(itemID)
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(L["OWSL_SEND_TO_SHOPPING"])
        for _, listName in ipairs(ns.ShoppingList:GetParentLists()) do
            local captured = listName
            rootDescription:CreateButton(listName, function()
                local ok = ns.FarmList:SendToShoppingList(itemID, captured)
                if ok then
                    local name = C_Item.GetItemNameByID(itemID) or tostring(itemID)
                    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, captured))
                else
                    print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_MOVE_FAILED"]:format(""))
                end
            end)
        end
    end)
end

function MainWindow:ShowFarmItemContextMenu(itemID)
    local row = ns.FarmList:GetItem(itemID)
    if not row then return end
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(C_Item.GetItemNameByID(itemID) or row.name or L["ITEM"])
        rootDescription:CreateButton(L["OWSL_SEARCH_AH"], function()
            SearchAuctionHouse(C_Item.GetItemNameByID(itemID) or row.name or "")
        end)
        rootDescription:CreateButton(L["OWSL_SEND_TO_SHOPPING"], function()
            MainWindow:ShowSendToShoppingMenu(itemID)
        end)
        rootDescription:CreateButton(DELETE, function()
            ns.FarmList:RemoveItem(itemID)
            if selectedFarmItemID == itemID then
                selectedFarmItemID = nil
            end
            MainWindow:RefreshFarmSidebar()
            MainWindow:RefreshFarmDetail()
        end)
    end)
end

function MainWindow:Show()
    if not mainFrame then self:Create() end
    mainFrame:Show()
    self:ApplyWindowMode()
    self:RefreshSidebar()
    self:RefreshItemList()
end

function MainWindow:Hide()
    if mainFrame then mainFrame:Hide() end
end

function MainWindow:Toggle()
    if not mainFrame then
        self:Create()
        mainFrame:Show()
        self:ApplyWindowMode()
        self:RefreshSidebar()
        self:RefreshItemList()
    elseif mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:ApplyWindowMode()
        self:RefreshSidebar()
        self:RefreshItemList()
    end
end

function MainWindow:IsShown()
    return mainFrame and mainFrame:IsShown()
end

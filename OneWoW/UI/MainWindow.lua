local ADDON_NAME, ns = ...

local UI = ns.UI
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local MainWindow = nil
local isInitialized = false
local currentModuleTab = "home"
local currentSubTab = nil
local navBackBtn = nil
local navForwardBtn = nil
local pendingLeaveSnapshot = nil
local pendingCoalesceLeave = nil
local pendingCoalesceArrive = nil
local coalesceQueued = false
local row2Buttons = {}
local moduleContentFrames = {}
local row1Container = nil
local row2Container = nil
local contentArea = nil
local homePanel = nil
local settingsPanel = nil
local placeholderData = {}
local sectionNavDropdown = nil
local sectionNavText = nil
local subNavDropdown = nil
local subNavText = nil
local subNavChevron = nil
local favoriteStar = nil
local pinReorder = nil
local pinSink = nil             -- hidden host so retired pins never orphan onto UIParent
local allPinFrames = {}        -- every pin created this refresh (visible + spilled)
local spilledFavoriteNames = {}
local pinLayoutPending = false
local refreshingSubNav = false
local sectionModuleNames = {}  -- hub module names between home and settings (refresh detection)
local sectionLabels = {}       -- moduleName -> display text
local FRAME_NAME = "OneWoWMainWindow"
local PIN_HEIGHT = 20
local PIN_FONT_SIZE = 11
local PIN_PAD_X = 14

local function RemoveFromUISpecialFrames(name)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            tremove(UISpecialFrames, i)
        end
    end
end

local function EnsureInUISpecialFrames(name)
    for _, v in ipairs(UISpecialFrames) do
        if v == name then return end
    end
    tinsert(UISpecialFrames, name)
end

hooksecurefunc("ToggleGameMenu", function()
    if MainWindow and MainWindow:IsShown() then
        UI:Hide()
        if GameMenuFrame and GameMenuFrame:IsShown() then
            HideUIPanel(GameMenuFrame)
        end
    end
end)

local function TabIsHidden(tabInfo)
    local hidden = tabInfo.hidden
    if type(hidden) == "function" then
        return hidden() and true or false
    end
    return hidden == true
end

local function GetSectionTabs(moduleName)
    if moduleName == "settings" then
        return UI.settingsTabs or {}
    end
    local mod = ns.ModuleRegistry:GetModule(moduleName)
    if not mod or not mod.tabs then
        return {}
    end
    local visible = {}
    for _, tabInfo in ipairs(mod.tabs) do
        if not TabIsHidden(tabInfo) then
            tinsert(visible, tabInfo)
        end
    end
    return visible
end

local function GetTabDisplayName(tabInfo)
    if not tabInfo then return "" end
    return type(tabInfo.displayName) == "function" and tabInfo.displayName() or (tabInfo.displayName or tabInfo.name or "")
end

local function FindSectionTab(moduleName, subTabName)
    for _, tabInfo in ipairs(GetSectionTabs(moduleName)) do
        if tabInfo.name == subTabName then
            return tabInfo
        end
    end
    return nil
end

local function GetFavoritesList(moduleName)
    local root = ns.db.global.subTabFavorites
    if not root[moduleName] then
        root[moduleName] = {}
    end
    return root[moduleName]
end

local function PruneFavorites(moduleName)
    local list = GetFavoritesList(moduleName)
    local valid = {}
    for _, tabInfo in ipairs(GetSectionTabs(moduleName)) do
        valid[tabInfo.name] = true
    end
    for i = #list, 1, -1 do
        if not valid[list[i]] then
            tremove(list, i)
        end
    end
    return list
end

local function IsFavorited(moduleName, subTabName)
    for _, name in ipairs(GetFavoritesList(moduleName)) do
        if name == subTabName then
            return true
        end
    end
    return false
end

local function SetFavorited(moduleName, subTabName, on)
    local list = GetFavoritesList(moduleName)
    for i, name in ipairs(list) do
        if name == subTabName then
            if not on then
                tremove(list, i)
            end
            return
        end
    end
    if on then
        tinsert(list, subTabName)
    end
end

local function MoveFavoriteEntry(moduleName, fromIndex, toIndex)
    local list = GetFavoritesList(moduleName)
    local n = #list
    if fromIndex < 1 or fromIndex > n or toIndex < 1 or toIndex > n or fromIndex == toIndex then
        return
    end
    local entry = tremove(list, fromIndex)
    tinsert(list, toIndex, entry)
end

local function StyleToolbarDropdown(dropdown)
    dropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    dropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    dropdown:SetScript("OnEnter", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    end)
end

local function CreateFavoritePinButton(parent, text, subTabName)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(PIN_HEIGHT)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    btn.subTabName = subTabName

    btn.text = OneWoW_GUI:CreateFS(btn, PIN_FONT_SIZE)
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn:SetWidth((btn.text:GetStringWidth() or 40) + PIN_PAD_X)

    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        if self.subTabName ~= currentSubTab then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.subTabName ~= currentSubTab then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        UI:SelectSubTab(currentModuleTab, self.subTabName)
    end)

    btn.Remeasure = function(self)
        if self.text then
            self:SetWidth((self.text:GetStringWidth() or 40) + PIN_PAD_X)
        end
    end

    return btn
end

local function UpdateRow2Styling()
    for _, btn in ipairs(row2Buttons) do
        if btn.subTabName == currentSubTab then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

local function UpdateContentAreaAnchors()
    if not contentArea or not row1Container then return end
    contentArea:ClearAllPoints()
    local gap = OneWoW_GUI:GetSpacing("XS")
    local topOffset = -gap
    if row2Container and row2Container:IsShown() then
        topOffset = -(gap + (row2Container:GetHeight() or 22) + gap)
    end
    -- Keep content full-bleed with the toolbar; pin row may be inset to nav/search.
    contentArea:SetPoint("TOPLEFT", row1Container, "BOTTOMLEFT", 0, topOffset)
    local resizeInset = 18  -- Clear 16px resize handle + 2px margin
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -resizeInset, resizeInset)
end

local function RetirePin(btn)
    if not btn or not btn.Hide then return end
    if pinReorder then
        pinReorder:Detach(btn)
    end
    -- Keep retired pins under a hidden sink on MainWindow — never SetParent(nil)
    -- (orphans can keep painting) and never leave them on the visible pin row.
    btn:Hide()
    btn:EnableMouse(false)
    btn:ClearAllPoints()
    local sink = pinSink or MainWindow
    if sink then
        btn:SetParent(sink)
    end
end

local function ClearPinRow()
    if pinReorder and pinReorder.Cancel then
        pinReorder:Cancel()
    end
    for _, btn in ipairs(allPinFrames) do
        RetirePin(btn)
    end
    -- Catch any pin that escaped allPinFrames (re-entrant refresh / deferred layout).
    if row2Container and row2Container.GetChildren then
        for _, child in ipairs({ row2Container:GetChildren() }) do
            RetirePin(child)
        end
    end
    wipe(allPinFrames)
    wipe(row2Buttons)
    wipe(spilledFavoriteNames)
end

local function EnsurePinReorder()
    if pinReorder then return pinReorder end
    pinReorder = OneWoW_GUI:CreateReorderDrag({
        getItems = function()
            return row2Buttons
        end,
        onReorder = function(from, to)
            local fromBtn = row2Buttons[from]
            local toBtn = row2Buttons[to]
            if not fromBtn or not toBtn then return end
            local list = GetFavoritesList(currentModuleTab)
            local fromIdx, toIdx
            for i, name in ipairs(list) do
                if name == fromBtn.subTabName then fromIdx = i end
                if name == toBtn.subTabName then toIdx = i end
            end
            if fromIdx and toIdx then
                MoveFavoriteEntry(currentModuleTab, fromIdx, toIdx)
                UI:RefreshSubNav()
            end
        end,
        onPickup = function(btn)
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        end,
        onRestore = function()
            UpdateRow2Styling()
        end,
        onHover = function(btn)
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end,
        onUnhover = function()
            UpdateRow2Styling()
        end,
    })
    return pinReorder
end

local function ResolvePinRowWidth()
    if not row2Container then return 0 end
    local w = row2Container:GetWidth() or 0
    if w > 1 then return w end
    -- Hidden / pre-layout: derive from the same anchors (section dropdown → search).
    if sectionNavDropdown then
        local left = sectionNavDropdown:GetLeft()
        local right
        local searchBox = OneWoWSearchBox
        if searchBox then
            right = searchBox:GetRight()
        elseif row1Container then
            right = row1Container:GetRight()
        end
        if left and right and right > left then
            return right - left
        end
    end
    if MainWindow then
        local mw = MainWindow:GetWidth() or 0
        if mw > 1 then
            return math.max(1, mw - 80)
        end
    end
    return 0
end

local function LayoutFavoritePins(allPins)
    wipe(spilledFavoriteNames)
    wipe(row2Buttons)

    if not row2Container or not allPins or #allPins == 0 then
        if row2Container then
            row2Container:Hide()
            UpdateContentAreaAnchors()
        end
        return
    end

    local containerWidth = ResolvePinRowWidth()
    if containerWidth <= 1 then
        -- Defer until anchors have a real width. Hide the just-created pins so a
        -- later refresh cannot leave them stacked on the row.
        for _, btn in ipairs(allPins) do
            RetirePin(btn)
        end
        wipe(allPinFrames)
        row2Container:Hide()
        UpdateContentAreaAnchors()
        if not pinLayoutPending then
            pinLayoutPending = true
            C_Timer.After(0, function()
                pinLayoutPending = false
                if isInitialized and currentModuleTab then
                    UI:RefreshSubNav()
                end
            end)
        end
        return
    end

    local spacing = OneWoW_GUI:GetSpacing("XS")
    local x = 0
    local visibleCount = 0
    local reorder = EnsurePinReorder()

    for i, btn in ipairs(allPins) do
        if btn.Remeasure then btn:Remeasure() end
        local w = btn:GetWidth() or 40
        local gap = (visibleCount > 0) and spacing or 0
        if x + gap + w <= containerWidth + 0.5 then
            btn:SetParent(row2Container)
            btn:EnableMouse(true)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", row2Container, "TOPLEFT", x + gap, 0)
            x = x + gap + w
            btn:Show()
            visibleCount = visibleCount + 1
            row2Buttons[visibleCount] = btn
            if not btn._oneWoWPinReorderAttached then
                reorder:Attach(btn, visibleCount)
                btn._oneWoWPinReorderAttached = true
            end
        else
            for j = i, #allPins do
                local spilled = allPins[j]
                RetirePin(spilled)
                spilledFavoriteNames[#spilledFavoriteNames + 1] = spilled.subTabName
            end
            break
        end
    end

    if visibleCount > 0 then
        row2Container:Show()
    else
        row2Container:Hide()
    end
    UpdateContentAreaAnchors()
end

local function SetSubNavVisible(visible)
    if subNavChevron then
        if visible then subNavChevron:Show() else subNavChevron:Hide() end
    end
    if subNavDropdown then
        if visible then subNavDropdown:Show() else subNavDropdown:Hide() end
    end
    if favoriteStar then
        if visible then favoriteStar:Show() else favoriteStar:Hide() end
    end
end

local function BuildSubNavItems()
    local items = {}
    local moduleName = currentModuleTab
    local tabs = GetSectionTabs(moduleName)
    local favSet = {}
    for _, name in ipairs(GetFavoritesList(moduleName)) do
        favSet[name] = true
    end

    if #spilledFavoriteNames > 0 then
        items[#items + 1] = { type = "header", text = FAVORITES }
        for _, name in ipairs(spilledFavoriteNames) do
            local tabInfo = FindSectionTab(moduleName, name)
            if tabInfo and not tabInfo.disabled then
                items[#items + 1] = {
                    value = name,
                    text = GetTabDisplayName(tabInfo),
                    filterKey = GetTabDisplayName(tabInfo),
                    iconAtlas = "CampCollection-icon-star",
                    iconSize = 11,
                }
            end
        end
        items[#items + 1] = { type = "divider" }
    end

    for _, tabInfo in ipairs(tabs) do
        local entry = {
            value = tabInfo.name,
            text = GetTabDisplayName(tabInfo),
            filterKey = GetTabDisplayName(tabInfo),
        }
        if favSet[tabInfo.name] then
            entry.iconAtlas = "CampCollection-icon-star"
            entry.iconSize = 11
        end
        items[#items + 1] = entry
    end
    return items
end

function UI:RefreshSubNav()
    if not isInitialized or refreshingSubNav then return end
    refreshingSubNav = true

    local function finish()
        refreshingSubNav = false
    end

    local moduleName = currentModuleTab
    local tabs = GetSectionTabs(moduleName)
    local showSubNav = moduleName ~= "home" and #tabs > 1

    SetSubNavVisible(showSubNav)

    if not showSubNav then
        ClearPinRow()
        if row2Container then
            row2Container:Hide()
            UpdateContentAreaAnchors()
        end
        finish()
        return
    end

    PruneFavorites(moduleName)

    local tabInfo = FindSectionTab(moduleName, currentSubTab)
    local label = tabInfo and GetTabDisplayName(tabInfo) or (currentSubTab or "")
    if subNavText then
        subNavText:SetText(label)
    end
    if subNavDropdown then
        subNavDropdown._activeValue = currentSubTab
    end

    if favoriteStar then
        favoriteStar:SetFavorite(currentSubTab and IsFavorited(moduleName, currentSubTab) or false)
    end

    ClearPinRow()
    local allPins = {}
    for _, name in ipairs(GetFavoritesList(moduleName)) do
        local info = FindSectionTab(moduleName, name)
        if info and not info.disabled then
            local pin = CreateFavoritePinButton(row2Container, GetTabDisplayName(info), name)
            allPins[#allPins + 1] = pin
            allPinFrames[#allPinFrames + 1] = pin
        end
    end

    -- Font before measure/fit so pin widths match what players actually see.
    if #allPins > 0 then
        for _, pin in ipairs(allPins) do
            OneWoW_GUI:ApplyFontToFrame(pin)
            if pin.Remeasure then pin:Remeasure() end
        end
    end
    LayoutFavoritePins(allPins)
    UpdateRow2Styling()
    finish()
end

local activeContentFrame = nil

local function HideAllContent()
    if activeContentFrame and activeContentFrame.Deactivate then
        activeContentFrame:Deactivate()
    end
    activeContentFrame = nil
    if homePanel then homePanel:Hide() end
    if settingsPanel then settingsPanel:Hide() end
    for _, frame in pairs(moduleContentFrames) do
        frame:Hide()
    end
end

-- Hub sections for the toolbar dropdown: Home, always-show / registered modules,
-- Settings. Rebuilt when the registry gains a module after MainWindow init.
local function BuildDisplayModules()
    wipe(placeholderData)

    local modules = ns.ModuleRegistry:GetModules()
    local registeredNames = {}
    for _, mod in ipairs(modules) do
        registeredNames[mod.name] = true
    end

    local displayModules = {}
    for _, mod in ipairs(modules) do
        tinsert(displayModules, mod)
    end
    for _, info in ipairs(ns:GetAlwaysShowModules()) do
        if not registeredNames[info.name] then
            placeholderData[info.name] = info
            tinsert(displayModules, {
                name = info.name,
                displayName = function() return L[info.localeKey] end,
                order = info.order,
            })
        end
    end
    sort(displayModules, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    return displayModules
end

--- Ordered section entries for the nav dropdown: { value, text }.
---@return table[]
local function BuildSectionList()
    local sections = {
        { value = "home", text = L["HOME_TAB"] },
    }
    wipe(sectionModuleNames)
    wipe(sectionLabels)
    sectionLabels.home = L["HOME_TAB"]
    for _, mod in ipairs(BuildDisplayModules()) do
        local displayText = type(mod.displayName) == "function" and mod.displayName() or mod.displayName
        tinsert(sections, { value = mod.name, text = displayText })
        tinsert(sectionModuleNames, mod.name)
        sectionLabels[mod.name] = displayText
    end
    tinsert(sections, { value = "settings", text = SETTINGS })
    sectionLabels.settings = SETTINGS
    return sections
end

local function SectionLabelFor(moduleName)
    return sectionLabels[moduleName] or moduleName
end

local function UpdateSectionNavLabel()
    if sectionNavText then
        sectionNavText:SetText(SectionLabelFor(currentModuleTab))
    end
    if sectionNavDropdown then
        sectionNavDropdown._activeValue = currentModuleTab
    end
end

local function IsValidSection(moduleName)
    return sectionLabels[moduleName] ~= nil
end

local function SectionModuleNamesMatch(displayModules)
    if #sectionModuleNames ~= #displayModules then return false end
    for i, mod in ipairs(displayModules) do
        if sectionModuleNames[i] ~= mod.name then return false end
    end
    return true
end

function UI:RefreshRow1ModuleTabs()
    if not isInitialized or not sectionNavDropdown then return end

    local displayModules = BuildDisplayModules()
    if SectionModuleNamesMatch(displayModules) then return end

    BuildSectionList()
    UpdateSectionNavLabel()

    -- A placeholder section may have been showing; re-select so real module content loads.
    if currentModuleTab ~= "home" and currentModuleTab ~= "settings" then
        if ns.ModuleRegistry:IsRegistered(currentModuleTab) then
            UI:SelectModuleTab(currentModuleTab)
        end
    end
end

-- Re-query the Home tab's per-feature status rows in place. Safe before the panel
-- is built and after FullReset (homePanel is nil); the OnShow hook covers those.
function UI:RefreshHomeStatus()
    if homePanel and homePanel.RefreshStatus then
        homePanel.RefreshStatus()
    end
end

local function GetNavContentFrame(moduleName, subTabName)
    if moduleName == "home" then
        return homePanel
    end
    if subTabName then
        return moduleContentFrames[moduleName .. ":" .. subTabName]
    end
    if moduleName == "settings" then
        return settingsPanel
    end
    return nil
end

local function SnapshotLocation()
    local frame = GetNavContentFrame(currentModuleTab, currentSubTab)
    local kind, id
    if frame and frame.GetNavEntity then
        kind, id = frame.GetNavEntity()
    end
    return {
        module = currentModuleTab,
        subtab = currentSubTab,
        kind = kind,
        id = id,
    }
end

local function FormatNavLabel(entry)
    if not entry then
        return nil
    end
    local section = SectionLabelFor(entry.module)
    if not entry.subtab then
        return section
    end
    local tabInfo = FindSectionTab(entry.module, entry.subtab)
    local subName = GetTabDisplayName(tabInfo)
    if subName ~= "" then
        return section .. " / " .. subName
    end
    return section
end

-- common-icon-forwardarrow is baked gold. Desaturate, then tint so the
-- arrows follow the theme instead of sitting as a yellow blob on the title bar.
local function PaintNavIcon(btn, hover)
    local icon = btn and btn.icon
    if not icon then
        return
    end
    icon:SetDesaturated(true)
    if btn._navEnabled then
        local key = hover and "TEXT_ACCENT" or "ACCENT_PRIMARY"
        icon:SetVertexColor(OneWoW_GUI:GetThemeColor(key))
        icon:SetAlpha(1)
    else
        icon:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        icon:SetAlpha(0.45)
    end
end

local function SetNavButtonState(btn, enabled)
    if not btn then
        return
    end
    btn._navEnabled = enabled
    btn:SetEnabled(enabled)
    btn:EnableMouse(true)
    PaintNavIcon(btn, btn:IsMouseOver())
end

function UI:RefreshNavButtons()
    local history = UI.NavHistory
    SetNavButtonState(navBackBtn, history.CanBack())
    SetNavButtonState(navForwardBtn, history.CanForward())
end

local function FlushHubNav()
    local leave = pendingCoalesceLeave
    local arrive = pendingCoalesceArrive
    pendingCoalesceLeave = nil
    pendingCoalesceArrive = nil
    coalesceQueued = false
    if arrive then
        UI.NavHistory.Commit(leave, arrive)
    end
    UI:RefreshNavButtons()
end

local function QueueHubNav(leave, arrive)
    if UI.NavHistory.IsApplying() or not UI.NavHistory.IsArmed() then
        return
    end
    if not pendingCoalesceLeave then
        pendingCoalesceLeave = leave
    end
    pendingCoalesceArrive = arrive
    if not coalesceQueued then
        coalesceQueued = true
        C_Timer.After(0, FlushHubNav)
    end
end

local function ApplyNavEntry(entry)
    if not entry then
        return
    end
    if entry.subtab then
        UI:SelectModuleTab(entry.module, entry.subtab)
    else
        UI:SelectModuleTab(entry.module)
    end
    local frame = GetNavContentFrame(entry.module, entry.subtab)
    if frame and frame.RestoreNavEntity and entry.kind ~= nil and entry.id ~= nil then
        frame.RestoreNavEntity(entry.kind, entry.id)
    end
end

function UI:GoBack()
    FlushHubNav()
    if not UI.NavHistory.CanBack() then
        return
    end
    UI.NavHistory.SetApplying(true)
    ApplyNavEntry(UI.NavHistory.Back())
    UI.NavHistory.SetApplying(false)
    UI:RefreshNavButtons()
end

function UI:GoForward()
    FlushHubNav()
    if not UI.NavHistory.CanForward() then
        return
    end
    UI.NavHistory.SetApplying(true)
    ApplyNavEntry(UI.NavHistory.Forward())
    UI.NavHistory.SetApplying(false)
    UI:RefreshNavButtons()
end

--- Stamp or push an entity after an Open* jump lands on the current tab.
---@param kind string
---@param id number|string
function UI:CommitNavEntity(kind, id)
    if not kind or id == nil then
        return
    end
    if UI.NavHistory.IsApplying() or not UI.NavHistory.IsArmed() then
        return
    end
    if pendingCoalesceArrive
        and pendingCoalesceArrive.module == currentModuleTab
        and pendingCoalesceArrive.subtab == currentSubTab then
        pendingCoalesceArrive.kind = kind
        pendingCoalesceArrive.id = id
        return
    end
    if UI.NavHistory.FillCurrentEntity(kind, id) then
        UI:RefreshNavButtons()
        return
    end
    local current = UI.NavHistory.Current()
    if not current then
        return
    end
    if current.module ~= currentModuleTab or current.subtab ~= currentSubTab then
        return
    end
    if current.kind == kind and current.id == id then
        return
    end
    QueueHubNav(current, {
        module = currentModuleTab,
        subtab = currentSubTab,
        kind = kind,
        id = id,
    })
end

function UI:SelectModuleTab(moduleName, targetSub)
    -- Lazy modules load the first time their tab is opened. Dormant until modules
    -- become LoadOnDemand; a no-op while all modules are login-phase.
    if ns.LoadOrchestrator then
        ns.LoadOrchestrator:EnsureModuleForTab(moduleName)
    end

    local leave = nil
    if not UI.NavHistory.IsApplying() and UI.NavHistory.IsArmed() then
        leave = SnapshotLocation()
    end
    pendingLeaveSnapshot = leave

    currentModuleTab = moduleName
    currentSubTab = nil

    ns.db.global.lastModuleTab = moduleName

    if OneWoW_Notes_API and OneWoW_Notes_API.CloseHelpPanel then
        OneWoW_Notes_API.CloseHelpPanel()
    end

    UpdateSectionNavLabel()
    HideAllContent()

    if moduleName == "home" then
        UI:RefreshSubNav()
        if not homePanel then
            homePanel = CreateFrame("Frame", nil, contentArea)
            homePanel:SetAllPoints()
            UI:CreateHomeTab(homePanel)
            OneWoW_GUI:ApplyFontToFrame(homePanel)
        end
        homePanel:Show()
        pendingLeaveSnapshot = nil
        QueueHubNav(leave, { module = moduleName, subtab = nil })
        return
    end

    if moduleName == "settings" then
        if UI.settingsTabs and #UI.settingsTabs > 0 then
            local lastSub = ns.db.global.lastSubTabs["settings"]
            local firstTab = UI.settingsTabs[1].name
            local targetTab = targetSub or lastSub or firstTab

            local found = false
            for _, tabInfo in ipairs(UI.settingsTabs) do
                if tabInfo.name == targetTab and not tabInfo.disabled then
                    found = true
                    break
                end
            end
            if not found then targetTab = firstTab end

            UI:SelectSubTab("settings", targetTab)
        else
            UI:RefreshSubNav()
            if not settingsPanel then
                settingsPanel = CreateFrame("Frame", nil, contentArea)
                settingsPanel:SetAllPoints()
                UI:CreateSettingsMainTab(settingsPanel)
            end
            settingsPanel:Show()
            pendingLeaveSnapshot = nil
            QueueHubNav(leave, { module = moduleName, subtab = nil })
        end
        return
    end

    if placeholderData[moduleName] then
        UI:RefreshSubNav()
        local key = moduleName .. ":placeholder"
        if not moduleContentFrames[key] then
            local frame = CreateFrame("Frame", nil, contentArea)
            frame:SetAllPoints()
            UI:CreateAddonPlaceholderFrame(frame, placeholderData[moduleName])
            moduleContentFrames[key] = frame
            OneWoW_GUI:ApplyFontToFrame(frame)
        end
        moduleContentFrames[key]:Show()
        pendingLeaveSnapshot = nil
        QueueHubNav(leave, { module = moduleName, subtab = nil })
        return
    end

    local tabs = GetSectionTabs(moduleName)
    if #tabs > 0 then
        local lastSub = ns.db.global.lastSubTabs[moduleName]
        local firstTab = tabs[1].name
        local targetTab = targetSub or lastSub or firstTab

        local found = false
        for _, tabInfo in ipairs(tabs) do
            if tabInfo.name == targetTab then
                found = true
                break
            end
        end
        if not found then targetTab = firstTab end

        UI:SelectSubTab(moduleName, targetTab)
    else
        UI:RefreshSubNav()
        pendingLeaveSnapshot = nil
        QueueHubNav(leave, { module = moduleName, subtab = nil })
    end
end

-- A sub-tab whose content depends on optional data addon(s) can declare
-- `requiresCatalogRole` (CatDB role: loads runtime + enabled era topics),
-- `requiresAddon` (single string), `requiresAnyAddon` (array; available when ANY
-- listed addon is loaded -- for aggregator panels), and/or `isAvailable`
-- (predicate, highest priority). When unavailable, the sub-tab renders a "Not
-- loaded" placeholder instead of its content. A tab with none of these is always
-- available (current behavior).
-- Catalog data packs are lazyStores: opening a pack-backed tab is the load
-- trigger (explicit user action), not login BringUp.
local function EnsureSubTabAddons(tabInfo)
    if not tabInfo then return end
    if tabInfo.requiresCatalogRole then
        ns:EnsureCatalogPack(tabInfo.requiresCatalogRole)
        return
    end
    if tabInfo.requiresAddon then
        ns:EnsureLoaded(tabInfo.requiresAddon)
    end
end

local function SubTabContentAvailable(tabInfo)
    if tabInfo.isAvailable then return tabInfo.isAvailable() and true or false end
    if tabInfo.requiresCatalogRole then
        return ns:IsCatalogPackAvailable(tabInfo.requiresCatalogRole)
    end
    if tabInfo.requiresAddon then return C_AddOns.IsAddOnLoaded(tabInfo.requiresAddon) end
    if tabInfo.requiresAnyAddon then
        for _, addon in ipairs(tabInfo.requiresAnyAddon) do
            if C_AddOns.IsAddOnLoaded(addon) then return true end
        end
        return false
    end
    return true
end

-- Builds a module sub-tab's content frame: real content when available, otherwise
-- the shared placeholder. Tags the frame so SelectSubTab can detect a stale
-- placeholder once the backing addon loads and rebuild it in place.
local function BuildModuleSubTabFrame(tabInfo)
    local frame = CreateFrame("Frame", nil, contentArea)
    frame:SetAllPoints()
    if SubTabContentAvailable(tabInfo) then
        tabInfo.create(frame)
        frame._isPlaceholder = false
    elseif tabInfo.requiresAnyAddon then
        UI:CreateAggregatorPlaceholderFrame(frame, {
            name = (type(tabInfo.displayName) == "function" and tabInfo.displayName()) or tabInfo.displayName,
            addons = tabInfo.requiresAnyAddon,
        })
        frame._isPlaceholder = true
        frame._requiresAnyAddon = tabInfo.requiresAnyAddon
    else
        UI:CreateAddonPlaceholderFrame(frame, {
            addonName = tabInfo.requiresAddon,
            name = (type(tabInfo.displayName) == "function" and tabInfo.displayName()) or tabInfo.displayName,
        })
        frame._isPlaceholder = true
        frame._requiresAddon = tabInfo.requiresAddon
    end
    OneWoW_GUI:ApplyFontToFrame(frame)
    return frame
end

local function FindModuleTab(moduleName, subTabName)
    local mod = ns.ModuleRegistry:GetModule(moduleName)
    if not mod or not mod.tabs then return nil end
    for _, tabInfo in ipairs(mod.tabs) do
        if tabInfo.name == subTabName then return tabInfo end
    end
    return nil
end

function UI:SelectSubTab(moduleName, subTabName)
    local leave = pendingLeaveSnapshot
    pendingLeaveSnapshot = nil
    if not leave and not UI.NavHistory.IsApplying() and UI.NavHistory.IsArmed() then
        leave = SnapshotLocation()
    end

    currentSubTab = subTabName

    ns.db.global.lastSubTabs[moduleName] = subTabName

    if OneWoW_Notes_API and OneWoW_Notes_API.CloseHelpPanel then
        OneWoW_Notes_API.CloseHelpPanel()
    end

    UI:RefreshSubNav()
    HideAllContent()

    local key = moduleName .. ":" .. subTabName

    local moduleTab = FindModuleTab(moduleName, subTabName)
    if moduleTab then
        EnsureSubTabAddons(moduleTab)
    end

    -- Drop a stale placeholder so it rebuilds as real content now that its backing
    -- addon is available (e.g. after a mid-session "Load Data Addons").
    local cached = moduleContentFrames[key]
    if cached and cached._isPlaceholder then
        if moduleTab and SubTabContentAvailable(moduleTab) then
            cached:Hide()
            cached:SetParent(nil)
            moduleContentFrames[key] = nil
        end
    end

    if not moduleContentFrames[key] then
        if moduleName == "settings" and UI.settingsTabs then
            for _, settingsTab in ipairs(UI.settingsTabs) do
                if settingsTab.name == subTabName and settingsTab.create then
                    local frame = CreateFrame("Frame", nil, contentArea)
                    frame:SetAllPoints()
                    settingsTab.create(frame)
                    moduleContentFrames[key] = frame
                    OneWoW_GUI:ApplyFontToFrame(frame)
                    break
                end
            end
        elseif moduleTab and moduleTab.create then
            moduleContentFrames[key] = BuildModuleSubTabFrame(moduleTab)
        end
    end

    if moduleContentFrames[key] then
        moduleContentFrames[key]:Show()
        activeContentFrame = moduleContentFrames[key]
        if activeContentFrame.Activate then
            activeContentFrame:Activate()
        end
    end

    QueueHubNav(leave, { module = moduleName, subtab = subTabName })
end

function UI:GetContentFrame(moduleName, subTabName)
    local key = moduleName .. ":" .. subTabName
    return moduleContentFrames[key]
end

function UI:InitMainWindow()
    if isInitialized then return end
    if not ns.Constants or not ns.Constants.GUI then return end

    L = ns.L
    local C = ns.Constants.GUI

    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    local db = ns.db.global
    -- mainFramePosition is optional (nil = center); not a MergeMissing default.
    local storage = db.mainFramePosition or {}
    if db.mainFrameSize and not storage.width then
        storage.width = db.mainFrameSize.width
        storage.height = db.mainFrameSize.height
        db.mainFramePosition = storage
    end
    local frameW = storage.width or C.WINDOW_WIDTH
    local frameH = storage.height or C.WINDOW_HEIGHT
    frameW = math.min(frameW, screenW)
    frameH = math.min(frameH, screenH)

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoWMainWindow",
        width = frameW,
        height = frameH,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })

    if not OneWoW_GUI:RestoreWindowPosition(MainWindow, storage) then
        MainWindow:SetPoint("CENTER")
    end

    MainWindow:SetMovable(true)
    MainWindow:EnableMouse(true)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetResizable(true)
    local maxW = math.min(C.MAX_WIDTH, screenW)
    local maxH = math.min(C.MAX_HEIGHT, screenH)
    MainWindow:SetResizeBounds(C.MIN_WIDTH, C.MIN_HEIGHT, maxW, maxH)
    MainWindow:SetScript("OnHide", function()
        local g = ns.db.global
        g.mainFramePosition = g.mainFramePosition or {}
        OneWoW_GUI:SaveWindowPosition(MainWindow, g.mainFramePosition)
        -- Cancel any in-flight pin drag (reparents to UIParent) and retire pins.
        ClearPinRow()
        if row2Container then
            row2Container:Hide()
        end
        pendingLeaveSnapshot = nil
        pendingCoalesceLeave = nil
        pendingCoalesceArrive = nil
        coalesceQueued = false
        UI.NavHistory.Clear()
        UI:RefreshNavButtons()
    end)
    MainWindow:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["ADDON_TITLE"],
        height = 20,
        showBrand = true,
        onClose = function() UI:Hide() end,
    })
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetPoint("TOPRIGHT", MainWindow, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() MainWindow:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() MainWindow:StopMovingOrSizing() end)

    local function AttachNavTooltip(btn, title, blizzardTip, peekFn)
        btn:HookScript("OnEnter", function(myself)
            PaintNavIcon(myself, true)
            GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title)
            if blizzardTip and blizzardTip ~= title then
                GameTooltip:AddLine(blizzardTip, 1, 1, 1, true)
            end
            local dest = peekFn()
            local label = dest and FormatNavLabel(dest)
            if label then
                GameTooltip:AddLine(label, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function(myself)
            PaintNavIcon(myself, false)
            GameTooltip:Hide()
        end)
    end

    local closeBtn = titleBar._closeBtn
    navForwardBtn = OneWoW_GUI:CreateAtlasIconButton(titleBar, {
        atlas = "common-icon-forwardarrow",
        width = 20,
        height = 20,
    })
    navForwardBtn:SetPoint("RIGHT", closeBtn, "LEFT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
    navForwardBtn:SetScript("OnClick", function()
        UI:GoForward()
    end)
    AttachNavTooltip(navForwardBtn, BROWSER_FORWARD_TOOLTIP, BROWSER_FORWARD_TOOLTIP, UI.NavHistory.PeekForward)

    navBackBtn = OneWoW_GUI:CreateAtlasIconButton(titleBar, {
        atlas = "common-icon-forwardarrow",
        width = 20,
        height = 20,
    })
    navBackBtn:SetPoint("RIGHT", navForwardBtn, "LEFT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
    navBackBtn.icon:SetTexCoord(1, 0, 0, 1)
    navBackBtn:SetScript("OnClick", function()
        UI:GoBack()
    end)
    AttachNavTooltip(navBackBtn, BACK, BROWSER_BACK_TOOLTIP, UI.NavHistory.PeekBack)

    UI:RefreshNavButtons()

    row1Container = CreateFrame("Frame", nil, MainWindow)
    row1Container:SetHeight(C.ROW1_HEIGHT)
    row1Container:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("XS"))
    row1Container:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -OneWoW_GUI:GetSpacing("XS"))

    row2Container = CreateFrame("Frame", nil, MainWindow)
    row2Container:SetHeight(C.ROW2_FAVORITE_HEIGHT or 22)
    row2Container:SetClipsChildren(true)
    row2Container:Hide()

    pinSink = CreateFrame("Frame", nil, MainWindow)
    pinSink:Hide()

    contentArea = CreateFrame("Frame", nil, MainWindow)
    UpdateContentAreaAnchors()

    BuildSectionList()
    sectionNavDropdown, sectionNavText = OneWoW_GUI:CreateDropdown(row1Container, {
        width = 170,
        height = 26,
        text = SectionLabelFor(currentModuleTab),
    })
    sectionNavDropdown:SetPoint("LEFT", row1Container, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    StyleToolbarDropdown(sectionNavDropdown)
    OneWoW_GUI:AttachFilterMenu(sectionNavDropdown, {
        searchable = false,
        menuWidth = 180,
        buildItems = function()
            return BuildSectionList()
        end,
        onSelect = function(value, displayText)
            sectionNavText:SetText(displayText)
            UI:SelectModuleTab(value)
        end,
        getActiveValue = function()
            return currentModuleTab
        end,
    })

    subNavChevron = row1Container:CreateTexture(nil, "ARTWORK")
    subNavChevron:SetSize(14, 14)
    subNavChevron:SetPoint("LEFT", sectionNavDropdown, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    subNavChevron:SetAtlas("shop-header-arrow-disabled")
    -- Mirror horizontally so the shop arrow reads as a breadcrumb ">".
    subNavChevron:SetTexCoord(1, 0, 0, 1)
    subNavChevron:Hide()

    subNavDropdown, subNavText = OneWoW_GUI:CreateDropdown(row1Container, {
        width = 190,
        height = 26,
        text = "",
    })
    subNavDropdown:SetPoint("LEFT", subNavChevron, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    StyleToolbarDropdown(subNavDropdown)
    OneWoW_GUI:AttachFilterMenu(subNavDropdown, {
        searchable = false,
        menuWidth = 220,
        buildItems = function()
            return BuildSubNavItems()
        end,
        onSelect = function(value, displayText)
            local tabInfo = FindSectionTab(currentModuleTab, value)
            if tabInfo and tabInfo.disabled then
                return
            end
            subNavText:SetText(displayText or value)
            UI:SelectSubTab(currentModuleTab, value)
        end,
        getActiveValue = function()
            return currentSubTab
        end,
    })
    subNavDropdown:Hide()

    favoriteStar = OneWoW_GUI:CreateFavoriteToggleButton(row1Container, {
        size = 16,
        favorite = false,
        tooltipTitle = FAVORITES,
        tooltipText = L["SUBNAV_FAVORITE_TIP"],
        onClick = function(_, isFavorite)
            if not currentSubTab then return end
            SetFavorited(currentModuleTab, currentSubTab, isFavorite)
            UI:RefreshSubNav()
        end,
    })
    favoriteStar:SetPoint("LEFT", subNavDropdown, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    favoriteStar:Hide()

    local searchBoxFrame = nil
    if ns.Search then
        searchBoxFrame = ns.Search:Init(row1Container)
    end

    -- Pin row matches section dropdown left / search right (not full window bleed).
    local row2Gap = OneWoW_GUI:GetSpacing("XS")
    row2Container:ClearAllPoints()
    row2Container:SetPoint("TOP", row1Container, "BOTTOM", 0, -row2Gap)
    row2Container:SetPoint("LEFT", sectionNavDropdown, "LEFT", 0, 0)
    if searchBoxFrame then
        row2Container:SetPoint("RIGHT", searchBoxFrame, "RIGHT", 0, 0)
    else
        row2Container:SetPoint("RIGHT", row1Container, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    end

    local refreshingPinRow = false
    row2Container:SetScript("OnSizeChanged", function()
        if not isInitialized or refreshingPinRow or refreshingSubNav then return end
        refreshingPinRow = true
        UI:RefreshSubNav()
        refreshingPinRow = false
    end)

    if UI.BuildSettingsTabs then
        UI:BuildSettingsTabs()
    end

    local resizeBtn = CreateFrame("Button", nil, MainWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(MainWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function()
        MainWindow:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        MainWindow:StopMovingOrSizing()
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local w, h = MainWindow:GetWidth(), MainWindow:GetHeight()
        if w > sw then MainWindow:SetWidth(sw) end
        if h > sh then MainWindow:SetHeight(sh) end
    end)

    EnsureInUISpecialFrames(FRAME_NAME)
    isInitialized = true

    OneWoW_GUI:ApplyFontToFrame(MainWindow)

    local lastTab = ns.db.global.lastModuleTab
    if not IsValidSection(lastTab) then
        lastTab = "home"
    end

    UI:SelectModuleTab(lastTab)
end

function UI:Show(moduleName)
    local wasHidden = not (MainWindow and MainWindow:IsShown())
    if not isInitialized then
        UI:InitMainWindow()
        wasHidden = true
    else
        UI:RefreshRow1ModuleTabs()
    end
    if MainWindow then
        MainWindow:Show()
        MainWindow:Raise()
        if wasHidden or not UI.NavHistory.IsArmed() then
            UI.NavHistory.SetArmed(true)
            if not UI.NavHistory.Current() then
                UI.NavHistory.Seed(SnapshotLocation())
            end
        end
        if moduleName then
            UI:SelectModuleTab(moduleName)
        else
            -- Init selects the last tab while the window is still hidden; refit pins now.
            UI:RefreshSubNav()
        end
        UI:RefreshNavButtons()
    end
end

function UI:Hide()
    ClearPinRow()
    if MainWindow then
        MainWindow:Hide()
    end
end

function UI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        UI:Hide()
    else
        UI:Show()
    end
end

function UI:GetMainWindow()
    return MainWindow
end

function UI:CreateAddonPlaceholderFrame(parent, info)
    parent.addonName = info.addonName

    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(96, 96)
    icon:SetPoint("CENTER", parent, "CENTER", 0, 60)
    icon:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")

    local nameText = OneWoW_GUI:CreateFS(parent, 16)
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -16)
    nameText:SetText(ns.Locale:GetOptional(ADDON_NAME, info.localeKey) or info.name)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local statusText = OneWoW_GUI:CreateFS(parent, 12)
    statusText:SetPoint("TOP", nameText, "BOTTOM", 0, -8)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function RefreshPlaceholderStatus()
        local state = ns:GetFeatureUnitState(parent.addonName)
        statusText:SetText(ns:GetFeatureUnitStatusLabel(state))
    end

    parent:SetScript("OnShow", RefreshPlaceholderStatus)
    RefreshPlaceholderStatus()

    local linkRow = CreateFrame("Frame", nil, parent)
    linkRow:SetSize(400, 20)
    linkRow:SetPoint("TOP", statusText, "BOTTOM", 0, -24)
    UI:CreateManageFeaturesLinkRow(linkRow, {
        pointerKey = "PLACEHOLDER_ENABLE_POINTER",
        center = true,
    })
end

--- Placeholder for an aggregator panel that has no single backing addon: it draws
--- from several optional data addons (info.addons) and is "available" when ANY of
--- them is loaded. Lists each source with its current load state so the user knows
--- what to enable in Manage Features.
---@param parent Frame
---@param info table { name: string, addons: string[] }
function UI:CreateAggregatorPlaceholderFrame(parent, info)
    local addons = info.addons or {}

    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(96, 96)
    icon:SetPoint("CENTER", parent, "CENTER", 0, 110)
    icon:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")

    local nameText = OneWoW_GUI:CreateFS(parent, 16)
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -16)
    nameText:SetText(info.name or "")
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local descText = OneWoW_GUI:CreateFS(parent, 12)
    descText:SetWidth(440)
    descText:SetJustifyH("CENTER")
    descText:SetPoint("TOP", nameText, "BOTTOM", 0, -10)
    descText:SetText(ns.L["AGGREGATOR_PLACEHOLDER_DESC"])
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    -- One status line per source addon (localized name + current load state).
    local sourceRows = {}
    local anchor = descText
    for _, addon in ipairs(addons) do
        local labelKey = ns:GetStoreLabelKey(addon)
        local fs = OneWoW_GUI:CreateFS(parent, 12)
        fs:SetPoint("TOP", anchor, "BOTTOM", 0, anchor == descText and -16 or -6)
        fs._addon = addon
        fs._label = (labelKey and ns.L[labelKey]) or addon
        sourceRows[#sourceRows + 1] = fs
        anchor = fs
    end

    local function RefreshSourceRows()
        for _, fs in ipairs(sourceRows) do
            local state = ns:GetFeatureUnitState(fs._addon)
            local loaded = C_AddOns.IsAddOnLoaded(fs._addon)
            fs:SetText(fs._label .. "  -  " .. ns:GetFeatureUnitStatusLabel(state))
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(loaded and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end
    end

    parent:SetScript("OnShow", RefreshSourceRows)
    RefreshSourceRows()

    local linkRow = CreateFrame("Frame", nil, parent)
    linkRow:SetSize(400, 20)
    linkRow:SetPoint("TOP", anchor, "BOTTOM", 0, -24)
    UI:CreateManageFeaturesLinkRow(linkRow, {
        pointerKey = "PLACEHOLDER_ENABLE_POINTER",
        center = true,
    })
end

function UI:ResetUIToDefaults()
    local C = ns.Constants.GUI
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    local defW = math.min(C.WINDOW_WIDTH, screenW)
    local defH = math.min(C.WINDOW_HEIGHT, screenH)
    ns.db.global.mainFrameSize = { width = defW, height = defH }
    ns.db.global.mainFramePosition = nil
    UI:FullReset()
    C_Timer.After(0.1, function() UI:Show() end)
end

function UI:FullReset()
    RemoveFromUISpecialFrames(FRAME_NAME)
    ClearPinRow()
    if MainWindow then
        MainWindow:Hide()
        MainWindow:SetParent(nil)
    end
    MainWindow = nil
    isInitialized = false
    currentModuleTab = "home"
    currentSubTab = nil
    row2Buttons = {}
    moduleContentFrames = {}
    row1Container = nil
    row2Container = nil
    pinSink = nil
    contentArea = nil
    homePanel = nil
    settingsPanel = nil
    placeholderData = {}
    sectionNavDropdown = nil
    sectionNavText = nil
    subNavDropdown = nil
    subNavText = nil
    subNavChevron = nil
    favoriteStar = nil
    pinReorder = nil
    wipe(allPinFrames)
    wipe(spilledFavoriteNames)
    pinLayoutPending = false
    refreshingSubNav = false
    wipe(sectionModuleNames)
    wipe(sectionLabels)
    navBackBtn = nil
    navForwardBtn = nil
    pendingLeaveSnapshot = nil
    pendingCoalesceLeave = nil
    pendingCoalesceArrive = nil
    coalesceQueued = false
    UI.NavHistory.Clear()
end

EventRegistry:RegisterCallback("ns.ModuleRegistered", function()
    UI:RefreshRow1ModuleTabs()
end)

EventRegistry:RegisterCallback("ns.FeatureStateChanged", function(_, name)
    UI:RefreshHomeStatus()
    -- A data addon loaded while its placeholder sub-tab is on screen: rebuild it in
    -- place. Off-screen placeholders rebuild lazily on next SelectSubTab. Covers
    -- both single-addon (`_requiresAddon`) and aggregator (`_requiresAnyAddon`) tabs.
    if not (activeContentFrame and activeContentFrame._isPlaceholder
        and currentModuleTab and currentSubTab) then
        return
    end
    local matches = activeContentFrame._requiresAddon == name
    if not matches and activeContentFrame._requiresAnyAddon then
        for _, addon in ipairs(activeContentFrame._requiresAnyAddon) do
            if addon == name then matches = true break end
        end
    end
    if matches then
        UI:SelectSubTab(currentModuleTab, currentSubTab)
    end
end)

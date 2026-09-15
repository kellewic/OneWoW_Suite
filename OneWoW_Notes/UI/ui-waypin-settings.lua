local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 16, edgeSize = 1,
}

local dialog
local syncFns = {}

local function CreateToggleRow(parent, labelKey, descKey, isEnabled, onToggle)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetBackdrop(backdrop)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local toggleBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    toggleBtn:SetSize(70, 28)
    toggleBtn:SetPoint("LEFT", row, "LEFT", 10, 0)
    toggleBtn:SetBackdrop(BACKDROP_INNER_NO_INSETS)

    local toggleLabel = OneWoW_GUI:CreateFS(toggleBtn, 12)
    toggleLabel:SetPoint("CENTER")

    local function RefreshToggle(enabled)
        if enabled then
            toggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            toggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            toggleLabel:SetText(L["SETTINGS_ENABLED"])
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            toggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            toggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            toggleLabel:SetText(L["SETTINGS_DISABLED"])
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    RefreshToggle(isEnabled())

    toggleBtn:SetScript("OnClick", function()
        RefreshToggle(onToggle())
    end)
    toggleBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
    end)
    toggleBtn:SetScript("OnLeave", function()
        RefreshToggle(isEnabled())
    end)

    local label = OneWoW_GUI:CreateFS(row, 12)
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 90, -10)
    label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -10)
    label:SetJustifyH("LEFT")
    label:SetText(L[labelKey])
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local desc = OneWoW_GUI:CreateFS(row, 10)
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(L[descKey])
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    row.label = label
    row.desc = desc
    tinsert(syncFns, function()
        RefreshToggle(isEnabled())
    end)
    return row
end

local function MeasureRow(row, minHeight)
    local labelH = row.label and row.label:GetStringHeight() or 14
    local descH = row.desc and row.desc:GetStringHeight() or 12
    local h = 10 + labelH + 4 + descH + 10
    if h < minHeight then
        h = minHeight
    end
    row:SetHeight(h)
    return h
end

local function LayoutSettings()
    if not dialog then return end
    local content = dialog.scrollContent
    local y = -12
    local width = content:GetWidth()
    if width < 40 then
        width = 460
    end

    for _, row in ipairs(dialog.rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, y)
        y = y - MeasureRow(row, row.minHeight or 56) - 8
    end
    content:SetHeight((-y) + 8)
end

local function EnsureDialog()
    if dialog then return dialog end
    wipe(syncFns)

    dialog = OneWoW_GUI:CreateDialog({
        name            = "OneWoW_NotesWayPinSettings",
        title           = L["WAYPINS_SETTINGS_TITLE"],
        width           = 520,
        height          = 720,
        showScrollFrame = true,
        buttons         = {
            { text = CLOSE, onClick = function(f) f:Hide() end },
        },
        relayout = function()
            LayoutSettings()
        end,
    })

    local content = dialog.scrollContent
    local rows = {}

    local master = CreateToggleRow(
        content,
        "TAB_WAYPINS",
        "SETTINGS_WAYPINS_ENABLED_DESC",
        function() return ns.WayPinsVisual.Enabled() end,
        function()
            OneWoW_Notes_API.SetWayPinsEnabled(not ns.WayPinsVisual.Enabled())
            return ns.WayPinsVisual.Enabled()
        end
    )
    master.minHeight = 62
    tinsert(rows, master)

    local world = CreateToggleRow(
        content,
        "WAYPINS_SHOW_WORLD",
        "SETTINGS_WAYPINS_WORLD_DESC",
        function() return ns.db.global.waypinShowWorld ~= false end,
        function()
            ns.db.global.waypinShowWorld = not (ns.db.global.waypinShowWorld ~= false)
            if ns.WayPinsMap then ns.WayPinsMap:Refresh() end
            return ns.db.global.waypinShowWorld ~= false
        end
    )
    world.minHeight = 62
    tinsert(rows, world)

    local mini = CreateToggleRow(
        content,
        "WAYPINS_SHOW_MINIMAP",
        "SETTINGS_WAYPINS_MINIMAP_DESC",
        function() return ns.db.global.waypinShowMinimap ~= false end,
        function()
            ns.db.global.waypinShowMinimap = not (ns.db.global.waypinShowMinimap ~= false)
            if ns.WayPinsMap then ns.WayPinsMap:Refresh() end
            return ns.db.global.waypinShowMinimap ~= false
        end
    )
    mini.minHeight = 62
    tinsert(rows, mini)

    local legend = CreateToggleRow(
        content,
        "WAYPINS_SHOW_MAP_PANEL",
        "SETTINGS_WAYPINS_MAP_PANEL_DESC",
        function() return ns.db.global.waypinShowMapPanel ~= false end,
        function()
            ns.db.global.waypinShowMapPanel = not (ns.db.global.waypinShowMapPanel ~= false)
            if ns.WayPinsMapPanel then ns.WayPinsMapPanel:Sync() end
            return ns.db.global.waypinShowMapPanel ~= false
        end
    )
    legend.minHeight = 62
    tinsert(rows, legend)

    local zoneList = CreateToggleRow(
        content,
        "WAYPINS_SHOW_ZONE_LIST",
        "SETTINGS_WAYPINS_ZONE_LIST_DESC",
        function() return ns.db.global.waypinShowZoneList ~= false end,
        function()
            ns.db.global.waypinShowZoneList = not (ns.db.global.waypinShowZoneList ~= false)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
            return ns.db.global.waypinShowZoneList ~= false
        end
    )
    zoneList.minHeight = 62
    tinsert(rows, zoneList)

    local hideInst = CreateToggleRow(
        content,
        "WAYPINS_HIDE_IN_INSTANCES",
        "SETTINGS_WAYPINS_HIDE_INSTANCES_DESC",
        function() return ns.db.global.waypinHideInInstances ~= false end,
        function()
            ns.db.global.waypinHideInInstances = not (ns.db.global.waypinHideInInstances ~= false)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
            return ns.db.global.waypinHideInInstances ~= false
        end
    )
    hideInst.minHeight = 62
    tinsert(rows, hideInst)

    local hideDelve = CreateToggleRow(
        content,
        "WAYPINS_HIDE_IN_DELVES",
        "SETTINGS_WAYPINS_HIDE_DELVES_DESC",
        function() return ns.db.global.waypinHideInDelves ~= false end,
        function()
            ns.db.global.waypinHideInDelves = not (ns.db.global.waypinHideInDelves ~= false)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
            return ns.db.global.waypinHideInDelves ~= false
        end
    )
    hideDelve.minHeight = 62
    tinsert(rows, hideDelve)

    local hidePet = CreateToggleRow(
        content,
        "WAYPINS_HIDE_IN_PET_BATTLES",
        "SETTINGS_WAYPINS_HIDE_PET_BATTLES_DESC",
        function() return ns.db.global.waypinHideInPetBattles ~= false end,
        function()
            ns.db.global.waypinHideInPetBattles = not (ns.db.global.waypinHideInPetBattles ~= false)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
            return ns.db.global.waypinHideInPetBattles ~= false
        end
    )
    hidePet.minHeight = 62
    tinsert(rows, hidePet)

    local hidePvp = CreateToggleRow(
        content,
        "WAYPINS_HIDE_IN_BATTLEGROUNDS",
        "SETTINGS_WAYPINS_HIDE_BATTLEGROUNDS_DESC",
        function() return ns.db.global.waypinHideInBattlegrounds ~= false end,
        function()
            ns.db.global.waypinHideInBattlegrounds = not (ns.db.global.waypinHideInBattlegrounds ~= false)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
            return ns.db.global.waypinHideInBattlegrounds ~= false
        end
    )
    hidePvp.minHeight = 62
    tinsert(rows, hidePvp)

    local clickMenu = CreateToggleRow(
        content,
        "WAYPINS_MAP_CLICK_MENU",
        "SETTINGS_WAYPINS_MAP_CLICK_MENU_DESC",
        function() return ns.WayPinsVisual.MapClickMenu() end,
        function()
            ns.db.global.waypinMapClickEnabled = not ns.WayPinsVisual.MapClickMenu()
            return ns.WayPinsVisual.MapClickMenu()
        end
    )
    clickMenu.minHeight = 62
    tinsert(rows, clickMenu)

    local clickRow = CreateFrame("Frame", nil, content, "BackdropTemplate")
    clickRow:SetBackdrop(backdrop)
    clickRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    clickRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    local clickDD = ns.UI.CreateThemedDropdown(clickRow, nil, 130, 26)
    clickDD:SetPoint("LEFT", clickRow, "LEFT", 10, 0)
    ns.UI.BindWaypinMapClickDropdown(clickDD)
    local clickLabel = OneWoW_GUI:CreateFS(clickRow, 12)
    clickLabel:SetPoint("TOPLEFT", clickRow, "TOPLEFT", 145, -10)
    clickLabel:SetPoint("TOPRIGHT", clickRow, "TOPRIGHT", -10, -10)
    clickLabel:SetJustifyH("LEFT")
    clickLabel:SetText(L["WAYPINS_MAP_CLICK"])
    clickLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local clickDesc = OneWoW_GUI:CreateFS(clickRow, 10)
    clickDesc:SetPoint("TOPLEFT", clickLabel, "BOTTOMLEFT", 0, -4)
    clickDesc:SetPoint("TOPRIGHT", clickRow, "TOPRIGHT", -10, 0)
    clickDesc:SetJustifyH("LEFT")
    clickDesc:SetWordWrap(true)
    clickDesc:SetText(L["SETTINGS_WAYPINS_MAP_CLICK_DESC"])
    clickDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    clickRow.label = clickLabel
    clickRow.desc = clickDesc
    clickRow.minHeight = 62
    tinsert(rows, clickRow)

    local sizeRow = CreateFrame("Frame", nil, content, "BackdropTemplate")
    sizeRow:SetBackdrop(backdrop)
    sizeRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    sizeRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    local worldSizeLabel = OneWoW_GUI:CreateFS(sizeRow, 11)
    worldSizeLabel:SetPoint("TOPLEFT", 12, -10)
    worldSizeLabel:SetText(L["WAYPINS_SIZE_WORLD"])
    worldSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local worldSlider = OneWoW_GUI:CreateSlider(sizeRow, {
        minVal = 12,
        maxVal = ns.WayPinsVisual.WorldSizeMax(),
        step = 1,
        currentVal = ns.db.global.waypinWorldSize,
        width = 220,
        fmt = "%.0f",
        onChange = function(val)
            ns.db.global.waypinWorldSize = val
            if ns.WayPinsMap then ns.WayPinsMap:Refresh() end
        end,
    })
    worldSlider:SetPoint("TOPLEFT", sizeRow, "TOPLEFT", 12, -28)
    local miniSizeLabel = OneWoW_GUI:CreateFS(sizeRow, 11)
    miniSizeLabel:SetPoint("TOPLEFT", 12, -58)
    miniSizeLabel:SetText(L["WAYPINS_SIZE_MINIMAP"])
    miniSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local miniSlider = OneWoW_GUI:CreateSlider(sizeRow, {
        minVal = 10,
        maxVal = ns.WayPinsVisual.MinimapSizeMax(),
        step = 1,
        currentVal = ns.db.global.waypinMinimapSize,
        width = 220,
        fmt = "%.0f",
        onChange = function(val)
            ns.db.global.waypinMinimapSize = val
            if ns.WayPinsMap then ns.WayPinsMap:Refresh() end
        end,
    })
    miniSlider:SetPoint("TOPLEFT", sizeRow, "TOPLEFT", 12, -76)
    sizeRow.minHeight = 110
    sizeRow.label = worldSizeLabel
    sizeRow.desc = miniSizeLabel
    tinsert(syncFns, function()
        worldSlider.slider:SetValue(ns.db.global.waypinWorldSize)
        miniSlider.slider:SetValue(ns.db.global.waypinMinimapSize)
    end)
    tinsert(rows, sizeRow)

    local anim = CreateToggleRow(
        content,
        "WAYPINS_MINIMAP_ANIM",
        "SETTINGS_WAYPINS_MINIMAP_ANIM_DESC",
        function() return ns.db.global.waypinMinimapAnimate == true end,
        function()
            ns.db.global.waypinMinimapAnimate = not (ns.db.global.waypinMinimapAnimate == true)
            if ns.WayPinsMap then ns.WayPinsMap:Refresh() end
            return ns.db.global.waypinMinimapAnimate == true
        end
    )
    anim.minHeight = 62
    tinsert(rows, anim)

    dialog.rows = rows
    function ns.UI.SyncWayPinSettings()
        for _, fn in ipairs(syncFns) do
            fn()
        end
        if ns.UI.SyncWaypinMapClick then
            ns.UI.SyncWaypinMapClick()
        end
    end
    return dialog
end

function ns.UI.OpenWayPinSettings()
    EnsureDialog()
    ns.UI.SyncWayPinSettings()
    LayoutSettings()
    dialog.frame:Show()
    dialog.frame:Raise()
end

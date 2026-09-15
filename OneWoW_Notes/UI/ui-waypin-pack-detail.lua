local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local C = OneWoW_GUI.Constants
local Visual = ns.WayPinsVisual
local strtrim = strtrim

ns.UI = ns.UI or {}

local PACK_PIN_H = 32

local pane
local widgets = {}
local pinRows = {}
local reorder
local painting = false
local currentPackId
local mapFilterRef = "current"
local highlightPinId

local function Location()
    return OneWoW.Location
end

local function EnsureReorder()
    if reorder then
        return reorder
    end
    reorder = ns.UI.CreateNotesListReorderDrag({
        getItems = function()
            local items = {}
            for _, row in ipairs(pinRows) do
                if row:IsShown() then
                    tinsert(items, row)
                end
            end
            return items
        end,
        getScrollFrame = function()
            return widgets.pinScroll
        end,
        onReorder = function(fromIdx, toIdx, insertBefore)
            if not currentPackId then
                return
            end
            local items = {}
            for _, row in ipairs(pinRows) do
                if row:IsShown() then
                    tinsert(items, row)
                end
            end
            local fromRow = items[fromIdx]
            local toRow = items[toIdx]
            if not fromRow or not toRow then
                return
            end
            ns.WayPinPacks:ReorderPins(currentPackId, fromRow._packIndex, toRow._packIndex, insertBefore)
        end,
    })
    return reorder
end

local function SavePackMeta()
    if painting or not currentPackId then
        return
    end
    local pack = ns.WayPinPacks:GetPack(currentPackId)
    if not pack then
        return
    end
    local name = strtrim(widgets.nameBox:GetSearchText() or "")
    if name == "" then
        name = pack.name
        widgets.nameBox:SetText(name or "")
    end
    local expansion = widgets.expDD:GetValue()
    if expansion == "" then
        expansion = nil
    end
    if name == pack.name and expansion == pack.expansion then
        return
    end
    ns.WayPinPacks:SetMeta(currentPackId, name, expansion)
end

local function LayoutPinRows(pack)
    local y = 0
    local filterID = mapFilterRef == "current" and tonumber(Location().GetPlayerMapID())
    local shown = 0
    local total = ns.WayPinPacks:PackPinCount(pack)
    local drag = EnsureReorder()
    for _, row in ipairs(pinRows) do
        row:Hide()
        drag:Detach(row)
    end
    for i, pin in ipairs(pack.pins) do
        if not filterID or tonumber(pin.mapID) == filterID then
            shown = shown + 1
            local row = pinRows[shown]
            if not row then
                row = CreateFrame("Button", nil, widgets.pinChild, "BackdropTemplate")
                row:SetHeight(PACK_PIN_H)
                row:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

                local preview = CreateFrame("Button", nil, row)
                preview:SetSize(20, 20)
                preview:SetPoint("LEFT", 6, 0)
                preview:EnableMouse(false)
                Visual.Attach(preview)
                row.preview = preview

                local editBtn = OneWoW_GUI:CreateFitTextButton(row, { text = EDIT, height = 20, minWidth = 36 })
                editBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                editBtn:SetScript("OnClick", function(myself)
                    local id = myself:GetParent().displayId
                    local data = id and ns.WayPins:GetPin(id)
                    if data then
                        ns.UI.OpenWayPinDialog(data)
                    end
                end)
                row.editBtn = editBtn

                local title = OneWoW_GUI:CreateFS(row, 12)
                title:SetPoint("LEFT", preview, "RIGHT", 8, 4)
                title:SetPoint("RIGHT", editBtn, "LEFT", -6, 4)
                title:SetJustifyH("LEFT")
                title:SetWordWrap(false)
                row.title = title

                local sub = OneWoW_GUI:CreateFS(row, 10)
                sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
                sub:SetPoint("RIGHT", editBtn, "LEFT", -6, 0)
                sub:SetJustifyH("LEFT")
                sub:SetWordWrap(false)
                row.sub = sub

                row:SetScript("OnClick", function(myself, button)
                    if drag:ShouldSuppressClick() then
                        return
                    end
                    local data = myself.displayId and ns.WayPins:GetPin(myself.displayId)
                    if not data then
                        return
                    end
                    if button == "RightButton" then
                        ns.WayPinsMap:ShowPinMenu(myself, data, { hideOpenTab = true })
                    end
                end)
                pinRows[shown] = row
            end
            local display = ns.WayPinPacks:BuildDisplayPin(pack, pin)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", widgets.pinChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", widgets.pinChild, "TOPRIGHT", 0, -y)
            row.displayId = display.id
            row._packIndex = i
            row._reorderIndex = shown
            row.title:SetText(pin.title or L["WAYPINS_UNTITLED"])
            row.sub:SetText(string.format("%s (%.1f, %.1f)", ns.WayPins:MapDisplayName(pin.mapID), pin.x or 0, pin.y or 0))
            row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            Visual.Apply(row.preview, display, { size = 20, animate = false })
            local lit = highlightPinId and highlightPinId == display.id
            if lit then
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                row.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            row:Show()
            if pack.orderLocked then
                drag:Detach(row)
            else
                drag:Attach(row, shown)
            end
            y = y + PACK_PIN_H + 2
        end
    end
    widgets.pinChild:SetHeight(math.max(y, 1))
    widgets.pinCount:SetText(string.format("%d / %d", shown, total))
end

local function EnsurePane(parent)
    if pane then
        return pane
    end

    pane = CreateFrame("Frame", nil, parent)
    pane:SetAllPoints(parent)
    pane:EnableMouse(true)
    pane:Hide()

    local header = ns.UI.CreateThemedBar(nil, pane)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(112)
    widgets.header = header
    header:EnableMouse(true)
    header:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" and currentPackId then
            ns.WayPinsMap:ShowPackMenu(myself, currentPackId)
        end
    end)

    local preview = CreateFrame("Button", nil, header)
    preview:SetSize(40, 40)
    preview:SetPoint("TOPLEFT", 10, -16)
    preview:EnableMouse(false)
    Visual.Attach(preview)
    widgets.preview = preview

    local nameBox = OneWoW_GUI:CreateEditBox(header, {
        placeholderText = L["WAYPINS_PACK_NAME_PH"],
        width = 280,
        maxLetters = 60,
    })
    nameBox:SetPoint("TOPLEFT", preview, "TOPRIGHT", 10, 0)
    nameBox:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    nameBox:HookScript("OnEnterPressed", function(myself)
        myself:ClearFocus()
        SavePackMeta()
    end)
    nameBox:HookScript("OnEditFocusLost", function()
        SavePackMeta()
    end)
    widgets.nameBox = nameBox

    local expDD = ns.UI.CreateThemedDropdown(header, L["EXPANSION"], 240, 24, ns.UI.GetWayPinExpansionMenuHeight())
    expDD:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)
    expDD:SetOptions(ns.UI.GetWayPinExpansionOptions())
    expDD.onSelect = function()
        SavePackMeta()
    end
    widgets.expDD = expDD

    local zones = OneWoW_GUI:CreateFS(header, 11)
    zones:SetPoint("TOPLEFT", expDD, "BOTTOMLEFT", 0, -6)
    zones:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    zones:SetJustifyH("LEFT")
    zones:SetWordWrap(false)
    zones:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    widgets.zones = zones

    local source = OneWoW_GUI:CreateFS(header, 11)
    source:SetPoint("TOPLEFT", zones, "BOTTOMLEFT", 0, -2)
    source:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    source:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    widgets.source = source

    local options = ns.UI.CreateThemedBar(nil, pane)
    options:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    options:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8)
    options:SetHeight(196)
    widgets.options = options

    local enableLabel = OneWoW_GUI:CreateFS(options, 12)
    enableLabel:SetPoint("TOPLEFT", 12, -12)
    enableLabel:SetText(ENABLE)
    enableLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local enableBtn, enableRefresh = OneWoW_GUI:CreateOnOffToggleButtons(options, {
        onLabel = L["SETTINGS_ENABLED"],
        offLabel = L["SETTINGS_DISABLED"],
        isEnabled = true,
        value = true,
        onValueChange = function(val)
            if currentPackId then
                ns.WayPinPacks:SetEnabled(currentPackId, val)
            end
            return true
        end,
    })
    enableBtn:SetPoint("LEFT", enableLabel, "RIGHT", 10, 0)
    widgets.enableRefresh = enableRefresh

    local lookBtn = OneWoW_GUI:CreateFitTextButton(options, { text = L["WAYPINS_PACK_LOOK"], height = 24 })
    lookBtn:SetPoint("TOPLEFT", 12, -44)
    lookBtn:SetScript("OnClick", function()
        if currentPackId then
            ns.UI.OpenWayPinPackLook(currentPackId)
        end
    end)

    local exportBtn = OneWoW_GUI:CreateFitTextButton(options, { text = L["WAYPINS_EXPORT"], height = 24 })
    exportBtn:SetPoint("LEFT", lookBtn, "RIGHT", 8, 0)
    exportBtn:SetScript("OnClick", function()
        if currentPackId then
            ns.UI.OpenWayPinPackExport(currentPackId)
        end
    end)

    local addHereBtn = OneWoW_GUI:CreateFitTextButton(options, { text = L["WAYPINS_ADD_HERE"], height = 24 })
    addHereBtn:SetPoint("TOPLEFT", 12, -76)
    addHereBtn:SetScript("OnClick", function()
        if currentPackId then
            ns.WayPinsMap:AddHere(currentPackId)
        end
    end)

    local findBtn = OneWoW_GUI:CreateFitTextButton(options, { text = L["WAYPINS_FIND_LOCATION"], height = 24 })
    findBtn:SetPoint("LEFT", addHereBtn, "RIGHT", 8, 0)
    findBtn:SetScript("OnClick", function()
        if currentPackId then
            ns.UI.OpenWayPinFindDialog(currentPackId)
        end
    end)

    local removeBtn = OneWoW_GUI:CreateFitTextButton(options, { text = DELETE, height = 24 })
    removeBtn:SetPoint("LEFT", findBtn, "RIGHT", 8, 0)
    removeBtn:SetScript("OnClick", function()
        if currentPackId then
            ns.UI.OpenWayPinPackRemove(currentPackId)
        end
    end)

    local lockCb = OneWoW_GUI:CreateCheckbox(options, {
        label = L["WAYPINS_LOCK_ORDER"],
        checked = false,
        onClick = function(myself)
            if currentPackId then
                ns.WayPinPacks:SetOrderLocked(currentPackId, myself:GetChecked())
                ns.UI.PaintWayPinPackPane()
            end
        end,
    })
    lockCb:SetPoint("LEFT", removeBtn, "RIGHT", 12, 0)
    widgets.lockCb = lockCb

    local showListCb = OneWoW_GUI:CreateCheckbox(options, {
        label = L["WAYPINS_SHOW_ON_LIST"],
        checked = true,
        onClick = function(myself)
            if currentPackId then
                ns.WayPinPacks:SetShowFlag(currentPackId, "showOnList", myself:GetChecked())
            end
        end,
    })
    showListCb:SetPoint("TOPLEFT", 12, -108)
    widgets.showListCb = showListCb

    local showWorldCb = OneWoW_GUI:CreateCheckbox(options, {
        label = L["WAYPINS_SHOW_WORLD"],
        checked = true,
        onClick = function(myself)
            if currentPackId then
                ns.WayPinPacks:SetShowFlag(currentPackId, "showOnWorld", myself:GetChecked())
            end
        end,
    })
    showWorldCb:SetPoint("TOPLEFT", showListCb, "BOTTOMLEFT", 0, -2)
    widgets.showWorldCb = showWorldCb

    local showMiniCb = OneWoW_GUI:CreateCheckbox(options, {
        label = L["WAYPINS_SHOW_MINIMAP"],
        checked = true,
        onClick = function(myself)
            if currentPackId then
                ns.WayPinPacks:SetShowFlag(currentPackId, "showOnMinimap", myself:GetChecked())
            end
        end,
    })
    showMiniCb:SetPoint("TOPLEFT", showWorldCb, "BOTTOMLEFT", 0, -2)
    widgets.showMiniCb = showMiniCb

    local listHeader = OneWoW_GUI:CreateFS(pane, 12)
    listHeader:SetPoint("TOPLEFT", options, "BOTTOMLEFT", 4, -10)
    listHeader:SetText(L["WAYPINS_PACK_PINS"])
    listHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    widgets.listHeader = listHeader

    local pinCount = OneWoW_GUI:CreateFS(pane, 11)
    pinCount:SetPoint("LEFT", listHeader, "RIGHT", 8, 0)
    pinCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    widgets.pinCount = pinCount

    local listHint = OneWoW_GUI:CreateFS(pane, 11)
    listHint:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -4)
    listHint:SetPoint("RIGHT", pane, "RIGHT", -4, 0)
    listHint:SetJustifyH("LEFT")
    listHint:SetWordWrap(false)
    listHint:SetText(L["MINIMAP_RIGHT_CLICK"])
    listHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    widgets.listHint = listHint

    local pinScroll, pinChild = OneWoW_GUI:CreateScrollFrame(pane, {})
    pinScroll:ClearAllPoints()
    pinScroll:SetPoint("TOPLEFT", listHint, "BOTTOMLEFT", 0, -6)
    pinScroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    widgets.pinScroll = pinScroll
    widgets.pinChild = pinChild

    return pane
end

function ns.UI.HideWayPinPackPane()
    if pane then
        pane:Hide()
    end
    currentPackId = nil
end

function ns.UI.PaintWayPinPackPane()
    if not pane or not currentPackId then
        return
    end
    local pack = ns.WayPinPacks:GetPack(currentPackId)
    if not pack then
        pane:Hide()
        return
    end
    painting = true
    Visual.Apply(widgets.preview, ns.WayPinPacks:LookForPaint(pack), { size = 40, animate = false })
    local name = pack.name or ""
    if widgets.nameBox:GetSearchText() ~= name then
        widgets.nameBox:SetText(name)
    end
    local expVal = pack.expansion
    if type(expVal) ~= "number" then
        expVal = ""
    end
    widgets.expDD:SetSelected(expVal)
    local zones = ns.WayPinPacks:ZoneNames(pack, mapFilterRef)
    if zones == "" then
        widgets.zones:SetText(string.format("%s: %s", L["TAB_ZONES"], NONE))
    else
        widgets.zones:SetText(string.format("%s: %s", L["TAB_ZONES"], zones))
    end
    local sourceKey = pack.source == "import" and "WAYPINS_PACK_SOURCE_IMPORT" or "WAYPINS_PACK_SOURCE_USER"
    widgets.source:SetText(string.format("%s: %s", L["WAYPINS_PACK_SOURCE"], L[sourceKey]))
    widgets.enableRefresh(true, ns.WayPinPacks:IsEnabled(pack))
    widgets.lockCb:SetChecked(pack.orderLocked == true)
    widgets.showListCb:SetChecked(ns.WayPinPacks:ShowsOn(pack, "showOnList"))
    widgets.showWorldCb:SetChecked(ns.WayPinPacks:ShowsOn(pack, "showOnWorld"))
    widgets.showMiniCb:SetChecked(ns.WayPinPacks:ShowsOn(pack, "showOnMinimap"))
    LayoutPinRows(pack)
    painting = false
    pane:Show()
end

function ns.UI.ShowWayPinPackPane(parent, packId, filter, highlightId)
    EnsurePane(parent)
    if pane:GetParent() ~= parent then
        pane:SetParent(parent)
        pane:SetAllPoints(parent)
    end
    currentPackId = packId
    mapFilterRef = filter or "current"
    highlightPinId = highlightId
    ns.UI.PaintWayPinPackPane()
end

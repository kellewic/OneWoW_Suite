local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local C = OneWoW_GUI.Constants
local Visual = ns.WayPinsVisual

ns.UI = ns.UI or {}

local selectedID
local selectedKind = "pin"
local highlightPackPinId
local listRows = {}
local showDisabledCb
local mapFilter = "current"
local storageFilter = "All"
local searchFilter = ""
local mapDropdown
local scrollChild
local emptyMessage
local listEmptyMessage
local leftStatusText
local detailWidgets = {}

local ROW_H = 38

local function ShowDisabledPacks()
    return ns.db.global.waypinShowDisabledPacks ~= false
end

local function PackMatchesSearch(pack)
    if searchFilter == "" then
        return true
    end
    local expName = ns.WayPinPacks:ExpansionLabel(pack)
    local hay = (pack.name or "") .. " " .. (expName or "")
    if hay:lower():find(searchFilter, 1, true) then
        return true
    end
    for _, pin in ipairs(pack.pins) do
        local pinHay = (pin.title or "") .. " " .. (pin.note or "")
        if pinHay:lower():find(searchFilter, 1, true) then
            return true
        end
    end
    return false
end

local function MatchesFilters(pin)
    if storageFilter ~= "All" and pin.storage ~= storageFilter then
        return false
    end
    if mapFilter == "current" then
        local mapID = Location.GetPlayerMapID()
        if tonumber(pin.mapID) ~= mapID then
            return false
        end
    end
    if searchFilter ~= "" then
        local hay = (pin.title or "") .. " " .. (pin.description or "") .. " " .. ns.WayPins:MapDisplayName(pin.mapID)
        if not hay:lower():find(searchFilter, 1, true) then
            return false
        end
    end
    return true
end

local function FilteredList()
    local out = {}
    local total = 0
    for _, pin in pairs(ns.WayPins:GetAll()) do
        if type(pin) == "table" then
            total = total + 1
            if MatchesFilters(pin) then
                tinsert(out, { kind = "pin", pin = pin })
            end
        end
    end
    local mapID = mapFilter == "current" and Location.GetPlayerMapID() or nil
    for _, pack in ipairs(ns.WayPinPacks:GetAllPacks()) do
        total = total + 1
        local enabled = pack.enabled ~= false
        if (enabled or ShowDisabledPacks())
            and PackMatchesSearch(pack)
            and (not mapID or ns.WayPinPacks:PackHasMap(pack, mapID))
        then
            tinsert(out, { kind = "pack", pack = pack })
        end
    end
    sort(out, function(a, b)
        if a.kind ~= b.kind then
            return a.kind == "pin"
        end
        if a.kind == "pack" then
            return (a.pack.name or "") < (b.pack.name or "")
        end
        local za = ns.WayPins:MapDisplayName(a.pin.mapID)
        local zb = ns.WayPins:MapDisplayName(b.pin.mapID)
        if za == zb then
            return (a.pin.title or "") < (b.pin.title or "")
        end
        return za < zb
    end)
    return out, total
end

local function EmptyListCopy()
    if searchFilter ~= "" or storageFilter ~= "All" then
        return L["WAYPINS_NO_MATCH"]
    end
    if mapFilter == "current" then
        return L["WAYPINS_MAP_PANEL_EMPTY"]
    end
    return L["WAYPINS_EMPTY"]
end

local function PinForPaint(pin)
    local draft = ns.WayPinsMap and ns.WayPinsMap:GetPreviewDraft()
    if draft and pin and draft.id and draft.id == pin.id then
        return draft
    end
    return pin
end

local function HideDetail()
    emptyMessage:Show()
    ns.UI.HideWayPinPackPane()
    for key, w in pairs(detailWidgets) do
        if key == "preview" then
            Visual.Hide(w)
        elseif w.Hide then
            w:Hide()
        end
    end
end

local function PaintDetail()
    if selectedKind == "pack" then
        local pack = selectedID and ns.WayPinPacks:GetPack(selectedID)
        if not pack then
            HideDetail()
            return
        end
        emptyMessage:Hide()
        for key, w in pairs(detailWidgets) do
            if key ~= "packHost" then
                if key == "preview" then
                    Visual.Hide(w)
                elseif w.Hide then
                    w:Hide()
                end
            end
        end
        detailWidgets.packHost:Show()
        ns.UI.ShowWayPinPackPane(detailWidgets.packHost, selectedID, mapFilter, highlightPackPinId)
        return
    end
    if detailWidgets.packHost then
        detailWidgets.packHost:Hide()
    end
    ns.UI.HideWayPinPackPane()
    local pin = selectedID and ns.WayPins:GetPin(selectedID)
    if not pin then
        HideDetail()
        return
    end
    emptyMessage:Hide()
    for key, w in pairs(detailWidgets) do
        if key ~= "packHost" and w.Show then
            w:Show()
        end
    end
    local paint = PinForPaint(pin)
    Visual.Apply(detailWidgets.preview, paint, { size = 40 })
    detailWidgets.title:SetText(paint.title or L["WAYPINS_UNTITLED"])
    detailWidgets.zone:SetText(string.format("%s (%d)", ns.WayPins:MapDisplayName(paint.mapID), paint.mapID))
    detailWidgets.coords:SetText(string.format("%.1f, %.1f", paint.x or 0, paint.y or 0))
    local stor = pin.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"]
    detailWidgets.storage:SetText(string.format(L["UI_STORAGE_WITH_VALUE"], stor))
    local description = paint.description
    local extra = 0
    if type(description) == "string" and description ~= "" then
        detailWidgets.desc:SetText(description)
        detailWidgets.desc:Show()
        extra = math.max(detailWidgets.desc:GetStringHeight(), 12) + 8
    else
        detailWidgets.desc:SetText("")
        detailWidgets.desc:Hide()
    end
    detailWidgets.infoBar:SetHeight(72 + extra)
end

local function PaintPinRow(row, pin)
    row.kind = "pin"
    row.pinID = pin.id
    row.packID = nil
    row.title:SetText(pin.title or L["WAYPINS_UNTITLED"])
    row.sub:SetText(string.format("%s (%d)", ns.WayPins:MapDisplayName(pin.mapID), pin.mapID))
    Visual.Apply(row.preview, PinForPaint(pin), { size = 22, animate = false })
    local selected = selectedKind == "pin" and selectedID == pin.id
    if selected then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        row.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
end

local function PaintPackRow(row, pack)
    row.kind = "pack"
    row.pinID = nil
    row.packID = pack.id
    row.title:SetText(pack.name or "")
    local count = ns.WayPinPacks:PackPinCount(pack)
    local sub = string.format("%s (%d)", L["WAYPINS_PACK_BADGE"], count)
    local enabled = pack.enabled ~= false
    if not enabled then
        sub = sub .. " - " .. L["SETTINGS_DISABLED"]
        row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    else
        row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
    row.sub:SetText(sub)
    Visual.Apply(row.preview, ns.WayPinPacks:LookForPaint(pack), { size = 22, animate = false })
    if selectedKind == "pack" and selectedID == pack.id then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        if enabled then
            row.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end
end

function ns.UI.RefreshWayPinsTab()
    if not scrollChild then return end
    local list, total = FilteredList()
    for _, row in ipairs(listRows) do
        row:Hide()
    end
    local y = 0
    for i, entry in ipairs(list) do
        local row = listRows[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            local preview = CreateFrame("Button", nil, row)
            preview:SetSize(22, 22)
            preview:SetPoint("LEFT", 8, 0)
            preview:EnableMouse(false)
            Visual.Attach(preview)
            row.preview = preview

            local title = OneWoW_GUI:CreateFS(row, 12)
            title:SetPoint("TOPLEFT", preview, "TOPRIGHT", 8, 2)
            title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            row.title = title

            local sub = OneWoW_GUI:CreateFS(row, 10)
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
            sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            sub:SetJustifyH("LEFT")
            sub:SetWordWrap(false)
            row.sub = sub

            row:SetScript("OnClick", function(myself, button)
                if myself.kind == "pack" then
                    selectedKind = "pack"
                    selectedID = myself.packID
                    highlightPackPinId = nil
                else
                    selectedKind = "pin"
                    selectedID = myself.pinID
                end
                ns.UI.RefreshWayPinsTab()
                if button == "RightButton" then
                    if myself.kind == "pack" and myself.packID then
                        ns.WayPinsMap:ShowPackMenu(myself, myself.packID)
                    elseif myself.pinID then
                        local data = ns.WayPins:GetPin(myself.pinID)
                        if data then
                            ns.WayPinsMap:ShowPinMenu(myself, data, { hideOpenTab = true })
                        end
                    end
                end
            end)
            listRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
        if entry.kind == "pack" then
            PaintPackRow(row, entry.pack)
        else
            PaintPinRow(row, entry.pin)
        end
        row:Show()
        y = y + ROW_H + 2
    end
    scrollChild:SetHeight(math.max(y, 1))
    if showDisabledCb then
        showDisabledCb:SetChecked(ShowDisabledPacks())
    end
    if leftStatusText then
        leftStatusText:SetText(string.format(L["WAYPINS_SHOWING"], #list, total))
    end
    local emptyCopy = EmptyListCopy()
    if listEmptyMessage then
        listEmptyMessage:SetText(emptyCopy)
        listEmptyMessage:SetShown(#list == 0)
    end
    if emptyMessage then
        if #list == 0 then
            emptyMessage:SetText(emptyCopy)
        else
            emptyMessage:SetText(L["WAYPINS_SELECT"])
        end
    end
    PaintDetail()
end

function ns.UI.SelectWayPin(pinID)
    if ns.WayPinPacks:IsPackPinId(pinID) then
        local packId = ns.WayPinPacks:ParseDisplayId(pinID)
        selectedKind = "pack"
        selectedID = packId
        highlightPackPinId = pinID
    else
        selectedKind = "pin"
        selectedID = pinID
        highlightPackPinId = nil
    end
    mapFilter = "all"
    if mapDropdown then
        mapDropdown:SetSelected("all")
    end
    ns.UI.RefreshWayPinsTab()
end

---@return string|nil packId
function ns.UI.GetSelectedPackId()
    if selectedKind == "pack" then
        return selectedID
    end
    return nil
end

function ns.UI.SelectWayPinPack(packId)
    selectedKind = "pack"
    selectedID = packId
    highlightPackPinId = nil
    mapFilter = "all"
    if mapDropdown then
        mapDropdown:SetSelected("all")
    end
    ns.UI.RefreshWayPinsTab()
end

function ns.UI.CreateWayPinsTab(parent)
    local panels = ns.UI.CreateSplitPanel(parent)

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    panels.listPanel:ClearAllPoints()
    panels.listPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -6)
    panels.listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 28)
    panels.detailPanel:ClearAllPoints()
    panels.detailPanel:SetPoint("TOPLEFT", panels.listPanel, "TOPRIGHT", 10, 0)
    panels.detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 28)

    local addHereBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["WAYPINS_ADD_HERE"], height = 25 })
    addHereBtn:SetPoint("LEFT", controlPanel, "LEFT", 8, 0)
    addHereBtn:SetScript("OnClick", function()
        ns.WayPinsMap:AddHere(ns.UI.GetSelectedPackId())
    end)

    local findBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["WAYPINS_FIND_LOCATION"], height = 25 })
    findBtn:SetPoint("LEFT", addHereBtn, "RIGHT", 8, 0)
    findBtn:SetScript("OnClick", function()
        ns.UI.OpenWayPinFindDialog(ns.UI.GetSelectedPackId())
    end)

    local importBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["WAYPINS_IMPORT"], height = 25 })
    importBtn:SetPoint("LEFT", findBtn, "RIGHT", 8, 0)
    importBtn:SetScript("OnClick", function()
        ns.UI.OpenWayPinPackImport()
    end)

    local newPackBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["WAYPINS_PACK_NEW"], height = 25 })
    newPackBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    newPackBtn:SetScript("OnClick", function()
        ns.UI.OpenWayPinPackCreate()
    end)

    local mapDD = ns.UI.CreateThemedDropdown(controlPanel, ZONE, 140, 25)
    mapDD:SetPoint("LEFT", newPackBtn, "RIGHT", 8, 0)
    mapDropdown = mapDD
    mapDD:SetOptions({
        { text = L["WAYPINS_FILTER_CURRENT"], value = "current" },
        { text = ALL, value = "all" },
    })
    mapDD:SetSelected(mapFilter)
    mapDD.onSelect = function(value)
        mapFilter = value
        ns.UI.RefreshWayPinsTab()
    end

    local storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", mapDD, "RIGHT", 8, 0)
    storeDD:SetOptions({
        { text = ALL, value = "All" },
        { text = L["UI_STORAGE_ACCOUNT"], value = "account" },
        { text = CHARACTER, value = "character" },
    })
    storeDD:SetSelected(storageFilter)
    storeDD.onSelect = function(value)
        storageFilter = value
        ns.UI.RefreshWayPinsTab()
    end

    local settingsBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = SETTINGS, height = 25 })
    settingsBtn:SetPoint("RIGHT", controlPanel, "RIGHT", -8, 0)
    settingsBtn:SetScript("OnClick", function()
        ns.UI.OpenWayPinSettings()
    end)

    local searchBox = OneWoW_GUI:CreateEditBox(controlPanel, {
        placeholderText = SEARCH,
        width = 160,
    })
    searchBox:SetPoint("RIGHT", settingsBtn, "LEFT", -8, 0)
    searchBox:HookScript("OnTextChanged", function(myself)
        searchFilter = (myself.GetSearchText and myself:GetSearchText() or myself:GetText()):lower()
        ns.UI.RefreshWayPinsTab()
    end)

    panels.listTitle:SetText(L["WAYPINS_LIST_TITLE"])
    scrollChild = panels.listScrollChild

    showDisabledCb = OneWoW_GUI:CreateCheckbox(panels.listPanel, {
        label = L["WAYPINS_SHOW_DISABLED_PACKS"],
        checked = ShowDisabledPacks(),
        wrap = true,
        labelMaxWidth = 220,
        onClick = function(myself)
            ns.db.global.waypinShowDisabledPacks = myself:GetChecked() and true or false
            ns.UI.RefreshWayPinsTab()
        end,
    })
    showDisabledCb:SetPoint("TOPLEFT", panels.listPanel, "TOPLEFT", 6, -28)
    local listContainer = panels.listScrollFrame:GetParent()
    listContainer:ClearAllPoints()
    listContainer:SetPoint("TOPLEFT", panels.listPanel, "TOPLEFT", 8, -56)
    listContainer:SetPoint("BOTTOMRIGHT", panels.listPanel, "BOTTOMRIGHT", -8, 8)

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT", panels.listPanel, "BOTTOMLEFT", 0, -4)
    leftStatusBar:SetPoint("TOPRIGHT", panels.listPanel, "BOTTOMRIGHT", 0, -4)
    leftStatusBar:SetHeight(28)
    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 11)
    leftStatusText:SetPoint("LEFT", 8, 0)
    leftStatusText:SetJustifyH("LEFT")
    leftStatusText:SetWordWrap(false)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetPoint("RIGHT", leftStatusBar, "RIGHT", -8, 0)

    panels.detailTitle:SetText(L["WAYPINS_DETAIL_TITLE"])

    emptyMessage = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyMessage:SetPoint("CENTER")
    emptyMessage:SetJustifyH("CENTER")
    emptyMessage:SetWordWrap(true)
    emptyMessage:SetText(L["WAYPINS_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    listEmptyMessage = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    listEmptyMessage:SetPoint("CENTER")
    listEmptyMessage:SetJustifyH("CENTER")
    listEmptyMessage:SetWordWrap(true)
    listEmptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    listEmptyMessage:Hide()

    local header = ns.UI.CreateDetailHeader(panels.detailPanel)
    detailWidgets.header = header

    local preview = CreateFrame("Button", nil, header)
    preview:SetSize(40, 40)
    preview:SetPoint("LEFT", 10, 8)
    preview:EnableMouse(false)
    Visual.Attach(preview)
    detailWidgets.preview = preview

    local title = OneWoW_GUI:CreateFS(header, 14)
    title:SetPoint("LEFT", preview, "RIGHT", 10, 8)
    title:SetPoint("RIGHT", header, "RIGHT", -10, 8)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    detailWidgets.title = title

    local goBtn = OneWoW_GUI:CreateFitTextButton(header, { text = L["WAYPINS_GO"], height = 24 })
    goBtn:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 8)
    goBtn:SetScript("OnClick", function()
        if selectedID then
            ns.WayPins:Track(selectedID)
        end
    end)
    detailWidgets.goBtn = goBtn

    local showMapBtn = OneWoW_GUI:CreateFitTextButton(header, { text = SHOW_MAP, height = 24 })
    showMapBtn:SetPoint("RIGHT", goBtn, "LEFT", -6, 0)
    showMapBtn:SetScript("OnClick", function()
        local pin = selectedID and ns.WayPins:GetPin(selectedID)
        if pin then
            ns.WayPinsMap:ShowOnMap(pin)
        end
    end)
    showMapBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(SHOW_MAP, 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_SHOW_ON_MAP_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    showMapBtn:SetScript("OnLeave", GameTooltip_Hide)
    detailWidgets.showMapBtn = showMapBtn

    local editBtn = OneWoW_GUI:CreateFitTextButton(header, { text = EDIT, height = 24 })
    editBtn:SetPoint("RIGHT", showMapBtn, "LEFT", -6, 0)
    editBtn:SetScript("OnClick", function()
        local pin = selectedID and ns.WayPins:GetPin(selectedID)
        if pin then
            ns.UI.OpenWayPinDialog(pin)
        end
    end)
    detailWidgets.editBtn = editBtn

    local delBtn = OneWoW_GUI:CreateFitTextButton(header, { text = DELETE, height = 24 })
    delBtn:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 10, 8)
    delBtn:SetScript("OnClick", function()
        local pin = selectedID and ns.WayPins:GetPin(selectedID)
        if pin then
            ns.WayPinsMap:ConfirmDelete(pin)
        end
    end)
    detailWidgets.delBtn = delBtn

    local sendBtn = OneWoW_GUI:CreateFitTextButton(header, { text = L["WAYPINS_SEND_TO_PACK"], height = 24 })
    sendBtn:SetPoint("LEFT", delBtn, "RIGHT", 6, 0)
    sendBtn:SetScript("OnClick", function()
        if selectedKind == "pin" and selectedID then
            ns.UI.OpenWayPinSendToPack(selectedID)
        end
    end)
    detailWidgets.sendBtn = sendBtn

    local packHost = CreateFrame("Frame", nil, panels.detailPanel)
    packHost:SetAllPoints(panels.detailPanel)
    packHost:SetFrameLevel(panels.detailPanel:GetFrameLevel() + 8)
    packHost:EnableMouse(true)
    packHost:Hide()
    detailWidgets.packHost = packHost

    local infoBar = ns.UI.CreateThemedBar(nil, panels.detailPanel)
    infoBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    infoBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8)
    infoBar:SetHeight(72)
    detailWidgets.infoBar = infoBar

    local zone = OneWoW_GUI:CreateFS(infoBar, 12)
    zone:SetPoint("TOPLEFT", 12, -10)
    zone:SetPoint("RIGHT", -12, 0)
    zone:SetJustifyH("LEFT")
    zone:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    detailWidgets.zone = zone

    local coords = OneWoW_GUI:CreateFS(infoBar, 11)
    coords:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 0, -6)
    coords:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    detailWidgets.coords = coords

    local storageFS = OneWoW_GUI:CreateFS(infoBar, 11)
    storageFS:SetPoint("TOPLEFT", coords, "BOTTOMLEFT", 0, -4)
    storageFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    detailWidgets.storage = storageFS

    local desc = OneWoW_GUI:CreateFS(infoBar, 11)
    desc:SetPoint("TOPLEFT", storageFS, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    detailWidgets.desc = desc

    parent:HookScript("OnShow", function()
        ns.UI.RefreshWayPinsTab()
    end)

    ns.UI.RefreshWayPinsTab()
end

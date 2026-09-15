local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local PinSupport = ns.PinSupport
local Visual = ns.WayPinsVisual

local ipairs, wipe, tinsert, pairs = ipairs, wipe, tinsert, pairs
local IsControlKeyDown = IsControlKeyDown

-- ============================================================================
-- WayPinsCompanion
-- ============================================================================
-- List of OneWay Pins for the current map. Pins owns this window. When a zone
-- note is also pinned, the list docks beside it (or fills it when Show Zone
-- Notes is off). Otherwise it is a standalone overlay. One list per map.
-- ============================================================================

local Companion = {}
ns.WayPinsCompanion = Companion

local ROW_HEIGHT = 26
local COMPANION_WIDTH = 220

local C = OneWoW_GUI.Constants

local function ApplyButtonTheme(btn)
    if not btn then return end
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    if btn.text then
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

local frame
local hostFrame
local rowPool = {}
local activeRows = {}
local pausedForMap = false
local restoreHosts = {}
local listDismissUntil = {}
local standaloneCollapsed = false
local eventsReady = false

local function ApplyMinimizeVisual()
    local btn = frame and frame.minimizeBtn
    if not btn or not btn.text then return end
    if hostFrame then
        btn.text:SetText(hostFrame.collapsed and "+" or "-")
    else
        btn.text:SetText(standaloneCollapsed and "+" or "-")
    end
end

local function HostHidesNote(host)
    if not host or not host.noteId or not ns.Zones then
        return false
    end
    local zd = ns.Zones:GetZone(host.noteId)
    return zd and zd.hideZoneNote == true
end

local function ListDismissed(mapID)
    local untilT = mapID and listDismissUntil[mapID]
    return untilT and GetTime() < untilT
end

local function DismissListForMap(mapID)
    if mapID then
        listDismissUntil[mapID] = GetTime() + 1800
    end
end

local function HostHidesScrollBar(host)
    host = host or hostFrame
    if not host or not host.noteId or not ns.Zones then
        return false
    end
    local zd = ns.Zones:GetZone(host.noteId)
    return zd and zd.hideScrollBar == true
end

local function ApplyScrollBarVisibility(host)
    if not frame or not frame.scroll then
        return
    end
    host = host or hostFrame
    if host and hostFrame and host ~= hostFrame then
        return
    end
    OneWoW_GUI:SetScrollBarAlwaysHidden(frame.scroll, HostHidesScrollBar(host or hostFrame))
end

local function EnsureFrame()
    if frame then return frame end

    frame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_WayPinsCompanion",
        width = COMPANION_WIDTH,
        height = 200,
        backdrop = C.BACKDROP_INNER,
        bgColor = "BG_PRIMARY",
        borderColor = "BORDER_DEFAULT",
    })
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    OneWoW_GUI:RegisterFontRoot(frame, function()
        Companion:RefreshRows()
    end)

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop(C.BACKDROP_SOFT)
    frame:SetScript("OnDragStart", function()
        if hostFrame and hostFrame:IsMovable() then
            hostFrame:StartMoving()
        elseif not hostFrame then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if hostFrame then
            hostFrame:StopMovingOrSizing()
            if hostFrame.SaveGeometry then
                hostFrame:SaveGeometry()
            end
        else
            frame:StopMovingOrSizing()
            local point, _, rel, x, y = frame:GetPoint(1)
            ns.db.global.waypinCompanionPos = { point, rel, x, y }
        end
    end)
    frame:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" then
            ns.WayPinsMap:ShowAddMenu(myself)
        end
    end)
    frame:SetScript("OnEnter", function()
        if hostFrame and hostFrame.ShowHoverControls then
            hostFrame.ShowHoverControls()
        end
    end)
    frame:SetScript("OnLeave", function()
        if hostFrame and hostFrame.HideHoverControlsIfAway then
            hostFrame.HideHoverControlsIfAway()
        end
    end)

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetHeight(24)
    titleBar:SetBackdrop(C.BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if hostFrame and hostFrame:IsMovable() then
            hostFrame:StartMoving()
        elseif not hostFrame then
            frame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        if hostFrame then
            hostFrame:StopMovingOrSizing()
            if hostFrame.SaveGeometry then
                hostFrame:SaveGeometry()
            end
        else
            frame:StopMovingOrSizing()
            local point, _, rel, x, y = frame:GetPoint(1)
            ns.db.global.waypinCompanionPos = { point, rel, x, y }
        end
    end)
    titleBar:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" then
            ns.WayPinsMap:ShowAddMenu(myself)
        end
    end)
    titleBar:SetScript("OnEnter", function()
        if hostFrame and hostFrame.ShowHoverControls then
            hostFrame.ShowHoverControls()
        end
    end)
    titleBar:SetScript("OnLeave", function()
        if hostFrame and hostFrame.HideHoverControlsIfAway then
            hostFrame.HideHoverControlsIfAway()
        end
    end)
    frame.titleBar = titleBar

    local closeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "X", width = 20, height = 20 })
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function()
        if hostFrame and HostHidesNote(hostFrame) and hostFrame.closeBtn then
            hostFrame.closeBtn:Click()
            return
        end
        Companion:DismissList()
    end)
    frame.closeBtn = closeBtn

    local minimizeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "-", width = 20, height = 20 })
    minimizeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    minimizeBtn:SetScript("OnClick", function()
        if hostFrame and hostFrame.ToggleCollapsed then
            hostFrame:ToggleCollapsed()
            return
        end
        standaloneCollapsed = not standaloneCollapsed
        Companion:ApplyStandaloneLayout()
        ApplyMinimizeVisual()
    end)
    minimizeBtn:SetScript("OnEnter", function(myself)
        PinSupport.ShowTooltip(myself, "ANCHOR_BOTTOM", MINIMIZE)
    end)
    minimizeBtn:SetScript("OnLeave", PinSupport.HideTooltip)
    frame.minimizeBtn = minimizeBtn

    local addBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = ADD, height = 20, minWidth = 36 })
    addBtn:SetPoint("RIGHT", minimizeBtn, "LEFT", -2, 0)
    addBtn:SetScript("OnClick", function(myself)
        ns.WayPinsMap:ShowAddMenu(myself)
    end)
    addBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["WAYPINS_ADD_PIN"], 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_COMPANION_ADD_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", GameTooltip_Hide)
    frame.addBtn = addBtn
    ApplyButtonTheme(closeBtn)
    ApplyButtonTheme(minimizeBtn)
    ApplyButtonTheme(addBtn)
    ApplyMinimizeVisual()

    local title = OneWoW_GUI:CreateFS(titleBar, 12)
    title:SetPoint("LEFT", 5, 0)
    title:SetPoint("RIGHT", addBtn, "LEFT", -4, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(L["TAB_WAYPINS"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    frame.title = title

    local scroll, child = OneWoW_GUI:CreateScrollFrame(frame, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -32)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.scroll = scroll
    frame.child = child
    child:EnableMouse(true)
    child:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" then
            ns.WayPinsMap:ShowAddMenu(myself)
        end
    end)

    if not eventsReady then
        eventsReady = true
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PET_BATTLE_OPENING_START")
        ev:RegisterEvent("PET_BATTLE_CLOSE")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:SetScript("OnEvent", function()
            Companion:Sync()
        end)
        OneWoW.Restriction.RegisterStateCallback("OneWoW_Notes.WayPinsList", function()
            Companion:Sync()
        end)
    end

    return frame
end

function Companion:PaintOpacity(bgColor, alpha, borderColor, titleBarColor)
    if not frame then return end
    if hostFrame then
        PinSupport.ApplyOpacityBackdrop(frame, bgColor, alpha, borderColor)
    else
        frame:SetBackdrop(C.BACKDROP_INNER)
        frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], alpha or 1)
        if borderColor then
            frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
        end
    end
    if frame.titleBar and titleBarColor then
        frame.titleBar:SetBackdrop(C.BACKDROP_SIMPLE)
        frame.titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)
    end
    frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    ApplyButtonTheme(frame.closeBtn)
    ApplyButtonTheme(frame.minimizeBtn)
    ApplyButtonTheme(frame.addBtn)
end

local function ApplyHostChrome(host)
    if not frame or not host then return end
    local r, g, b, a = host:GetBackdropColor()
    local br, bg, bb = host:GetBackdropBorderColor()
    local alpha = a or 1
    PinSupport.ApplyOpacityBackdrop(frame, { r, g, b }, alpha, { br, bg, bb })
    if host.titleBar then
        local tr, tg, tb, ta = host.titleBar:GetBackdropColor()
        frame.titleBar:SetBackdrop(C.BACKDROP_SIMPLE)
        frame.titleBar:SetBackdropColor(tr, tg, tb, ta or 0.8)
    end
    frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    ApplyButtonTheme(frame.closeBtn)
    ApplyButtonTheme(frame.minimizeBtn)
    ApplyButtonTheme(frame.addBtn)
    frame:SetParent(host)
    PinSupport.ApplyAllOverlayStrata()
    frame:SetFrameLevel(host:GetFrameLevel() + 1)
end

function Companion:ApplyClusterLayout(host)
    host = host or hostFrame
    if not host then return end
    local hover = host.hoverPanel

    if host.collapsed then
        if frame then frame:Hide() end
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.titleBar then host.titleBar:Show() end
        if host.closeBtn then host.closeBtn:Show() end
        if host.minimizeBtn then host.minimizeBtn:Show() end
        if host.resizeBtn then host.resizeBtn:Hide() end
        if hover then
            hover:Hide()
            hover:ClearAllPoints()
            hover:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, 0)
            hover:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, 0)
        end
        return
    end

    if not frame or not frame:IsShown() then
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.titleBar then host.titleBar:Show() end
        if host.closeBtn then host.closeBtn:Show() end
        if host.minimizeBtn then host.minimizeBtn:Show() end
        if hover then
            hover:ClearAllPoints()
            hover:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, 0)
            hover:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, 0)
        end
        return
    end

    local hideNote = HostHidesNote(host)
    if hideNote then
        if not host._widthBeforeHideNote then
            host._widthBeforeHideNote = PinSupport.GetPinWidth(host, 300)
        end
        if host.titleBar then host.titleBar:Hide() end
        if host.contentFrame then host.contentFrame:Hide() end
        if host.todoMainFrame then host.todoMainFrame:Hide() end
        if host.closeBtn then host.closeBtn:Hide() end
        if host.minimizeBtn then host.minimizeBtn:Hide() end
        host:SetWidth(COMPANION_WIDTH)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
        frame:SetWidth(COMPANION_WIDTH)
    else
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.titleBar then host.titleBar:Show() end
        if host.closeBtn then host.closeBtn:Show() end
        if host.minimizeBtn then host.minimizeBtn:Show() end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0)
        frame:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", 4, 0)
        frame:SetWidth(COMPANION_WIDTH)
    end

    if frame.minimizeBtn then
        if hideNote then
            frame.minimizeBtn:Show()
            if frame.addBtn then
                frame.addBtn:SetPoint("RIGHT", frame.minimizeBtn, "LEFT", -2, 0)
            end
        else
            frame.minimizeBtn:Hide()
            if frame.addBtn then
                frame.addBtn:SetPoint("RIGHT", frame.closeBtn, "LEFT", -2, 0)
            end
        end
    end

    if host.resizeBtn then
        host.resizeBtn:Show()
        host.resizeBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    end

    if hover then
        hover:ClearAllPoints()
        hover:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, 0)
        if frame:IsShown() and not hideNote then
            hover:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        else
            hover:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, 0)
        end
    end

    ApplyScrollBarVisibility(host)
end

local function AcquireRow(parent)
    for _, row in ipairs(rowPool) do
        if not row._inUse then
            row:SetParent(parent)
            return row
        end
    end
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 2, 0)
    row.icon = icon

    local label = OneWoW_GUI:CreateFS(row, 12)
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    row:SetScript("OnEnter", function(myself)
        myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        local pin = myself.pinData
        if pin then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            ns.WayPinsTooltip.Fill(GameTooltip, pin, L["WAYPINS_COMPANION_TT"])
            GameTooltip:Show()
        end
        if hostFrame and hostFrame.ShowHoverControls then
            hostFrame.ShowHoverControls()
        end
    end)
    row:SetScript("OnLeave", function(myself)
        Companion:PaintRow(myself)
        GameTooltip:Hide()
        if hostFrame and hostFrame.HideHoverControlsIfAway then
            hostFrame.HideHoverControlsIfAway()
        end
    end)
    row:SetScript("OnClick", function(myself, button)
        local pin = myself.pinData
        if not pin then return end
        if button == "RightButton" then
            ns.WayPinsMap:ShowListMenu(myself, pin)
            return
        end
        if IsControlKeyDown() then
            ns.WayPinsMap:OpenPinTab(pin.id)
            return
        end
        ns.WayPins:Track(pin.id)
    end)

    tinsert(rowPool, row)
    return row
end

function Companion:PaintRow(row)
    if not row.pinData then return end
    local tracked = ns.WayPinsMap and ns.WayPinsMap:GetLivePinID() == row.pinData.id
    if tracked then
        row.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
    else
        row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    OneWoW.OverlayIcons:ApplyIconSpec(row.icon, row.pinData.icon)
end

function Companion:RefreshRows()
    if not frame or not frame:IsShown() then return end
    for _, row in ipairs(activeRows) do
        row._inUse = false
        row:Hide()
    end
    wipe(activeRows)

    local mapID = Location.GetPlayerMapID()
    local pins = ns.WayPins:GetForMap(mapID, "list")
    local y = 0
    for _, pin in ipairs(pins) do
        local row = AcquireRow(frame.child)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", frame.child, "TOPRIGHT", 0, -y)
        row.pinData = pin
        row._inUse = true
        row.label:SetText(pin.title or L["WAYPINS_UNTITLED"])
        self:PaintRow(row)
        row:Show()
        tinsert(activeRows, row)
        y = y + ROW_HEIGHT
    end
    frame.child:SetHeight(math.max(y, 1))
    ApplyScrollBarVisibility(hostFrame)
end

function Companion:DismissList()
    DismissListForMap(Location.GetPlayerMapID())
    local host = hostFrame
    self:Hide()
    if host then
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.RefreshLayout then
            host:RefreshLayout()
        elseif host.ApplyClusterLayout then
            host:ApplyClusterLayout()
        end
    end
end

function Companion:ApplyTheme()
    if frame and hostFrame then
        ApplyHostChrome(hostFrame)
        self:ApplyClusterLayout(hostFrame)
    elseif frame and frame:IsShown() then
        self:ApplyStandaloneLayout()
    end
    if frame and frame:IsShown() then
        self:RefreshRows()
    end
end

function Companion:Hide()
    hostFrame = nil
    if frame then
        frame:Hide()
    end
end

function Companion:IsShown()
    return frame and frame:IsShown()
end

function Companion:IsMouseOver()
    return frame and frame:IsMouseOver()
end

function Companion:GetWidth()
    return COMPANION_WIDTH
end

function Companion:IsPausedForMap()
    return pausedForMap
end

function Companion:PauseForMap()
    pausedForMap = true
    wipe(restoreHosts)
    if ns.zonePins then
        for id, pinFrame in pairs(ns.zonePins) do
            if pinFrame and pinFrame:IsShown() then
                restoreHosts[id] = true
                pinFrame:Hide()
            end
        end
    end
    if frame then
        frame:Hide()
    end
end

function Companion:ResumeAfterMap()
    pausedForMap = false
    for id in pairs(restoreHosts) do
        local pinFrame = ns.zonePins and ns.zonePins[id]
        if pinFrame then
            pinFrame:Show()
        end
    end
    wipe(restoreHosts)
    self:Sync()
end

--- Hide or show the pin-list scrollbar. Wheel scrolling still works when hidden.
---@param host Frame|nil
function Companion:ApplyScrollBarVisibility(host)
    ApplyScrollBarVisibility(host)
end

function Companion:ApplyOverlayStrata(strata)
    if not frame then return end
    frame:SetFrameStrata(strata or PinSupport.OverlayStrata())
end

function Companion:ApplyScale()
    if not frame then return end
    if hostFrame then
        frame:SetScale(1)
        return
    end
    PinSupport.ApplyPinScale(frame)
end

function Companion:ApplyStandaloneLayout()
    if not frame or hostFrame then return end
    frame:SetParent(UIParent)
    PinSupport.ApplyOverlayStrata(frame)
    frame:ClearAllPoints()
    local pos = ns.db.global.waypinCompanionPos
    if type(pos) == "table" and pos[1] then
        frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
    end
    frame:SetBackdrop(C.BACKDROP_INNER)
    frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    if frame.titleBar then
        frame.titleBar:SetBackdrop(C.BACKDROP_SIMPLE)
        frame.titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    end
    if frame.title then
        frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end
    ApplyButtonTheme(frame.closeBtn)
    ApplyButtonTheme(frame.minimizeBtn)
    ApplyButtonTheme(frame.addBtn)
    if standaloneCollapsed then
        if frame.scroll then frame.scroll:Hide() end
        frame:SetHeight(32)
    else
        if frame.scroll then frame.scroll:Show() end
        frame:SetHeight(240)
    end
    frame:SetWidth(COMPANION_WIDTH)
    if frame.minimizeBtn then
        frame.minimizeBtn:Show()
    end
    ApplyMinimizeVisual()
    self:ApplyScale()
end

function Companion:ShowStandalone()
    EnsureFrame()
    hostFrame = nil
    frame:Show()
    self:ApplyStandaloneLayout()
    self:RefreshRows()
end

function Companion:ShowDocked(host)
    EnsureFrame()
    hostFrame = host
    standaloneCollapsed = false
    frame:SetScale(1)
    ApplyHostChrome(host)
    frame:Show()
    self:ApplyClusterLayout(host)
    self:RefreshRows()
end

local function WantPinList()
    if not Visual.ShowZoneList() then
        return false
    end
    if Visual.HideListHere() then
        return false
    end
    local mapID = Location.GetPlayerMapID()
    if ListDismissed(mapID) then
        return false
    end
    local pins = ns.WayPins:GetForMap(mapID, "list")
    return pins[1] ~= nil
end

function Companion:Sync()
    if pausedForMap then return end
    if not Visual.Enabled() then
        local previous = hostFrame
        self:Hide()
        if previous and previous.ApplyClusterLayout then
            previous:ApplyClusterLayout()
        end
        return
    end

    local host
    local collapsedHost
    if ns.zonePins then
        for _, pinFrame in pairs(ns.zonePins) do
            if pinFrame and pinFrame:IsShown() then
                if pinFrame.collapsed then
                    collapsedHost = pinFrame
                else
                    host = pinFrame
                    break
                end
            end
        end
    end

    local wantList = WantPinList()
    if wantList and host then
        self:ShowDocked(host)
    elseif wantList and collapsedHost then
        local previous = hostFrame
        self:Hide()
        if previous and previous.ApplyClusterLayout then
            previous:ApplyClusterLayout()
        end
        return
    elseif wantList then
        local previous = hostFrame
        if previous and previous.ApplyClusterLayout then
            hostFrame = nil
            if previous._widthBeforeHideNote then
                previous:SetWidth(previous._widthBeforeHideNote)
                previous._widthBeforeHideNote = nil
            end
            previous:ApplyClusterLayout()
        end
        self:ShowStandalone()
    else
        local previous = hostFrame
        self:Hide()
        if previous and previous.ApplyClusterLayout then
            previous:ApplyClusterLayout()
        end
    end
    PinSupport.ApplyAllOverlayStrata()
end

local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local PinSupport = ns.PinSupport

local ZonePins = {}
ns.ZonePins = ZonePins

local TITLEBAR_DOUBLE_CLICK = 0.4

local function ApplyMinimizeVisual(pin)
    local btn = pin.minimizeBtn
    if not btn then return end
    if btn.text then
        btn.text:SetText(pin.collapsed and "+" or "-")
    end
end

local function CollapsedHeight(pin)
    return PinSupport.GetFrameHeight(pin.titleBar, 20) + 14
end

function ZonePins:Initialize()
    if not ns.zonePins then ns.zonePins = {} end

    if ns.Zones then
        C_Timer.After(0.5, function()
            local zoneText    = GetZoneText()    or ""
            local subZoneText = GetSubZoneText() or ""
            if subZoneText == zoneText then
                subZoneText = ""
            end
            local matching = ns.Zones:FindMatchingNotes(zoneText, subZoneText)
            for _, entry in ipairs(matching) do
                local zoneData = entry.data
                if zoneData and zoneData.pinEnabled then
                    local dismissed = zoneData.dismissedUntil and GetTime() < zoneData.dismissedUntil
                    if not dismissed then
                        self:ShowZonePin(entry.id, zoneData)
                    end
                end
            end
        end)
    end
end

function ZonePins:ShowZonePin(noteId, zoneData)
    local addon = ns
    if not noteId or not zoneData then return end
    if ns.WayPinsCompanion and ns.WayPinsCompanion:IsPausedForMap() then
        return
    end
    if not addon.zonePins then addon.zonePins = {} end

    if addon.zonePins[noteId] then
        local pin = addon.zonePins[noteId]
        if pin.contentText then
            pin.contentText:SetText(zoneData.content or "")
        end
        if pin.titleText and ns.Zones then
            pin.titleText:SetText(ns.Zones:FormatTitleFromData(zoneData))
            if pin.UpdateTitleHeight then pin:UpdateTitleHeight() end
        end
        pin:Show()
        if pin.RefreshTodos then pin:RefreshTodos() end
        if pin.RefreshLayout then pin:RefreshLayout() end
        if addon.BringWindowToFront then
            addon:BringWindowToFront(pin)
        end
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:Sync()
        end
        return pin
    end

    return self:CreateZonePin(noteId, zoneData)
end

function ZonePins:HideZonePin(zoneName)
    if not ns.zonePins or not ns.zonePins[zoneName] then return end

    local pinFrame = ns.zonePins[zoneName]
    if pinFrame then
        pinFrame:Hide()
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
end

function ZonePins:DestroyZonePin(zoneName)
    if not ns.zonePins or not ns.zonePins[zoneName] then return end

    local pinFrame = ns.zonePins[zoneName]
    ns.zonePins[zoneName] = nil
    if pinFrame then
        pinFrame._destroying = true
        pinFrame:Hide()
        pinFrame:SetParent(nil)
    end
end

function ZonePins:HideAllPins()
    if not ns.zonePins then return end
    for _, pinFrame in pairs(ns.zonePins) do
        if pinFrame then
            pinFrame._destroying = true
            pinFrame:Hide()
        end
    end
    ns.zonePins = {}
end

function ZonePins:SavePinPosition(zoneName, point, relativePoint, x, y, width, height, meta)
    meta = meta or {}
    ns.db.global.zonePinPositions[zoneName] = {
        point = point, relativePoint = relativePoint,
        x = x, y = y, width = width, height = height,
        collapsed = meta.collapsed and true or false,
        expandedWidth = meta.expandedWidth or width,
        expandedHeight = meta.expandedHeight or height,
    }
end

function ZonePins:GetPinPosition(zoneName)
    return ns.db.global.zonePinPositions[zoneName]
end

function ZonePins:CreateZonePin(zoneName, zoneData)
    if not zoneName or not zoneData then return end

    local pinColor    = zoneData.pinColor  or "hunter"
    local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
    local bgColor     = colorConfig.background
    local borderColor = colorConfig.border

    -- Sanitize zone name for frame global name
    local safeName = zoneName:gsub("[^%w]", "_")

    local function SaveZonePinGeometry(myself)
        if PinSupport.IsLayoutBlocked() then
            PinSupport.DeferGeometrySave(myself, function()
                SaveZonePinGeometry(myself)
            end)
            return
        end
        PinSupport.CachePinSize(myself)
        local point, _, relativePoint, x, y = myself:GetPoint()
        local w = PinSupport.GetPinWidth(myself, 300)
        if myself._widthBeforeHideNote then
            w = myself._widthBeforeHideNote
        end
        local h = PinSupport.GetPinHeight(myself, 400)
        local collapsed = myself.collapsed and true or false
        local ew, eh = w, h
        if collapsed then
            ew = myself._savedWidth or w
            eh = myself._savedHeight or h
        end
        ZonePins:SavePinPosition(zoneName, point, relativePoint, x, y, w, h, {
            collapsed = collapsed,
            expandedWidth = ew,
            expandedHeight = eh,
        })
    end

    local pin = CreateFrame("Frame", "OneWoW_ZonePin_" .. safeName, UIParent, "BackdropTemplate")
    pin:SetSize(300, 400)
    pin._cachedWidth = 300
    pin._cachedHeight = 400
    pin:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -50)
    pin:SetMovable(true)
    pin:SetResizable(true)
    PinSupport.ApplyPinScale(pin)
    PinSupport.SetPinResizeBounds(pin, 200, 150)
    pin:EnableMouse(true)
    pin:SetClampedToScreen(true)
    pin:RegisterForDrag("LeftButton")
    pin:SetScript("OnDragStart", pin.StartMoving)
    pin:SetScript("OnDragStop", function(myself)
        myself:StopMovingOrSizing()
        SaveZonePinGeometry(myself)
    end)
    pin.SaveGeometry = function(myself)
        SaveZonePinGeometry(myself)
    end

    pin:SetScript("OnMouseDown", function(myself)
        if myself.windowInfo and ns.BringWindowToFront then
            ns:BringWindowToFront(myself)
        end
    end)

    local pinAlpha = zoneData.opacity or 0.9
    PinSupport.ApplyOpacityBackdrop(pin, bgColor, pinAlpha, borderColor)
    pin:SetAlpha(1.0)
    pin.zoneName = zoneName
    pin.noteId = zoneName
    pin.collapsed = false
    pin._titleBarLastClick = 0
    pin._savedWidth = 300
    pin._savedHeight = 400

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  pin, "TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", pin, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(20)
    titleBar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                           insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    local titleBarColor = colorConfig.titleBar
    titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)

    -- Determine title text color from fontColor
    local noteFontColor = zoneData.fontColor or "match"
    local titleColor
    if noteFontColor == "match" then
        titleColor = borderColor
    elseif noteFontColor == "white" then
        titleColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        titleColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        titleColor = fontConfig and fontConfig.border or borderColor
    end

    local titleText = OneWoW_GUI:CreateFS(titleBar, 10)
    titleText:SetPoint("LEFT",  titleBar, "LEFT",  5, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -48, 0)
    titleText:SetText(ns.Zones and ns.Zones:FormatTitleFromData(zoneData) or zoneName)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
    pin.titleText = titleText
    pin.titleBar  = titleBar

    -- Grow the title bar to fit a wrapped (multi-line) zone name instead of clipping.
    pin.UpdateTitleHeight = function(myself)
        if not myself.titleText or not myself.titleBar then return end
        local th = myself.titleText:GetStringHeight() or 0
        myself.titleBar:SetHeight(math.max(20, math.ceil(th) + 8))
    end

    -- Close button — sets dismissedUntil 30 min so it won't re-open on re-enter
    local closeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "X", width = 20, height = 20 })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function()
        -- Dismiss for 30 minutes so zone re-entry doesn't immediately re-open it
        if ns.Zones then
            local zd = ns.Zones:GetZone(zoneName)
            if zd then
                zd.dismissedUntil = GetTime() + (30 * 60)
                ns.Zones:SaveZone(zoneName, zd)
            end
        end
        ZonePins:HideZonePin(zoneName)
    end)
    pin.closeBtn = closeBtn

    local minimizeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "-", width = 20, height = 20 })
    minimizeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    minimizeBtn:SetScript("OnClick", function()
        pin:ToggleCollapsed()
    end)
    minimizeBtn:SetScript("OnEnter", function(myself)
        PinSupport.ShowTooltip(myself, "ANCHOR_BOTTOM", MINIMIZE)
        if pin.ShowHoverControls then
            pin.ShowHoverControls()
        end
    end)
    minimizeBtn:SetScript("OnLeave", function()
        PinSupport.HideTooltip()
        if pin.HideHoverControlsIfAway then
            pin.HideHoverControlsIfAway()
        end
    end)
    pin.minimizeBtn = minimizeBtn

    -- Content area (scrollable)
    local contentFrame = CreateFrame("Frame", nil, pin)
    contentFrame:SetPoint("TOPLEFT",  titleBar, "BOTTOMLEFT",  5, -5)
    contentFrame:SetPoint("TOPRIGHT", pin,      "TOPRIGHT",    -5, -5)
    contentFrame:SetHeight(120)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
    scrollFrame:SetPoint("TOPLEFT",     0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(myself, delta)
        local cur = myself:GetVerticalScroll()
        local max = myself:GetVerticalScrollRange()
        myself:SetVerticalScroll(delta > 0 and math.max(0, cur - 30) or math.min(max, cur + 30))
    end)

    local contentText = CreateFrame("EditBox", nil, scrollFrame)
    contentText:SetMultiLine(true)
    contentText:SetAutoFocus(false)
    contentText:EnableMouse(false)
    contentText:EnableKeyboard(false)
    contentText:SetHyperlinksEnabled(true)
    contentText:SetWidth(PinSupport.GetScrollWidth(scrollFrame, 280, "_cachedScrollWidth"))
    contentText:SetHeight(1)
    scrollFrame:SetScrollChild(contentText)

    scrollFrame:HookScript("OnSizeChanged", function(myself, width)
        if PinSupport.IsLayoutBlocked() then
            width = myself._cachedScrollWidth or 280
        elseif width then
            myself._cachedScrollWidth = width
        end
        contentText:SetWidth(math.max(1, width or 280))
    end)

    contentText:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
        if button == "LeftButton" then
            SetItemRef(linkData, link, button)
        end
    end)

    local fontSize = zoneData.fontSize or 12
    local fontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)
    contentText:SetFont(fontPath, fontSize, zoneData.fontOutline or "")

    local contentTextColor
    if noteFontColor == "match" then
        contentTextColor = borderColor
    elseif noteFontColor == "white" then
        contentTextColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        contentTextColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        contentTextColor = fontConfig and fontConfig.border or borderColor
    end
    contentText:SetTextColor(contentTextColor[1], contentTextColor[2], contentTextColor[3], 1)
    contentText:SetText(zoneData.content or "")

    pin.contentText  = contentText
    pin.contentFrame = contentFrame
    pin.scrollFrame  = scrollFrame

    -- Todo section
    local todoMainFrame = CreateFrame("Frame", nil, pin)
    todoMainFrame:SetPoint("TOPLEFT",     titleBar, "BOTTOMLEFT",  5, -5)
    todoMainFrame:SetPoint("BOTTOMRIGHT", pin,      "BOTTOMRIGHT", -5, 15)
    pin.todoMainFrame = todoMainFrame

    local todoContainer = CreateFrame("Frame", nil, todoMainFrame)
    todoContainer:SetPoint("TOPLEFT",  todoMainFrame, "TOPLEFT",  0, 0)
    todoContainer:SetPoint("TOPRIGHT", todoMainFrame, "TOPRIGHT", 0, 0)
    pin.todoContainer = todoContainer
    pin.todoItems = {}

    pin.RefreshLayout = function(myself, skipTodoRefresh)
        if not myself.contentFrame or not myself.todoMainFrame then return end

        local zd = ns.Zones and ns.Zones:GetZone(zoneName)
        if not zd then return end

        myself:UpdateTitleHeight()

        if myself.collapsed then
            local ch = CollapsedHeight(myself)
            myself:SetHeight(ch)
            myself._cachedHeight = ch
            PinSupport.SetPinResizeBounds(myself, 200, ch)
            if myself.titleBar then myself.titleBar:Show() end
            if myself.closeBtn then myself.closeBtn:Show() end
            if myself.minimizeBtn then myself.minimizeBtn:Show() end
            myself.contentFrame:Hide()
            myself.todoMainFrame:Hide()
            if myself.resizeBtn then myself.resizeBtn:Hide() end
            if myself.hoverPanel then myself.hoverPanel:Hide() end
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:ApplyClusterLayout(myself)
            end
            return
        end

        if zd.hideZoneNote == true then
            myself.contentFrame:Hide()
            myself.todoMainFrame:Hide()
            if PinSupport.IsLayoutBlocked() then
                PinSupport.RegisterDeferredPin(myself)
            else
                PinSupport.CachePinSize(myself)
            end
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:ApplyClusterLayout(myself)
            end
            return
        end

        local todoCount = #(zd.todos or {})
        local taskHeight = 0
        if todoCount > 0 then
            taskHeight = PinSupport.GetFrameHeight(myself.todoContainer, myself._cachedTodoHeight or 40)
            if taskHeight <= 10 then
                taskHeight = math.max(40, todoCount * 25 + 20)
            end
            myself._cachedTodoHeight = taskHeight
        end

        local hasContent  = zd.content and zd.content ~= ""
        local titleBarHeight = PinSupport.GetFrameHeight(myself.titleBar, 20) + 10
        local minWindow   = titleBarHeight + (hasContent and 60 or 10) + taskHeight + 35
        PinSupport.SetPinResizeBounds(myself, 200, minWindow)

        myself.contentFrame:ClearAllPoints()
        myself.todoMainFrame:ClearAllPoints()
        myself.todoContainer:ClearAllPoints()

        local tasksOnTop = zd.tasksOnTop == true

        if todoCount == 0 then
            myself.todoMainFrame:Hide()
            if hasContent then
                myself.contentFrame:SetPoint("TOPLEFT", myself.titleBar, "BOTTOMLEFT", 5, -5)
                myself.contentFrame:SetPoint("BOTTOMRIGHT", myself, "BOTTOMRIGHT", -5, 15)
                myself.contentFrame:Show()
            else
                myself.contentFrame:Hide()
            end
        elseif hasContent then
            myself.todoMainFrame:Show()
            if tasksOnTop then
                myself.todoMainFrame:SetPoint("TOPLEFT",  myself.titleBar, "BOTTOMLEFT",  5, -5)
                myself.todoMainFrame:SetPoint("TOPRIGHT", myself,          "TOPRIGHT",    -5, -5)
                myself.todoMainFrame:SetHeight(taskHeight)
                myself.todoContainer:SetPoint("TOPLEFT",  myself.todoMainFrame, "TOPLEFT",  0, 0)
                myself.todoContainer:SetPoint("TOPRIGHT", myself.todoMainFrame, "TOPRIGHT", 0, 0)
                myself.contentFrame:SetPoint("TOPLEFT",     myself.todoMainFrame, "BOTTOMLEFT", 0, -5)
                myself.contentFrame:SetPoint("BOTTOMRIGHT", myself,               "BOTTOMRIGHT", -5, 15)
            else
                myself.todoMainFrame:SetPoint("BOTTOMLEFT",  myself, "BOTTOMLEFT",  5, 15)
                myself.todoMainFrame:SetPoint("BOTTOMRIGHT", myself, "BOTTOMRIGHT", -5, 15)
                myself.todoMainFrame:SetHeight(taskHeight)
                myself.todoContainer:SetPoint("TOPLEFT",  myself.todoMainFrame, "TOPLEFT",  0, 0)
                myself.todoContainer:SetPoint("TOPRIGHT", myself.todoMainFrame, "TOPRIGHT", 0, 0)
                myself.contentFrame:SetPoint("TOPLEFT",  myself.titleBar, "BOTTOMLEFT",  5, -5)
                myself.contentFrame:SetPoint("TOPRIGHT", myself,          "TOPRIGHT",    -5, -5)
                myself.contentFrame:SetPoint("BOTTOMRIGHT", myself.todoMainFrame, "TOPRIGHT", 0, -5)
            end
            myself.contentFrame:Show()
        else
            myself.todoMainFrame:Show()
            myself.todoMainFrame:SetPoint("TOPLEFT",     myself.titleBar, "BOTTOMLEFT",  5, -5)
            myself.todoMainFrame:SetPoint("BOTTOMRIGHT", myself,          "BOTTOMRIGHT", -5, 15)
            myself.todoMainFrame:SetHeight(taskHeight)
            myself.todoContainer:SetPoint("TOPLEFT",  myself.todoMainFrame, "TOPLEFT",  0, 0)
            myself.todoContainer:SetPoint("TOPRIGHT", myself.todoMainFrame, "TOPRIGHT", 0, 0)
            myself.contentFrame:Hide()
        end

        if myself.todoContainer then
            myself.todoContainer:SetWidth(PinSupport.GetPinWidth(myself, 300))
        end

        if not skipTodoRefresh and myself.RefreshTodos then
            myself:RefreshTodos()
        end

        if PinSupport.IsLayoutBlocked() then
            PinSupport.RegisterDeferredPin(myself)
        else
            PinSupport.CachePinSize(myself)
        end

        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:ApplyClusterLayout(myself)
        end
    end

    pin.RefreshTodos = function(myself)
        if not myself.todoContainer then return end

        for i = #myself.todoItems, 1, -1 do
            local item = table.remove(myself.todoItems, i)
            if item then
                item:Hide()
                item._checkbox:SetScript("OnClick", nil)
                item._checkbox:SetChecked(false)
                table.insert(ns.NotesPins._zoneTodoPool or {}, item)
            end
        end

        local zd = ns.Zones and ns.Zones:GetZone(zoneName)
        if not zd or not zd.todos or #zd.todos == 0 then
            myself.todoContainer:SetHeight(0)
            myself:RefreshLayout(true)
            return
        end

        if not ns.NotesPins._zoneTodoPool then ns.NotesPins._zoneTodoPool = {} end

        local yOffset = 0
        for _, todo in ipairs(zd.todos) do
            local todoFrame = table.remove(ns.NotesPins._zoneTodoPool)
            if todoFrame then
                todoFrame:SetParent(myself.todoContainer)
                todoFrame:ClearAllPoints()
                todoFrame:Show()
            else
                todoFrame = CreateFrame("Frame", nil, myself.todoContainer)
                todoFrame:SetHeight(22)
                todoFrame._checkbox = CreateFrame("CheckButton", nil, todoFrame, "UICheckButtonTemplate")
                todoFrame._checkbox:SetSize(16, 16)
                todoFrame._checkbox:SetPoint("LEFT", todoFrame, "LEFT", 2, 0)
                todoFrame._text = todoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                todoFrame._text:SetPoint("LEFT", todoFrame._checkbox, "RIGHT", 5, 0)
                todoFrame._text:SetJustifyH("LEFT")
            end

            todoFrame:SetPoint("TOPLEFT", myself.todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetPoint("RIGHT",   myself.todoContainer, "RIGHT",   0, 0)

            todoFrame._checkbox:SetChecked(todo.completed)
            todoFrame._checkbox:SetScript("OnClick", function(cb)
                todo.completed = cb:GetChecked()
                if zd then zd.modified = GetServerTime() end
                myself:RefreshTodos()
            end)

            todoFrame._text:ClearAllPoints()
            todoFrame._text:SetPoint("LEFT",  todoFrame._checkbox, "RIGHT",  5, 0)
            todoFrame._text:SetPoint("RIGHT", todoFrame,           "RIGHT", -5, 0)
            todoFrame._text:SetText(todo.text or "")

            local fs = zd.fontSize or 12
            local todoFontPath = ns.Config:ResolveFontPath(zd.fontFamily)
            todoFrame._text:SetFont(todoFontPath, fs, zd.fontOutline or "")

            if todo.completed then
                todoFrame._text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            else
                todoFrame._text:SetTextColor(contentTextColor[1], contentTextColor[2], contentTextColor[3], 1)
            end

            table.insert(myself.todoItems, todoFrame)
            yOffset = yOffset - 25
        end

        myself.todoContainer:SetHeight(math.abs(yOffset) + 10)
        myself._cachedTodoHeight = math.abs(yOffset) + 10
    end

    -- Resize handle
    local resizeBtn = CreateFrame("Button", nil, pin)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function() pin:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function()
        pin:StopMovingOrSizing()
        SaveZonePinGeometry(pin)
        if pin.RefreshLayout then pin:RefreshLayout(true) end
    end)
    pin.resizeBtn = resizeBtn

    -- Hover controls (alpha slider + lock buttons)
    local hoverPanel = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    hoverPanel:SetPoint("TOPLEFT",  pin, "BOTTOMLEFT",  0, 0)
    hoverPanel:SetPoint("TOPRIGHT", pin, "BOTTOMRIGHT", 0, 0)
    hoverPanel:SetHeight(50)
    local listItemColor = colorConfig.listItem
    PinSupport.ApplyOpacityBackdrop(hoverPanel, listItemColor, pinAlpha, borderColor)
    hoverPanel:SetFrameLevel(pin:GetFrameLevel() + 10)
    hoverPanel:Hide()
    pin.hoverPanel = hoverPanel

    local function ApplyAllOpacity(val)
        PinSupport.ApplyOpacityBackdrop(pin, bgColor, val, borderColor)
        PinSupport.ApplyOpacityBackdrop(hoverPanel, listItemColor, val, borderColor)
        if pin.titleBar then
            pin.titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)
        end
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:PaintOpacity(bgColor, val, borderColor, titleBarColor)
        end
    end

    local alphaSlider = OneWoW_GUI:CreateSlider(hoverPanel, {
        minVal = 0.1,
        maxVal = 1.0,
        step = 0.05,
        currentVal = pinAlpha,
        onChange = function(val)
            zoneData.opacity = val
            ApplyAllOpacity(val)
        end,
    })
    pin.alphaSlider = alphaSlider

    local lockMoveCB = OneWoW_GUI:CreateCheckbox(hoverPanel, {
        label = L["LOCK_MOVE"],
        checked = zoneData.lockMove,
        onClick = function(myself)
            zoneData.lockMove = myself:GetChecked()
            if zoneData.lockMove then
                pin:SetMovable(false)
                pin:RegisterForDrag()
            else
                pin:SetMovable(true)
                pin:RegisterForDrag("LeftButton")
            end
            if pin.SyncTitleBarDrag then pin:SyncTitleBarDrag() end
        end,
    })
    if zoneData.lockMove then
        pin:SetMovable(false)
        pin:RegisterForDrag()
    end
    pin.lockMoveCB = lockMoveCB

    local showNoteCB = OneWoW_GUI:CreateCheckbox(hoverPanel, {
        label = L["WAYPINS_SHOW_NOTE"],
        checked = zoneData.hideZoneNote ~= true,
        onClick = function(myself)
            zoneData.hideZoneNote = not myself:GetChecked()
            ns.Zones:SaveZone(zoneName, zoneData)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
            if pin.RefreshLayout then
                pin:RefreshLayout()
            end
        end,
    })
    pin.showNoteCB = showNoteCB

    local hideScrollCB = OneWoW_GUI:CreateCheckbox(hoverPanel, {
        label = L["WAYPINS_HIDE_SCROLLBAR"],
        checked = zoneData.hideScrollBar == true,
        onClick = function(myself)
            zoneData.hideScrollBar = myself:GetChecked() and true or false
            ns.Zones:SaveZone(zoneName, zoneData)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:ApplyScrollBarVisibility(pin)
            end
        end,
    })
    pin.hideScrollCB = hideScrollCB

    pin.ApplyClusterLayout = function(myself)
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:ApplyClusterLayout(myself)
        end
    end

    local function HideHoverControls()
        hoverPanel:Hide()
    end
    local function OverCluster()
        if pin:IsMouseOver() or hoverPanel:IsMouseOver() then
            return true
        end
        if ns.WayPinsCompanion and ns.WayPinsCompanion:IsMouseOver() then
            return true
        end
        return false
    end
    local function ShowHoverControls()
        if pin.collapsed then return end
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:ApplyClusterLayout(pin)
        end
        local items = {
            { control = alphaSlider, fill = true },
            { control = lockMoveCB },
        }
        tinsert(items, { control = showNoteCB })
        tinsert(items, { control = hideScrollCB })
        PinSupport.LayoutHoverPanel(hoverPanel, items)
        hoverPanel:Show()
    end
    local function HideHoverControlsIfAway()
        C_Timer.After(0.05, function()
            if not OverCluster() then
                HideHoverControls()
            end
        end)
    end
    pin.ShowHoverControls = ShowHoverControls
    pin.HideHoverControlsIfAway = HideHoverControlsIfAway

    pin.SyncTitleBarDrag = function()
        if zoneData.lockMove then
            titleBar:RegisterForDrag()
        else
            titleBar:RegisterForDrag("LeftButton")
        end
    end

    pin.ToggleCollapsed = function(myself)
        if myself.collapsed then
            myself.collapsed = false
            local ew = myself._savedWidth or 300
            local eh = myself._savedHeight or 400
            myself:SetSize(ew, eh)
            myself._cachedWidth = ew
            myself._cachedHeight = eh
            myself:SetResizable(true)
            if myself.resizeBtn then
                myself.resizeBtn:Show()
            end
            ApplyMinimizeVisual(myself)
            if myself.RefreshLayout then
                myself:RefreshLayout()
            end
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
        else
            local ew = myself._widthBeforeHideNote or PinSupport.GetPinWidth(myself, 300)
            local eh = PinSupport.GetPinHeight(myself, 400)
            myself._savedWidth = ew
            myself._savedHeight = eh
            if myself._widthBeforeHideNote then
                myself:SetWidth(myself._widthBeforeHideNote)
                myself._widthBeforeHideNote = nil
            end
            myself.collapsed = true
            if myself.hoverPanel then myself.hoverPanel:Hide() end
            myself.contentFrame:Hide()
            myself.todoMainFrame:Hide()
            if myself.resizeBtn then myself.resizeBtn:Hide() end
            myself:SetResizable(false)
            if myself.titleBar then myself.titleBar:Show() end
            if myself.closeBtn then myself.closeBtn:Show() end
            if myself.minimizeBtn then myself.minimizeBtn:Show() end
            ApplyMinimizeVisual(myself)
            local ch = CollapsedHeight(myself)
            myself:SetHeight(ch)
            myself._cachedHeight = ch
            myself._cachedWidth = myself._savedWidth
            PinSupport.SetPinResizeBounds(myself, 200, ch)
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
        end
        SaveZonePinGeometry(myself)
    end

    titleBar:EnableMouse(true)
    titleBar:SetScript("OnEnter", function()
        PinSupport.ShowTooltip(titleBar, "ANCHOR_BOTTOM", L["DOUBLE_CLICK_OR_SHIFT_CLICK_TO_COLLAPSE_OR_EXPAND"])
        ShowHoverControls()
    end)
    titleBar:SetScript("OnLeave", function()
        PinSupport.HideTooltip()
        HideHoverControlsIfAway()
    end)
    titleBar:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        if IsShiftKeyDown() then
            pin:ToggleCollapsed()
            pin._titleBarLastClick = 0
            return
        end
        local now = GetTime()
        if pin._titleBarLastClick and (now - pin._titleBarLastClick) < TITLEBAR_DOUBLE_CLICK then
            pin:ToggleCollapsed()
            pin._titleBarLastClick = 0
        else
            pin._titleBarLastClick = now
        end
    end)
    titleBar:SetScript("OnDragStart", function()
        if not zoneData.lockMove then
            pin:StartMoving()
            pin._titleBarLastClick = 0
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        pin:StopMovingOrSizing()
        SaveZonePinGeometry(pin)
    end)
    pin:SyncTitleBarDrag()

    hoverPanel:EnableMouse(true)
    hoverPanel:SetScript("OnEnter", ShowHoverControls)
    hoverPanel:SetScript("OnLeave", HideHoverControlsIfAway)

    HideHoverControls()
    pin:SetScript("OnEnter", ShowHoverControls)
    pin:SetScript("OnLeave", HideHoverControlsIfAway)

    -- Restore saved position
    local savedPos = self:GetPinPosition(zoneName)
    if savedPos then
        pin:ClearAllPoints()
        pin:SetPoint(savedPos.point or "CENTER", UIParent, savedPos.relativePoint or "CENTER",
                     savedPos.x or 0, savedPos.y or 0)
        if savedPos.collapsed and savedPos.expandedWidth and savedPos.expandedHeight then
            pin.collapsed = true
            pin._savedWidth = savedPos.expandedWidth
            pin._savedHeight = savedPos.expandedHeight
            local collapsedH = savedPos.height or CollapsedHeight(pin)
            pin:SetSize(savedPos.expandedWidth, collapsedH)
            pin._cachedWidth = savedPos.expandedWidth
            pin._cachedHeight = collapsedH
            pin:SetResizable(false)
            ApplyMinimizeVisual(pin)
        elseif savedPos.width and savedPos.height then
            pin:SetSize(savedPos.width, savedPos.height)
            pin._savedWidth = savedPos.width
            pin._savedHeight = savedPos.height
            pin._cachedWidth = savedPos.width
            pin._cachedHeight = savedPos.height
        end
    end

    ns.zonePins[zoneName] = pin

    if ns.RegisterWindow then
        pin.windowInfo = ns:RegisterWindow(pin, "zone_pinned", function()
            pin:Hide()
        end)
    end

    pin:SetScript("OnHide", function(myself)
        if myself._destroying then
            if ns.zonePins and ns.zonePins[zoneName] == myself then
                ns.zonePins[zoneName] = nil
            end
        end
        if myself.windowInfo and ns.UnregisterWindow then
            ns:UnregisterWindow(myself)
            myself.windowInfo = nil
        end
    end)

    pin:SetScript("OnShow", function(myself)
        if not myself.windowInfo and ns.RegisterWindow then
            myself.windowInfo = ns:RegisterWindow(myself, "zone_pinned", function()
                myself:Hide()
            end)
        end
    end)

    pin:RefreshLayout()
    pin:RefreshTodos()
    pin:Show()

    if ns.BringWindowToFront then
        ns:BringWindowToFront(pin)
    end
    PinSupport.ApplyOverlayStrata(pin)

    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end

    return pin
end

function ZonePins:RefreshZonePinColors(zoneName)
    if not ns.zonePins or not ns.zonePins[zoneName] then return end

    local pinFrame = ns.zonePins[zoneName]
    if not pinFrame then return end

    local zoneData = ns.Zones and ns.Zones:GetZone(zoneName)
    if not zoneData then return end

    if pinFrame.titleText and ns.Zones then
        pinFrame.titleText:SetText(ns.Zones:FormatTitleFromData(zoneData))
        if pinFrame.UpdateTitleHeight then pinFrame:UpdateTitleHeight() end
    end
    if not pinFrame:IsShown() then return end

    local pinColorKey = zoneData.pinColor or "hunter"
    local colorConfig = ns.Config:GetResolvedColorConfig(pinColorKey)
    local bgColor     = colorConfig.background
    local borderColor = colorConfig.border
    local pinAlpha    = zoneData.opacity or 0.9
    local listItemColor = colorConfig.listItem

    PinSupport.ApplyOpacityBackdrop(pinFrame, bgColor, pinAlpha, borderColor)

    if pinFrame.titleBar then
        local titleColor = colorConfig.titleBar
        pinFrame.titleBar:SetBackdropColor(titleColor[1], titleColor[2], titleColor[3], 0.8)
    end
    if pinFrame.hoverPanel then
        PinSupport.ApplyOpacityBackdrop(pinFrame.hoverPanel, listItemColor, pinAlpha, borderColor)
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:PaintOpacity(bgColor, pinAlpha, borderColor, colorConfig.titleBar)
    end

    local noteFontColor = zoneData.fontColor or "match"
    local fontSize      = zoneData.fontSize  or 12
    local textColor

    if noteFontColor == "match" then
        textColor = borderColor
    elseif noteFontColor == "white" then
        textColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        textColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        textColor = fontConfig and fontConfig.border or borderColor
    end

    if pinFrame.titleText then
        pinFrame.titleText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    end
    if pinFrame.contentText then
        pinFrame.contentText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
        local fontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)
        pinFrame.contentText:SetFont(fontPath, fontSize, zoneData.fontOutline or "")
    end
    if pinFrame.RefreshTodos then
        pinFrame:RefreshTodos()
    end
end

function ZonePins:RefreshAllPinFonts()
    if not ns.zonePins then return end
    for zoneName, pinFrame in pairs(ns.zonePins) do
        if pinFrame and pinFrame:IsShown() then
            self:RefreshZonePinColors(zoneName)
        end
    end
end

function ZonePins:RefreshSyncPins()
    if not ns.zonePins then return end

    for zoneName, pinFrame in pairs(ns.zonePins) do
        if pinFrame and pinFrame:IsShown() then
            local zoneData = ns.Zones and ns.Zones:GetZone(zoneName)
            if zoneData and zoneData.pinColor == "sync" then
                local colorConfig = ns.Config:GetResolvedColorConfig("sync")
                local bgColor = colorConfig.background
                local borderColor = colorConfig.border
                local titleBarColor = colorConfig.titleBar
                local opacity = zoneData.opacity or 0.9
                PinSupport.ApplyOpacityBackdrop(pinFrame, bgColor, opacity, borderColor)

                if pinFrame.titleBar then
                    pinFrame.titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)
                end
                if pinFrame.hoverPanel then
                    PinSupport.ApplyOpacityBackdrop(pinFrame.hoverPanel, colorConfig.listItem, opacity, borderColor)
                end
                if ns.WayPinsCompanion then
                    ns.WayPinsCompanion:PaintOpacity(bgColor, opacity, borderColor, titleBarColor)
                end

                if pinFrame.titleText then
                    local fontColor = zoneData.fontColor or "match"
                    local titleColor = ns.Config:GetResolvedFontColor(fontColor, "sync")
                    pinFrame.titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
                end
            end
        end
    end
end

function ZonePins:ApplyWayPinsEnabled()
    if not ns.zonePins then return end
    for _, pin in pairs(ns.zonePins) do
        if pin.showNoteCB then
            pin.showNoteCB:Show()
        end
        if pin.RefreshLayout then
            pin:RefreshLayout()
        end
    end
end

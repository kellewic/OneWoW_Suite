local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location

ns.TrackerPinned = {}
local TP = ns.TrackerPinned

local ipairs, format, tinsert, tremove, pairs, math_max, math_min, math_abs = ipairs, format, tinsert, tremove, pairs, math.max, math.min, math.abs
local GetTime, IsShiftKeyDown = GetTime, IsShiftKeyDown
local tonumber = tonumber

local BACKDROP_SOFT = OneWoW_GUI.Constants.BACKDROP_SOFT or OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

-- Tracker steps store coordinates as 0-100.

local DOUBLE_CLICK_INTERVAL = 0.4
local HOVER_HIDE_DELAY      = 0.05

local SCALE_MIN     = 50
local SCALE_MAX     = 200
local SCALE_STEP    = 5
local SCALE_DEFAULT = 100
local PIN_MIN_W, PIN_MIN_H = 200, 100
local PIN_MAX_W, PIN_MAX_H = 500, 800

TP.SCALE_MIN  = SCALE_MIN
TP.SCALE_MAX  = SCALE_MAX
TP.SCALE_STEP = SCALE_STEP

--- Clamp a pinned-window scale percent to the supported range.
---@param percent number|nil
---@return number
function TP:ClampScalePercent(percent)
    return math_min(SCALE_MAX, math_max(SCALE_MIN, tonumber(percent) or SCALE_DEFAULT))
end

local function ScreenSizeInFrameUnits(frame)
    local scale = frame:GetScale()
    if scale <= 0 then scale = 1 end
    return GetScreenWidth() / scale, GetScreenHeight() / scale
end

local function ApplyPinnedScale(frame)
    frame:SetScale(TP:ClampScalePercent(ns.db.global.pinnedScale) / 100)
    local sw, sh = ScreenSizeInFrameUnits(frame)
    frame:SetResizeBounds(PIN_MIN_W, PIN_MIN_H, math_min(PIN_MAX_W, sw), math_min(PIN_MAX_H, sh))
end

local sectionPool = {}
local stepPool = {}
local objPool = {}

local function AcquireSection(parent)
    local f = tremove(sectionPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        f._count:SetText("")
        f._count:Hide()
        f:SetScript("OnClick", nil)
        return f
    end
    f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetHeight(20)
    f._accent = f:CreateTexture(nil, "ARTWORK")
    f._accent:SetSize(3, 20)
    f._accent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f._collapseIcon = f:CreateTexture(nil, "ARTWORK")
    f._collapseIcon:SetSize(10, 10)
    f._collapseIcon:SetPoint("LEFT", f._accent, "RIGHT", 4, 0)
    f._label = OneWoW_GUI:CreateFS(f, 10)
    f._label:SetPoint("LEFT", f._collapseIcon, "RIGHT", 3, 0)
    f._count = OneWoW_GUI:CreateFS(f, 10)
    f._count:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    return f
end

local function ReleaseSection(f)
    f:Hide()
    f:SetScript("OnClick", nil)
    tinsert(sectionPool, f)
end

local function AcquireStep(parent)
    local f = tremove(stepPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        f:SetScript("OnClick", nil)
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
        f:RegisterForClicks("LeftButtonUp")
        return f
    end
    f = CreateFrame("Button", nil, parent)
    f:SetHeight(18)
    f._dot = f:CreateTexture(nil, "ARTWORK")
    f._dot:SetSize(6, 6)
    f._dot:SetPoint("LEFT", f, "LEFT", 4, 0)
    f._label = OneWoW_GUI:CreateFS(f, 10)
    f._label:SetPoint("LEFT", f._dot, "RIGHT", 6, 0)
    f._label:SetJustifyH("LEFT")
    f._label:SetWordWrap(false)
    f._prog = OneWoW_GUI:CreateFS(f, 10)
    f._prog:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    return f
end

local function ReleaseStep(f)
    f:Hide()
    f:SetScript("OnClick", nil)
    f:SetScript("OnEnter", nil)
    f:SetScript("OnLeave", nil)
    tinsert(stepPool, f)
end

local function AcquireObj(parent)
    local f = tremove(objPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        f:SetScript("OnClick", nil)
        return f
    end
    f = CreateFrame("Button", nil, parent)
    f:SetHeight(16)
    f._dot = f:CreateTexture(nil, "ARTWORK")
    f._dot:SetSize(4, 4)
    f._dot:SetPoint("LEFT", f, "LEFT", 4, 0)
    f._label = OneWoW_GUI:CreateFS(f, 10)
    f._label:SetPoint("LEFT", f._dot, "RIGHT", 4, 0)
    f._label:SetJustifyH("LEFT")
    f._label:SetWordWrap(false)
    return f
end

local function ReleaseObj(f)
    f:Hide()
    f:SetScript("OnClick", nil)
    tinsert(objPool, f)
end

local function SetDotStatus(dot, enabled)
    if enabled then
        dot:SetColorTexture(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
    else
        dot:SetColorTexture(OneWoW_GUI:GetThemeColor("DOT_FEATURES_DISABLED"))
    end
end

function TP:Create(listID)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine

    local list = TD:GetList(listID)
    if not list then return nil end

    -- Per-list pinned UI state. The normalizer guarantees these exist after
    -- DB init; reading them with `or default` here is the lazy-restore path
    -- for the first frame open after the v5 migration.
    local startCollapsed = list.pinnedCollapsed and true or false
    local expandedW = list.pinnedExpandedWidth  or list.pinnedWidth  or 300
    local expandedH = list.pinnedExpandedHeight or list.pinnedHeight or 400

    local frame = OneWoW_GUI:CreateFrame(nil, {
        name = "TrackerPinned_" .. listID:gsub("%-", "_"),
        width = expandedW,
        height = expandedH,
        backdrop = BACKDROP_SOFT,
    })
    frame:SetParent(UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    ApplyPinnedScale(frame)
    frame:EnableMouse(true)

    if list.pinnedPosition then
        local pp = list.pinnedPosition
        frame:SetPoint(pp.point or "CENTER", UIParent, pp.relativePoint or "CENTER", pp.x or 0, pp.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    local titleBar = OneWoW_GUI:CreateTitleBar(frame, {
        title = list.title or "Tracker",
        onClose = function()
            TE:DestroyPinnedWindow(listID)
        end,
    })

    local totalLabel = OneWoW_GUI:CreateFS(titleBar, 10)
    totalLabel:SetPoint("RIGHT", titleBar, "RIGHT", -28, 0)
    totalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    -- ------------------------------------------------------------------
    -- Opacity application — re-applies BG_PRIMARY/BORDER_DEFAULT theme
    -- colors at the chosen alpha. Called on creation, on theme change,
    -- and whenever the hover-controls opacity slider moves.
    -- ------------------------------------------------------------------
    local function ApplyOpacity(value)
        local r, g, b = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
        frame:SetBackdropColor(r, g, b, value)
        local br, bg, bb = OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")
        frame:SetBackdropBorderColor(br, bg, bb, value)
    end
    ApplyOpacity(list.pinnedOpacity or 1.0)

    -- ------------------------------------------------------------------
    -- Resize handle. Hidden when pinnedLockResize or collapsed; otherwise
    -- a standard bottom-right sizer that records the new dimensions onto
    -- the list as the expanded size (so collapse/restore round-trips it).
    -- ------------------------------------------------------------------
    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:RegisterForDrag("LeftButton")
    resizeBtn:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        list.pinnedWidth          = frame:GetWidth()
        list.pinnedHeight         = frame:GetHeight()
        list.pinnedExpandedWidth  = list.pinnedWidth
        list.pinnedExpandedHeight = list.pinnedHeight
    end)

    local function ApplyResizeLock()
        if list.pinnedLockResize or frame.pinnedCollapsed then
            resizeBtn:Hide()
            frame:SetResizable(false)
        else
            resizeBtn:Show()
            frame:SetResizable(true)
        end
    end

    local scrollContainer = CreateFrame("Frame", nil, frame)
    scrollContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
    scrollContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 14)

    local _, scrollChild = OneWoW_GUI:CreateScrollFrame(scrollContainer, {})

    local activeSections = {}
    local activeSteps = {}
    local activeObjs = {}

    local function ClearContent()
        for i = #activeSections, 1, -1 do
            ReleaseSection(tremove(activeSections, i))
        end
        for i = #activeSteps, 1, -1 do
            ReleaseStep(tremove(activeSteps, i))
        end
        for i = #activeObjs, 1, -1 do
            ReleaseObj(tremove(activeObjs, i))
        end
    end

    function frame:Refresh()
        ClearContent()

        local currentList = TD:GetList(listID)
        if not currentList then return end

        if frame.hideCompletedCB then
            frame.hideCompletedCB:SetChecked(currentList.pinnedHideCompleted and true or false)
        end
        if frame.autoHideCB then
            frame.autoHideCB:SetChecked(currentList.pinnedAutoHideWhenComplete and true or false)
        end

        if currentList.listType == "farmvalue" and ns.TrackerFarmValue then
            totalLabel:SetText("")
            ns.TrackerFarmValue:RenderPinned(currentList, scrollChild, frame)
            return
        end

        local done, total = TD:GetListCompletion(listID)
        totalLabel:SetText(total > 0 and format("%d/%d", done, total) or "")

        -- `pinnedHideCompleted` filters out finished steps and any section
        -- whose remaining (visible) steps are all complete. Computed once
        -- here and threaded through the inner loop guards.
        local hideCompleted = currentList.pinnedHideCompleted and true or false

        local yOffset = 0

        for _, sec in ipairs(currentList.sections) do
          if TE:IsSectionVisible(sec) then
           if not hideCompleted or TE:HasIncompleteVisibleStep(listID, sec) then
            local secDone, secTotal = TD:GetSectionCompletion(listID, sec.key)

            local secHeader = AcquireSection(scrollChild)
            secHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            secHeader:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
            secHeader:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)

            if secTotal > 0 and secDone >= secTotal then
                secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
            else
                secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            end
            secHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(activeSections, secHeader)

            secHeader._accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            secHeader._collapseIcon:SetTexture(sec.collapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")
            secHeader._label:SetText(sec.label or L["TRACKER_SECTION_FALLBACK"])
            secHeader._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            if secTotal > 0 then
                secHeader._count:SetText(format("%d/%d", secDone, secTotal))
                secHeader._count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                secHeader._count:Show()
            end

            secHeader:SetScript("OnClick", function()
                sec.collapsed = not sec.collapsed
                frame:Refresh()
            end)

            yOffset = yOffset - 22

          if not sec.collapsed then
            for _, step in ipairs(sec.steps or {}) do
              if TE:IsStepVisible(step, sec) then
                local sp = TD:GetStepProgress(listID, sec.key, step.key)
                local rosterCompleters = step.rosterMode and TD:GetRosterCompleters(listID, step.key) or nil
                local isComplete
                if step.rosterMode then
                    isComplete = TD:IsRosterCompleter(listID, step.key, TD:GetCurrentCharKey())
                else
                    isComplete = sp.completed or false
                end

               if not (hideCompleted and isComplete) then
                local stepRow = AcquireStep(scrollChild)
                stepRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOffset)
                stepRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                tinsert(activeSteps, stepRow)

                if step.optional then
                    stepRow._dot:SetSize(6, 6)
                    stepRow._dot:SetColorTexture(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    stepRow._dot:SetSize(6, 6)
                    SetDotStatus(stepRow._dot, isComplete)
                end

                stepRow._label:ClearAllPoints()
                stepRow._label:SetPoint("LEFT", stepRow._dot, "RIGHT", 6, 0)
                stepRow._label:SetPoint("RIGHT", stepRow, "RIGHT", -50, 0)
                stepRow._label:SetText(step.label or L["TRACKER_STEP_FALLBACK"])

                if step.optional then
                    stepRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                elseif isComplete then
                    stepRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    stepRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end

                local progressStr = ns.TrackerEvaluators.FormatStepProgress(
                    step, sp, rosterCompleters and #rosterCompleters or nil)

                stepRow._prog:SetText(progressStr)
                stepRow._prog:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local hasCoords = step.mapID and step.coordX and step.coordY and tonumber(step.mapID) and tonumber(step.coordX) and tonumber(step.coordY)
                if hasCoords then
                    stepRow:SetScript("OnClick", function()
                        if Location.SetWaypoint(step.mapID, step.coordX, step.coordY, {
                            format = "percent",
                            title = step.label or L["TRACKER_STEP_FALLBACK"],
                        }) then
                            print(format("%s %s", L["ADDON_CHAT_PREFIX"], format(L["TRACKER_WAYPOINT_SET"], step.label or L["TRACKER_STEP_FALLBACK"], tonumber(step.coordX), tonumber(step.coordY))))
                        else
                            print(format("%s %s", L["ADDON_CHAT_PREFIX"], L["MSG_CANNOT_SET_WAYPOINT"]))
                        end
                    end)
                elseif not step.rosterMode and step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                    stepRow:RegisterForClicks("AnyDown", "AnyUp")
                    stepRow:SetScript("OnClick", function(_, button)
                        if button == "LeftButton" then
                            if not isComplete and not TE:TryUserComplete(listID, sec.key, step.key) then
                                return
                            end
                            if step.max and step.max > 1 then
                                TD:BumpStepProgress(listID, sec.key, step.key, 1, step.max)
                            else
                                TD:ToggleStepComplete(listID, sec.key, step.key)
                            end
                        elseif button == "RightButton" then
                            if sp.current and sp.current > 0 then
                                local newVal = sp.current - 1
                                TD:SetStepProgress(listID, sec.key, step.key, newVal, step.max)
                                if newVal < (step.max or 1) then
                                    sp.completed = false
                                end
                            end
                        end
                        TE:NotifyProgressChanged()
                    end)
                end

                stepRow:SetScript("OnEnter", function(myself)
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    ns.TrackerEngine:BuildStepTooltip(GameTooltip, listID, sec.key, step)
                    GameTooltip:Show()
                end)
                stepRow:SetScript("OnLeave", GameTooltip_Hide)

                yOffset = yOffset - 20

                if rosterCompleters then
                    local myKey = TD:GetCurrentCharKey()
                    local meListed = false

                    for _, c in ipairs(rosterCompleters) do
                        local cRow = AcquireObj(scrollChild)
                        cRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
                        cRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                        tinsert(activeObjs, cRow)

                        SetDotStatus(cRow._dot, true)
                        cRow._label:ClearAllPoints()
                        cRow._label:SetPoint("LEFT", cRow._dot, "RIGHT", 4, 0)
                        cRow._label:SetPoint("RIGHT", cRow, "RIGHT", -4, 0)
                        cRow._label:SetText(c.realm and (c.name .. "-" .. c.realm) or c.name)

                        local color = c.class and RAID_CLASS_COLORS[c.class]
                        if color then
                            cRow._label:SetTextColor(color.r, color.g, color.b)
                        else
                            cRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        end

                        if c.charKey == myKey then meListed = true end

                        local removeKey = c.charKey
                        cRow:SetScript("OnClick", function()
                            TD:RemoveRosterCompleter(listID, step.key, removeKey)
                            TE:NotifyProgressChanged()
                        end)

                        yOffset = yOffset - 18
                    end

                    if not meListed and myKey then
                        local addRow = AcquireObj(scrollChild)
                        addRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
                        addRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                        tinsert(activeObjs, addRow)

                        SetDotStatus(addRow._dot, false)
                        addRow._label:ClearAllPoints()
                        addRow._label:SetPoint("LEFT", addRow._dot, "RIGHT", 4, 0)
                        addRow._label:SetPoint("RIGHT", addRow, "RIGHT", -4, 0)
                        addRow._label:SetText(L["TRACKER_ROSTER_ADD_ME"])
                        addRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                        addRow:SetScript("OnClick", function()
                            if not TE:TryUserComplete(listID, sec.key, step.key) then
                                return
                            end
                            TD:RecordRosterCompletion(listID, step.key)
                            TE:NotifyProgressChanged()
                        end)

                        yOffset = yOffset - 18
                    end

                elseif step.objectives and #step.objectives > 0 then
                    for _, obj in ipairs(step.objectives) do
                        local objComplete = TD:GetObjectiveProgress(listID, sec.key, step.key, obj.key)

                        local objRow = AcquireObj(scrollChild)
                        objRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
                        objRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                        tinsert(activeObjs, objRow)

                        SetDotStatus(objRow._dot, objComplete)

                        objRow._label:ClearAllPoints()
                        objRow._label:SetPoint("LEFT", objRow._dot, "RIGHT", 4, 0)
                        objRow._label:SetPoint("RIGHT", objRow, "RIGHT", -4, 0)
                        objRow._label:SetText(obj.description or obj.type)

                        if objComplete then
                            objRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                        else
                            objRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        end

                        if obj.type == "manual" then
                            objRow:SetScript("OnClick", function()
                                TD:SetObjectiveComplete(listID, sec.key, step.key, obj.key, not objComplete)
                                TE:EvaluateStep(listID, sec.key, step)
                                TE:NotifyProgressChanged()
                            end)
                        end

                        yOffset = yOffset - 18
                    end
                end
               end
              end
            end
          end

            yOffset = yOffset - 4
           end
          end
        end

        scrollChild:SetHeight(math_max(1, math_abs(yOffset)))
    end

    -- ------------------------------------------------------------------
    -- Collapse / expand. Stores the live size into pinnedExpandedWidth /
    -- pinnedExpandedHeight before shrinking the frame down to the title
    -- bar, and restores from there on uncollapse. Also drives the resize
    -- handle (hidden while collapsed) and the hover-controls panel
    -- (suppressed while collapsed — no controls to show without a body).
    -- ------------------------------------------------------------------
    local function ApplyCollapseState()
        if frame.pinnedCollapsed then
            scrollContainer:Hide()
            local titleH = titleBar:GetHeight() or 22
            frame:SetHeight(titleH + 6)
        else
            scrollContainer:Show()
            local w = list.pinnedExpandedWidth  or list.pinnedWidth  or 300
            local h = list.pinnedExpandedHeight or list.pinnedHeight or 400
            frame:SetSize(w, h)
        end
        ApplyResizeLock()
    end

    local function ToggleCollapsed()
        if frame.pinnedCollapsed then
            frame.pinnedCollapsed = false
            list.pinnedCollapsed = false
            ApplyCollapseState()
            frame:Refresh()
        else
            list.pinnedExpandedWidth  = frame:GetWidth()
            list.pinnedExpandedHeight = frame:GetHeight()
            frame.pinnedCollapsed = true
            list.pinnedCollapsed = true
            if frame.hoverControlsPanel then frame.hoverControlsPanel:Hide() end
            ApplyCollapseState()
        end
    end

    -- ------------------------------------------------------------------
    -- Title bar interaction. Move-drag is gated on pinnedLockMove; the
    -- existing left-button OnMouseUp doubles as a shift-click / double-
    -- click handler for collapse, mirroring the OneWoW_Notes pinned-note
    -- title bar behavior. OnDragStart suppresses the click counter so
    -- that finishing a drag never triggers a collapse.
    -- ------------------------------------------------------------------
    titleBar:EnableMouse(true)
    frame._titleBarLastClick = 0

    local function ApplyMoveLock()
        if list.pinnedLockMove then
            titleBar:RegisterForDrag()
            frame:SetMovable(false)
        else
            titleBar:RegisterForDrag("LeftButton")
            frame:SetMovable(true)
        end
    end

    titleBar:SetScript("OnDragStart", function()
        if not list.pinnedLockMove then
            frame:StartMoving()
            frame._titleBarLastClick = 0
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        list.pinnedPosition = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
    end)
    titleBar:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        if IsShiftKeyDown() then
            ToggleCollapsed()
            frame._titleBarLastClick = 0
            return
        end
        local now = GetTime()
        if frame._titleBarLastClick and (now - frame._titleBarLastClick) < DOUBLE_CLICK_INTERVAL then
            ToggleCollapsed()
            frame._titleBarLastClick = 0
        else
            frame._titleBarLastClick = now
        end
    end)
    titleBar:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["DOUBLE_CLICK_OR_SHIFT_CLICK_TO_COLLAPSE_OR_EXPAND"], 1, 1, 1)
        GameTooltip:Show()
    end)
    titleBar:SetScript("OnLeave", GameTooltip_Hide)

    -- ------------------------------------------------------------------
    -- Hover-controls panel — anchors under the pinned tracker and shows
    -- the opacity / lock-move / lock-resize / hide-completed controls
    -- when the mouse is over the pin or the panel itself. Mirrors the
    -- OneWoW_Notes pinned-note control strip so users see the same
    -- vocabulary on both kinds of pin.
    -- ------------------------------------------------------------------
    local hoverControlsPanel = OneWoW_GUI:CreateFrame(frame, {
        backdrop = BACKDROP_SOFT,
    })
    hoverControlsPanel:SetPoint("TOPLEFT",  frame, "BOTTOMLEFT",  0, 0)
    hoverControlsPanel:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local isFarm = list.listType == "farmvalue"
    hoverControlsPanel:SetHeight(isFarm and 76 or 100)
    hoverControlsPanel:SetFrameStrata(frame:GetFrameStrata())
    hoverControlsPanel:SetFrameLevel(frame:GetFrameLevel() + 10)
    hoverControlsPanel:EnableMouse(true)
    hoverControlsPanel:Hide()
    frame.hoverControlsPanel = hoverControlsPanel

    local opacitySlider = OneWoW_GUI:CreateSlider(hoverControlsPanel, {
        minVal = 0.1,
        maxVal = 1.0,
        step   = 0.05,
        currentVal = list.pinnedOpacity or 1.0,
        fmt    = "%.2f",
        onChange = function(val)
            list.pinnedOpacity = val
            ApplyOpacity(val)
        end,
    })
    opacitySlider:SetPoint("TOPLEFT",  hoverControlsPanel, "TOPLEFT",  10, -4)
    opacitySlider:SetPoint("TOPRIGHT", hoverControlsPanel, "TOPRIGHT", -10, -4)

    local lockMoveCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label   = L["LOCK_MOVE"],
        checked = list.pinnedLockMove,
        onClick = function(myself)
            list.pinnedLockMove = myself:GetChecked() and true or false
            ApplyMoveLock()
        end,
    })
    lockMoveCB:SetPoint("BOTTOMLEFT", hoverControlsPanel, "BOTTOMLEFT", 10, isFarm and 28 or 52)

    local lockResizeCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label   = L["LOCK_RESIZE"],
        checked = list.pinnedLockResize,
        onClick = function(myself)
            list.pinnedLockResize = myself:GetChecked() and true or false
            ApplyResizeLock()
        end,
    })
    lockResizeCB:SetPoint("LEFT", lockMoveCB, "RIGHT", 90, 0)

    local hideCompletedCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label   = L["TRACKER_PIN_HIDE_COMPLETED"],
        checked = list.pinnedHideCompleted,
        onClick = function(myself)
            list.pinnedHideCompleted = myself:GetChecked() and true or false
            frame:Refresh()
            if ns.UI.RefreshTab then
                ns.UI.RefreshTab()
            end
        end,
    })
    hideCompletedCB:SetPoint("BOTTOMLEFT", hoverControlsPanel, "BOTTOMLEFT", 10, isFarm and 4 or 28)
    frame.hideCompletedCB = hideCompletedCB
    local function HideCompletedTooltip(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TRACKER_PIN_HIDE_COMPLETED"], 1, 1, 1)
        GameTooltip:AddLine(L["TRACKER_PIN_HIDE_COMPLETED_DESC"]
            or "Hide completed steps and any section with nothing left to do.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    hideCompletedCB:SetScript("OnEnter", HideCompletedTooltip)
    hideCompletedCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if hideCompletedCB.label then
        hideCompletedCB.label:SetScript("OnEnter", HideCompletedTooltip)
        hideCompletedCB.label:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local autoHideCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label   = L["TRACKER_PIN_AUTO_HIDE"],
        checked = list.pinnedAutoHideWhenComplete,
        onClick = function(myself)
            list.pinnedAutoHideWhenComplete = myself:GetChecked() and true or false
            TE:SyncPinnedOverlay(listID)
            if frame:IsShown() then
                frame:Refresh()
            end
        end,
    })
    autoHideCB:SetPoint("BOTTOMLEFT", hoverControlsPanel, "BOTTOMLEFT", 10, 4)
    frame.autoHideCB = autoHideCB
    local function AutoHideTooltip(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TRACKER_PIN_AUTO_HIDE"], 1, 1, 1)
        GameTooltip:AddLine(L["TRACKER_PIN_AUTO_HIDE_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    autoHideCB:SetScript("OnEnter", AutoHideTooltip)
    autoHideCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if autoHideCB.label then
        autoHideCB.label:SetScript("OnEnter", AutoHideTooltip)
        autoHideCB.label:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if isFarm then
        hideCompletedCB:Hide()
        autoHideCB:Hide()
    end

    local function HideHoverControls()
        hoverControlsPanel:Hide()
    end
    local function ShowHoverControls()
        if frame.pinnedCollapsed then return end
        hoverControlsPanel:Show()
    end
    local function PinLeaveCheck()
        C_Timer.After(HOVER_HIDE_DELAY, function()
            if not frame:IsMouseOver() and not hoverControlsPanel:IsMouseOver() then
                HideHoverControls()
            end
        end)
    end

    frame:SetScript("OnEnter", ShowHoverControls)
    frame:SetScript("OnLeave", PinLeaveCheck)
    hoverControlsPanel:SetScript("OnLeave", PinLeaveCheck)

    function frame:ApplyThemeColors()
        ApplyOpacity(list.pinnedOpacity or 1.0)
        frame:Refresh()
    end

    -- Initial state — apply locks, then collapse/uncollapse to the saved
    -- state, then render.
    ApplyMoveLock()
    frame.pinnedCollapsed = startCollapsed
    ApplyCollapseState()
    frame:Refresh()
    frame:Show()
    return frame
end

local windows = {}

--- Live overlay frame for a list, if shown.
---@param listID string
---@return Frame|nil
function TP:Get(listID)
    return windows[listID]
end

--- Show or reuse the overlay for a list. Sets `list.pinned`.
---@param listID string
---@return Frame|nil
function TP:Show(listID)
    local existing = windows[listID]
    if existing then
        existing:Show()
        return existing
    end
    local win = self:Create(listID)
    if not win then return nil end
    windows[listID] = win
    local list = ns.TrackerData:GetList(listID)
    list.pinned = true
    return win
end

--- Hide the overlay without clearing `list.pinned` (auto-hide / role scope).
---@param listID string
function TP:Suppress(listID)
    local win = windows[listID]
    if not win then return end
    win:Hide()
    if win.hoverControlsPanel then
        win.hoverControlsPanel:Hide()
    end
end

--- Hide the overlay and clear `list.pinned`.
---@param listID string
function TP:Destroy(listID)
    local win = windows[listID]
    if win then
        win:Hide()
        windows[listID] = nil
    end
    local list = ns.TrackerData:GetList(listID)
    if list then
        list.pinned = false
    end
end

function TP:RefreshAll()
    for _, win in pairs(windows) do
        win:Refresh()
        OneWoW_GUI:ApplyFontToFrame(win)
    end
end

--- Apply the saved global scale to every live pinned overlay.
function TP:ApplyAllScales()
    for _, win in pairs(windows) do
        ApplyPinnedScale(win)
    end
end

--- Recreate overlays for lists that were pinned last session.
function TP:RestoreAll()
    local lists = ns.TrackerData:GetListsDB()
    for listID, list in pairs(lists) do
        if list.pinned then
            C_Timer.After(1, function()
                ns.TrackerEngine:SyncPinnedOverlay(listID)
            end)
        end
    end
end

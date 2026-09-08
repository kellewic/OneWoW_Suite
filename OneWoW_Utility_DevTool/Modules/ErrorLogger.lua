local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

local ErrorLogger = {}
ns.ErrorLogger = ErrorLogger

ErrorLogger.currentError = nil

local tinsert, tremove = tinsert, tremove
local format = string.format
local ipairs, type, tostring = ipairs, type, tostring
local time = time
local GetTime = GetTime
local CreateFrame = CreateFrame

local ROW_HEIGHT = 20

local function getConstants()
    return ns.Constants or {}
end

local function throttlePerSec()
    local c = getConstants()
    return c.ERROR_LOGGER_ERRORS_PER_SEC or 10
end

local function captureEventName()
    local c = getConstants()
    return c.ERROR_CAPTURE_EVENT or "OneWoW_DevTool.ErrorCaptured"
end

local function alertEventName()
    local c = getConstants()
    return c.ERROR_ALERT_EVENT or "OneWoW_DevTool.ErrorAlert"
end

local function getErrorDB()
    return ns.db.global.errorDB
end

local function maxErrorsCap()
    local db = getErrorDB()
    local n = db and db.maxErrors
    if type(n) ~= "number" or n < 1 then
        return 100
    end
    if n > 500 then
        return 500
    end
    return n
end

local function keepSessionsCap()
    local db = getErrorDB()
    local n = db and db.keepLastSessions
    if type(n) ~= "number" or n < 1 then
        return 10
    end
    if n > 20 then
        return 20
    end
    return n
end

local function soundKitForChoice(key)
    if key == "raid_warning" then
        return SOUNDKIT.RAID_WARNING
    end
    if key == "tell_message" then
        return SOUNDKIT.TELL_MESSAGE
    end
    if key == "map_ping" then
        return SOUNDKIT.MAP_PING or SOUNDKIT.RAID_WARNING
    end
    return nil
end

local function normalizeSoundChoice(db)
    local sc = db.soundChoice
    if sc == "devtools_error" or sc == "raid_warning" or sc == "tell_message" or sc == "map_ping" or sc == "off" then
        return
    end
    if db.playSound then
        db.soundChoice = "raid_warning"
    else
        db.soundChoice = "off"
    end
end

local function GetErrorStack()
    local GetCallstackHeight = GetCallstackHeight
    local GetErrorCallstackHeight = GetErrorCallstackHeight
    local debugstack = debugstack
    local ech = GetErrorCallstackHeight and GetErrorCallstackHeight()
    if ech then
        local currentStackHeight = GetCallstackHeight()
        local errorStackOffset = ech - 1
        local debugStackLevel = currentStackHeight - errorStackOffset
        return debugstack(debugStackLevel), debugStackLevel
    end
    return debugstack(3), 3
end

local function GetErrorLocals(level)
    local debuglocals = debuglocals
    if not debuglocals then
        return nil
    end
    return debuglocals(level)
end

local function fetchErrorByMessage(errors, targetMsg, targetSession)
    for i = #errors, 1, -1 do
        local err = errors[i]
        if err.message == targetMsg and err.session == targetSession then
            return err, i
        end
    end
end

local function trimOldest(errors, cap)
    while #errors > cap do
        tremove(errors, 1)
    end
end

local function formatTimeDisplay(err)
    if type(err.time) == "number" then
        return date("%Y-%m-%d %H:%M:%S", err.time)
    end
    return tostring(err.time or "?")
end

ErrorLogger.originalErrorHandler = nil
ErrorLogger._msgsAllowed = nil
ErrorLogger._msgsAllowedLastTime = nil
ErrorLogger._paused = nil
ErrorLogger._lastThrottleWarn = nil
ErrorLogger._lastSoundTime = nil
ErrorLogger._uiRefreshPending = nil
ErrorLogger._eventFrame = nil
ErrorLogger._badAddonBlocked = nil
ErrorLogger._bugGrabberBridgeRegistered = nil
ErrorLogger._bugGrabberBridgeActive = nil
ErrorLogger._bugGrabberLoadFrame = nil
ErrorLogger._bugGrabberCallbackOwner = nil

function ErrorLogger:IsBugGrabberAvailable()
    local bg = rawget(_G, "BugGrabber")
    return type(bg) == "table" and type(bg.GetErrorByID) == "function"
end

function ErrorLogger:IsBugGrabberBridgeActive()
    return self._bugGrabberBridgeActive and true or false
end

function ErrorLogger:UpdateLuaTabBugGrabberNotice()
    local tab = ns.LuaConsoleTab
    local notice = tab and tab.bugGrabberNotice
    local clearBtn = tab and tab.luaClearBtn
    if not tab or not notice or not clearBtn then
        return
    end
    if self:IsBugGrabberBridgeActive() then
        notice:SetText(L["LUA_TAB_BUGGRABBER_NOTICE"])
        notice:ClearAllPoints()
        notice:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
        notice:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -5, -5)
        notice:Show()
        clearBtn:ClearAllPoints()
        clearBtn:SetPoint("TOPLEFT", notice, "BOTTOMLEFT", 0, -10)
    else
        notice:SetText("")
        notice:Hide()
        notice:ClearAllPoints()
        clearBtn:ClearAllPoints()
        clearBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    end
    if tab.LayoutErrorRowAnchors then
        C_Timer.After(0, function()
            if ns.LuaConsoleTab and ns.LuaConsoleTab.LayoutErrorRowAnchors then
                ns.LuaConsoleTab.LayoutErrorRowAnchors()
            end
        end)
    end
end

function ErrorLogger:_unregisterAuxEvents()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame:SetScript("OnEvent", nil)
        self._eventFrame = nil
    end
    self._badAddonBlocked = {}
end

function ErrorLogger:_ensureBugGrabberLateLoadListener()
    if self._bugGrabberWatcherRegistered then
        return
    end
    self._bugGrabberWatcherRegistered = true
    local c = ns.Constants
    local want = (c and c.BUGGRABBER_STANDALONE_ADDON) or "!BugGrabber"
    local function onBugGrabberLoaded()
        if not ErrorLogger:IsBugGrabberAvailable() then
            return
        end
        ErrorLogger:_registerBugGrabberBridgeOnce()
        ErrorLogger:_unregisterAuxEvents()
        ErrorLogger:UpdateLuaTabBugGrabberNotice()
    end
    OneWoW:RegisterAddonLoadedWatcher(want, function(addonName)
        if addonName ~= want then
            return
        end
        onBugGrabberLoaded()
    end)
end

function ErrorLogger:_registerBugGrabberBridgeOnce()
    if self._bugGrabberBridgeRegistered then
        return
    end
    if not self:IsBugGrabberAvailable() then
        return
    end
    self._bugGrabberBridgeRegistered = true
    self._bugGrabberBridgeActive = true
    local owner = {}
    self._bugGrabberCallbackOwner = owner
    EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, tableID)
        -- keep BugGrabber's callback chain healthy on handler errors
        pcall(function()
            ErrorLogger:_onBugGrabberBugGrabbed(tableID)
        end)
    end, owner)
    self:UpdateLuaTabBugGrabberNotice()
end

function ErrorLogger:_onBugGrabberBugGrabbed(tableID)
    if type(tableID) ~= "string" then
        return
    end
    local bg = rawget(_G, "BugGrabber")
    if not bg or type(bg.GetErrorByID) ~= "function" then
        return
    end
    local bgErr = bg:GetErrorByID(tableID)
    if type(bgErr) ~= "table" then
        return
    end
    self:_importFromBugGrabber(bgErr)
end

function ErrorLogger:_importFromBugGrabber(bgErr)
    local db = getErrorDB()
    if not db then
        return
    end

    local rawMsg = bgErr.message
    local msgStr
    if OneWoW.Restriction.IsSecret(rawMsg) then
        msgStr = L["ERR_MSG_SECRET"]
    else
        msgStr = tostring(rawMsg)
        if OneWoW.Restriction.IsSecret(msgStr) then
            msgStr = L["ERR_MSG_SECRET"]
        end
    end
    if msgStr:find("ErrorLogger", 1, true) or msgStr:find("OneWoW_Utility_DevTool", 1, true) then
        return
    end

    local isSimple = not (type(bgErr.stack) == "string" and bgErr.stack ~= "")
    local stackStr = type(bgErr.stack) == "string" and bgErr.stack or ""
    local localsStr
    if bgErr.locals == nil then
        localsStr = ""
    else
        localsStr = tostring(bgErr.locals)
    end

    self:_mergeErrorIntoDB(msgStr, isSimple, stackStr, localsStr)
end

--- Dedup, trim, notify. Optional stack/locals from BugGrabber (nil = compute from live context when not isSimple).
function ErrorLogger:_mergeErrorIntoDB(msgStr, isSimple, stackOverride, localsOverride)
    local db = getErrorDB()
    if not db then
        return
    end

    local errors = db.errors
    local session = db.session
    local now = time()
    local existing, pos = fetchErrorByMessage(errors, msgStr, session)

    local function stackLocalsForNew()
        if stackOverride ~= nil then
            return stackOverride, localsOverride or ""
        end
        if not isSimple then
            local stack, level = GetErrorStack()
            local loc = GetErrorLocals(level)
            return stack or "", loc and tostring(loc) or ""
        end
        return "", ""
    end

    local function stackLocalsForUpdate()
        if stackOverride ~= nil then
            return stackOverride, localsOverride or ""
        end
        if not isSimple then
            local stack, level = GetErrorStack()
            local loc = GetErrorLocals(level)
            return stack or "", loc and tostring(loc) or ""
        end
        return "", ""
    end

    if not existing then
        local errObj = {
            message = msgStr,
            session = session,
            time = now,
            counter = 1,
            stack = "",
            locals = "",
        }
        if not isSimple then
            local st, loc = stackLocalsForNew()
            errObj.stack = st
            errObj.locals = loc
        end
        tinsert(errors, errObj)
        trimOldest(errors, maxErrorsCap())
        self:_afterNewOrUpdated(errObj)
        return
    end

    existing.counter = (existing.counter or 1) + 1
    local prevTime = existing.time
    if type(prevTime) ~= "number" then
        prevTime = now
    end
    existing.time = now

    if now - prevTime > 10 then
        tremove(errors, pos)
        tinsert(errors, existing)
    end

    if not isSimple and now - prevTime > 120 then
        local st, loc = stackLocalsForUpdate()
        existing.stack = st
        existing.locals = loc
    end

    trimOldest(errors, maxErrorsCap())
    self:_afterNewOrUpdated(existing)
end

function ErrorLogger:_applyErrorThrottle()
    local rate = throttlePerSec()
    self._msgsAllowed = self._msgsAllowed + (GetTime() - self._msgsAllowedLastTime) * rate
    self._msgsAllowedLastTime = GetTime()
    if self._msgsAllowed < 1 then
        if not self._paused then
            if GetTime() > (self._lastThrottleWarn or 0) + 10 then
                ns:Print(L["ERR_THROTTLE_PAUSED"])
                self._lastThrottleWarn = GetTime()
            end
            self._paused = true
        end
        return false
    end
    self._paused = false
    if self._msgsAllowed > rate then
        self._msgsAllowed = rate
    end
    self._msgsAllowed = self._msgsAllowed - 1
    return true
end

function ErrorLogger:Initialize()
    local db = getErrorDB()
    if not db then
        return
    end
    normalizeSoundChoice(db)
    if type(db.copyFormat) ~= "string" then
        db.copyFormat = "plain"
    end
    if type(db.clearOnReload) ~= "boolean" then
        db.clearOnReload = false
    end
    if type(db.keepLastSessions) ~= "number" then
        db.keepLastSessions = 10
    end
    if type(db.maxErrors) ~= "number" then
        db.maxErrors = 100
    end

    db.session = (type(db.session) == "number" and db.session or 0) + 1

    if db.clearOnReload then
        db.errors = {}
    else
        local cur = db.session
        local keep = keepSessionsCap()
        local minSession = cur - keep + 1
        local kept = {}
        for _, e in ipairs(db.errors) do
            if type(e.session) == "number" and e.session >= minSession then
                tinsert(kept, e)
            end
        end
        db.errors = kept
    end

    self._msgsAllowed = throttlePerSec()
    self._msgsAllowedLastTime = GetTime()
    self._paused = false

    if self:IsBugGrabberAvailable() then
        self.originalErrorHandler = nil
        self:_registerBugGrabberBridgeOnce()
    else
        self.originalErrorHandler = geterrorhandler()
        seterrorhandler(function(msg)
            return ErrorLogger:_onLuaError(msg)
        end)
        self:_registerAuxEvents()
        self:_ensureBugGrabberLateLoadListener()
    end

    C_Timer.After(2, function()
        ErrorLogger:UpdateErrorBadge()
        ns.ErrorFloat:ShowSessionErrors()
    end)
end

function ErrorLogger:_registerAuxEvents()
    if self._eventFrame then
        return
    end
    self._badAddonBlocked = {}
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_ACTION_BLOCKED")
    f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    f:RegisterEvent("LUA_WARNING")
    f:SetScript("OnEvent", function(_, event, ...)
        ErrorLogger:_onAuxEvent(event, ...)
    end)
    self._eventFrame = f

    if UIParent and UIParent.UnregisterEvent then
        pcall(function()
            UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
            UIParent:UnregisterEvent("ADDON_ACTION_BLOCKED")
        end)
    end

    if ScriptErrorsFrame and ScriptErrorsFrame.UnregisterEvent then
        pcall(function()
            ScriptErrorsFrame:UnregisterEvent("LUA_WARNING")
        end)
    end
end

function ErrorLogger:_onAuxEvent(event, a1, a2)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local addonName = a1 or "<name>"
        local fn = a2 or "<func>"
        if not self._badAddonBlocked[addonName] then
            self._badAddonBlocked[addonName] = true
            local template = L["ERR_ADDON_CALL_PROTECTED"]
            self:StoreErrorSimple(format(template, event, addonName, fn))
        end
    elseif event == "LUA_WARNING" then
        local w = a1
        if not w then
            w = ""
        end
        self:StoreErrorSimple("LUA_WARNING: " .. tostring(w))
    end
end

function ErrorLogger:_onLuaError(msg)
    -- avoid breaking the error pipeline on capture failures
    pcall(function()
        self:_captureFromHandler(msg, false)
    end)
    if self.originalErrorHandler then
        return self.originalErrorHandler(msg)
    end
end

function ErrorLogger:StoreErrorSimple(message)
    self:_captureFromHandler(message, true)
end

function ErrorLogger:_captureFromHandler(msg, isSimple)
    local db = getErrorDB()
    if not db then
        return
    end

    if not self:_applyErrorThrottle() then
        return
    end

    local msgStr
    if OneWoW.Restriction.IsSecret(msg) then
        msgStr = L["ERR_MSG_SECRET"]
    else
        msgStr = tostring(msg)
        if OneWoW.Restriction.IsSecret(msgStr) then
            msgStr = L["ERR_MSG_SECRET"]
        end
    end
    if msgStr:find("ErrorLogger", 1, true) or msgStr:find("OneWoW_Utility_DevTool", 1, true) then
        return
    end

    self:_mergeErrorIntoDB(msgStr, isSimple, nil, nil)
end

function ErrorLogger:_afterNewOrUpdated(errObj)
    self:PlayAlertSound()
    EventRegistry:TriggerEvent(captureEventName(), errObj)
    self:ScheduleUIRefresh()
    self:UpdateErrorBadge()
    ns.ErrorFloat:OnError(errObj)
end

function ErrorLogger:ScheduleUIRefresh()
    if self._uiRefreshPending then
        return
    end
    self._uiRefreshPending = true
    C_Timer.After(0, function()
        ErrorLogger._uiRefreshPending = false
        ErrorLogger:UpdateUI()
    end)
end

function ErrorLogger:GetSessionId()
    return getErrorDB() and getErrorDB().session or 0
end

function ErrorLogger:GetErrors()
    return getErrorDB() and getErrorDB().errors or {}
end

function ErrorLogger:PlayAlertSound()
    local db = getErrorDB()
    if not db then
        return
    end
    normalizeSoundChoice(db)
    local choice = db.soundChoice
    if choice == "off" or not choice then
        return
    end
    local t = GetTime()
    if self._lastSoundTime and (t - self._lastSoundTime) < 2 then
        return
    end
    self._lastSoundTime = t
    if choice == "devtools_error" then
        local path = getConstants().ERROR_LOGGER_ALERT_SOUND_FILE
        if path then
            pcall(function()
                PlaySoundFile(path, "Master")
            end)
        end
        return
    end
    local kit = soundKitForChoice(choice)
    if not kit then
        return
    end
    pcall(function()
        PlaySound(kit, "Master")
    end)
end

function ErrorLogger:PreviewSoundChoice(key)
    if key == "off" or not key then
        return
    end
    if key == "devtools_error" then
        local path = getConstants().ERROR_LOGGER_ALERT_SOUND_FILE
        if path then
            pcall(function()
                PlaySoundFile(path, "Master")
            end)
        end
        return
    end
    local kit = soundKitForChoice(key)
    if not kit then
        return
    end
    pcall(function()
        PlaySound(kit, "Master")
    end)
end

function ErrorLogger:GetMinimapButton()
    return OneWoW_GUI:GetMinimapButton()
end

function ErrorLogger:HasCurrentSessionErrors()
    local errors = self:GetErrors()
    local currentSession = self:GetSessionId()
    for i = #errors, 1, -1 do
        if errors[i].session == currentSession then
            return true
        end
    end
    return false
end

function ErrorLogger:UpdateErrorBadge()
    local showBadge = self:HasCurrentSessionErrors()

    if not self.errorBadge and showBadge then
        local button = self:GetMinimapButton()
        if button then
            local badge = CreateFrame("Frame", nil, button)
            badge:SetSize(20, 20)
            badge:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
            badge:SetFrameLevel(button:GetFrameLevel() + 5)

            local icon = badge:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetAtlas("Ping_Chat_Warning")

            self.errorBadge = badge
        end
    end

    if self.errorBadge then
        if showBadge then
            self.errorBadge:Show()
        else
            self.errorBadge:Hide()
        end
    end

    EventRegistry:TriggerEvent(alertEventName(), showBadge)
end

function ErrorLogger:UpdateUI()
    if not ns.LuaConsoleTab then
        return
    end

    self:UpdateLuaTabBugGrabberNotice()

    local tab = ns.LuaConsoleTab
    local errors = self:GetErrors()
    local currentSession = self:GetSessionId()

    tab.countLabel:SetText((L["LABEL_ERRORS"]) .. " " .. #errors)
    if tab.LayoutErrorRowAnchors then
        tab.LayoutErrorRowAnchors()
    end

    local SC = ns.StackColorizer
    for i, btn in ipairs(tab.errorButtons) do
        local errorIdx = #errors - (i - 1)
        local err = errors[errorIdx]

        if err then
            local isCurrentSession = (err.session == currentSession)
            local sessionLabel
            if isCurrentSession then
                sessionLabel = L["ERR_SESSION_CURRENT"]
            else
                sessionLabel = (L["SESSION"]) .. " " .. (err.session or "?")
            end

            local countStr = ""
            if err.counter and err.counter > 1 then
                countStr = " (x" .. err.counter .. ")"
            end

            local shortMsg = err.message or ""
            if #shortMsg > 60 then
                shortMsg = shortMsg:sub(1, 57) .. "..."
            end

            if SC then
                btn.label:SetText(SC:ColorizeListRow(formatTimeDisplay(err), sessionLabel, isCurrentSession, shortMsg, countStr))
            else
                btn.label:SetText(format("[%s] %s - %s%s", formatTimeDisplay(err), sessionLabel, shortMsg, countStr))
            end
            btn.errorData = err
            btn:Show()
        else
            btn:Hide()
        end
    end

    local displayCount = math.min(#errors, #tab.errorButtons)
    local contentHeight = math.max(displayCount * ROW_HEIGHT + 5, tab.listScroll:GetHeight())
    tab.listScroll:GetScrollChild():SetHeight(contentHeight)
end

function ErrorLogger:ShowErrorDetails(errorData)
    if not ns.LuaConsoleTab or not errorData then
        return
    end

    self.currentError = errorData
    local tab = ns.LuaConsoleTab
    local currentSession = self:GetSessionId()
    local SC = ns.StackColorizer

    local sessionLabel
    if errorData.session == currentSession then
        sessionLabel = L["ERR_SESSION_CURRENT_FULL"]
    else
        sessionLabel = (L["SESSION"]) .. " " .. (errorData.session or "?")
    end

    local details = {}
    if SC then
        tinsert(details, SC:ColorizeMetaLine(L["ERR_DETAIL_TIME"], formatTimeDisplay(errorData)))
        tinsert(details, SC:ColorizeMetaLine(L["ERR_DETAIL_SESSION"], sessionLabel))
        if errorData.counter and errorData.counter > 1 then
            tinsert(details, SC:ColorizeMetaLine(L["ERR_DETAIL_COUNT"], errorData.counter))
        end
        tinsert(details, "")
        tinsert(details, SC:ColorizeHeader(L["ERR_DETAIL_MESSAGE"]))
        tinsert(details, SC:ColorizeMessage(errorData.message or ""))
        tinsert(details, "")
        tinsert(details, SC:ColorizeHeader(L["ERR_DETAIL_STACK"]))
        tinsert(details, SC:ColorizeStack(errorData.stack or ""))

        if errorData.locals and errorData.locals ~= "" then
            tinsert(details, "")
            tinsert(details, SC:ColorizeHeader(L["ERR_DETAIL_LOCALS"]))
            tinsert(details, SC:ColorizeLocals(errorData.locals))
        end
    else
        tinsert(details, (L["ERR_DETAIL_TIME"]) .. " " .. formatTimeDisplay(errorData))
        tinsert(details, (L["ERR_DETAIL_SESSION"]) .. " " .. sessionLabel)
        if errorData.counter and errorData.counter > 1 then
            tinsert(details, (L["ERR_DETAIL_COUNT"]) .. " " .. errorData.counter)
        end
        tinsert(details, "")
        tinsert(details, (L["ERR_DETAIL_MESSAGE"]))
        tinsert(details, errorData.message or "")
        tinsert(details, "")
        tinsert(details, (L["ERR_DETAIL_STACK"]))
        tinsert(details, errorData.stack or "")

        if errorData.locals and errorData.locals ~= "" then
            tinsert(details, "")
            tinsert(details, (L["ERR_DETAIL_LOCALS"]))
            tinsert(details, errorData.locals)
        end
    end

    local displayText = table.concat(details, "\n")
    tab.detailsText._lastSetText = displayText
    tab.detailsText:SetText(displayText)

    C_Timer.After(0, function()
        if not tab.detailsText or not tab.detailsScroll then return end
        local _, fontHeight = tab.detailsText:GetFont()
        local lineCount = select(2, displayText:gsub("\n", "\n")) + 1
        local contentHeight = lineCount * (fontHeight + 2) + 10
        tab.detailsText:SetHeight(math.max(contentHeight, tab.detailsScroll:GetHeight()))
    end)

    local analysis = errorData._analysis
    if not analysis and ns.ErrorAnalyzer then
        analysis = ns.ErrorAnalyzer:Analyze(errorData)
        errorData._analysis = analysis
    end

    if analysis and tab.analysisText then
        local lines = {}
        if SC then
            tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_ERROR_TYPE"], analysis.errorType or ""))
            tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_ROOT_CAUSE"], analysis.rootCauseLabel or ""))
            if analysis.reportedAddon then
                tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_REPORTED_ADDON"], analysis.reportedAddon))
            end
            if analysis.offendingAddon and analysis.offendingAddon ~= analysis.reportedAddon then
                tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_OFFENDING_ADDON"], analysis.offendingAddon))
            end
            if analysis.taintSource then
                tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_TAINT_SOURCE"], analysis.taintSource))
            end
            if analysis.protectedAction then
                tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_PROTECTED"], analysis.protectedAction))
            end
            if analysis.triggerLocation then
                tinsert(lines, SC:ColorizeMetaLine(L["ERR_ANALYSIS_TRIGGER"], analysis.triggerLocation))
            end
            tinsert(lines, "")
            tinsert(lines, SC:ColorizeHeader(L["ERR_ANALYSIS_RECOMMENDATION"]))
            tinsert(lines, SC:ColorizeMessage(analysis.recommendation or ""))
        else
            tinsert(lines, (L["ERR_ANALYSIS_ERROR_TYPE"]) .. " " .. (analysis.errorType or ""))
            tinsert(lines, (L["ERR_ANALYSIS_ROOT_CAUSE"]) .. " " .. (analysis.rootCauseLabel or ""))
            if analysis.reportedAddon then
                tinsert(lines, (L["ERR_ANALYSIS_REPORTED_ADDON"]) .. " " .. analysis.reportedAddon)
            end
            if analysis.offendingAddon and analysis.offendingAddon ~= analysis.reportedAddon then
                tinsert(lines, (L["ERR_ANALYSIS_OFFENDING_ADDON"]) .. " " .. analysis.offendingAddon)
            end
            if analysis.taintSource then
                tinsert(lines, (L["ERR_ANALYSIS_TAINT_SOURCE"]) .. " " .. analysis.taintSource)
            end
            if analysis.protectedAction then
                tinsert(lines, (L["ERR_ANALYSIS_PROTECTED"]) .. " " .. analysis.protectedAction)
            end
            if analysis.triggerLocation then
                tinsert(lines, (L["ERR_ANALYSIS_TRIGGER"]) .. " " .. analysis.triggerLocation)
            end
            tinsert(lines, "")
            tinsert(lines, (L["ERR_ANALYSIS_RECOMMENDATION"]))
            tinsert(lines, analysis.recommendation or "")
        end

        tab.analysisText:SetText(table.concat(lines, "\n"))
        local aHeight = tab.analysisText:GetStringHeight()
        tab.analysisScroll:GetScrollChild():SetHeight(math.max(aHeight + 10, tab.analysisScroll:GetHeight()))
    end
end

function ErrorLogger:CopyCurrentError()
    if not self.currentError then
        ns:Print(L["LABEL_NO_ERROR"])
        return
    end

    local db = getErrorDB()
    local fmt = db and db.copyFormat or "plain"
    local text
    if ns.ErrorExport and ns.ErrorExport.GetCopyText then
        text = ns.ErrorExport.GetCopyText(self.currentError, fmt, L)
    else
        text = tostring(self.currentError.message)
    end

    ns:CopyToClipboard(text, L["ERR_COPY_TITLE"])
end

function ErrorLogger:CopyAllErrors()
    local db = getErrorDB()
    local fmt = db and db.copyFormat or "plain"
    local text = ns.ErrorExport.BuildAllText(self:GetErrors(), fmt, L, self:GetSessionId())
    if text == "" then
        ns:Print(L["ERR_DEVMODE_EMPTY"])
        return
    end
    ns:CopyToClipboard(text, L["ERR_COPY_ALL_TITLE"])
end

function ErrorLogger:ClearErrors()
    local db = getErrorDB()
    if db then
        db.errors = {}
    end

    self.currentError = nil
    self:UpdateUI()
    self:UpdateErrorBadge()
    ns.ErrorFloat:Hide()

    if ns.LuaConsoleTab then
        local noErr = L["LABEL_NO_ERROR"]
        ns.LuaConsoleTab.detailsText._lastSetText = noErr
        ns.LuaConsoleTab.detailsText:SetText(noErr)
        if ns.LuaConsoleTab.analysisText then
            ns.LuaConsoleTab.analysisText:SetText(L["ERR_ANALYSIS_NONE"])
        end
    end

    ns:Print(L["ERR_MSG_CLEARED"])
end

-- ============================================================================
-- FramePicker
-- ============================================================================
-- Pick Frame overlay: hover the UI, Tab to cycle, click/Enter to inspect.
-- Uses C_System.GetFrameStack (same stack as /fstack) on a 0.1s cadence.
-- Do not walk EnumerateFrames here -- that path tanks FPS on dense 12.x UI.
-- ============================================================================

local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

local GetTime = GetTime
local IsShiftKeyDown = IsShiftKeyDown
local IsMouseButtonDown = IsMouseButtonDown

local STACK_UPDATE_INTERVAL = 0.1

local FramePicker = {}
ns.FramePicker = FramePicker

local detailsLines = {}

--- True when `frame` is the picker overlay, info window, highlight, or a child of those.
---@param frame ScriptRegion
---@param ancestor Frame|nil
---@return boolean
local function isUnder(frame, ancestor)
    if not ancestor then
        return false
    end
    local current = frame
    while current do
        if current == ancestor then
            return true
        end
        current = current.GetParent and current:GetParent()
    end
    return false
end

function FramePicker:Initialize()
    if self.overlay then return end

    self.overlay = CreateFrame("Frame", "OneWoWDevToolsPickerOverlay", UIParent)
    self.overlay:SetFrameStrata("TOOLTIP")
    self.overlay:SetAllPoints(UIParent)
    self.overlay:EnableMouse(false)
    self.overlay:EnableKeyboard(true)
    self.overlay:Hide()

    self.currentFrame = nil
    self.lastMouseState = false
    self.frameIndex = 1
    self.allFrames = {}
    self.nextStackUpdate = 0
    self.detailsKey = nil

    self.overlay:SetScript("OnUpdate", function(_, elapsed)
        FramePicker:OnUpdate(elapsed)
    end)

    self.overlay:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            FramePicker:Cancel()
        elseif key == "TAB" then
            FramePicker:CycleFrame()
        elseif key == "ENTER" then
            FramePicker:OnClick()
        end
    end)

    self.overlay:SetPropagateKeyboardInput(false)

    local dialogResult = OneWoW_GUI:CreateDialog({
        name = "OneWoWDevToolsPickerInfo",
        title = L["FRAME_PICKER_TITLE"],
        width = 450,
        height = 350,
        strata = "TOOLTIP",
        movable = true,
        escClose = false,
        showBrand = false,
    })
    local infoWindow = dialogResult.frame
    infoWindow:ClearAllPoints()
    infoWindow:SetPoint("TOP", UIParent, "TOP", 0, -100)
    infoWindow:Hide()

    infoWindow.details = dialogResult.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoWindow.details:SetPoint("TOPLEFT", dialogResult.contentFrame, "TOPLEFT", 10, -10)
    infoWindow.details:SetPoint("BOTTOMRIGHT", dialogResult.contentFrame, "BOTTOMRIGHT", -10, 10)
    infoWindow.details:SetJustifyH("LEFT")
    infoWindow.details:SetJustifyV("TOP")
    infoWindow.details:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    infoWindow.details:SetText(L["FRAME_PICKER_HOVER"])

    self.infoWindow = infoWindow
end

--- True when `frame` belongs to the picker chrome (must not be pickable).
---@param frame ScriptRegion
---@return boolean
function FramePicker:IsPickerUI(frame)
    if isUnder(frame, self.overlay) then
        return true
    end
    if isUnder(frame, self.infoWindow) then
        return true
    end
    return isUnder(frame, ns.FrameInspector.highlightFrame)
end

--- Cursor stack from the client, minus picker chrome and forbidden regions.
---@return ScriptRegion[]
function FramePicker:CollectValidFrames()
    local stack = C_System.GetFrameStack()
    local validFrames = {}
    for i = 1, #stack do
        local frame = stack[i]
        if frame and not (frame.IsForbidden and frame:IsForbidden()) and not self:IsPickerUI(frame) then
            tinsert(validFrames, frame)
        end
    end
    return validFrames
end

--- Refresh the info window and highlight for `self.frameIndex` in `self.allFrames`.
function FramePicker:ShowSelection()
    local validFrames = self.allFrames
    local targetFrame = validFrames[self.frameIndex]

    if not targetFrame then
        self.currentFrame = nil
        if self.detailsKey ~= "empty" then
            self.detailsKey = "empty"
            if #validFrames == 0 then
                self.infoWindow.details:SetText(L["FRAME_PICKER_MSG_NO_FRAME"])
            else
                self.infoWindow.details:SetText(L["FRAME_PICKER_ALL_FILTERED"])
            end
        end
        ns.FrameInspector:ClearHighlight()
        return
    end

    self.currentFrame = targetFrame
    ns.FrameInspector:HighlightFrame(targetFrame)

    local detailsKey = tostring(targetFrame) .. ":" .. self.frameIndex .. ":" .. #validFrames
    if detailsKey == self.detailsKey then
        return
    end
    self.detailsKey = detailsKey

    wipe(detailsLines)
    if #validFrames > 1 then
        tinsert(detailsLines, (L["FRAME_PICKER_FRAME_OF"]):format(self.frameIndex, #validFrames))
        tinsert(detailsLines, "")
    end

    local name = ns.safeGet(targetFrame, "GetName") or "Anonymous"
    if type(name) ~= "string" then
        name = "Anonymous"
    end
    local ftype = ns.safeGet(targetFrame, "GetObjectType") or "Unknown"

    tinsert(detailsLines, "NAME: " .. name)
    tinsert(detailsLines, "TYPE: " .. ftype)

    local shown = ns.safeGet(targetFrame, "IsShown")
    if shown ~= nil then
        tinsert(detailsLines, "SHOWN: " .. (shown and "Yes" or "No"))
    end

    local mouse = ns.safeGet(targetFrame, "IsMouseEnabled")
    if mouse ~= nil then
        tinsert(detailsLines, "MOUSE: " .. (mouse and "Yes" or "No"))
    end

    local parent = targetFrame.GetParent and targetFrame:GetParent()
    if parent then
        local pname = ns.safeGet(parent, "GetName") or "Anonymous"
        if type(pname) ~= "string" then
            pname = "Anonymous"
        end
        tinsert(detailsLines, "PARENT: " .. pname)
    end

    local width = ns.safeGet(targetFrame, "GetWidth")
    local height = ns.safeGet(targetFrame, "GetHeight")
    if width ~= nil and height ~= nil then
        tinsert(detailsLines, string.format("SIZE: %.0f x %.0f", width, height))
    end

    local strata = ns.safeGet(targetFrame, "GetFrameStrata")
    if strata then
        tinsert(detailsLines, "STRATA: " .. strata)
    end

    local level = ns.safeGet(targetFrame, "GetFrameLevel")
    if level ~= nil then
        tinsert(detailsLines, "LEVEL: " .. level)
    end

    self.infoWindow.details:SetText(table.concat(detailsLines, "\n"))
end

function FramePicker:RefreshStack()
    self.allFrames = self:CollectValidFrames()
    if self.frameIndex > #self.allFrames then
        self.frameIndex = 1
    end
    self:ShowSelection()
end

function FramePicker:Start()
    self:Initialize()

    self.wasMainFrameShown = false

    if ns.UI and ns.UI.mainFrame and ns.UI.mainFrame:IsShown() then
        self.wasMainFrameShown = true
        ns.UI.mainFrame:Hide()
    end

    self.currentFrame = nil
    self.frameIndex = 1
    self.allFrames = {}
    self.detailsKey = nil
    self.nextStackUpdate = 0
    self.lastMouseState = false

    self.overlay:Show()
    self.overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    self.infoWindow:Show()

    ns:Print(L["FRAME_PICKER_MSG_ACTIVE"])
end

function FramePicker:CycleFrame()
    if #self.allFrames <= 1 then
        ns:Print(L["FRAME_PICKER_MSG_ONE"])
        return
    end

    self.frameIndex = (self.frameIndex % #self.allFrames) + 1
    ns:Print((L["FRAME_PICKER_MSG_CYCLING"]):format(self.frameIndex, #self.allFrames))
    self:ShowSelection()
end

function FramePicker:Cancel()
    if not self.overlay then return end

    self.overlay:Hide()
    self.infoWindow:Hide()
    self.currentFrame = nil
    self.detailsKey = nil
    ns.FrameInspector:ClearHighlight()

    if self.wasMainFrameShown and ns.UI and ns.UI.mainFrame then
        ns.UI.mainFrame:Show()
    end

    ns:Print(L["FRAME_PICKER_MSG_CANCELLED"])
end

function FramePicker:OnUpdate(_)
    local shiftHeld = IsShiftKeyDown()

    if shiftHeld then
        self.lastMouseState = IsMouseButtonDown("LeftButton")
        return
    end

    local mouseDown = IsMouseButtonDown("LeftButton")
    if mouseDown and not self.lastMouseState then
        self:OnClick()
        self.lastMouseState = mouseDown
        return
    end
    self.lastMouseState = mouseDown

    if IsMouseButtonDown("RightButton") then
        self:Cancel()
        return
    end

    local now = GetTime()
    if now < self.nextStackUpdate then
        return
    end
    self.nextStackUpdate = now + STACK_UPDATE_INTERVAL
    self:RefreshStack()
end

function FramePicker:OnClick()
    if not self.currentFrame then
        ns:Print(L["FRAME_PICKER_MSG_NO_FRAME"])
        return
    end

    local frame = self.currentFrame
    self:Cancel()

    ns.FrameInspector:InspectFrame(frame)
    local selectedName = ns.safeGet(frame, "GetName") or "Anonymous"
    if type(selectedName) ~= "string" then
        selectedName = "Anonymous"
    end
    ns:Print((L["FRAME_PICKER_MSG_SELECTED"]):format(selectedName))

    if ns.UI then
        ns.UI:Show()
    end
end

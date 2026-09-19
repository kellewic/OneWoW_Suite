local _, ns = ...

-- Metadata table lives in module.lua (loaded first); grab it + this module's locale
-- view here. Capture into file-locals at load -- never read Current() at runtime.
local AFKPanelModule, L = ns.ModuleRegistry:Current()
if not AFKPanelModule then return end

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local math = math

local CAMERA_SPEED = 0.035
local DOCK_PAD = 16
local CARD_GAP = 8
local HERE_H = 120
local MODEL_GAP = 500
local MODEL_INSET = 8
-- Distance 1 fills a gap-sized PlayerModel. Higher values shrink the figure
-- (the old 3.0 was for a 2x-screen widget).
local MODEL_CAM_DISTANCE = 0.9
local MODEL_LEVEL = 1
local CHROME_LEVEL = 10
local COL_MIN = 320
local IDLE_KINDS = { "session", "mounts", "pets", "toys", "tip" }
-- Must match #IDLE_TIP_KEYS in OneWoW StatusCards.
local IDLE_TIP_COUNT = 4

-- Intentional cinematic palette; not tied to suite theme.
local PALETTE = {
    BAR_DARK_BG     = { 0.05, 0.05, 0.05, 0.95 },
    BAR_GOLD_BORDER = { 0.8, 0.6, 0.2, 1 },
}

local backdrop = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 16,
    edgeSize = 16,
    insets   = {left = 4, right = 4, top = 4, bottom = 4},
}

local ignoreKeys = {
    LALT   = true,
    LSHIFT = true,
    RSHIFT = true,
}

local printKeys = {
    PRINTSCREEN = true,
}

if IsMacClient() then
    printKeys[KEY_PRINTSCREEN_MAC or "PRINT"] = true
end

local function CreateTopBar(parent)
    local topBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    topBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    topBar:SetHeight(60)
    topBar:SetFrameLevel(CHROME_LEVEL)
    topBar:SetBackdrop(backdrop)
    topBar:SetBackdropColor(unpack(PALETTE.BAR_DARK_BG))
    topBar:SetBackdropBorderColor(unpack(PALETTE.BAR_GOLD_BORDER))

    local topText = OneWoW_GUI:CreateFS(topBar, 18)
    topText:SetPoint("CENTER", topBar, "CENTER", 0, 0)
    topText:SetText(L["AFKPANEL_MODE_TITLE"])
    topText:SetTextColor(unpack(PALETTE.BAR_GOLD_BORDER))

    return topBar
end

function AFKPanelModule:ApplyDockBackground()
    local parent = self._bottomPanel
    if ns.ModuleRegistry:GetToggleValue("afkpanel", "show_dock_bg") then
        parent:SetBackdrop(backdrop)
        parent:SetBackdropColor(unpack(PALETTE.BAR_DARK_BG))
        parent:SetBackdropBorderColor(unpack(PALETTE.BAR_GOLD_BORDER))
    else
        parent:SetBackdrop(nil)
    end
end

local function DockMetrics()
    local inner = UIParent:GetWidth() - 2 * DOCK_PAD
    local minPair = COL_MIN * 2
    if inner < minPair + CARD_GAP then
        local colW = math.max(200, math.floor((inner - CARD_GAP) / 2))
        return colW, inner - 2 * colW
    end
    local gap = MODEL_GAP
    if inner < minPair + gap then
        gap = inner - minPair
    end
    return math.floor((inner - gap) / 2), gap
end

local function ColumnWidth()
    local colW = DockMetrics()
    return colW
end

local function ApplyModelCamera(model)
    model:SetCamDistanceScale(MODEL_CAM_DISTANCE)
    model:SetFacing(6)
end

function AFKPanelModule:ApplyCardWidths()
    local w = ColumnWidth()
    local cards = { self._youPanel, self._herePanel, self._infoPanel }
    for i = 1, #cards do
        local panel = cards[i]
        panel:SetWidth(w)
        panel._width = w
    end
end

function AFKPanelModule:PickIdleLine()
    self._idleKind = IDLE_KINDS[math.random(#IDLE_KINDS)]
    if self._idleKind == "tip" then
        self._idleTipIndex = math.random(IDLE_TIP_COUNT)
    else
        self._idleTipIndex = nil
    end
end

function AFKPanelModule:SetupFrames()
    if self._afkFrame then
        return
    end

    local afkFrame = CreateFrame("Frame", "OneWoW_QoL_AFKFrame")
    afkFrame:SetFrameLevel(1)
    afkFrame:SetScale(UIParent:GetEffectiveScale())
    afkFrame:SetAllPoints(UIParent)
    afkFrame:EnableKeyboard(true)
    afkFrame:SetScript("OnKeyDown", function(_, key)
        AFKPanelModule:OnKeyDown(key)
    end)
    afkFrame:SetScript("OnSizeChanged", function()
        AFKPanelModule:OnDisplaySizeChanged()
    end)
    afkFrame:Hide()
    self._afkFrame = afkFrame

    self._topBar = CreateTopBar(afkFrame)

    local bottomPanel = CreateFrame("Frame", nil, afkFrame, "BackdropTemplate")
    bottomPanel:SetFrameLevel(CHROME_LEVEL)
    bottomPanel:SetPoint("BOTTOMLEFT", afkFrame, "BOTTOMLEFT", 0, 0)
    bottomPanel:SetPoint("BOTTOMRIGHT", afkFrame, "BOTTOMRIGHT", 0, 0)
    bottomPanel:SetHeight(HERE_H + 2 * DOCK_PAD)
    self._bottomPanel = bottomPanel
    self:ApplyDockBackground()
    OneWoW_GUI:RegisterFontRoot(bottomPanel)

    -- PlayerModel paints its 3D mesh in the model frame's rectangle. Size it
    -- to the dock's center gap (not 2x the screen) so the character cannot
    -- cover the cards. Clip + a lower frame level keep any overflow behind chrome.
    local modelHolder = CreateFrame("Frame", nil, afkFrame)
    modelHolder:SetFrameLevel(MODEL_LEVEL)
    modelHolder:SetClipsChildren(true)
    modelHolder:EnableMouse(false)
    self._modelHolder = modelHolder

    local model = CreateFrame("PlayerModel", "OneWoW_QoL_AFKPlayerModel", modelHolder)
    model:SetFrameLevel(MODEL_LEVEL)
    model:EnableMouse(false)
    ApplyModelCamera(model)
    self._model = model

    local colW = ColumnWidth()
    self._youPanel = OneWoW.StatusCards:CreateYou(bottomPanel, {
        name = "OneWoWAFKYou",
        width = colW,
        interactive = false,
        mail = true,
        durability = true,
        vault = true,
        cache = true,
        endeavors = true,
        timer = true,
    })
    self._youPanel:SetPoint("BOTTOMLEFT", bottomPanel, "BOTTOMLEFT", DOCK_PAD, DOCK_PAD)

    self._herePanel = OneWoW.StatusCards:CreateHere(bottomPanel, {
        name = "OneWoWAFKHere",
        width = colW,
        interactive = false,
        collections = false,
        zoneNotes = false,
        fixedHeight = HERE_H,
    })
    self._infoPanel = OneWoW.StatusCards:CreateInfo(bottomPanel, {
        name = "OneWoWAFKInfo",
        width = colW,
    })
    self:LayoutDock()
end

function AFKPanelModule:CameraSpin(status)
    if status and ns.ModuleRegistry:GetToggleValue("afkpanel", "camera_spin") then
        MoveViewLeftStart(CAMERA_SPEED)
    else
        MoveViewLeftStop()
    end
end

function AFKPanelModule:LayoutDock()
    local parent = self._bottomPanel
    local youH = self._youPanel:GetHeight()
    local rightH = self._herePanel:GetHeight() + CARD_GAP + self._infoPanel:GetHeight()
    local innerH = math.max(youH, rightH)
    parent:SetHeight(innerH + 2 * DOCK_PAD)

    -- Character keeps its content minimum, then stretches so a taller
    -- Zone+Info stack does not leave an empty band above it in the dock.
    self._youPanel:ClearAllPoints()
    self._youPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", DOCK_PAD, DOCK_PAD)
    self._youPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", DOCK_PAD, -DOCK_PAD)

    self._infoPanel:ClearAllPoints()
    self._infoPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -DOCK_PAD, DOCK_PAD)

    self._herePanel:ClearAllPoints()
    self._herePanel:SetPoint("BOTTOMRIGHT", self._infoPanel, "TOPRIGHT", 0, CARD_GAP)
    self:LayoutModel()
end

function AFKPanelModule:LayoutModel()
    local holder = self._modelHolder
    local model = self._model
    if not holder or not model or not self._topBar or not self._bottomPanel then
        return
    end
    if not self._youPanel or not self._infoPanel then
        return
    end
    holder:ClearAllPoints()
    holder:SetPoint("TOP", self._topBar, "BOTTOM", 0, 0)
    holder:SetPoint("BOTTOM", self._bottomPanel, "TOP", 0, 0)
    holder:SetPoint("LEFT", self._youPanel, "RIGHT", MODEL_INSET, 0)
    holder:SetPoint("RIGHT", self._infoPanel, "LEFT", -MODEL_INSET, 0)
    model:ClearAllPoints()
    model:SetAllPoints(holder)
end

function AFKPanelModule:OnDisplaySizeChanged()
    if self._sizeQueued or not self._infoPanel then
        return
    end
    self._sizeQueued = true
    C_Timer.After(0, function()
        AFKPanelModule._sizeQueued = false
        if not AFKPanelModule._infoPanel then
            return
        end
        if AFKPanelModule.isAFK then
            AFKPanelModule:RefreshCards()
        else
            AFKPanelModule:ApplyCardWidths()
            AFKPanelModule:LayoutDock()
        end
    end)
end

function AFKPanelModule:RefreshCards()
    self:ApplyCardWidths()
    OneWoW.StatusCards:RefreshYou(self._youPanel, OneWoW.StatusCards:CollectYou({
        vault = true,
        cache = true,
        endeavors = true,
        requestEndeavors = true,
    }))
    OneWoW.StatusCards:SetYouTimer(self._youPanel, 0)
    OneWoW.StatusCards:RefreshHere(self._herePanel, OneWoW.StatusCards:CollectHere())
    OneWoW.StatusCards:RefreshInfo(self._infoPanel, OneWoW.StatusCards:CollectInfo({
        idleKind = self._idleKind,
        idleTipIndex = self._idleTipIndex,
    }))
    self:LayoutDock()
end

function AFKPanelModule:SetAFK(status)
    if status then
        self:CameraSpin(true)
        CloseAllWindows()

        if not self._idleKind then
            self:PickIdleLine()
        end

        self._afkFrame:Show()
        OneWoW.UIParent:Hide()
        self:RefreshCards()

        local model = self._model
        model.curAnimation = "wave"
        model.startTime    = GetTime()
        model.duration     = 2.3
        model.isIdle       = nil
        model.idleDuration = 40
        model:SetUnit("player")
        ApplyModelCamera(model)
        model:SetAnimation(67)
        model:SetScript("OnUpdate", function(myself)
            AFKPanelModule:Model_OnUpdate(myself)
        end)

        if self._timer then
            self._timer:Cancel()
            self._timer = nil
        end
        self._startTime = GetTime()
        self._timer = C_Timer.NewTicker(1, function()
            OneWoW.StatusCards:SetYouTimer(self._youPanel, GetTime() - self._startTime)
        end)

        self.isAFK = true

    elseif self.isAFK then
        OneWoW.UIParent:Restore()
        self._afkFrame:Hide()

        self:CameraSpin(false)

        if self._model then
            self._model:SetScript("OnUpdate", nil)
        end

        if self._timer then
            self._timer:Cancel()
            self._timer = nil
        end
        if self._animTimer then
            self._animTimer:Cancel()
            self._animTimer = nil
        end

        OneWoW.StatusCards:SetYouTimer(self._youPanel, 0)
        self._idleKind = nil
        self._idleTipIndex = nil
        self.isAFK = false
    end
end

function AFKPanelModule:OnKeyDown(key)
    if ignoreKeys[key] then
        return
    end

    if printKeys[key] then
        Screenshot()
    elseif self.isAFK then
        self:SetAFK(false)
        C_Timer.After(60, function()
            if AFKPanelModule._eventFrame then
                AFKPanelModule:CheckAFK()
            end
        end)
    end
end

function AFKPanelModule:CheckAFK()
    if OneWoW.Restriction.IsInCombat() then
        return
    end
    if CinematicFrame and CinematicFrame:IsShown() then
        return
    end
    if MovieFrame and MovieFrame:IsShown() then
        return
    end
    if UnitCastingInfo("player") then
        return
    end
    C_Timer.After(0, function()
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            return
        end
        local isPetBattle = C_PetBattles.IsInBattle()
        self:SetAFK(UnitIsAFK("player") and not isPetBattle)
    end)
end

function AFKPanelModule:LoopAnimations()
    local model = self._model
    if not model then
        return
    end
    if model.curAnimation == "wave" then
        model:SetAnimation(69)
        model.curAnimation = "dance"
        model.startTime    = GetTime()
        model.duration     = 300
        model.isIdle       = false
        model.idleDuration = 120
    end
end

function AFKPanelModule:Model_OnUpdate(model)
    if not model.isIdle then
        local timePassed = GetTime() - model.startTime
        if timePassed > model.duration then
            model:SetAnimation(0)
            model.isIdle = true

            self._animTimer = C_Timer.After(model.idleDuration, function()
                AFKPanelModule:LoopAnimations()
            end)
        end
    end
end

function AFKPanelModule:OnEnable()
    self:SetupFrames()

    self._origAutoClearAFK = GetCVar("autoClearAFK")
    SetCVar("autoClearAFK", 1)

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_AFKPanelEvents")
        self._eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self._eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
        self._eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
        self._eventFrame:SetScript("OnEvent", function(_, event, arg1)
            AFKPanelModule:OnEvent(event, arg1)
        end)
    end
end

function AFKPanelModule:OnEvent(event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        self._eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return
    elseif event == "UPDATE_BATTLEFIELD_STATUS" or event == "PLAYER_REGEN_DISABLED" or event == "LFG_PROPOSAL_SHOW" then
        if event ~= "UPDATE_BATTLEFIELD_STATUS" or (GetBattlefieldStatus(arg1) == "confirm") then
            self:SetAFK(false)
        end
        if event == "PLAYER_REGEN_DISABLED" then
            self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end

    if event == "PLAYER_FLAGS_CHANGED" and arg1 ~= "player" then
        return
    end
    if OneWoW.Restriction.IsInCombat() then
        return
    end
    if CinematicFrame and CinematicFrame:IsShown() then
        return
    end
    if MovieFrame and MovieFrame:IsShown() then
        return
    end

    if UnitCastingInfo("player") then
        C_Timer.After(30, function()
            AFKPanelModule:OnEvent("PLAYER_FLAGS_CHANGED", "player")
        end)
        return
    end

    C_Timer.After(0, function()
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            return
        end
        local isPetBattle = C_PetBattles.IsInBattle()
        self:SetAFK(UnitIsAFK("player") and not isPetBattle)
    end)
end

function AFKPanelModule:OnDisable()
    if self.isAFK then
        self:SetAFK(false)
    end
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    if self._origAutoClearAFK then
        SetCVar("autoClearAFK", self._origAutoClearAFK)
    end
end

function AFKPanelModule:OnToggle(toggleId, value)
    if toggleId == "camera_spin" then
        if self.isAFK then
            self:CameraSpin(value)
        end
    elseif toggleId == "show_dock_bg" then
        if self._bottomPanel then
            self:ApplyDockBackground()
        end
    end
end

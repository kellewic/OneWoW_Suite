local _, ns = ...

local PinSupport = {}
ns.PinSupport = PinSupport

local pinTooltip = CreateFrame("GameTooltip", "OneWoW_NotesPinTooltip", UIParent, "GameTooltipTemplate")

local deferredPins = {}
local deferredGeometrySaves = {}
local worldMapHooked = false

function PinSupport.IsLayoutBlocked()
    return OneWoW.Restriction.IsProtectedActionBlocked()
end

function PinSupport.ShowTooltip(owner, anchor, title, body)
    pinTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    pinTooltip:ClearLines()
    pinTooltip:SetText(title, 1, 1, 1)
    if body then
        pinTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
    end
    pinTooltip:Show()
end

function PinSupport.HideTooltip()
    pinTooltip:Hide()
end

PinSupport.SCALE_MIN     = 50
PinSupport.SCALE_MAX     = 200
PinSupport.SCALE_STEP    = 5
PinSupport.SCALE_DEFAULT = 100

--- Clamp a pinned-window scale percent to the supported range.
---@param percent number|nil
---@return number
function PinSupport.ClampScalePercent(percent)
    local n = tonumber(percent)
    if not n then n = PinSupport.SCALE_DEFAULT end
    if n < PinSupport.SCALE_MIN then return PinSupport.SCALE_MIN end
    if n > PinSupport.SCALE_MAX then return PinSupport.SCALE_MAX end
    return n
end

--- Screen size in the frame's local units (UIParent size / frame:GetScale).
---@param frame Frame
---@return number width
---@return number height
function PinSupport.ScreenSizeInFrameUnits(frame)
    local scale = frame:GetScale()
    if scale <= 0 then scale = 1 end
    return GetScreenWidth() / scale, GetScreenHeight() / scale
end

--- Apply resize max from screen size in the pin's local units.
---@param frame Frame
---@param minW number
---@param minH number
function PinSupport.SetPinResizeBounds(frame, minW, minH)
    local sw, sh = PinSupport.ScreenSizeInFrameUnits(frame)
    frame:SetResizeBounds(minW, minH, sw, sh)
end

--- Apply the saved global scale to one pin.
---@param frame Frame
function PinSupport.ApplyPinScale(frame)
    frame:SetScale(PinSupport.ClampScalePercent(ns.db.global.pinnedScale) / 100)
end

--- Apply the saved global scale to every live note and zone pin.
function PinSupport.ApplyAllPinScales()
    local scale = PinSupport.ClampScalePercent(ns.db.global.pinnedScale) / 100
    if ns.notePins then
        for _, pin in pairs(ns.notePins) do
            pin:SetScale(scale)
            pin:RefreshLayout()
        end
    end
    if ns.zonePins then
        for _, pin in pairs(ns.zonePins) do
            pin:SetScale(scale)
            pin:RefreshLayout()
        end
    end
    if ns.WayPinsCompanion and ns.WayPinsCompanion.ApplyScale then
        ns.WayPinsCompanion:ApplyScale()
    end
end

function PinSupport.CachePinSize(pin)
    if PinSupport.IsLayoutBlocked() then return end
    pin._cachedWidth = pin:GetWidth()
    pin._cachedHeight = pin:GetHeight()
end

function PinSupport.GetPinWidth(pin, fallback)
    if PinSupport.IsLayoutBlocked() then
        return pin._cachedWidth or fallback or 300
    end
    local w = pin:GetWidth()
    pin._cachedWidth = w
    return w
end

function PinSupport.GetPinHeight(pin, fallback)
    if PinSupport.IsLayoutBlocked() then
        return pin._cachedHeight or fallback or 400
    end
    local h = pin:GetHeight()
    pin._cachedHeight = h
    return h
end

function PinSupport.GetFrameHeight(frame, fallback)
    if PinSupport.IsLayoutBlocked() then
        return fallback or 20
    end
    return frame:GetHeight()
end

function PinSupport.GetScrollWidth(scrollFrame, fallback, cacheKey)
    if PinSupport.IsLayoutBlocked() then
        return scrollFrame[cacheKey] or fallback or 280
    end
    local w = scrollFrame:GetWidth() or fallback or 280
    scrollFrame[cacheKey] = w
    return w
end

function PinSupport.RegisterDeferredPin(pin)
    deferredPins[pin] = true
    PinSupport.EnsureWorldMapHook()
    -- Recover when the restriction lifts, not only on WorldMapFrame:OnHide.
    OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_Notes.PinSupport", PinSupport.FlushDeferred)
end

function PinSupport.DeferGeometrySave(pin, fn)
    deferredGeometrySaves[pin] = fn
    PinSupport.EnsureWorldMapHook()
    -- Recover when the restriction lifts, not only on WorldMapFrame:OnHide.
    OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_Notes.PinSupport", PinSupport.FlushDeferred)
end

function PinSupport.FlushDeferred()
    PinSupport.HideTooltip()

    for pin, fn in pairs(deferredGeometrySaves) do
        if pin and fn then
            fn()
        end
    end
    wipe(deferredGeometrySaves)

    for pin in pairs(deferredPins) do
        if pin and pin:IsShown() and pin.RefreshLayout then
            pin:RefreshLayout()
        end
    end
    wipe(deferredPins)
end

-- Lays out a pin's hover-control panel and sizes it to fit. Full-width controls
-- (e.g. the alpha slider) take their own row; the rest flow left-to-right and
-- wrap onto a new row only when the next control's measured width won't fit.
-- All sizes are read live, so the panel packs tightly at small fonts and stays
-- overlap-free at large fonts (fixed offsets used to overlap or waste space).
--
-- items: array of { control = frame, fill = bool }
--   fill = span both edges on its own row; otherwise the control flows.
function PinSupport.LayoutHoverPanel(panel, items)
    local padX, padY, colGap, rowGap = 8, 8, 12, 6
    local panelW = panel:GetWidth()
    if not panelW or panelW < 1 then panelW = 300 end
    local avail = panelW - padX * 2

    local function measure(c)
        local w = c.GetMeasuredWidth  and c:GetMeasuredWidth()  or c:GetWidth()
        local h = c.GetMeasuredHeight and c:GetMeasuredHeight() or c:GetHeight()
        if not w or w < 1 then w = 20 end
        if not h or h < 1 then h = 20 end
        return w, h
    end

    local y = -padY
    local i, n = 1, #items
    while i <= n do
        local item = items[i]
        local c = item.control
        if item.fill then
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT",  panel, "TOPLEFT",   padX, y)
            c:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padX, y)
            local _, h = measure(c)
            y = y - h - rowGap
            i = i + 1
        else
            local x, rowH, placed = padX, 0, 0
            while i <= n and not items[i].fill do
                local cc = items[i].control
                local w, h = measure(cc)
                if placed > 0 and (x + w) > (padX + avail) then break end
                cc:ClearAllPoints()
                cc:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
                x = x + w + colGap
                if h > rowH then rowH = h end
                placed = placed + 1
                i = i + 1
            end
            y = y - rowH - rowGap
        end
    end

    local total = (-y) - rowGap + padY
    panel:SetHeight(math.max(total, 36))
end

local BACKDROP_SOLID = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local BACKDROP_FADE = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

--- Same solid/fade switch for pinned notes, hover bars, and the pins list.
---@param frame Frame
---@param color number[]
---@param alpha number
---@param borderColor number[]|nil
function PinSupport.ApplyOpacityBackdrop(frame, color, alpha, borderColor)
    if not frame then return end
    if alpha >= 1.0 then
        frame:SetBackdrop(BACKDROP_SOLID)
        frame:SetBackdropColor(color[1], color[2], color[3], 1.0)
    else
        frame:SetBackdrop(BACKDROP_FADE)
        frame:SetBackdropColor(color[1], color[2], color[3], alpha)
    end
    if borderColor then
        frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
    end
end

-- Character / bank / professions sit on MEDIUM. HIGH (and MEDIUM at
-- Notes window-stack levels) paints over them. Drop overlays to LOW
-- while those panels are open; restore MEDIUM when they close.
local COVER_PANEL_NAMES = {
    CharacterFrame = true,
    BankFrame = true,
    GuildBankFrame = true,
    ProfessionsFrame = true,
    ProfessionsBookFrame = true,
}

local OVERLAY_STRATA = "MEDIUM"
local COVERED_STRATA = "LOW"
local coverHooksReady = false
local hookedCoverFrames = {}

local function WatchCoverFrame(frame)
    if not frame or hookedCoverFrames[frame] then
        return
    end
    hookedCoverFrames[frame] = true
    frame:HookScript("OnShow", PinSupport.ApplyAllOverlayStrata)
    frame:HookScript("OnHide", PinSupport.ApplyAllOverlayStrata)
end

function PinSupport.CoveringGamePanelShown()
    for name in pairs(COVER_PANEL_NAMES) do
        local panel = _G[name]
        if panel and panel:IsShown() then
            return true
        end
    end
    return false
end

function PinSupport.OverlayStrata()
    if PinSupport.CoveringGamePanelShown() then
        return COVERED_STRATA
    end
    return OVERLAY_STRATA
end

function PinSupport.ApplyOverlayStrata(frame)
    if not frame then return end
    frame:SetFrameStrata(PinSupport.OverlayStrata())
end

function PinSupport.ApplyAllOverlayStrata()
    local strata = PinSupport.OverlayStrata()
    if ns.zonePins then
        for _, pin in pairs(ns.zonePins) do
            if pin then
                pin:SetFrameStrata(strata)
            end
        end
    end
    if ns.WayPinsCompanion and ns.WayPinsCompanion.ApplyOverlayStrata then
        ns.WayPinsCompanion:ApplyOverlayStrata(strata)
    end
end

local function WatchNamedCoverFrames()
    for name in pairs(COVER_PANEL_NAMES) do
        WatchCoverFrame(_G[name])
    end
end

local function EnsureCoverPanelHooks()
    if coverHooksReady then return end
    coverHooksReady = true
    local function OnPanelToggle(frame)
        if type(frame) ~= "table" or not frame.GetName then
            return
        end
        local name = frame:GetName()
        if name and COVER_PANEL_NAMES[name] then
            WatchCoverFrame(frame)
            PinSupport.ApplyAllOverlayStrata()
        end
    end
    hooksecurefunc("ShowUIPanel", OnPanelToggle)
    hooksecurefunc("HideUIPanel", OnPanelToggle)
    WatchNamedCoverFrames()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", WatchNamedCoverFrames)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsBook", WatchNamedCoverFrames)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_GuildBankUI", WatchNamedCoverFrames)
end

EnsureCoverPanelHooks()

function PinSupport.EnsureWorldMapHook()
    if worldMapHooked then return end
    worldMapHooked = true

    local function HookWorldMap()
        if not WorldMapFrame then return end
        WorldMapFrame:HookScript("OnShow", PinSupport.HideTooltip)
        WorldMapFrame:HookScript("OnHide", PinSupport.FlushDeferred)
    end

    if WorldMapFrame then
        HookWorldMap()
    else
        C_Timer.After(0, HookWorldMap)
    end
end

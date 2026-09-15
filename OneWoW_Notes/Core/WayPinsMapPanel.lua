local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Visual = ns.WayPinsVisual

local ipairs, wipe, tinsert = ipairs, wipe, tinsert
local IsControlKeyDown = IsControlKeyDown

-- ============================================================================
-- WayPinsMapPanel
-- ============================================================================
-- OneWay Pins live at the bottom of the world map Map Legend (a new category
-- on the legend scroll). Hover a row to glow that pin on the canvas. If the
-- legend scroll is not there, the same list docks to the right of the quest /
-- events / legend tabs so those tabs stay clickable.
-- ============================================================================

local Panel = {}
ns.WayPinsMapPanel = Panel

local ROW_HEIGHT = 28
local PANEL_WIDTH = 260
local LEGEND_LAYOUT_INDEX = 50
local FALLBACK_TAB_GAP = 4

local category
local fallback
local rowPool = {}
local activeRows = {}
local initialized = false
local displayModeHooked = false

local function BrandTheme()
    return OneWoW_GUI:GetSetting("minimap.theme")
end

local function GetLegendScrollChild()
    local legend = QuestMapFrame.MapLegend
    local scroll = legend and legend.ScrollFrame
    return scroll and scroll.ScrollChild, legend
end

local function RelayoutLegend()
    local scrollChild, legend = GetLegendScrollChild()
    if scrollChild then
        scrollChild:Layout()
    end
    if legend and legend.ScrollFrame then
        legend.ScrollFrame:UpdateScrollChildRect()
    end
end

local function EnsureCategory()
    if category then
        return category
    end
    local scrollChild = GetLegendScrollChild()
    if not scrollChild then
        return nil
    end
    category = CreateFrame("Frame", "OneWoW_WayPinsLegendCategory", scrollChild, "MapLegendCategoryTemplate")
    category.layoutIndex = LEGEND_LAYOUT_INDEX
    category:SetWidth(262)
    category.TitleText:SetText(L["TAB_WAYPINS"])

    local empty = OneWoW_GUI:CreateFS(category, 11)
    empty:SetPoint("TOPLEFT", 0, -4)
    empty:SetPoint("TOPRIGHT", 0, -4)
    empty:SetJustifyH("LEFT")
    empty:SetWordWrap(true)
    empty:SetText(L["WAYPINS_MAP_PANEL_EMPTY"])
    empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    category.empty = empty

    OneWoW_GUI:RegisterFontRoot(category, function()
        Panel:RefreshRows()
    end)
    return category
end

local function EnsureFallback()
    if fallback then
        return fallback
    end
    fallback = CreateFrame("Frame", "OneWoW_WayPinsMapPanel", QuestMapFrame, "BackdropTemplate")
    fallback:SetWidth(PANEL_WIDTH)
    fallback:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    fallback:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    fallback:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    fallback:EnableMouse(true)
    fallback:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(fallback, {
        title = L["TAB_WAYPINS"],
        showBrand = true,
        factionTheme = BrandTheme(),
        onClose = function()
            ns.db.global.waypinShowMapPanel = false
            Panel:Hide()
        end,
    })
    fallback.titleBar = titleBar

    OneWoW_GUI:RegisterFontRoot(fallback, function()
        Panel:RefreshRows()
    end)

    local scroll, child = OneWoW_GUI:CreateScrollFrame(fallback, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", fallback, "BOTTOMRIGHT", -8, 8)
    fallback.scroll = scroll
    fallback.child = child

    local empty = OneWoW_GUI:CreateFS(fallback, 11)
    empty:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 12, -16)
    empty:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -12, -16)
    empty:SetJustifyH("LEFT")
    empty:SetWordWrap(true)
    empty:SetText(L["WAYPINS_MAP_PANEL_EMPTY"])
    empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    fallback.empty = empty

    return fallback
end

local function AnchorFallback()
    local tab = QuestMapFrame.MapLegendTab
    fallback:SetParent(QuestMapFrame)
    fallback:ClearAllPoints()
    fallback:SetPoint("TOPLEFT", tab, "TOPRIGHT", FALLBACK_TAB_GAP, 0)
    fallback:SetPoint("BOTTOM", QuestMapFrame, "BOTTOM", 0, 0)
    fallback:SetWidth(PANEL_WIDTH)
    fallback:SetFrameStrata(QuestMapFrame:GetFrameStrata())
    fallback:SetFrameLevel(QuestMapFrame:GetFrameLevel() + 5)
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

    local preview = CreateFrame("Button", nil, row)
    preview:SetSize(22, 22)
    preview:SetPoint("LEFT", 2, 0)
    preview:EnableMouse(false)
    Visual.Attach(preview)
    row.preview = preview

    local label = OneWoW_GUI:CreateFS(row, 12)
    label:SetPoint("LEFT", preview, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    row:SetScript("OnEnter", function(myself)
        myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        local pin = myself.pinData
        if pin then
            ns.WayPinsMap:SetHoverPin(pin.id)
            GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
            ns.WayPinsTooltip.Fill(GameTooltip, pin, L["WAYPINS_LEGEND_TT"])
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(myself)
        ns.WayPinsMap:ClearHoverPin()
        Panel:PaintRow(myself)
        GameTooltip:Hide()
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
        WorldMapFrame:SetMapID(pin.mapID)
        ns.WayPinsMap:TrackPin(pin)
    end)

    tinsert(rowPool, row)
    return row
end

function Panel:PaintRow(row)
    if not row.pinData then return end
    local tracked = ns.WayPinsMap and ns.WayPinsMap:GetLivePinID() == row.pinData.id
    if tracked then
        row.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
    else
        row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    Visual.Apply(row.preview, row.pinData, { size = 22, tracked = tracked, animate = false })
end

local function ReleaseRows()
    for _, row in ipairs(activeRows) do
        row._inUse = false
        row:Hide()
    end
    wipe(activeRows)
end

function Panel:RefreshRows()
    local usingLegend = category and category:IsShown()
    local usingFallback = fallback and fallback:IsShown()
    if not usingLegend and not usingFallback then
        return
    end

    ReleaseRows()

    local parent = usingLegend and category or fallback.child
    local mapID = WorldMapFrame:GetMapID()
    local pins = ns.WayPins:GetForMap(mapID, "world")
    local y = usingLegend and 4 or 0
    for _, pin in ipairs(pins) do
        local row = AcquireRow(parent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
        row.pinData = pin
        row._inUse = true
        row.label:SetText(pin.title or L["WAYPINS_UNTITLED"])
        self:PaintRow(row)
        row:Show()
        tinsert(activeRows, row)
        y = y + ROW_HEIGHT
    end

    if usingLegend then
        category.TitleText:SetText(L["TAB_WAYPINS"])
        category.empty:SetShown(#pins == 0)
        category:SetHeight(math.max(y + 8, 32))
        RelayoutLegend()
    else
        fallback.child:SetHeight(math.max(y, 1))
        fallback.empty:SetShown(#pins == 0)
        if fallback.titleBar and fallback.titleBar._titleText then
            fallback.titleBar._titleText:SetText(L["TAB_WAYPINS"])
        end
    end
end

function Panel:ApplyTheme()
    if fallback then
        fallback:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        fallback:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        if fallback.titleBar and fallback.titleBar.brandIcon then
            fallback.titleBar.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(BrandTheme()))
        end
    end
    if category and category.empty then
        category.empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    self:RefreshRows()
end

function Panel:Hide()
    ns.WayPinsMap:ClearHoverPin()
    if category then
        category:Hide()
        RelayoutLegend()
    end
    if fallback then
        fallback:Hide()
    end
end

function Panel:Sync()
    if not WorldMapFrame:IsShown() then
        self:Hide()
        return
    end
    if not ns.WayPinsVisual.Enabled() or ns.db.global.waypinShowMapPanel == false then
        self:Hide()
        return
    end

    local scrollChild = GetLegendScrollChild()
    if scrollChild then
        if fallback then
            fallback:Hide()
        end
        EnsureCategory()
        if category:GetParent() ~= scrollChild then
            category:SetParent(scrollChild)
        end
        category.layoutIndex = LEGEND_LAYOUT_INDEX
        category:Show()
        self:RefreshRows()
        return
    end

    if category then
        category:Hide()
    end
    EnsureFallback()
    AnchorFallback()
    fallback:Show()
    self:RefreshRows()
end

function Panel:Initialize()
    if initialized then return end
    initialized = true

    if not displayModeHooked then
        displayModeHooked = true
        EventRegistry:RegisterCallback("QuestLog.SetDisplayMode", function()
            Panel:Sync()
        end)
    end

    OneWoW.Locale:OnApply(function()
        Panel:RefreshRows()
    end)

    if WorldMapFrame:IsShown() then
        self:Sync()
    end
end

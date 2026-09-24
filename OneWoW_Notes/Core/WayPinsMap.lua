local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local Visual = ns.WayPinsVisual

local ipairs, pairs, next, tinsert = ipairs, pairs, next, tinsert
local abs, sqrt = math.abs, math.sqrt
local C_Timer, C_Minimap = C_Timer, C_Minimap
local GetCVar, GetPlayerFacing, IsControlKeyDown = GetCVar, GetPlayerFacing, IsControlKeyDown
local MenuUtil, GameTooltip, GameTooltip_Hide = MenuUtil, GameTooltip, GameTooltip_Hide
local GetCursorPosition, UIParent = GetCursorPosition, UIParent
local OpenWorldMap, securecallfunction, securecallmethod = OpenWorldMap, securecallfunction, securecallmethod
local CreateFromMixins, Mixin = CreateFromMixins, Mixin
local CreateUnsecuredRegionPoolInstance = CreateUnsecuredRegionPoolInstance
local MapCanvasDataProviderMixin, MapCanvasPinMixin = MapCanvasDataProviderMixin, MapCanvasPinMixin
local Minimap = Minimap

-- ============================================================================
-- WayPinsMap
-- ============================================================================
-- World-map MapCanvas pins + minimap radar. Minimap placement uses world-yard
-- dx/dy from Location.WorldDelta against C_Minimap.GetViewRadius so a landmark
-- stays put while you walk. Out-of-range pins sit on the rim. Clicking a pin
-- sets the suite waypoint (Blizzard or the active arrow provider). Arrival
-- clears that live track only.
-- The map-chrome button parents to GetCanvasContainer and sits under the
-- lowest icon already in that top-right stack.
-- ============================================================================

local WayPinsMap = {}
ns.WayPinsMap = WayPinsMap

local ARRIVE_YARDS = 22
local PERCENT_FMT = "percent"
local WORLD_PIN_TEMPLATE = "OneWoW_WayPinsWorldMapPinTemplate"
local PREVIEW_MINIMAP_KEY = "__preview"

local initialized = false
local livePinID = nil
local soloPinID = nil
local hoverPinID = nil
local arrivalTicker = nil
local mapHooked = false
local worldProvider
local minimapDriver
local minimapDirty = true
local lastMinimapMapID
local minimapActive = {}
local minimapPinPool = {}

local function MarkMinimapDirty()
    minimapDirty = true
end
local mapButton
local placingPin = false
local placeCatcher
local placeGhost

-- Top-right map-chrome stack: first slot when empty, then under the lowest icon.
local MAP_BTN_X = -1
local MAP_BTN_FIRST_Y = -2
local MAP_BTN_GAP = -2
local MAP_BTN_MIN = 20
local MAP_BTN_MAX = 48
local MAP_BTN_EDGE = 8
local MAP_BTN_STACK_DEPTH = 280

local function PinVisible(data)
    if soloPinID and data.id ~= soloPinID then
        return false
    end
    return true
end

local previewDraft
local returnConfirm
local pendingReturnId
local deleteConfirm
local pendingDeleteId

local function PinsForMap(mapID, surface)
    local pins = ns.WayPins:GetForMap(mapID, surface)
    if not previewDraft or tonumber(previewDraft.mapID) ~= tonumber(mapID) then
        return pins
    end
    if previewDraft.id then
        for i, data in ipairs(pins) do
            if data.id == previewDraft.id then
                pins[i] = previewDraft
                return pins
            end
        end
    end
    tinsert(pins, previewDraft)
    return pins
end

--- Overlay the pin editor draft onto the maps without writing SavedVariables.
---@param draft table|nil
function WayPinsMap:SetPreviewDraft(draft)
    previewDraft = draft
    MarkMinimapDirty()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPinsMap:ClearPreviewDraft()
    if not previewDraft then return end
    previewDraft = nil
    MarkMinimapDirty()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

---@return table|nil
function WayPinsMap:GetPreviewDraft()
    return previewDraft
end

local function StopArrivalWatch()
    if arrivalTicker then
        arrivalTicker:Cancel()
        arrivalTicker = nil
    end
end

local function ClearLiveWaypoint()
    if not livePinID then
        StopArrivalWatch()
        return
    end
    livePinID = nil
    StopArrivalWatch()
    Location.ClearActiveWaypoint()
    MarkMinimapDirty()
    WayPinsMap:RefreshWorldMap()
    WayPinsMap:UpdateMinimapPins()
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:RefreshRows()
    end
end

local function StartArrivalWatch()
    StopArrivalWatch()
    arrivalTicker = C_Timer.NewTicker(0.4, function()
        if not livePinID then
            StopArrivalWatch()
            return
        end
        if not Location.HasActiveWaypoint() then
            livePinID = nil
            StopArrivalWatch()
            MarkMinimapDirty()
            WayPinsMap:RefreshWorldMap()
            WayPinsMap:UpdateMinimapPins()
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:RefreshRows()
            end
            return
        end
        local dist = Location.GetActiveDistance()
        if dist and dist > 0 and dist < ARRIVE_YARDS then
            ClearLiveWaypoint()
            return
        end
        local pin = ns.WayPins:GetPin(livePinID)
        if not pin then
            ClearLiveWaypoint()
            return
        end
        local mapID, px, py = Location.GetPlayerLocation()
        if mapID and tonumber(pin.mapID) == mapID and px then
            if Location.IsWithinRadius(pin.x, pin.y, px, py, 1.6) then
                ClearLiveWaypoint()
            end
        end
    end)
end

function WayPinsMap:GetLivePinID()
    return livePinID
end

local function WorldPinPaintOpts(data)
    local hover = hoverPinID == data.id
    local size = Visual.WorldSize(data)
    if hover then
        size = size * 1.2
    end
    return {
        size = size,
        tracked = livePinID == data.id or hover,
    }
end

--- Glow / enlarge a world-map pin (Map Legend hover). Nil clears.
---@param pinID string|nil
function WayPinsMap:SetHoverPin(pinID)
    if hoverPinID == pinID then
        return
    end
    hoverPinID = pinID
    if not WorldMapFrame or not WorldMapFrame.pinPools or not WorldMapFrame.pinPools[WORLD_PIN_TEMPLATE] then
        return
    end
    for pin in WorldMapFrame:EnumeratePinsByTemplate(WORLD_PIN_TEMPLATE) do
        local data = pin.pinData
        if data then
            Visual.Apply(pin, data, WorldPinPaintOpts(data))
        end
    end
end

function WayPinsMap:ClearHoverPin()
    self:SetHoverPin(nil)
end

function WayPinsMap:GetSoloPinID()
    return soloPinID
end

function WayPinsMap:ToggleSolo(pinID)
    if soloPinID == pinID then
        soloPinID = nil
    else
        soloPinID = pinID
    end
    self:Refresh()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPinsMap:ClearSolo()
    if not soloPinID then return end
    soloPinID = nil
    self:Refresh()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPinsMap:TrackPin(pin)
    if type(pin) ~= "table" or not pin.mapID then
        return false
    end
    local set = Location.SetWaypoint(pin.mapID, pin.x, pin.y, {
        format = "percent",
        title = pin.title,
    })
    if not set then
        return false
    end
    livePinID = pin.id
    StartArrivalWatch()
    MarkMinimapDirty()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:RefreshRows()
    end
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:RefreshRows()
    end
    return true
end

--- Return a pack pin to My Pins after confirm.
---@param pin table
function WayPinsMap:ConfirmReturnFromPack(pin)
    if type(pin) ~= "table" or not pin.id then return end
    if not ns.WayPinPacks:IsPackPinId(pin.id) then return end
    pendingReturnId = pin.id
    local title = pin.title or L["WAYPINS_UNTITLED"]
    local message = string.format(L["WAYPINS_REMOVE_FROM_PACK_CONFIRM"], title)
    if not returnConfirm then
        returnConfirm = OneWoW_GUI:CreateConfirmDialog({
            name = "OneWoW_NotesReturnWayPinConfirm",
            title = L["WAYPINS_REMOVE_FROM_PACK"],
            message = message,
            buttons = {
                {
                    text = L["WAYPINS_REMOVE_FROM_PACK"],
                    color = { 0.8, 0.2, 0.2 },
                    onClick = function(dlg)
                        dlg:Hide()
                        local pinID = pendingReturnId
                        pendingReturnId = nil
                        if not pinID then
                            return
                        end
                        local newId = ns.WayPinPacks:ReturnPinToPersonal(pinID)
                        if newId and ns.UI and ns.UI.SelectWayPin then
                            ns.UI.SelectWayPin(newId)
                        end
                    end,
                },
                { text = CANCEL, onClick = function(dlg)
                    pendingReturnId = nil
                    dlg:Hide()
                end },
            },
        })
    else
        returnConfirm.titleLabel:SetText(L["WAYPINS_REMOVE_FROM_PACK"])
        returnConfirm.messageLabel:SetText(message)
    end
    returnConfirm.frame:Show()
    returnConfirm.frame:Raise()
end

function WayPinsMap:ConfirmDelete(pin)
    if type(pin) ~= "table" or not pin.id then return end
    pendingDeleteId = pin.id
    local title = pin.title or L["WAYPINS_UNTITLED"]
    local message = string.format(L["POPUP_DELETE_WAYPIN"], title)
    if not deleteConfirm then
        deleteConfirm = OneWoW_GUI:CreateConfirmDialog({
            name = "OneWoW_NotesDeleteWayPinConfirm",
            title = L["DIALOG_CONFIRM_DELETE"],
            message = message,
            buttons = {
                {
                    text = DELETE,
                    color = { 0.8, 0.2, 0.2 },
                    onClick = function(dlg)
                        dlg:Hide()
                        local pinID = pendingDeleteId
                        pendingDeleteId = nil
                        if pinID then
                            ns.WayPins:Remove(pinID)
                        end
                    end,
                },
                { text = CANCEL, onClick = function(dlg)
                    pendingDeleteId = nil
                    dlg:Hide()
                end },
            },
        })
    else
        deleteConfirm.titleLabel:SetText(L["DIALOG_CONFIRM_DELETE"])
        deleteConfirm.messageLabel:SetText(message)
    end
    deleteConfirm.frame:Show()
    deleteConfirm.frame:Raise()
end

--- Open the world map on this pin's zone, switch to Map Legend, and set a live waypoint.
--- Does not hide other pins.
---@param pin table
function WayPinsMap:ShowOnMap(pin)
    if type(pin) ~= "table" or not pin.mapID then return end
    securecallfunction(OpenWorldMap, pin.mapID)
    if WorldMapFrame then
        securecallmethod(WorldMapFrame, "SetMapID", pin.mapID)
    end
    if QuestMapFrame then
        securecallmethod(QuestMapFrame, "SetDisplayMode", QuestLogDisplayMode.MapLegend)
    end
    self:TrackPin(pin)
end

--- Open the create dialog at the player's feet. `packId` adds the pin into that pack.
---@param packId string|nil
function WayPinsMap:AddHere(packId)
    if not Visual.Enabled() then return end
    local mapID, x, y = Location.GetPlayerLocation()
    if not mapID or not x then
        return
    end
    local seed = {
        mapID  = mapID,
        x      = x,
        y      = y,
        source = "manual",
    }
    if packId then
        seed.packId = packId
        seed.usePackLook = true
    end
    ns.UI.OpenWayPinDialog(seed)
end

function WayPinsMap:ShowAddMenu(owner)
    if not Visual.Enabled() then return end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L["TAB_WAYPINS"])
        rootDescription:CreateButton(L["WAYPINS_ADD_HERE"], function()
            WayPinsMap:AddHere()
        end)
        rootDescription:CreateButton(L["WAYPINS_FIND_LOCATION"], function()
            ns.UI.OpenWayPinFindDialog()
        end)
    end)
end

function WayPinsMap:OpenPinTab(pinID)
    if not Visual.Enabled() then return end
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "waypins")
    if pinID and ns.UI.SelectWayPin then
        ns.UI.SelectWayPin(pinID)
    end
end

local function AddSendToPackMenu(rootDescription, pinID)
    local sendSub = rootDescription:CreateButton(L["WAYPINS_SEND_TO_PACK"], function() end)
    sendSub:CreateButton(L["WAYPINS_PACK_NEW"], function()
        ns.UI.OpenWayPinSendToPack(pinID)
    end)
    local skipPackId
    if ns.WayPinPacks:IsPackPinId(pinID) then
        skipPackId = select(1, ns.WayPinPacks:ParseDisplayId(pinID))
    end
    for _, pack in ipairs(ns.WayPinPacks:GetAllPacks()) do
        if pack.id ~= skipPackId then
            local destId = pack.id
            sendSub:CreateButton(pack.name or destId, function()
                ns.WayPinPacks:MovePinToPack(pinID, destId)
                ns.UI.SelectWayPinPack(destId)
            end)
        end
    end
end

---@param owner Frame
---@param data table
---@param opts table|nil
function WayPinsMap:ShowPinMenu(owner, data, opts)
    if not data then return end
    opts = opts or {}
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateButton(L["WAYPINS_MENU_GO"], function()
            WayPinsMap:TrackPin(data)
        end)
        rootDescription:CreateButton(SHOW_MAP, function()
            WayPinsMap:ShowOnMap(data)
        end)
        rootDescription:CreateButton(EDIT, function()
            ns.UI.OpenWayPinDialog(data)
        end)
        if not opts.hideOpenTab then
            rootDescription:CreateButton(L["WAYPINS_OPEN_TAB"], function()
                WayPinsMap:OpenPinTab(data.id)
            end)
        end
        if soloPinID == data.id then
            rootDescription:CreateButton(L["WAYPINS_SHOW_ALL"], function()
                WayPinsMap:ClearSolo()
            end)
        else
            rootDescription:CreateButton(L["WAYPINS_ONLY_THIS"], function()
                WayPinsMap:ToggleSolo(data.id)
            end)
        end
        AddSendToPackMenu(rootDescription, data.id)
        if ns.WayPinPacks:IsPackPinId(data.id) then
            rootDescription:CreateButton(L["WAYPINS_REMOVE_FROM_PACK"], function()
                WayPinsMap:ConfirmReturnFromPack(data)
            end)
        end
        rootDescription:CreateButton(DELETE, function()
            WayPinsMap:ConfirmDelete(data)
        end)
    end)
end

---@param owner Frame
---@param data table
function WayPinsMap:ShowListMenu(owner, data)
    self:ShowPinMenu(owner, data)
end

---@param owner Frame
---@param packId string
function WayPinsMap:ShowPackMenu(owner, packId)
    local pack = ns.WayPinPacks:GetPack(packId)
    if not pack then return end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(pack.name or L["WAYPINS_PACK_BADGE"])
        if pack.enabled ~= false then
            rootDescription:CreateButton(DISABLE, function()
                ns.WayPinPacks:SetEnabled(packId, false)
            end)
        else
            rootDescription:CreateButton(ENABLE, function()
                ns.WayPinPacks:SetEnabled(packId, true)
            end)
        end
        rootDescription:CreateButton(L["WAYPINS_PACK_LOOK"], function()
            ns.UI.OpenWayPinPackLook(packId)
        end)
        rootDescription:CreateButton(L["WAYPINS_ADD_HERE"], function()
            WayPinsMap:AddHere(packId)
        end)
        rootDescription:CreateButton(L["WAYPINS_FIND_LOCATION"], function()
            ns.UI.OpenWayPinFindDialog(packId)
        end)
        rootDescription:CreateButton(L["WAYPINS_EXPORT"], function()
            ns.UI.OpenWayPinPackExport(packId)
        end)
        rootDescription:CreateButton(DELETE, function()
            ns.UI.OpenWayPinPackRemove(packId)
        end)
    end)
end

-- MapCanvas AcquirePin asserts OnEnter/OnLeave are unset, then wires those
-- scripts to OnMouseEnter/OnMouseLeave. Clicks go through OnMouseClickAction.
local WayPinsWorldPinMixin = CreateFromMixins(MapCanvasPinMixin)

function WayPinsWorldPinMixin:OnLoad()
    self:SetIgnoreGlobalPinScale(true)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetNudgeTargetFactor(0)
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self:EnableMouse(true)
    Visual.Attach(self)
end

function WayPinsWorldPinMixin:ShouldMouseButtonBePassthrough()
    -- MapCanvas default passes RightButton through so the map can zoom out.
    return false
end

function WayPinsWorldPinMixin:OnMouseEnter()
    local data = self.pinData
    if not data then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    ns.WayPinsTooltip.Fill(GameTooltip, data, L["WAYPINS_MAP_TT"])
    GameTooltip:Show()
end

function WayPinsWorldPinMixin:OnMouseLeave()
    GameTooltip_Hide()
end

function WayPinsWorldPinMixin:OnMouseClickAction(button)
    local data = self.pinData
    if not data then return end
    if button == "RightButton" then
        WayPinsMap:ShowPinMenu(self, data)
        return
    end
    WayPinsMap:TrackPin(data)
end

function WayPinsWorldPinMixin:OnAcquired(data)
    self.pinData = data
    Visual.Apply(self, data, WorldPinPaintOpts(data))
    self:Show()
end

function WayPinsWorldPinMixin:OnReleased()
    Visual.Hide(self)
    self.pinData = nil
end

local WayPinsDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function WayPinsDataProviderMixin:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(WORLD_PIN_TEMPLATE)
end

function WayPinsDataProviderMixin:RefreshAllData()
    self:RemoveAllData()
    if not Visual.ShowWorld() then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local mapID = self:GetMap():GetMapID()
    if not mapID then return end

    local pins = PinsForMap(mapID, "world")
    for _, data in ipairs(pins) do
        if PinVisible(data) then
            local x = (data.x or 0) / 100
            local y = (data.y or 0) / 100
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local pin = self:GetMap():AcquirePin(WORLD_PIN_TEMPLATE, data)
                pin:SetPosition(x, y)
            end
        end
    end
end

local function EnsureWorldMapProvider()
    if worldProvider or not WorldMapFrame then return end

    local pool = CreateUnsecuredRegionPoolInstance(WORLD_PIN_TEMPLATE)
    pool.parent = WorldMapFrame:GetCanvas()
    pool.createFunc = function()
        local btn = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
        Mixin(btn, WayPinsWorldPinMixin)
        return btn
    end
    pool.resetFunc = function(_, pin)
        pin:Hide()
        pin:ClearAllPoints()
        pin:OnReleased()
        pin.pinTemplate = nil
        pin.owningMap = nil
    end
    pool.creationFunc = pool.createFunc
    pool.resetterFunc = pool.resetFunc
    if not WorldMapFrame.pinPools then
        WorldMapFrame.pinPools = {}
    end
    WorldMapFrame.pinPools[WORLD_PIN_TEMPLATE] = pool

    worldProvider = CreateFromMixins(WayPinsDataProviderMixin)
    WorldMapFrame:AddDataProvider(worldProvider)
end

function WayPinsMap:RefreshWorldMap()
    if worldProvider then
        worldProvider:RefreshAllData()
    end
end

local function AcquireMinimapPin()
    for _, pin in ipairs(minimapPinPool) do
        if not pin._inUse then
            return pin
        end
    end
    local btn = CreateFrame("Button", nil, Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(12)
    btn:EnableMouse(true)
    Visual.Attach(btn)

    btn:SetScript("OnEnter", function(myself)
        local pinData = myself.pinData
        if not pinData then return end
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        ns.WayPinsTooltip.Fill(GameTooltip, pinData)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function(myself)
        if myself.pinData then
            WayPinsMap:TrackPin(myself.pinData)
        end
    end)

    tinsert(minimapPinPool, btn)
    return btn
end

local function ReleaseMinimapPin(pin)
    pin._inUse = false
    pin.pinID = nil
    pin.pinData = nil
    pin._paintKey = nil
    Visual.Hide(pin)
end

local function MinimapPinKey(data)
    return data.id or PREVIEW_MINIMAP_KEY
end

local function SyncMinimapPinSet(mapID)
    for _, pin in pairs(minimapActive) do
        pin._keep = false
    end

    if mapID and Visual.ShowMinimap() then
        local animate = Visual.MinimapAnimate()
        for _, data in ipairs(PinsForMap(mapID, "minimap")) do
            if PinVisible(data) then
                local key = MinimapPinKey(data)
                local pin = minimapActive[key]
                if not pin then
                    pin = AcquireMinimapPin()
                    pin._inUse = true
                    minimapActive[key] = pin
                end
                pin._keep = true
                pin.pinID = key
                pin.pinData = data
                local paintKey = key .. ":" .. tostring(livePinID) .. ":" .. Visual.PaintSignature(data, Visual.MinimapSize(data), animate, livePinID == data.id)
                if pin._paintKey ~= paintKey then
                    Visual.Apply(pin, data, {
                        size = Visual.MinimapSize(data),
                        tracked = livePinID == data.id,
                        animate = animate,
                    })
                    pin._paintKey = paintKey
                end
            end
        end
    end

    for key, pin in pairs(minimapActive) do
        if not pin._keep then
            ReleaseMinimapPin(pin)
            minimapActive[key] = nil
        end
    end
end

--- Keep out-of-range pins on the rim. Square minimaps clamp per-axis; others
--- use a circle. Corner shapes stay circular so this table does not grow.
---@param nx number
---@param ny number
---@return number
---@return number
local function FloatOnMinimapEdge(nx, ny)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local ax, ay = abs(nx), abs(ny)
        local m = ax > ay and ax or ay
        if m > 1 then
            return nx / m, ny / m
        end
        return nx, ny
    end
    local mag2 = nx * nx + ny * ny
    if mag2 > 1 then
        local mag = sqrt(mag2)
        return nx / mag, ny / mag
    end
    return nx, ny
end

local function PositionMinimapPins(mapID, px, py)
    local view = C_Minimap.GetViewRadius()
    if not view or view <= 0 or not px then
        for _, pin in pairs(minimapActive) do
            pin:Hide()
        end
        return
    end

    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing() or nil
    local radiusPx = Minimap:GetWidth() / 2 - 4

    for _, pin in pairs(minimapActive) do
        local data = pin.pinData
        if data then
            local dWx, dWy = Location.WorldDelta(mapID, data.x, data.y, px, py, PERCENT_FMT)
            local nx, ny
            if dWx then
                nx, ny = Location.MinimapOffset(dWx, dWy, view, facing)
            end
            if nx then
                local mag = sqrt(nx * nx + ny * ny)
                nx, ny = FloatOnMinimapEdge(nx, ny)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", nx * radiusPx, ny * radiusPx)
                if mag > 1 then
                    mag = 1
                end
                pin:SetAlpha(1.0 - (mag * 0.35))
                pin:Show()
            else
                pin:Hide()
            end
        end
    end
end

function WayPinsMap:UpdateMinimapPins()
    if not Visual.ShowMinimap() or not Minimap:IsVisible() then
        if next(minimapActive) then
            SyncMinimapPinSet(nil)
        end
        return
    end

    local mapID, px, py = Location.GetPlayerLocation()
    if minimapDirty or mapID ~= lastMinimapMapID then
        SyncMinimapPinSet(mapID)
        lastMinimapMapID = mapID
        minimapDirty = false
    end

    PositionMinimapPins(mapID, px, py)
end

local function EnsureMinimapDriver()
    if minimapDriver then return end
    minimapDriver = CreateFrame("Frame")
    minimapDriver:SetScript("OnUpdate", function()
        WayPinsMap:UpdateMinimapPins()
    end)
end

local function PlacePinAtCursor()
    if not WorldMapFrame then return false end
    local sc = WorldMapFrame.ScrollContainer
    if not sc then return false end
    local x, y = sc:GetNormalizedCursorPosition()
    local mapID = WorldMapFrame:GetMapID()
    if not mapID or not x or not y then return false end
    if x <= 0 or x >= 1 or y <= 0 or y >= 1 then return false end
    ns.UI.OpenWayPinDialog({
        mapID  = mapID,
        x      = x * 100,
        y      = y * 100,
        source = "map",
    })
    return true
end

local function StopPlaceMode()
    placingPin = false
    if placeCatcher then
        placeCatcher:Hide()
        placeCatcher:EnableMouse(false)
        placeCatcher:EnableKeyboard(false)
    end
    if placeGhost then
        placeGhost:Hide()
    end
end

local function EnsurePlaceChrome()
    if placeGhost then return end
    placeGhost = CreateFrame("Frame", nil, UIParent)
    placeGhost:SetSize(28, 44)
    placeGhost:SetFrameStrata("TOOLTIP")
    placeGhost:EnableMouse(false)
    local gtex = placeGhost:CreateTexture(nil, "OVERLAY")
    gtex:SetSize(24, 24)
    gtex:SetPoint("TOP", 0, 0)
    OneWoW.OverlayIcons:ApplyToTexture(gtex, "icon-pin")
    placeGhost.icon = gtex
    local coords = OneWoW_GUI:CreateFS(placeGhost, 11)
    coords:SetPoint("TOP", gtex, "BOTTOM", 0, -2)
    coords:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    placeGhost.coords = coords
    placeGhost:Hide()

    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    placeCatcher = CreateFrame("Button", nil, sc or UIParent)
    placeCatcher:Hide()
    placeCatcher:SetAllPoints()
    placeCatcher:SetFrameStrata("HIGH")
    placeCatcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    placeCatcher:EnableMouse(false)
    placeCatcher:SetScript("OnUpdate", function()
        if not placingPin then return end
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        placeGhost:ClearAllPoints()
        placeGhost:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx / scale, cy / scale + 8)
        local mapSC = WorldMapFrame and WorldMapFrame.ScrollContainer
        local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
        if mapSC and mapID then
            local x, y = mapSC:GetNormalizedCursorPosition()
            if x and y and x > 0 and x < 1 and y > 0 and y < 1 then
                placeGhost.coords:SetText(string.format("%d  %.1f, %.1f", mapID, x * 100, y * 100))
            else
                placeGhost.coords:SetText("")
            end
        end
    end)
    placeCatcher:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            StopPlaceMode()
            return
        end
        if PlacePinAtCursor() then
            StopPlaceMode()
        end
    end)
    placeCatcher:SetScript("OnKeyDown", function(myself, key)
        if key == "ESCAPE" then
            myself:SetPropagateKeyboardInput(false)
            StopPlaceMode()
            return
        end
        myself:SetPropagateKeyboardInput(true)
    end)
end

local function StartPlaceMode()
    if not Visual.Enabled() then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    EnsurePlaceChrome()
    local sc = WorldMapFrame.ScrollContainer
    if sc and placeCatcher:GetParent() ~= sc then
        placeCatcher:SetParent(sc)
        placeCatcher:SetAllPoints()
    end
    placingPin = true
    placeCatcher:SetFrameLevel((sc and sc:GetFrameLevel() or 0) + 50)
    placeCatcher:EnableMouse(true)
    placeCatcher:EnableKeyboard(true)
    placeCatcher:Show()
    placeGhost:Show()
end

local function PaintMapButtonIcon()
    if not mapButton then return end
    mapButton.icon:SetTexture(OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme")))
end

local function MapButtonMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L["TAB_WAYPINS"])
        rootDescription:CreateCheckbox(L["WAYPINS_SHOW_WORLD"], function()
            return Visual.ShowWorld()
        end, function()
            ns.db.global.waypinShowWorld = not Visual.ShowWorld()
            WayPinsMap:Refresh()
        end)
        rootDescription:CreateCheckbox(L["WAYPINS_SHOW_MINIMAP"], function()
            return Visual.ShowMinimap()
        end, function()
            ns.db.global.waypinShowMinimap = not Visual.ShowMinimap()
            WayPinsMap:Refresh()
        end)
        rootDescription:CreateCheckbox(L["WAYPINS_SHOW_MAP_PANEL"], function()
            return ns.db.global.waypinShowMapPanel ~= false
        end, function()
            ns.db.global.waypinShowMapPanel = not (ns.db.global.waypinShowMapPanel ~= false)
            if ns.WayPinsMapPanel then
                ns.WayPinsMapPanel:Sync()
            end
        end)
        if soloPinID then
            rootDescription:CreateButton(L["WAYPINS_SHOW_ALL"], function()
                WayPinsMap:ClearSolo()
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox(L["WAYPINS_MAP_CLICK_MENU"], function()
            return Visual.MapClickMenu()
        end, function()
            ns.db.global.waypinMapClickEnabled = not Visual.MapClickMenu()
            if ns.UI.SyncWayPinSettings then
                ns.UI.SyncWayPinSettings()
            end
        end)
        rootDescription:CreateTitle(L["WAYPINS_MAP_CLICK"])
        local function MapClickLabel(mode)
            if mode == "right" then return L["WAYPINS_MAP_CLICK_RIGHT"] end
            return L["WAYPINS_MAP_CLICK_CTRL"]
        end
        for _, mode in ipairs({ "ctrlRight", "right" }) do
            rootDescription:CreateRadio(MapClickLabel(mode), function()
                return Visual.MapClick() == mode
            end, function()
                ns.db.global.waypinMapClick = mode
                if ns.UI.SyncWaypinMapClick then
                    ns.UI.SyncWaypinMapClick()
                end
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["WAYPINS_ADD_PIN"], function()
            C_Timer.After(0, StartPlaceMode)
        end)
        rootDescription:CreateButton(L["WAYPINS_ADD_HERE"], function()
            WayPinsMap:AddHere()
        end)
        rootDescription:CreateButton(L["WAYPINS_FIND_LOCATION"], function()
            ns.UI.OpenWayPinFindDialog()
        end)
        rootDescription:CreateButton(L["WAYPINS_OPEN_TAB"], function()
            WayPinsMap:OpenPinTab()
        end)
        rootDescription:CreateButton(SETTINGS, function()
            ns.UI.OpenWayPinSettings()
        end)
    end)
end

local function MapButtonParent()
    return WorldMapFrame:GetCanvasContainer() or WorldMapFrame
end

local function IsTopRightStackIcon(frame, parent)
    if frame == mapButton or not frame:IsShown() then
        return false
    end
    local w, h = frame:GetWidth(), frame:GetHeight()
    if w < MAP_BTN_MIN or w > MAP_BTN_MAX or h < MAP_BTN_MIN or h > MAP_BTN_MAX then
        return false
    end
    local parentRight, parentTop = parent:GetRight(), parent:GetTop()
    local frameRight, frameTop = frame:GetRight(), frame:GetTop()
    if not parentRight or not parentTop or not frameRight or not frameTop then
        return false
    end
    if abs(frameRight - parentRight) > MAP_BTN_EDGE then
        return false
    end
    if (parentTop - frameTop) > MAP_BTN_STACK_DEPTH then
        return false
    end
    return true
end

local function ScanStack(parent, lowest, lowestBottom)
    if not parent then
        return lowest, lowestBottom
    end
    local children = { parent:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if IsTopRightStackIcon(child, parent) then
            local bottom = child:GetBottom()
            if bottom and (not lowestBottom or bottom < lowestBottom) then
                lowest = child
                lowestBottom = bottom
            end
        end
    end
    return lowest, lowestBottom
end

local function LowestTopRightStackIcon(parent)
    local lowest, lowestBottom = ScanStack(parent)
    if WorldMapFrame and parent ~= WorldMapFrame then
        lowest, lowestBottom = ScanStack(WorldMapFrame, lowest, lowestBottom)
    end
    return lowest
end

local function AnchorMapButton()
    if not mapButton or not WorldMapFrame then return end
    local parent = MapButtonParent()
    if mapButton:GetParent() ~= parent then
        mapButton:SetParent(parent)
    end
    mapButton:ClearAllPoints()
    local below = LowestTopRightStackIcon(parent)
    if below then
        mapButton:SetPoint("TOP", below, "BOTTOM", 0, MAP_BTN_GAP)
    else
        mapButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", MAP_BTN_X, MAP_BTN_FIRST_Y)
    end
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel(parent:GetFrameLevel() + 20)
end

local function EnsureMapButton()
    if mapButton or not WorldMapFrame then return end
    local size = ns.Constants.GUI.WAYPIN_MAP_BUTTON_SIZE
    mapButton = CreateFrame("Button", "OneWoW_WayPinsMapButton", MapButtonParent())
    mapButton:SetSize(size, size)
    mapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = mapButton:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    mapButton.icon = tex
    PaintMapButtonIcon()

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", mapButton, function()
        PaintMapButtonIcon()
    end)

    mapButton:SetScript("OnEnter", function(myself)
        PaintMapButtonIcon()
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        GameTooltip:SetText(L["TAB_WAYPINS"], 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_MAP_BTN_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    mapButton:SetScript("OnLeave", GameTooltip_Hide)
    mapButton:SetScript("OnClick", function(myself)
        if placingPin then
            StopPlaceMode()
        end
        MapButtonMenu(myself)
    end)
    AnchorMapButton()
    if not Visual.Enabled() then
        mapButton:Hide()
    end
end

local function MapClickAdds()
    if not Visual.Enabled() or not Visual.MapClickMenu() then return false end
    if Visual.MapClick() == "right" then return true end
    return IsControlKeyDown()
end

function WayPinsMap:ApplyEnabled()
    if not Visual.Enabled() then
        StopPlaceMode()
    end
    if mapButton then
        if Visual.Enabled() then
            mapButton:Show()
        else
            mapButton:Hide()
        end
    end
    self:Refresh()
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:Sync()
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
    if ns.ZonePins and ns.ZonePins.ApplyWayPinsEnabled then
        ns.ZonePins:ApplyWayPinsEnabled()
    end
    if ns.UI.ApplyNpcWaypinButton then
        ns.UI.ApplyNpcWaypinButton()
    end
    if OneWoW.UI and OneWoW.UI.RefreshSubNav then
        OneWoW.UI:RefreshSubNav()
    end
end

local function WireWorldMap()
    if mapHooked or not WorldMapFrame then return end
    mapHooked = true
    EnsureWorldMapProvider()
    EnsureMapButton()

    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        AnchorMapButton()
        WayPinsMap:RefreshWorldMap()
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Sync()
        end
    end)
    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0, AnchorMapButton)
        C_Timer.After(0.15, AnchorMapButton)
        PaintMapButtonIcon()
        if mapButton then
            if Visual.Enabled() then
                mapButton:Show()
            else
                mapButton:Hide()
            end
        end
        WayPinsMap:RefreshWorldMap()
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:PauseForMap()
        end
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Sync()
        end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        StopPlaceMode()
        hoverPinID = nil
        if worldProvider then
            worldProvider:RemoveAllData()
        end
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Hide()
        end
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:ResumeAfterMap()
        end
    end)

    local sc = WorldMapFrame.ScrollContainer
    if sc then
        local downX, downY
        sc:HookScript("OnMouseDown", function(myself, button)
            if placingPin then return end
            if button ~= "RightButton" then return end
            if not MapClickAdds() then return end
            downX, downY = myself:GetNormalizedCursorPosition()
        end)
        sc:HookScript("OnMouseUp", function(myself, button)
            if placingPin then return end
            if button ~= "RightButton" then return end
            if not MapClickAdds() then return end
            local x, y = myself:GetNormalizedCursorPosition()
            if not x or not y then return end
            if downX and (abs(x - downX) > 0.008 or abs(y - downY) > 0.008) then
                return
            end
            MenuUtil.CreateContextMenu(myself, function(_, rootDescription)
                rootDescription:CreateButton(L["WAYPINS_ADD_PIN"], function()
                    PlacePinAtCursor()
                end)
            end)
        end)
    end
end

function WayPinsMap:Refresh()
    MarkMinimapDirty()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:RefreshRows()
    end
end

function WayPinsMap:ApplyTheme()
    PaintMapButtonIcon()
    self:Refresh()
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:ApplyTheme()
    end
end

function WayPinsMap:Initialize()
    if initialized then return end
    initialized = true
    EnsureMinimapDriver()

    local function Arm()
        WireWorldMap()
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Initialize()
        end
        self:Refresh()
        if WorldMapFrame:IsShown() then
            PaintMapButtonIcon()
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:PauseForMap()
            end
            if ns.WayPinsMapPanel then
                ns.WayPinsMapPanel:Sync()
            end
        end
    end

    if WorldMapFrame then
        Arm()
    else
        OneWoW_Notes:RegisterAddonLoadedWatcher("Blizzard_WorldMap", Arm)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("USER_WAYPOINT_UPDATED")
    f:RegisterEvent("SUPER_TRACKING_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED")
    f:SetScript("OnEvent", function(_, event)
        if event == "USER_WAYPOINT_UPDATED" or event == "SUPER_TRACKING_CHANGED" then
            if livePinID and not Location.HasActiveWaypoint() then
                livePinID = nil
                StopArrivalWatch()
                MarkMinimapDirty()
                self:Refresh()
                if ns.WayPinsCompanion then
                    ns.WayPinsCompanion:RefreshRows()
                end
            end
        else
            self:UpdateMinimapPins()
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
        end
    end)
end

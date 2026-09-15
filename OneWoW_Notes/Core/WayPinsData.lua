local _, ns = ...
local L = ns.L

local Location = OneWoW.Location

local CopyTable = CopyTable
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local tinsert, sort, format = tinsert, sort, string.format
local GetServerTime = GetServerTime
local C_Map = C_Map

-- ============================================================================
-- WayPins
-- ============================================================================
-- Persistent OneWay Pin landmarks (mapID + percent coords + overlay icon).
-- Separate from zone notes (prose/todos). This module owns storage and CRUD.
-- The Pins list window is Pins-owned; a zone note docks beside it when both show.
-- ============================================================================

local WayPins = ns.DataModule:New("waypins", nil, {})
ns.WayPins = WayPins

local DEFAULT_ICON = { kind = "list", value = "VignetteEvent-SuperTracked" }
local PERCENT_COORDS = { format = "percent" }
local idSeq = 0

local function CopyIcon(spec)
    if type(spec) ~= "table" or not spec.value or spec.value == "" then
        return CopyTable(DEFAULT_ICON)
    end
    local icon = {
        kind = spec.kind or "list",
        value = spec.value,
    }
    if type(spec.tint) == "table" then
        icon.tint = { spec.tint[1], spec.tint[2], spec.tint[3] }
    end
    return icon
end

local function CopyDescription(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end
    return text
end

local function CopyBg(bg)
    if type(bg) ~= "table" or not bg.enabled then
        return nil
    end
    local copy = {
        enabled = true,
        style = bg.style or "Solid-Circle",
        effect = bg.effect or "none",
        scale = tonumber(bg.scale) or 1,
    }
    if type(bg.color) == "table" then
        copy.color = { bg.color[1] or 1, bg.color[2] or 1, bg.color[3] or 1 }
    end
    return copy
end

local function CopyEffect(effect)
    if effect == "spinning" or effect == "zooming" or effect == "both" then
        return effect
    end
    return nil
end

local notifyDepth = 0

function WayPins:NotifyChanged()
    if notifyDepth > 0 then
        return
    end
    notifyDepth = notifyDepth + 1
    self:InvalidateCache()
    if ns.WayPinsMap then
        ns.WayPinsMap:Refresh()
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:Sync()
    end
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
    notifyDepth = notifyDepth - 1
end

local function NotifyChanged()
    WayPins:NotifyChanged()
end

function WayPins:MakeNewId()
    idSeq = idSeq + 1
    return format("wp_%d_%d", GetServerTime() or 0, idSeq)
end

function WayPins:GetPin(pinID)
    if not pinID then return nil end
    local personal = self:GetAll()[pinID]
    if personal then
        return personal
    end
    if ns.WayPinPacks then
        return ns.WayPinPacks:GetDisplayPinById(pinID)
    end
    return nil
end

local function SourceKeyMatch(a, b)
    if a == nil or b == nil then
        return false
    end
    return tostring(a) == tostring(b)
end

--- First pin with this source, sourceKey, and map. Nil sourceKey never matches.
---@param source string|nil
---@param sourceKey any
---@param mapID number|nil
---@return table|nil pin
function WayPins:FindBySource(source, sourceKey, mapID)
    if type(source) ~= "string" or source == "" or sourceKey == nil then
        return nil
    end
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then
        return nil
    end
    local first
    for _, pin in pairs(self:GetAll()) do
        if type(pin) == "table"
            and pin.source == source
            and SourceKeyMatch(pin.sourceKey, sourceKey)
            and tonumber(pin.mapID) == mapID
        then
            if not first or (pin.id or "") < (first.id or "") then
                first = pin
            end
        end
    end
    return first
end

--- Pins for a uiMapID, title-sorted.
---@param mapID number|nil
---@param surface string|nil "list"|"world"|"minimap"; nil = every pin (editor lists)
---@return table[]
function WayPins:GetForMap(mapID, surface)
    mapID = tonumber(mapID)
    local out = {}
    if not mapID or mapID == 0 then
        return out
    end
    for _, pin in pairs(self:GetAll()) do
        if type(pin) == "table" and tonumber(pin.mapID) == mapID then
            tinsert(out, pin)
        end
    end
    if ns.WayPinPacks then
        ns.WayPinPacks:AppendEnabledPinsForMap(out, mapID)
    end
    sort(out, function(a, b)
        local ta = a.title or ""
        local tb = b.title or ""
        if ta == tb then
            return (a.id or "") < (b.id or "")
        end
        return ta < tb
    end)
    if surface then
        local filtered = {}
        for _, pin in ipairs(out) do
            if ns.WayPinsVisual.PinShowsOn(pin, surface) then
                tinsert(filtered, pin)
            end
        end
        return filtered
    end
    return out
end

---@param fields table
---@return string|nil pinID
function WayPins:Add(fields)
    if not ns.WayPinsVisual.Enabled() then return nil end
    if type(fields) ~= "table" then return nil end
    local mapID = tonumber(fields.mapID)
    local x = tonumber(fields.x)
    local y = tonumber(fields.y)
    if not mapID or mapID == 0 or not x or not y then
        return nil
    end

    if fields.source and fields.sourceKey ~= nil then
        local existing = self:FindBySource(fields.source, fields.sourceKey, mapID)
        if existing then
            return existing.id
        end
    end

    local pinID = fields.id
    if type(pinID) ~= "string" or not pinID:match("^wp_") then
        pinID = self:MakeNewId()
    end

    local title = fields.title
    if type(title) ~= "string" or title == "" then
        title = L["WAYPINS_UNTITLED"]
    end

    local storage = fields.storage == "character" and "character" or "account"
    local pin = {
        id          = pinID,
        title       = title,
        description = CopyDescription(fields.description),
        mapID       = mapID,
        x           = x,
        y           = y,
        icon        = CopyIcon(fields.icon),
        bg          = CopyBg(fields.bg),
        effect      = CopyEffect(fields.effect),
        mapSize     = tonumber(fields.mapSize),
        minimapSize = tonumber(fields.minimapSize),
        source      = fields.source or "manual",
        sourceKey   = fields.sourceKey,
        showOnList     = fields.showOnList ~= false,
        showOnWorld    = fields.showOnWorld ~= false,
        showOnMinimap  = fields.showOnMinimap ~= false,
        storage     = storage,
        created     = fields.created or GetServerTime(),
        modified    = GetServerTime(),
    }

    local targetDB = self:GetDataDB(storage)
    targetDB[pinID] = pin
    NotifyChanged()
    return pinID
end

function WayPins:Save(pinID, pin)
    if not pinID or type(pin) ~= "table" then return end
    if ns.WayPinPacks and ns.WayPinPacks:IsPackPinId(pinID) then
        ns.WayPinPacks:SaveDisplayPin(pin)
        return
    end
    pin.id = pinID
    pin.mapID = tonumber(pin.mapID) or pin.mapID
    pin.x = tonumber(pin.x) or pin.x
    pin.y = tonumber(pin.y) or pin.y
    pin.description = CopyDescription(pin.description)
    pin.icon = CopyIcon(pin.icon)
    pin.bg = CopyBg(pin.bg)
    pin.effect = CopyEffect(pin.effect)
    pin.mapSize = tonumber(pin.mapSize)
    pin.minimapSize = tonumber(pin.minimapSize)
    pin.showOnList = pin.showOnList ~= false
    pin.showOnWorld = pin.showOnWorld ~= false
    pin.showOnMinimap = pin.showOnMinimap ~= false
    pin.storage = pin.storage == "character" and "character" or "account"
    pin.modified = GetServerTime()

    local targetDB = self:GetDataDB(pin.storage)
    if pin.storage == "character" then
        ns.db.global.waypins[pinID] = nil
    else
        ns.db.char.waypins[pinID] = nil
    end
    targetDB[pinID] = pin
    NotifyChanged()
end

function WayPins:Remove(pinID)
    if not pinID then return end
    if ns.WayPinPacks and ns.WayPinPacks:IsPackPinId(pinID) then
        ns.WayPinPacks:DeletePinByDisplayId(pinID)
        return
    end
    local pin = self:GetPin(pinID)
    if pin and pin.source and pin.sourceKey ~= nil then
        local source, sourceKey, mapID = pin.source, pin.sourceKey, pin.mapID
        local ids = {}
        for id, other in pairs(self:GetAll()) do
            if type(other) == "table"
                and other.source == source
                and SourceKeyMatch(other.sourceKey, sourceKey)
                and tonumber(other.mapID) == tonumber(mapID)
            then
                tinsert(ids, id)
            end
        end
        for _, id in ipairs(ids) do
            ns.DataModule.Remove(self, id)
        end
    else
        ns.DataModule.Remove(self, pinID)
    end
    NotifyChanged()
end

function WayPins:Track(pinID)
    local pin = self:GetPin(pinID)
    if not pin then return false end
    if ns.WayPinsMap then
        return ns.WayPinsMap:TrackPin(pin)
    end
    return Location.SetWaypoint(pin.mapID, pin.x, pin.y, PERCENT_COORDS)
end

function WayPins:MapDisplayName(mapID)
    mapID = tonumber(mapID)
    if not mapID then return "" end
    local info = C_Map.GetMapInfo(mapID)
    return (info and info.name) or tostring(mapID)
end

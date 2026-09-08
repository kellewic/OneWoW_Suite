local _, ns = ...
local L = ns.L

local CopyTable = CopyTable
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local tinsert, tremove, sort, format = tinsert, tremove, sort, string.format
local strtrim = strtrim
local GetServerTime = GetServerTime
local loadstring, setfenv, pcall = loadstring, setfenv, pcall

-- ============================================================================
-- WayPinPacks
-- ============================================================================
-- Named groups of OneWay Pins stored in Notes SavedVariables. Personal
-- waypins stay in WayPins; a pack is one left-list row. Enabled pack pins
-- merge into GetForMap (world map, minimap, zone companion). Import/export
-- uses a closed OWP1 table, not arbitrary Lua. Imported packs are fully
-- editable; source is provenance only.
-- ============================================================================

local Packs = {}
ns.WayPinPacks = Packs

local DEFAULT_ICON = { kind = "list", value = "VignetteEvent-SuperTracked" }
local PACK_ID_PREFIX = "pk:"
local idSeq = 0

local SERIALIZE_KEYS = {
    id = "i", name = "n", expansion = "e", icon = "ic",
    mapSize = "ms", minimapSize = "mm", pins = "p",
    kind = "k", value = "v", mapID = "m", x = "x", y = "y",
    title = "t", note = "d",
    bg = "bg", effect = "ef", scale = "sc", style = "st",
    color = "c", tint = "tn", enabled = "on",
}

local DESERIALIZE_KEYS = {}
for k, v in pairs(SERIALIZE_KEYS) do
    DESERIALIZE_KEYS[v] = k
end

local function CopyIconOptional(spec)
    if type(spec) ~= "table" or not spec.value or spec.value == "" then
        return nil
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

local function CopyIcon(spec)
    return CopyIconOptional(spec) or CopyTable(DEFAULT_ICON)
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

local function CopyExpansion(val)
    if val == nil or val == "" then
        return nil
    end
    local id = tonumber(val)
    if not id or id < 0 or id > LE_EXPANSION_LEVEL_CURRENT then
        return nil
    end
    if not OneWoW:GetExpansionName(id) then
        return nil
    end
    return id
end

local function HasPinLook(pin)
    if type(pin) ~= "table" then
        return false
    end
    return pin.icon ~= nil
        or pin.bg ~= nil
        or pin.effect ~= nil
        or pin.mapSize ~= nil
        or pin.minimapSize ~= nil
end

local function ClearPinLook(pin)
    pin.icon = nil
    pin.bg = nil
    pin.effect = nil
    pin.mapSize = nil
    pin.minimapSize = nil
end

local function CopyNote(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end
    return text
end

local function SanitizeId(raw, fallbackPrefix)
    if type(raw) == "string" then
        local cleaned = raw:gsub("[^%w%-_]", "")
        if cleaned ~= "" then
            return cleaned
        end
    end
    idSeq = idSeq + 1
    return format("%s_%d_%d", fallbackPrefix, GetServerTime() or 0, idSeq)
end

local function Store()
    return ns.db.global.pinPacks
end

local function IsShippedPack(pack)
    return type(pack) == "table" and pack.shipped == true
end

local function SerializeValue(val)
    if type(val) == "string" then
        return format("%q", val)
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "table" then
        local parts = {}
        if #val > 0 then
            for _, v in ipairs(val) do
                tinsert(parts, SerializeValue(v))
            end
        else
            for k, v in pairs(val) do
                local sk = SERIALIZE_KEYS[k] or k
                tinsert(parts, format("[%q]=%s", sk, SerializeValue(v)))
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

local function DeserializeValue(str)
    if not str or str == "" then
        return nil
    end
    local func = loadstring("return " .. str)
    if not func then
        return nil
    end
    setfenv(func, {})
    local ok, result = pcall(func)
    if not ok then
        return nil
    end
    return result
end

local function ExpandKeys(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local result = {}
    if #tbl > 0 then
        for i, v in ipairs(tbl) do
            result[i] = ExpandKeys(v)
        end
        return result
    end
    for k, v in pairs(tbl) do
        result[DESERIALIZE_KEYS[k] or k] = ExpandKeys(v)
    end
    return result
end

local function ClampSize(n, lo, hi, fallback)
    n = tonumber(n)
    if not n then
        return fallback
    end
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

local function WorldSize(n)
    return ClampSize(n, 12, ns.WayPinsVisual.WorldSizeMax(), ns.WayPinsVisual.WorldDefault())
end

local function MinimapSize(n)
    return ClampSize(n, 10, ns.WayPinsVisual.MinimapSizeMax(), ns.WayPinsVisual.MinimapDefault())
end

local function ApplyLook(target, fields)
    if type(fields) ~= "table" then
        return
    end
    target.icon = CopyIcon(fields.icon)
    target.bg = CopyBg(fields.bg)
    target.effect = CopyEffect(fields.effect)
    target.mapSize = WorldSize(fields.mapSize)
    target.minimapSize = MinimapSize(fields.minimapSize)
end

function Packs:IsPackPinId(pinID)
    return type(pinID) == "string" and pinID:sub(1, #PACK_ID_PREFIX) == PACK_ID_PREFIX
end

function Packs:MakeDisplayId(packId, pinId)
    return PACK_ID_PREFIX .. packId .. ":" .. pinId
end

function Packs:ParseDisplayId(pinID)
    if not self:IsPackPinId(pinID) then
        return nil, nil
    end
    local packId, pinId = pinID:match("^pk:(.+):([^:]+)$")
    return packId, pinId
end

function Packs:GetPack(packId)
    if not packId then
        return nil
    end
    local pack = Store()[packId]
    if type(pack) == "table" then
        return pack
    end
    for _, row in pairs(Store()) do
        if type(row) == "table" and row.id == packId then
            return row
        end
    end
    for _, shipped in ipairs(OneWoW.CatalogData:GetMapPinPacks()) do
        if shipped.id == packId then
            return shipped
        end
    end
    return nil
end

function Packs:GetAllPacks()
    local out = {}
    local seen = {}
    for _, pack in pairs(Store()) do
        if type(pack) == "table" and type(pack.pins) == "table" then
            tinsert(out, pack)
            if pack.id then
                seen[pack.id] = true
            end
        end
    end
    for _, shipped in ipairs(OneWoW.CatalogData:GetMapPinPacks()) do
        if type(shipped) == "table" and type(shipped.pins) == "table" and not seen[shipped.id] then
            tinsert(out, shipped)
        end
    end
    sort(out, function(a, b)
        local na = a.name or ""
        local nb = b.name or ""
        if na == nb then
            return (a.id or "") < (b.id or "")
        end
        return na < nb
    end)
    return out
end

function Packs:PackPinCount(pack)
    if type(pack) ~= "table" or type(pack.pins) ~= "table" then
        return 0
    end
    return #pack.pins
end

function Packs:PackHasMap(pack, mapID)
    mapID = tonumber(mapID)
    if not mapID or type(pack) ~= "table" or type(pack.pins) ~= "table" then
        return false
    end
    for _, pin in ipairs(pack.pins) do
        if tonumber(pin.mapID) == mapID then
            return true
        end
    end
    return false
end

function Packs:ZoneNames(pack, mapFilter)
    if type(pack) ~= "table" or type(pack.pins) ~= "table" then
        return ""
    end
    local seen = {}
    local names = {}
    local filterID = mapFilter == "current" and tonumber(OneWoW.Location.GetPlayerMapID())
    for _, pin in ipairs(pack.pins) do
        local mapID = tonumber(pin.mapID)
        if mapID and (not filterID or mapID == filterID) and not seen[mapID] then
            seen[mapID] = true
            tinsert(names, ns.WayPins:MapDisplayName(mapID))
        end
    end
    sort(names)
    return table.concat(names, ", ")
end

function Packs:ExpansionLabel(pack)
    local exp = pack and pack.expansion
    local id = tonumber(exp)
    if id then
        return OneWoW:GetExpansionName(id) or NONE
    end
    if type(exp) == "string" and exp ~= "" then
        return exp
    end
    return NONE
end

function Packs:LookForPaint(pack)
    if type(pack) ~= "table" then
        return {}
    end
    return {
        icon        = CopyIcon(pack.icon),
        bg          = CopyBg(pack.bg),
        effect      = CopyEffect(pack.effect),
        mapSize     = WorldSize(pack.mapSize),
        minimapSize = MinimapSize(pack.minimapSize),
    }
end

function Packs:BuildDisplayPin(pack, pin)
    local note = CopyNote(pin.note)
    local usePackLook = not HasPinLook(pin)
    return {
        id          = self:MakeDisplayId(pack.id, pin.id),
        packId      = pack.id,
        packPinId   = pin.id,
        title       = pin.title,
        description = note,
        mapID       = tonumber(pin.mapID),
        x           = tonumber(pin.x),
        y           = tonumber(pin.y),
        icon        = CopyIcon(pin.icon or pack.icon),
        bg          = CopyBg(pin.bg) or CopyBg(pack.bg),
        effect      = CopyEffect(pin.effect) or CopyEffect(pack.effect),
        mapSize     = WorldSize(pin.mapSize ~= nil and pin.mapSize or pack.mapSize),
        minimapSize = MinimapSize(pin.minimapSize ~= nil and pin.minimapSize or pack.minimapSize),
        usePackLook = usePackLook,
        source      = "pack",
        sourceKey   = pack.id .. ":" .. pin.id,
        storage     = "account",
    }
end

function Packs:GetDisplayPinById(pinID)
    local pack, pin = self:ResolvePackedPin(pinID)
    if not pack or not pin then
        return nil
    end
    return self:BuildDisplayPin(pack, pin)
end

function Packs:AppendEnabledPinsForMap(out, mapID)
    mapID = tonumber(mapID)
    if not mapID then
        return
    end
    for _, pack in ipairs(self:GetAllPacks()) do
        if pack.enabled ~= false then
            for _, pin in ipairs(pack.pins) do
                if tonumber(pin.mapID) == mapID then
                    tinsert(out, self:BuildDisplayPin(pack, pin))
                end
            end
        end
    end
end

local function Notify()
    ns.WayPins:NotifyChanged()
end

function Packs:CreatePack(fields)
    fields = fields or {}
    local name = CopyNote(fields.name)
    if not name then
        return nil
    end
    local packId = SanitizeId(fields.id, "pp")
    while Store()[packId] do
        idSeq = idSeq + 1
        packId = format("pp_%d_%d", GetServerTime() or 0, idSeq)
    end
    local pack = {
        id          = packId,
        name        = name,
        expansion   = CopyExpansion(fields.expansion),
        icon        = CopyIcon(fields.icon),
        bg          = CopyBg(fields.bg),
        effect      = CopyEffect(fields.effect),
        mapSize     = WorldSize(fields.mapSize),
        minimapSize = MinimapSize(fields.minimapSize),
        enabled     = true,
        orderLocked = false,
        source      = fields.source == "import" and "import" or "user",
        created     = GetServerTime(),
        modified    = GetServerTime(),
        pins        = {},
    }
    Store()[packId] = pack
    Notify()
    return packId
end

function Packs:SetEnabled(packId, enabled)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) then
        return
    end
    pack.enabled = enabled and true or false
    pack.modified = GetServerTime()
    Notify()
end

function Packs:SetOrderLocked(packId, locked)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) then
        return
    end
    pack.orderLocked = locked and true or false
    pack.modified = GetServerTime()
end

function Packs:SetLook(packId, fields)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) or type(fields) ~= "table" then
        return
    end
    ApplyLook(pack, fields)
    pack.modified = GetServerTime()
    Notify()
end

function Packs:SetVisual(packId, icon, mapSize, minimapSize)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) then
        return
    end
    if icon ~= nil then
        pack.icon = CopyIcon(icon)
    end
    if mapSize ~= nil then
        pack.mapSize = WorldSize(mapSize)
    end
    if minimapSize ~= nil then
        pack.minimapSize = MinimapSize(minimapSize)
    end
    pack.modified = GetServerTime()
    Notify()
end

function Packs:SetMeta(packId, name, expansion)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) then
        return
    end
    local trimmed = CopyNote(name)
    if trimmed then
        pack.name = trimmed
    end
    pack.expansion = CopyExpansion(expansion)
    pack.modified = GetServerTime()
    Notify()
end

function Packs:FindPin(pack, pinId)
    if type(pack) ~= "table" or type(pack.pins) ~= "table" or pinId == nil then
        return nil, nil
    end
    pinId = tostring(pinId)
    for i, pin in pairs(pack.pins) do
        if type(pin) == "table" and tostring(pin.id) == pinId then
            return pin, i
        end
    end
    return nil, nil
end

--- Pack table, raw pin row, and pins-array index for a `pk:` display id.
function Packs:ResolvePackedPin(pinID)
    if not self:IsPackPinId(pinID) then
        return nil
    end
    local packId, pinId = self:ParseDisplayId(pinID)
    local function matchIn(pack)
        if type(pack) ~= "table" or type(pack.pins) ~= "table" then
            return nil
        end
        local pin, index = self:FindPin(pack, pinId)
        if pin then
            return pin, index
        end
        for i, row in pairs(pack.pins) do
            if type(row) == "table" and self:MakeDisplayId(pack.id, row.id) == pinID then
                return row, i
            end
        end
        return nil
    end
    local pack = packId and self:GetPack(packId)
    if pack then
        local pin, index = matchIn(pack)
        if pin then
            return pack, pin, index
        end
    end
    for _, other in pairs(Store()) do
        local pin, index = matchIn(other)
        if pin then
            return other, pin, index
        end
    end
    return nil
end

function Packs:AddPin(packId, fields)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) or type(fields) ~= "table" then
        return nil
    end
    local mapID = tonumber(fields.mapID)
    local x = tonumber(fields.x)
    local y = tonumber(fields.y)
    if not mapID or mapID == 0 or not x or not y then
        return nil
    end
    local pinId = SanitizeId(fields.id, "p")
    if self:FindPin(pack, pinId) then
        idSeq = idSeq + 1
        pinId = format("p_%d_%d", GetServerTime() or 0, idSeq)
    end
    local title = fields.title
    if type(title) ~= "string" or title == "" then
        title = L["WAYPINS_UNTITLED"]
    end
    local row = {
        id     = pinId,
        title  = title,
        note   = CopyNote(fields.note or fields.description),
        mapID  = mapID,
        x      = x,
        y      = y,
    }
    if HasPinLook(fields) then
        row.icon = CopyIconOptional(fields.icon)
        row.bg = CopyBg(fields.bg)
        row.effect = CopyEffect(fields.effect)
        if fields.mapSize ~= nil then
            row.mapSize = WorldSize(fields.mapSize)
        end
        if fields.minimapSize ~= nil then
            row.minimapSize = MinimapSize(fields.minimapSize)
        end
    end
    tinsert(pack.pins, row)
    pack.modified = GetServerTime()
    Notify()
    return self:MakeDisplayId(packId, pinId)
end

function Packs:SaveDisplayPin(display)
    if type(display) ~= "table" then
        return
    end
    local packId = display.packId
    local pinId = display.packPinId
    if not packId or not pinId then
        packId, pinId = self:ParseDisplayId(display.id)
    end
    local pack = packId and self:GetPack(packId)
    if not pack or IsShippedPack(pack) then
        return
    end
    local pin = pack and select(1, self:FindPin(pack, pinId))
    if not pin then
        return
    end
    local mapID = tonumber(display.mapID)
    local x = tonumber(display.x)
    local y = tonumber(display.y)
    if mapID and mapID ~= 0 then
        pin.mapID = mapID
    end
    if x then
        pin.x = x
    end
    if y then
        pin.y = y
    end
    if type(display.title) == "string" and display.title ~= "" then
        pin.title = display.title
    end
    pin.note = CopyNote(display.description or display.note)
    if display.usePackLook then
        ClearPinLook(pin)
    else
        pin.icon = CopyIcon(display.icon)
        pin.bg = CopyBg(display.bg)
        pin.effect = CopyEffect(display.effect)
        pin.mapSize = WorldSize(display.mapSize)
        pin.minimapSize = MinimapSize(display.minimapSize)
    end
    pack.modified = GetServerTime()
    Notify()
end

function Packs:DeletePinByDisplayId(pinID, quiet)
    local pack, _, index = self:ResolvePackedPin(pinID)
    if not pack or IsShippedPack(pack) or index == nil then
        return false
    end
    if type(index) == "number" then
        tremove(pack.pins, index)
    else
        pack.pins[index] = nil
    end
    pack.modified = GetServerTime()
    if not quiet then
        Notify()
    end
    return true
end

function Packs:ReturnPinToPersonal(pinID)
    local display = self:GetDisplayPinById(pinID)
    if not display then
        return nil
    end
    -- Drop the pack row first. Add notifies; if that refresh errors, the pack
    -- pin must already be gone so a reload does not keep both copies.
    if not self:DeletePinByDisplayId(pinID, true) then
        return nil
    end
    local newId = ns.WayPins:Add({
        title       = display.title,
        description = display.description,
        mapID       = display.mapID,
        x           = display.x,
        y           = display.y,
        icon        = display.icon,
        bg          = display.bg,
        effect      = display.effect,
        mapSize     = display.mapSize,
        minimapSize = display.minimapSize,
        source      = "manual",
        storage     = "account",
    })
    if not newId then
        self:AddPin(display.packId, {
            id          = display.packPinId,
            title       = display.title,
            note        = display.description,
            mapID       = display.mapID,
            x           = display.x,
            y           = display.y,
            icon        = display.icon,
            bg          = display.bg,
            effect      = display.effect,
            mapSize     = display.mapSize,
            minimapSize = display.minimapSize,
        })
        return nil
    end
    return newId
end

function Packs:SendPersonalPin(pinID, packId)
    local pin = ns.WayPins:GetPin(pinID)
    if not pin or self:IsPackPinId(pinID) then
        return nil
    end
    local pack = self:GetPack(packId)
    if not pack then
        return nil
    end
    local displayId = self:AddPin(packId, {
        title       = pin.title,
        note        = pin.description,
        mapID       = pin.mapID,
        x           = pin.x,
        y           = pin.y,
    })
    ns.DataModule.Remove(ns.WayPins, pinID)
    Notify()
    return displayId
end

--- Move a personal pin or pack pin into another pack. Same pack is a no-op.
---@param pinID string
---@param targetPackId string
---@return string|nil displayId
function Packs:MovePinToPack(pinID, targetPackId)
    if not pinID or not targetPackId then
        return nil
    end
    if not self:GetPack(targetPackId) then
        return nil
    end
    if not self:IsPackPinId(pinID) then
        return self:SendPersonalPin(pinID, targetPackId)
    end
    local srcPackId, srcPinId = self:ParseDisplayId(pinID)
    if srcPackId == targetPackId then
        return pinID
    end
    local srcPack = srcPackId and self:GetPack(srcPackId)
    local pin = srcPack and select(1, self:FindPin(srcPack, srcPinId))
    if not pin then
        return nil
    end
    local fields = {
        title = pin.title,
        note  = pin.note,
        mapID = pin.mapID,
        x     = pin.x,
        y     = pin.y,
    }
    if HasPinLook(pin) then
        fields.icon        = pin.icon
        fields.bg          = pin.bg
        fields.effect      = pin.effect
        fields.mapSize     = pin.mapSize
        fields.minimapSize = pin.minimapSize
    end
    local displayId = self:AddPin(targetPackId, fields)
    if not displayId then
        return nil
    end
    self:DeletePinByDisplayId(pinID)
    return displayId
end

function Packs:ReorderPins(packId, fromIdx, toIdx, insertBefore)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) or pack.orderLocked then
        return
    end
    if ns.UI.ApplySectionReorder(pack.pins, fromIdx, toIdx, insertBefore) then
        pack.modified = GetServerTime()
        Notify()
    end
end

function Packs:RemovePack(packId, returnPins)
    local pack = self:GetPack(packId)
    if not pack or IsShippedPack(pack) then
        return
    end
    if returnPins then
        for i = #pack.pins, 1, -1 do
            local display = self:BuildDisplayPin(pack, pack.pins[i])
            ns.WayPins:Add({
                title       = display.title,
                description = display.description,
                mapID       = display.mapID,
                x           = display.x,
                y           = display.y,
                icon        = display.icon,
                bg          = display.bg,
                effect      = display.effect,
                mapSize     = display.mapSize,
                minimapSize = display.minimapSize,
                source      = "manual",
                storage     = "account",
            })
        end
    end
    Store()[packId] = nil
    Notify()
end

local function NormalizeImportPin(raw)
    if type(raw) ~= "table" then
        return nil
    end
    local mapID = tonumber(raw.mapID)
    local x = tonumber(raw.x)
    local y = tonumber(raw.y)
    if not mapID or mapID == 0 or not x or not y then
        return nil
    end
    local title = raw.title
    if type(title) ~= "string" or title == "" then
        title = L["WAYPINS_UNTITLED"]
    end
    local pin = {
        id    = SanitizeId(raw.id, "p"),
        title = title,
        note  = CopyNote(raw.note or raw.description),
        mapID = mapID,
        x     = x,
        y     = y,
    }
    if HasPinLook(raw) then
        pin.icon = CopyIconOptional(raw.icon)
        pin.bg = CopyBg(raw.bg)
        pin.effect = CopyEffect(raw.effect)
        if raw.mapSize ~= nil then
            pin.mapSize = WorldSize(raw.mapSize)
        end
        if raw.minimapSize ~= nil then
            pin.minimapSize = MinimapSize(raw.minimapSize)
        end
    end
    return pin
end

local function NormalizeImport(raw)
    if type(raw) ~= "table" then
        return nil
    end
    local name = CopyNote(raw.name)
    if not name then
        return nil
    end
    local pins = {}
    local seen = {}
    if type(raw.pins) == "table" then
        for _, row in ipairs(raw.pins) do
            local pin = NormalizeImportPin(row)
            if pin then
                while seen[pin.id] do
                    idSeq = idSeq + 1
                    pin.id = format("p_%d_%d", GetServerTime() or 0, idSeq)
                end
                seen[pin.id] = true
                tinsert(pins, pin)
            end
        end
    end
    return {
        id          = SanitizeId(raw.id, "pp"),
        name        = name,
        expansion   = CopyExpansion(raw.expansion),
        icon        = CopyIcon(raw.icon),
        bg          = CopyBg(raw.bg),
        effect      = CopyEffect(raw.effect),
        mapSize     = WorldSize(raw.mapSize),
        minimapSize = MinimapSize(raw.minimapSize),
        pins        = pins,
    }
end

function Packs:Export(packId)
    local pack = self:GetPack(packId)
    if not pack then
        return nil
    end
    local pins = {}
    for _, pin in ipairs(pack.pins) do
        local row = {
            id    = pin.id,
            title = pin.title,
            note  = pin.note,
            mapID = pin.mapID,
            x     = pin.x,
            y     = pin.y,
        }
        if HasPinLook(pin) then
            if pin.icon then
                row.icon = CopyIconOptional(pin.icon)
            end
            if pin.bg then
                row.bg = CopyBg(pin.bg)
            end
            if pin.effect then
                row.effect = CopyEffect(pin.effect)
            end
            if pin.mapSize ~= nil then
                row.mapSize = WorldSize(pin.mapSize)
            end
            if pin.minimapSize ~= nil then
                row.minimapSize = MinimapSize(pin.minimapSize)
            end
        end
        tinsert(pins, row)
    end
    local payload = {
        id          = pack.id,
        name        = pack.name,
        expansion   = pack.expansion,
        icon        = CopyIcon(pack.icon),
        bg          = CopyBg(pack.bg),
        effect      = CopyEffect(pack.effect),
        mapSize     = WorldSize(pack.mapSize),
        minimapSize = MinimapSize(pack.minimapSize),
        pins        = pins,
    }
    return "OWP1:" .. SerializeValue(payload)
end

--- Import an OWP1 string.
---@param str string
---@param replace boolean|nil
---@return string|nil packId
---@return string|nil err "exists"|"invalid"
---@return table|nil existing
function Packs:Import(str, replace)
    if type(str) ~= "string" then
        return nil, "invalid"
    end
    str = strtrim(str)
    if str:sub(1, 5) == "OWP1:" then
        str = str:sub(6)
    end
    local raw = DeserializeValue(str)
    if not raw then
        return nil, "invalid"
    end
    local data = NormalizeImport(ExpandKeys(raw))
    if not data then
        return nil, "invalid"
    end
    local existing = Store()[data.id]
    if existing and not replace then
        return nil, "exists", existing
    end
    local pack = {
        id          = data.id,
        name        = data.name,
        expansion   = data.expansion,
        icon        = data.icon,
        bg          = data.bg,
        effect      = data.effect,
        mapSize     = data.mapSize,
        minimapSize = data.minimapSize,
        enabled     = (not existing) or (existing.enabled ~= false),
        orderLocked = existing and existing.orderLocked == true or false,
        source      = "import",
        created     = (existing and existing.created) or GetServerTime(),
        modified    = GetServerTime(),
        pins        = data.pins,
    }
    Store()[data.id] = pack
    Notify()
    return data.id
end

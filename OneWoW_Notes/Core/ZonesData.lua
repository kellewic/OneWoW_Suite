local _, ns = ...
local L = ns.L

local Zones = ns.DataModule:New("zones", "zoneCustomCategories", {
    "General", "Quest", "Farming", "Rare", "Treasure", "Dungeon", "Raid", "PvP", "Event"
})
ns.Zones = Zones

Zones.GetAllZones = Zones.GetAll

local lastAlertedZone = nil
local lastAlertTime   = 0
local currentZone     = ""
local currentSubZone  = ""
local currentInstanceID = nil
local zoneEventFrame  = CreateFrame("Frame")
local zoneWatchStarted = false
local idSeq = 0

------------------------------------------------------------
-- Title / id / location helpers
------------------------------------------------------------

function Zones:FormatTitle(zone, subzone)
    zone = zone or ""
    subzone = subzone or ""
    if subzone ~= "" and subzone ~= zone then
        return zone .. " - " .. subzone
    end
    return zone
end

function Zones:FormatTitleFromData(data)
    if not data or type(data) ~= "table" then return "" end
    return self:FormatTitle(data.zone, data.subzone)
end

function Zones:MakeNewId()
    idSeq = idSeq + 1
    return string.format("zn_%d_%d", GetServerTime() or 0, idSeq)
end

--- Split a legacy title-key ("Zone - Subzone" or plain zone) into parts.
function Zones:ParseLegacyKey(key)
    if not key or key == "" then
        return "", ""
    end
    local zone, subzone = string.match(key, "^(.-) %- (.+)$")
    if zone and subzone then
        return zone, subzone
    end
    return key, ""
end

--- Catalog Quests zone filter name: map display name when mapID is set, else zone field.
function Zones:ResolveCatalogZoneName(data)
    if not data or type(data) ~= "table" then
        return nil
    end
    local mapID = tonumber(data.mapID)
    if mapID then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            return mapInfo.name
        end
    end
    if data.zone and data.zone ~= "" then
        return data.zone
    end
    return nil
end

function Zones:GetCurrentZoneParts()
    local zone = GetZoneText() or ""
    local subzone = GetSubZoneText() or ""
    if subzone == zone then
        subzone = ""
    end
    return zone, subzone, self:GetCurrentMapInfo()
end

--- Display helper for current location (not an SV key).
function Zones:GetCurrentZoneName()
    local zone, subzone = self:GetCurrentZoneParts()
    return self:FormatTitle(zone, subzone)
end

--- Parent note (empty subzone) matches any subzone in that zone; specific notes need both.
function Zones:NoteMatchesLocation(data, zoneText, subZoneText)
    if not data or type(data) ~= "table" then
        return false
    end
    local z = data.zone or ""
    if z == "" or z ~= (zoneText or "") then
        return false
    end
    local sz = data.subzone or ""
    if sz == "" then
        return true
    end
    return sz == (subZoneText or "")
end

function Zones:FindMatchingNotes(zoneText, subZoneText)
    local results = {}
    for id, data in pairs(self:GetAll()) do
        if type(data) == "table" and self:NoteMatchesLocation(data, zoneText, subZoneText) then
            results[#results + 1] = { id = id, data = data }
        end
    end
    return results
end

--- Exact zone+subzone match (for "already exists" on create).
function Zones:FindIdByParts(zone, subzone)
    zone = zone or ""
    subzone = subzone or ""
    if zone == "" then
        return nil
    end
    for id, data in pairs(self:GetAll()) do
        if type(data) == "table"
            and data.zone == zone
            and (data.subzone or "") == subzone
        then
            return id
        end
    end
    return nil
end

function Zones:Initialize()
    -- Always watch zone changes so pinned zone notes trigger even when the zone
    -- alert messages are turned off. Alerts themselves stay gated by the setting.
    self:StartZoneWatch()
    C_Timer.After(1, function() Zones:CheckZones() end)
end

-- Register the zone-change events / poll once. Independent of zone alerts so
-- pins keep working regardless of the alert toggle.
function Zones:StartZoneWatch()
    if zoneWatchStarted then return end
    zoneWatchStarted = true

    zoneEventFrame:SetScript("OnEvent", function() C_Timer.After(0.1, function() Zones:CheckZones() end) end)
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

    OneWoW_Notes:RegisterEnteringWorldHandler("zones", function()
        C_Timer.After(0.1, function() Zones:CheckZones() end)
    end)

    if not self.periodicTimer then
        self.periodicTimer = C_Timer.NewTicker(2, function()
            local newZone = GetZoneText()
            local newSubZone = GetSubZoneText()
            local _, _, _, _, _, _, _, newInstanceID = GetInstanceInfo()
            if newZone ~= currentZone or newSubZone ~= currentSubZone or newInstanceID ~= currentInstanceID then
                Zones:CheckZones()
            end
        end)
    end
end

-- "Scanning" in the settings UI refers to the zone alert messages, not pin
-- triggering (pins are always watched once StartZoneWatch has run).
function Zones:IsScanning()
    return ns.db.global.zoneAlertsEnabled and true or false
end

function Zones:EnableScanning()
    ns.db.global.zoneAlertsEnabled = true
    self:StartZoneWatch()
    Zones:CheckZones()
end

function Zones:DisableScanning()
    -- Only turn off the alert messages; the zone watcher keeps running so pinned
    -- zone notes still appear on zone change.
    ns.db.global.zoneAlertsEnabled = false
end

function Zones:IsPinnedWindowEnabled()
    return ns.db.global.zonePinnedWindowEnabled ~= false
end

function Zones:SetPinnedWindowEnabled(enabled)
    ns.db.global.zonePinnedWindowEnabled = enabled and true or false
    if not enabled and ns.ZonePins and ns.zonePins then
        local ids = {}
        for noteId in pairs(ns.zonePins) do
            ids[#ids + 1] = noteId
        end
        for _, noteId in ipairs(ids) do
            ns.ZonePins:HideZonePin(noteId)
        end
    end
    self:CheckZones()
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
end

-- Runs on every zone change: shows/hides pinned zone notes (always) and fires
-- zone alert messages (only when zone alerts are enabled).
function Zones:CheckZones()
    local now = GetTime()
    local alertsOn = ns.db.global.zoneAlertsEnabled and true or false

    local zoneText    = GetZoneText()    or ""
    local subZoneText = GetSubZoneText() or ""
    if subZoneText == zoneText then
        subZoneText = ""
    end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

    local previousZone       = currentZone
    local previousSubZone    = currentSubZone
    local previousInstanceID = currentInstanceID

    currentZone       = zoneText
    currentSubZone    = subZoneText
    currentInstanceID = instanceID

    local mainZoneChanged = (previousZone ~= zoneText)
    local subZoneChanged  = (previousSubZone ~= subZoneText)
    local instanceChanged = (previousInstanceID ~= instanceID)

    if not mainZoneChanged and not subZoneChanged and not instanceChanged then return end

    local shouldHidePins = false
    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
        shouldHidePins = instanceChanged
    else
        shouldHidePins = (mainZoneChanged or subZoneChanged)
    end

    local matching = self:FindMatchingNotes(zoneText, subZoneText)
    local matchSet = {}
    for _, entry in ipairs(matching) do
        matchSet[entry.id] = true
    end

    if shouldHidePins and ns.ZonePins and ns.zonePins then
        local toHide = {}
        for noteId in pairs(ns.zonePins) do
            if not matchSet[noteId] then
                toHide[#toHide + 1] = noteId
            end
        end
        for _, noteId in ipairs(toHide) do
            ns.ZonePins:HideZonePin(noteId)
        end
    end

    for _, entry in ipairs(matching) do
        local noteId = entry.id
        local zoneData = entry.data
        local dismissed = zoneData.dismissedUntil and GetTime() < zoneData.dismissedUntil
        local title = self:FormatTitleFromData(zoneData)

        if zoneData.pinEnabled and not dismissed and ns.ZonePins
            and ns.db.global.zonePinnedWindowEnabled ~= false
        then
            ns.ZonePins:ShowZonePin(noteId, zoneData)
        end

        -- Alert message / sound / toast only when zone alerts are enabled.
        if alertsOn and zoneData.alertEnabled ~= false and not dismissed then
            if not (lastAlertedZone == noteId and (now - lastAlertTime) < 30) then
                lastAlertTime   = now
                lastAlertedZone = noteId
                print("|cFFFFD100OneWoW - Zones:|r " .. (L["NPC_LABEL_ZONE"]) .. " " .. title)
                PlaySound(SOUNDKIT.RAID_WARNING)
                local preview = (zoneData.content and zoneData.content ~= "") and zoneData.content:sub(1, 60) or nil
                OneWoW.Toasts.FireZoneAlert(title, preview)
            end
        end
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
end

function Zones:GetParentZoneName()
    local mapInfo = self:GetCurrentMapInfo()
    if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
        local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
        if parentInfo then return parentInfo.name end
    end
    return GetZoneText() or ""
end

function Zones:GetCurrentMapInfo()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil end
    return {
        mapID       = mapID,
        name        = info.name,
        parentMapID = info.parentMapID or 0,
    }
end

--- Look up a zone note by opaque id.
function Zones:GetZone(noteId)
    if not noteId then return nil end
    return self:GetAll()[noteId]
end

--- Create a zone note. Requires zoneData.zone. Returns the opaque note id.
---@param zoneData table
---@return string|nil noteId
function Zones:AddZone(zoneData)
    if not zoneData or type(zoneData) ~= "table" then return nil end
    local zone = zoneData.zone
    if not zone or zone == "" then return nil end

    local subzone = zoneData.subzone or ""
    if subzone == zone then
        subzone = ""
    end

    local noteId = zoneData.id or self:MakeNewId()
    zoneData.id      = noteId
    zoneData.zone    = zone
    zoneData.subzone = subzone
    if zoneData.mapID ~= nil then
        zoneData.mapID = tonumber(zoneData.mapID) or zoneData.mapID
    end

    zoneData.content       = zoneData.content or zoneData.text or ""
    zoneData.text          = nil
    zoneData.todos         = zoneData.todos or {}
    zoneData.alertEnabled  = zoneData.alertEnabled  == nil and true  or zoneData.alertEnabled
    zoneData.pinEnabled    = zoneData.pinEnabled     == nil and false or zoneData.pinEnabled
    zoneData.pinColor      = zoneData.pinColor  or "sync"
    zoneData.fontColor     = zoneData.fontColor or "match"
    zoneData.fontFamily    = zoneData.fontFamily or nil
    zoneData.fontSize      = zoneData.fontSize  or 12
    zoneData.opacity       = zoneData.opacity   or 0.9
    zoneData.tasksOnTop    = zoneData.tasksOnTop == nil and false or zoneData.tasksOnTop
    zoneData.storage       = zoneData.storage   or "account"
    zoneData.category      = zoneData.category  or "General"
    zoneData.created       = zoneData.created   or GetServerTime()
    zoneData.modified      = GetServerTime()
    zoneData.sortOrder     = zoneData.sortOrder or 0

    local targetDB = (zoneData.storage == "character") and ns.db.char.zones or ns.db.global.zones
    targetDB[noteId] = zoneData
    self:InvalidateCache()
    return noteId
end

function Zones:SaveZone(noteId, zoneData)
    if not noteId or not zoneData then return end
    zoneData.id = noteId
    zoneData.modified = GetServerTime()
    if zoneData.zone and zoneData.subzone == zoneData.zone then
        zoneData.subzone = ""
    end
    local targetDB = (zoneData.storage == "character") and ns.db.char.zones or ns.db.global.zones
    -- Drop from the other storage if storage changed.
    if zoneData.storage == "character" then
        ns.db.global.zones[noteId] = nil
    else
        ns.db.char.zones[noteId] = nil
    end
    targetDB[noteId] = zoneData
    self:InvalidateCache()
end

function Zones:RemoveZone(noteId)
    if not noteId then return end
    self:Remove(noteId)
end

function Zones:AddTodo(noteId, todoText)
    local zoneData = self:GetZone(noteId)
    if not zoneData then return end
    if not zoneData.todos then zoneData.todos = {} end

    local todo = {
        id        = math.random(100000, 999999),
        text      = todoText,
        completed = false,
        created   = GetServerTime(),
    }
    tinsert(zoneData.todos, todo)
    zoneData.modified = GetServerTime()
    self:SaveZone(noteId, zoneData)
    return todo
end

function Zones:UpdateTodo(noteId, todoId, newText, completed)
    local zoneData = self:GetZone(noteId)
    if not zoneData or not zoneData.todos then return end
    for _, todo in ipairs(zoneData.todos) do
        if todo.id == todoId then
            if newText    ~= nil then todo.text      = newText    end
            if completed  ~= nil then todo.completed = completed  end
            zoneData.modified = GetServerTime()
            self:SaveZone(noteId, zoneData)
            return true
        end
    end
    return false
end

function Zones:RemoveTodo(noteId, todoId)
    local zoneData = self:GetZone(noteId)
    if not zoneData or not zoneData.todos then return end
    for i, todo in ipairs(zoneData.todos) do
        if todo.id == todoId then
            tremove(zoneData.todos, i)
            zoneData.modified = GetServerTime()
            self:SaveZone(noteId, zoneData)
            return true
        end
    end
    return false
end

local _, ns = ...
local L = ns.L

-- ============================================================================
-- Navigation
-- ============================================================================
-- Shared map navigation for the Catalog: opens the world map to a zone and, when
-- coordinates are known, drops a super-tracked user waypoint.
--
-- Coordinate scaling and the waypoint call itself live in OneWoW.Location; this
-- file owns the Catalog-specific half. Journal DB2 and Delve doors arrive as
-- continent Map.db2 + world XY. Delve rows also carry uiMapID as the outdoor
-- zone for GetAreaPOIInfo, not as percent coords. Wowhead fallbacks have
-- uiMapID + 0-100 and no mapID. ContinentID 0 rows fall back to a live POI
-- lookup.
-- ============================================================================

local tonumber = tonumber
local ipairs = ipairs
local C_Map, C_SuperTrack, C_EncounterJournal, C_AreaPoiInfo = C_Map, C_SuperTrack, C_EncounterJournal, C_AreaPoiInfo
local CreateVector2D, UnitFactionGroup = CreateVector2D, UnitFactionGroup

ns.Navigation = ns.Navigation or {}
local Navigation = ns.Navigation

--- Opens the world map to `mapID` and sets a super-tracked user waypoint when
--- x/y are provided and the map supports waypoints. Coordinates arrive from
--- mixed sources (Wowhead 0-100, converted DB2 world positions), so the format
--- is left to `OneWoW.Location`'s tolerant reading.
---@param mapID number
---@param x number|nil  0-100 or 0-1
---@param y number|nil  0-100 or 0-1
---@param title string|nil arrow name when the provider accepts one
---@return boolean opened
function Navigation:OpenMapPin(mapID, x, y, title)
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then return false end

    OneWoW.Location.SetWaypoint(mapID, x, y, { openMap = true, title = title })

    return true
end

local function PlayerFactionID()
    local group = UnitFactionGroup("player")
    if group == "Alliance" then
        return 1
    end
    if group == "Horde" then
        return 0
    end
    return -1
end

--- Pick faction-matching door rows. Alliance=1, Horde=0, -1 = any.
---@param entrances table
---@return table
local function FactionCandidates(entrances)
    local faction = PlayerFactionID()
    if faction >= 0 then
        local matched = {}
        for _, row in ipairs(entrances) do
            if row.faction == faction then
                matched[#matched + 1] = row
            end
        end
        if matched[1] then
            return matched
        end
    end
    local any = {}
    for _, row in ipairs(entrances) do
        if row.faction == -1 then
            any[#any + 1] = row
        end
    end
    if any[1] then
        return any
    end
    return entrances
end

--- Convert continent Map.db2 + world XY into a UiMap + 0-1 position.
--- Drills Continent -> Zone when the child at that point is a zone (not the dungeon interior).
---@param continentID number
---@param worldX number
---@param worldY number
---@param preferredUiMapID number|nil outdoor zone to convert onto when known
---@return number|nil uiMapID
---@return number|nil x
---@return number|nil y
local function ResolveWorldPos(continentID, worldX, worldY, preferredUiMapID)
    local worldPos = CreateVector2D(worldX, worldY)
    if preferredUiMapID then
        local zoneID, zonePos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, preferredUiMapID)
        if zoneID and zonePos then
            return zoneID, zonePos.x, zonePos.y
        end
    end
    local uiMapID, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos)
    if not uiMapID or not mapPos then
        return nil
    end

    local info = C_Map.GetMapInfo(uiMapID)
    if info and info.mapType and info.mapType < Enum.UIMapType.Zone then
        local child = C_Map.GetMapInfoAtPosition(uiMapID, mapPos.x, mapPos.y)
        local childID = child and child.mapID
        local childType = child and child.mapType
        if childID and childID ~= uiMapID
                and (childType == Enum.UIMapType.Zone or childType == Enum.UIMapType.Micro) then
            local zoneID, zonePos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, childID)
            if zoneID and zonePos then
                uiMapID, mapPos = zoneID, zonePos
            end
        end
    end
    return uiMapID, mapPos.x, mapPos.y
end

---@param uiMapID number
---@return number
local function MapPinScore(uiMapID)
    local info = C_Map.GetMapInfo(uiMapID)
    local mapType = info and info.mapType or 0
    local score = 0
    if mapType == Enum.UIMapType.Zone then
        score = score + 20
    elseif mapType == Enum.UIMapType.Continent then
        score = score + 5
    end
    if OneWoW.Location.GetActiveProvider() ~= "tomtom"
            and C_Map.CanSetUserWaypointOnMap(uiMapID) then
        score = score + 10
    end
    return score
end

--- Midnight delve doors often have ContinentID 0, so world XY cannot convert.
--- Walk from the door's outdoor zone (when known), then the player's map parents.
---@param areaPoiID number
---@param uiMapID number|nil
---@return number|nil uiMapID
---@return number|nil x
---@return number|nil y
local function WalkAreaPoiFrom(areaPoiID, uiMapID)
    local seen = {}
    while uiMapID and uiMapID ~= 0 and not seen[uiMapID] do
        seen[uiMapID] = true
        local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, areaPoiID)
        local pos = info and info.position
        if pos then
            return uiMapID, pos.x, pos.y
        end
        local mapInfo = C_Map.GetMapInfo(uiMapID)
        uiMapID = mapInfo and mapInfo.parentMapID
    end
    return nil
end

---@param areaPoiID number
---@param startMapID number|nil
---@return number|nil uiMapID
---@return number|nil x
---@return number|nil y
local function ResolveAreaPoiPin(areaPoiID, startMapID)
    local uiMapID, x, y = WalkAreaPoiFrom(areaPoiID, startMapID)
    if uiMapID then
        return uiMapID, x, y
    end
    local playerMap = C_Map.GetBestMapForUnit("player")
    if playerMap and playerMap ~= startMapID then
        return WalkAreaPoiFrom(areaPoiID, playerMap)
    end
    return nil
end

---@param uiMapID number
---@param instanceID number
---@return boolean
local function SuperTrackDungeonEntrance(uiMapID, instanceID)
    local list = C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID)
    if not list then
        return false
    end
    for i = 1, #list do
        local info = list[i]
        if info.journalInstanceID == instanceID then
            C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, info.areaPoiID)
            return true
        end
    end
    return false
end

---@param instanceID number
---@param entrances table
---@return number|nil uiMapID
---@return number|nil x
---@return number|nil y
---@return number|nil areaPoiID
local function ResolveInstanceEntrance(instanceID, entrances)
    instanceID = tonumber(instanceID)
    if not instanceID or not entrances or not entrances[1] then
        return nil
    end

    local candidates = FactionCandidates(entrances)
    local bestScore, bestMapID, bestX, bestY, bestContinent, bestPoiID = -1, nil, nil, nil, -1, nil
    for _, row in ipairs(candidates) do
        local uiMapID, x, y
        -- Delve/DB2 doors always have continent mapID + world XY. uiMapID on
        -- those rows is the outdoor zone for POI lookup, not percent coords.
        -- Wowhead fallbacks have uiMapID + 0-100 and no mapID.
        if row.mapID and row.mapID ~= 0 then
            uiMapID, x, y = ResolveWorldPos(row.mapID, row.x, row.y, row.uiMapID)
        elseif row.mapID == nil and row.uiMapID then
            uiMapID, x, y = row.uiMapID, row.x, row.y
        end
        if uiMapID then
            local score = MapPinScore(uiMapID)
            local continentKey = row.mapID or row.uiMapID or 0
            if score > bestScore or (score == bestScore and continentKey > bestContinent) then
                bestScore, bestMapID, bestX, bestY, bestContinent, bestPoiID = score, uiMapID, x, y, continentKey, row.areaPoiID
            end
        end
    end
    if not bestMapID then
        for _, row in ipairs(candidates) do
            if row.areaPoiID then
                local uiMapID, x, y = ResolveAreaPoiPin(row.areaPoiID, row.uiMapID)
                if uiMapID then
                    return uiMapID, x, y, row.areaPoiID
                end
            end
        end
        return nil
    end
    return bestMapID, bestX, bestY, bestPoiID
end

--- Opens the world map on an instance entrance.
--- DB2 rows convert continent MapID + world XY. Fallback rows already have uiMapID + 0-100.
--- Super-tracks the official dungeon/raid pin when the client exposes it on that map.
---@param instanceID number
---@param entrances table|nil
---@param title string|nil
---@return boolean opened
function Navigation:OpenInstanceEntrance(instanceID, entrances, title)
    local bestMapID, bestX, bestY, bestPoiID = ResolveInstanceEntrance(instanceID, entrances)
    if not bestMapID then
        return false
    end

    -- User waypoint is the visible marker (quests use the same path). Official
    -- dungeon/raid AreaPOI super-track is a nicer arrow when the client has one.
    -- TomTom owns the arrow when it is the active provider.
    self:OpenMapPin(bestMapID, bestX, bestY, title)
    if OneWoW.Location.GetActiveProvider() == "tomtom" then
        return true
    end
    if SuperTrackDungeonEntrance(bestMapID, instanceID) then
        return true
    end
    local parent = C_Map.GetMapInfo(bestMapID)
    local parentID = parent and parent.parentMapID
    if parentID and parentID ~= 0 then
        SuperTrackDungeonEntrance(parentID, instanceID)
    end
    if bestPoiID then
        C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, bestPoiID)
    end
    return true
end

--- Saves an instance entrance as a OneWay Pin landmark (Notes).
---@param instData table
---@return string|nil pinID
function Navigation:SaveInstanceEntranceWayPin(instData)
    if not instData or not instData.instanceID then return nil end
    local mapID, x, y = ResolveInstanceEntrance(instData.instanceID, instData.entrances)
    if not mapID then return nil end
    return self:SaveOneWayPin(instData.name, mapID, x, y, "journal", instData.instanceID)
end

function Navigation:IsWayPinsEnabled()
    if not OneWoW_Notes_API then return true end
    return OneWoW_Notes_API.IsWayPinsEnabled()
end

--- First saved pin for this source, sourceKey, and map. Does not load Notes.
---@param source string
---@param sourceKey any
---@param mapID number
---@return string|nil pinID
function Navigation:FindOneWayPin(source, sourceKey, mapID)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.FindWayPin then
        return nil
    end
    if not OneWoW_Notes_API.IsWayPinsEnabled() then
        return nil
    end
    local pin = OneWoW_Notes_API.FindWayPin(source, sourceKey, mapID)
    return pin and pin.id or nil
end

--- Open Notes on the OneWay Pins tab for this pin.
---@param pinID string
function Navigation:OpenOneWayPin(pinID)
    if not pinID then return end
    OneWoW:BringUp("OneWoW_Notes")
    if OneWoW_Notes_API and OneWoW_Notes_API.OpenWayPin then
        OneWoW_Notes_API.OpenWayPin(pinID)
    end
end

--- Persist a landmark in Notes OneWay Pins. Coordinates may be 0-1 or 0-100.
---@param title string
---@param mapID number
---@param x number
---@param y number
---@param source string|nil
---@param sourceKey any
---@return string|nil pinID
function Navigation:SaveOneWayPin(title, mapID, x, y, source, sourceKey)
    if OneWoW_Notes_API and not OneWoW_Notes_API.IsWayPinsEnabled() then
        return nil
    end
    OneWoW:BringUp("OneWoW_Notes")
    if not OneWoW_Notes_API or not OneWoW_Notes_API.AddWayPin then
        return nil
    end
    local fx = OneWoW.Location.ToFraction(x)
    local fy = OneWoW.Location.ToFraction(y)
    if not fx or not fy then return nil end
    return OneWoW_Notes_API.AddWayPin({
        title     = title,
        mapID     = mapID,
        x         = fx * 100,
        y         = fy * 100,
        source    = source or "manual",
        sourceKey = sourceKey,
    })
end

local function NotesHasCoords(coords)
    return type(coords) == "table" and tonumber(coords.x) and tonumber(coords.y)
end

--- Catalog NPC learn payload. Coordinates may be 0-1 or 0-100.
---@param npcInfo table|nil
---@return table
local function CatalogLearnInfo(npcInfo)
    npcInfo = npcInfo or {}
    local mapID = tonumber(npcInfo.mapID)
    if mapID == 0 then
        mapID = nil
    end

    local x, y = npcInfo.x, npcInfo.y
    if NotesHasCoords(npcInfo.coords) then
        x, y = npcInfo.coords.x, npcInfo.coords.y
    end
    x = OneWoW.Location.ToPercent(OneWoW.Location.ToFraction(x))
    y = OneWoW.Location.ToPercent(OneWoW.Location.ToFraction(y))

    local category = npcInfo.category
    if category == "Quest Givers" or category == "Quest Giver" or not category or category == "" then
        category = "quest_giver"
    end

    return {
        name = npcInfo.name,
        zone = npcInfo.zone,
        mapID = mapID,
        x = x,
        y = y,
        category = category,
        roles = npcInfo.roles or { "quest_giver" },
        questID = npcInfo.questID,
        displayID = npcInfo.displayID,
        title = npcInfo.title,
    }
end

--- Opens Catalog NPCs on this creature. Creates the card when NPCDB has no row.
---@param npcID number
---@param npcInfo table|nil  { name, zone, mapID, coords = { x, y }, x, y, category, roles, questID }
---@return boolean opened
function Navigation:OpenNPC(npcID, npcInfo)
    npcID = tonumber(npcID)
    if not npcID then return false end

    local info = CatalogLearnInfo(npcInfo)
    if OneWoW.CatDBSync then
        OneWoW.CatDBSync.LearnNPC(npcID, info)
    end
    OneWoW:EnsureCatalogPack("vendors")
    if ns.UI and ns.UI.OpenToVendor then
        ns.UI.OpenToVendor(npcID, info)
        return true
    end
    return false
end

--- Opens OneWoW_Notes to the given item's note, creating it under the "Quest"
--- category if it does not exist yet. No-op (returns false) when Notes is not
--- installed.
---@param itemID number
---@param itemInfo table|nil  { category }
---@return boolean opened
function Navigation:OpenItemNote(itemID, itemInfo)
    itemID = tonumber(itemID)
    if not itemID then return false end

    -- Full mid-session bring-up (load + lifecycle catch-up); respects soft
    -- opt-out via EnsureLoaded, in which case the Notes API stays nil.
    OneWoW:BringUp("OneWoW_Notes")

    local notesAPI = OneWoW_Notes_API
    if not notesAPI then
        print("|cFFFFD100OneWoW:|r " .. L["NAV_NOTES_UNAVAILABLE"])
        return false
    end

    if not notesAPI.GetItem(itemID) then
        itemInfo = itemInfo or {}
        notesAPI.AddOrUpdateItem(itemID, {
            name     = itemInfo.name,
            link     = itemInfo.link,
            icon     = itemInfo.icon,
            quality  = itemInfo.quality,
            rarity   = itemInfo.rarity or itemInfo.quality,
            category = itemInfo.category or "Quest",
            storage  = itemInfo.storage or "account",
            content  = itemInfo.content,
        })
    end
    return notesAPI.OpenItem(itemID)
end

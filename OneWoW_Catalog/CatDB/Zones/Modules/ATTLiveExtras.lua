-- ============================================================================
-- ATTLiveExtras
-- ============================================================================
-- Live AllTheThings extras overlay. Fallback only: ATT already loaded, and
-- the extra is not already on the shipped card. Never LoadAddOn / EnsureLoaded.
-- Per-card SearchForField only. Shipped-Data: live overlay, not a generator.
-- ============================================================================
local _, ns = ...

local Card = ns.JournalCard
local ATTLive = {}
ns.ATTLiveExtras = ATTLive

local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local tinsert = tinsert
local C_AddOns = C_AddOns

local HEADER_RARES = -46
local HEADER_WORLD_BOSSES = -61

---@param value any
---@return number|nil
local function PositiveMapID(value)
    return type(value) == "number" and value > 0 and value or nil
end

---@param coords table|nil
---@return number|nil
local function MapIDFromCoords(coords)
    if type(coords) ~= "table" then
        return nil
    end
    local first = coords[1]
    if type(first) == "table" then
        return PositiveMapID(first[3] or first.mapID)
    end
    for mapID, points in pairs(coords) do
        if type(mapID) == "number" and mapID > 0 and type(points) == "table" then
            return mapID
        end
    end
    return nil
end

---@param maps table|nil
---@return number|nil
local function MapIDFromMaps(maps)
    if type(maps) ~= "table" then
        return nil
    end
    for i = 1, #maps do
        local id = PositiveMapID(maps[i])
        if id then
            return id
        end
    end
    return nil
end

---@param group table
---@param GetRelativeValue function|nil
---@param fallback number|nil
---@return number|nil
local function ResolveWorldMapID(group, GetRelativeValue, fallback)
    local mapID = MapIDFromCoords(group.coords)
    if mapID then
        return mapID
    end
    if GetRelativeValue then
        mapID = PositiveMapID(GetRelativeValue(group, "mapID") or group.mapID)
        if mapID then
            return mapID
        end
        mapID = MapIDFromCoords(GetRelativeValue(group, "coords"))
        if mapID then
            return mapID
        end
        mapID = MapIDFromMaps(GetRelativeValue(group, "maps") or group.maps)
        if mapID then
            return mapID
        end
    else
        mapID = PositiveMapID(group.mapID) or MapIDFromMaps(group.maps)
        if mapID then
            return mapID
        end
    end
    return PositiveMapID(fallback)
end

---@return table|nil
local function GetATT()
    if not C_AddOns.IsAddOnLoaded("AllTheThings") then
        return nil
    end
    local att = AllTheThings
    if not att or not att.SearchForField then
        return nil
    end
    return att
end

---@param group table
---@param out table
local function CollectItemGroups(group, out)
    if group.itemID then
        tinsert(out, group)
    end
    local kids = group.g
    if kids then
        for i = 1, #kids do
            CollectItemGroups(kids[i], out)
        end
    end
end

---@param group table
---@param out table
local function CollectWorldRareItems(group, out)
    local headerID = group.headerID
    if headerID == HEADER_RARES or headerID == HEADER_WORLD_BOSSES then
        CollectItemGroups(group, out)
        return
    end
    local kids = group.g
    if kids then
        for i = 1, #kids do
            CollectWorldRareItems(kids[i], out)
        end
    end
end

---@param itemID number
---@param encounterID number|nil
---@param npcID number|nil
---@return string
local function LocKey(itemID, encounterID, npcID)
    return (itemID or 0) .. ":" .. (encounterID or 0) .. ":" .. (tonumber(npcID) or 0)
end

---@param inst table
---@return table
local function ExistingLocKeys(inst)
    local seen = {}
    for _, enc in ipairs(inst.encounters or {}) do
        local encID = (enc.encounterID and enc.encounterID > 0) and enc.encounterID or 0
        local npcID = enc.npcID
        for _, item in ipairs(enc.items or {}) do
            if item.itemID then
                seen[LocKey(item.itemID, encID, npcID or item.npcID)] = true
            end
        end
    end
    return seen
end

---@param inst table
---@param groups table|nil
---@param worldOnly boolean
---@param att table
---@param seen table
---@param extras table
local function HarvestGroups(inst, groups, worldOnly, att, seen, extras)
    if not groups then
        return
    end
    local GetRelativeValue = att.GetRelativeValue
    for i = 1, #groups do
        local group = groups[i]
        local harvested = {}
        if worldOnly then
            CollectWorldRareItems(group, harvested)
        else
            CollectItemGroups(group, harvested)
        end
        for j = 1, #harvested do
            local node = harvested[j]
            local itemID = node.itemID
            if itemID then
                local unobtainable = node.u or (GetRelativeValue and GetRelativeValue(node, "u"))
                local loc = {
                    encounterID = GetRelativeValue and GetRelativeValue(node, "encounterID") or 0,
                    instanceID = inst.instanceID,
                    npcID = GetRelativeValue and GetRelativeValue(node, "npcID") or node.npcID,
                    mapID = ResolveWorldMapID(node, GetRelativeValue, inst.mapID),
                    source = "att-live",
                }
                local locKey = LocKey(itemID, loc.encounterID, loc.npcID)
                if not unobtainable and not seen[locKey] then
                    seen[locKey] = true
                    tinsert(extras, {
                        itemID = itemID,
                        itemData = {
                            itemID = itemID,
                            name = node.text or node.name,
                            toyID = node.toyID,
                            mountID = node.mountID,
                            speciesID = node.speciesID,
                            spellID = node.spellID,
                            questID = node.questID,
                            achievementID = node.achievementID,
                            source = "att-live",
                        },
                        difficulties = {},
                        source = "att-live",
                        encounterID = loc.encounterID,
                        instanceID = loc.instanceID,
                        npcID = loc.npcID,
                        mapID = loc.mapID,
                    })
                end
            end
        end
    end
end

--- Append unseen ATT extras onto an already-built card. Safe no-op without ATT.
---@param inst table
---@return boolean added
function ATTLive:MergeLiveATTExtras(inst)
    if not inst or inst.instanceType == "delve" then
        return false
    end
    local att = GetATT()
    if not att then
        return false
    end
    if att.GetDatabaseRoot then
        att:GetDatabaseRoot()
    end

    local seen = ExistingLocKeys(inst)
    local extras = {}
    if inst.instanceType ~= "zone" and inst.instanceID and inst.instanceID > 0 then
        HarvestGroups(inst, att.SearchForField("instanceID", inst.instanceID), false, att, seen, extras)
    end
    if (inst.instanceType == "world" or inst.instanceType == "zone") and inst.mapID then
        HarvestGroups(inst, att.SearchForField("mapID", inst.mapID), true, att, seen, extras)
    end
    if #extras == 0 then
        return false
    end

    local added = false
    for i = 1, #extras do
        if Card.PlaceExtraOnCard(inst, extras[i]) then
            added = true
        end
    end
    if not added then
        return false
    end
    Card.SortEncountersInPlace(inst)
    Card.RecalculateInstanceTotals(inst)
    return true
end

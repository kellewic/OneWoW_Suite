local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

local pairs, ipairs, type = pairs, ipairs, type
local tonumber, tostring, format = tonumber, tostring, string.format
local tinsert, sort, wipe = tinsert, sort, wipe
local C_Item = C_Item
local C_Map = C_Map
local C_Timer = C_Timer
local C_TooltipInfo = C_TooltipInfo
local C_AreaPoiInfo = C_AreaPoiInfo
local C_QuestLog = C_QuestLog
local C_UIWidgetManager = C_UIWidgetManager

-- Public, cross-addon read surface for ZoneDB. ns stays private.
-- Journal-shaped helpers for the Catalog Zones tab. Catalog can
-- swap packs. Cards are views over ns.Places / ns.Encounters, not shard writes.
OneWoW_CatDB_ZoneDB_API = {}

local EXPANSIONS = {
    { expansionID = 1,  displayName = "Classic" },
    { expansionID = 2,  displayName = "The Burning Crusade" },
    { expansionID = 3,  displayName = "Wrath of the Lich King" },
    { expansionID = 4,  displayName = "Cataclysm" },
    { expansionID = 5,  displayName = "Mists of Pandaria" },
    { expansionID = 6,  displayName = "Warlords of Draenor" },
    { expansionID = 7,  displayName = "Legion" },
    { expansionID = 8,  displayName = "Battle for Azeroth" },
    { expansionID = 9,  displayName = "Shadowlands" },
    { expansionID = 10, displayName = "Dragonflight" },
    { expansionID = 11, displayName = "The War Within" },
    { expansionID = 12, displayName = "Midnight" },
}

local expansionNameByID = {}
for _, exp in ipairs(EXPANSIONS) do
    expansionNameByID[exp.expansionID] = exp.displayName
end

local cardsByKey = {}
local dropIndex
local dropNameIndex
local achievementIndex
local bountifulMapIDs = {}
local storyByMapID = {}
local mapNameCache = {}
local placeByInstanceID
local placeByUiMapID

local COLLECTIBLES_SPECIAL_TYPES = {
    TMog = true, Mount = true, Pet = true, Toy = true, Recipe = true, Housing = true,
}

-- Synthetic encounterIDs from bin/lib/catdb_zone.py. Journal rows use the
-- same grouping: named bosses, per-NPC World Rares, General Loot leftovers.
local RARE_BASE = 10000000
local GENERAL_MIN = 20000000
local WORLD_BOSSES_SECTION_ID = -10
local WORLD_RARES_SECTION_ID = -11
local ACHIEVEMENT_ENC_ID = -2
local QUEST_ENC_ID = -3

local function ExpansionName(expansionID)
    return expansionNameByID[expansionID] or OneWoW:GetExpansionName(expansionID) or ""
end

local function ParsePlaceKey(placeKey)
    if type(placeKey) ~= "string" then
        return nil, nil
    end
    local kind, id = placeKey:match("^(%a+):(%d+)$")
    return kind, tonumber(id)
end

local function PlaceInstanceID(placeKey, place)
    if place.instanceID then
        return place.instanceID
    end
    local kind, keyID = ParsePlaceKey(placeKey)
    if kind == "world" then
        return 0
    end
    return keyID or place.mapID
end

---@param expansionID number
---@param instanceID number|nil
---@param instanceType string|nil
---@return string
local function CacheKey(expansionID, instanceID, instanceType)
    if instanceType == "delve" then
        return tostring(expansionID) .. ":delve:" .. tostring(instanceID)
    end
    if instanceType == "zone" then
        return tostring(expansionID) .. ":zone:" .. tostring(instanceID)
    end
    if instanceType == "world" and (not instanceID or instanceID == 0) then
        return tostring(expansionID) .. ":world"
    end
    return tostring(expansionID) .. ":" .. tostring(instanceID)
end

---@param place table
---@return table
local function PlaceExpansions(place)
    local expansions = place.expansions
    if type(expansions) == "table" and #expansions > 0 then
        return expansions
    end
    return { place.expansion }
end

--- Place.expansions plus ListingOverrides.forceShow keys for this instance.
---@param placeKey string
---@param place table
---@return table
local function ListingExpansions(placeKey, place)
    local seen = {}
    local out = {}
    local function add(expID)
        if expID and not seen[expID] then
            seen[expID] = true
            tinsert(out, expID)
        end
    end
    local expansions = PlaceExpansions(place)
    for i = 1, #expansions do
        add(expansions[i])
    end
    local overrides = ns.ListingOverrides
    if overrides and overrides.forceShow then
        local instanceID = PlaceInstanceID(placeKey, place)
        local instanceType = place.instanceType
        for key in pairs(overrides.forceShow) do
            local expID = tonumber((tostring(key)):match("^(%d+):"))
            if expID then
                local suffix = tostring(key):match("^%d+:(.+)$")
                if instanceType == "world" and suffix == "world" then
                    add(expID)
                elseif instanceType == "delve" and suffix == ("delve:" .. tostring(instanceID)) then
                    add(expID)
                elseif instanceType == "zone" and suffix == ("zone:" .. tostring(instanceID)) then
                    add(expID)
                elseif suffix == tostring(instanceID) then
                    add(expID)
                end
            end
        end
    end
    return out
end

---@param encounterIDs table|nil
---@return number
local function CountBosses(encounterIDs)
    if not encounterIDs then
        return 0
    end
    local n = 0
    for i = 1, #encounterIDs do
        if encounterIDs[i] > 0 and encounterIDs[i] < RARE_BASE then
            n = n + 1
        end
    end
    return n
end

---@param encounterIDs table|nil
---@return number
local function CountRares(encounterIDs)
    if not encounterIDs then
        return 0
    end
    local n = 0
    for i = 1, #encounterIDs do
        local id = encounterIDs[i]
        if id >= RARE_BASE and id < GENERAL_MIN then
            local enc = ns.Encounters[id]
            local loot = enc and enc.loot
            if loot and #loot > 0 then
                n = n + 1
            end
        end
    end
    return n
end

---@param encounterIDs table|nil
---@return number
local function CountPlaceLoot(encounterIDs)
    if not encounterIDs then
        return 0
    end
    local seen = {}
    local n = 0
    for i = 1, #encounterIDs do
        local enc = ns.Encounters[encounterIDs[i]]
        local loot = enc and enc.loot
        if loot then
            for j = 1, #loot do
                local itemID = loot[j].itemID
                if itemID and not seen[itemID] then
                    seen[itemID] = true
                    n = n + 1
                end
            end
        end
    end
    return n
end

---@param ids table|nil
---@return table
local function AchievementRows(ids)
    local rows = {}
    if not ids then
        return rows
    end
    for i = 1, #ids do
        tinsert(rows, { id = ids[i] })
    end
    return rows
end

--- Catalog GetCachedItem shape. Quality is a number (GetItemQualityByID / ItemDB),
--- never GetItemInfoInstant's itemSubType (e.g. "Elixirs").
---@param itemID number
---@return table|nil
local function ItemSnapshot(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end
    if ns.DataLoader then
        local cached = ns.DataLoader:GetCachedItem(itemID)
        if cached then
            return cached
        end
    end
    local itemAPI = OneWoW_CatDB_ItemDB_API
    if itemAPI then
        local rec = itemAPI.GetItem(itemID)
        if rec then
            local name = rec.name or itemAPI.GetItemName(itemID)
            if name then
                local quality = rec.quality
                if type(quality) ~= "number" then
                    quality = C_Item.GetItemQualityByID(itemID)
                end
                return {
                    name = name,
                    quality = quality,
                    icon = rec.icon or C_Item.GetItemIconByID(itemID),
                }
            end
        end
        local shipped = itemAPI.GetItemName(itemID)
        if shipped then
            return {
                name = shipped,
                quality = C_Item.GetItemQualityByID(itemID),
                icon = C_Item.GetItemIconByID(itemID),
            }
        end
    end
    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        return nil
    end
    return {
        name = name,
        quality = C_Item.GetItemQualityByID(itemID),
        icon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID)),
    }
end

local function IsHidden(cacheKey, expansionID, instanceID)
    local overrides = ns.ListingOverrides
    if not overrides or not overrides.forceHide then
        return false
    end
    if cacheKey and overrides.forceHide[cacheKey] then
        return true
    end
    return overrides.forceHide[tostring(expansionID) .. ":" .. tostring(instanceID)] == true
end

---@param placeKey string
---@param expansionID number|nil
---@return table|nil
local function GetCard(placeKey, expansionID)
    local place = ns.Places[placeKey]
    if not place then
        return nil
    end
    expansionID = expansionID or place.expansion
    local storeKey = tostring(expansionID) .. "\0" .. placeKey
    local card = cardsByKey[storeKey]
    if card then
        return card
    end
    local instanceID = PlaceInstanceID(placeKey, place)
    local instanceType = place.instanceType
    local cacheKey = CacheKey(expansionID, instanceID, instanceType)
    if IsHidden(cacheKey, expansionID, instanceID) then
        return nil
    end
    local orderIndex = place.order or 0
    local membership = ns.TierMembership[expansionID]
    if membership and instanceID and membership[instanceID] ~= nil then
        orderIndex = membership[instanceID]
    end
    card = {
        placeKey = placeKey,
        cacheKey = cacheKey,
        name = place.name,
        expansionID = expansionID,
        expansionName = ExpansionName(expansionID),
        instanceID = instanceID,
        instanceType = instanceType,
        kind = place.kind,
        mapID = place.mapID or place.uiMapID,
        uiMapID = place.uiMapID,
        parentUiMapID = place.parentUiMapID,
        orderIndex = orderIndex,
        entrance = place.entrance,
        entrances = place.entrance,
        isCity = place.isCity,
        encounterIDs = place.encounterIDs,
        encounters = {},
        encountersHydrated = false,
        bossCount = CountBosses(place.encounterIDs),
        rareCount = CountRares(place.encounterIDs),
        totalItems = CountPlaceLoot(place.encounterIDs),
        validDifficulties = place.difficultyIDs,
        achievements = AchievementRows(place.achievementIDs),
    }
    cardsByKey[storeKey] = card
    return card
end

local function InstancePassesTypeFilter(inst, instanceTypeFilter)
    if not instanceTypeFilter or instanceTypeFilter == "all" then
        return true
    end
    if instanceTypeFilter == "city" then
        return inst.instanceType == "zone" and inst.isCity
    end
    if instanceTypeFilter == "zone" then
        return inst.instanceType == "zone" and not inst.isCity
    end
    return inst.instanceType == instanceTypeFilter
end

local function ItemSpecial(itemID, lootRow)
    if lootRow and lootRow.achievementID then
        local itemAPI = OneWoW_CatDB_ItemDB_API
        return "Achievement", itemAPI and itemAPI.GetItem(itemID)
    end
    local itemAPI = OneWoW_CatDB_ItemDB_API
    local rec = itemAPI and itemAPI.GetItem(itemID)
    if not rec then
        return nil, nil
    end
    if rec.isTransmog then
        return "TMog", rec
    end
    if rec.speciesID then
        return "Pet", rec
    end
    if rec.mountID then
        return "Mount", rec
    end
    if rec.isToy or rec.toyID then
        return "Toy", rec
    end
    if rec.classID == Enum.ItemClass.Recipe then
        return "Recipe", rec
    end
    if rec.classID == Enum.ItemClass.Questitem then
        return "Quest", rec
    end
    if rec.classID == Enum.ItemClass.Housing then
        return "Housing", rec
    end
    if rec.classID == Enum.ItemClass.Battlepet then
        return "Pet", rec
    end
    return nil, rec
end

---@param questIDs table
---@return table
local function QuestSourcesFromIDs(questIDs)
    local sources = {}
    if type(questIDs) ~= "table" or #questIDs == 0 then
        return sources
    end
    local questAPI = OneWoW:GetCatalogPackAPI("quests")
    for i = 1, #questIDs do
        local questID = tonumber(questIDs[i])
        if questID then
            local quest = questAPI and questAPI.GetQuest(questID)
            tinsert(sources, {
                id = questID,
                faction = quest and quest.faction,
            })
        end
    end
    return sources
end

--- Loot.diffs mixed leftover quest IDs with difficulties. Keep IDs only.
---@param lootRow table
---@return table
local function LootQuestSources(lootRow)
    if type(lootRow.questSources) == "table" and lootRow.questSources[1] then
        return lootRow.questSources
    end
    local ids = {}
    if lootRow.questID then
        tinsert(ids, lootRow.questID)
    end
    if type(lootRow.questIDs) == "table" then
        for i = 1, #lootRow.questIDs do
            tinsert(ids, lootRow.questIDs[i])
        end
    end
    local diffs = lootRow.diffs
    if type(diffs) == "table" then
        for i = 1, #diffs do
            local entry = diffs[i]
            local did = (type(entry) == "table" and entry.id) or entry
            did = tonumber(did)
            if did and not ns.Difficulties[did] then
                tinsert(ids, did)
            end
        end
    end
    return QuestSourcesFromIDs(ids)
end

---@param diffIDs table|nil
---@return table
local function KnownDifficultyIDs(diffIDs)
    local out = {}
    if type(diffIDs) ~= "table" then
        return out
    end
    for i = 1, #diffIDs do
        local entry = diffIDs[i]
        local did = (type(entry) == "table" and entry.id) or entry
        if did and ns.Difficulties[did] then
            tinsert(out, did)
        end
    end
    return out
end

---@param diffIDs table|nil
---@return table
local function DiffRowsFromIDs(diffIDs)
    local rows = {}
    if type(diffIDs) ~= "table" then
        return rows
    end
    for i = 1, #diffIDs do
        local entry = diffIDs[i]
        if type(entry) == "table" and entry.id then
            tinsert(rows, entry)
        else
            local did = entry
            local meta = ns.Difficulties[did]
            local name = (meta and meta.name) or GetDifficultyInfo(did)
            tinsert(rows, { id = did, name = name or ("Difficulty " .. tostring(did)) })
        end
    end
    return rows
end

---@param enc table
---@return table
local function BuildEncounterItems(enc)
    local items = {}
    local loot = enc.loot
    if not loot then
        return items
    end
    for i = 1, #loot do
        local row = loot[i]
        local itemID = row.itemID
        if itemID then
            local questSources = LootQuestSources(row)
            local special, itemData = ItemSpecial(itemID, row)
            local snap = ItemSnapshot(itemID)
            local diffs = KnownDifficultyIDs(row.diffs)
            if #diffs == 0 then
                diffs = KnownDifficultyIDs(enc.difficultyIDs)
            end
            tinsert(items, {
                itemID = itemID,
                difficulties = DiffRowsFromIDs(diffs),
                special = special,
                itemData = itemData or snap,
                questSources = questSources,
                name = (snap and snap.name) or L["JOURNAL_UNKNOWN_ITEM"],
                nameResolved = snap ~= nil and snap.name ~= nil,
                icon = (snap and snap.icon) or 134400,
                quality = (snap and snap.quality) or 1,
            })
        end
    end
    sort(items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return items
end

---@param encounterID number|nil
---@return string
local function ClassifyEncounterID(encounterID)
    if not encounterID then
        return "general"
    end
    if encounterID >= GENERAL_MIN then
        return "general"
    end
    if encounterID >= RARE_BASE then
        return "rare"
    end
    if encounterID > 0 then
        return "boss"
    end
    return "general"
end

---@param inst table
---@return boolean
local function UsesWorldLayout(inst)
    return inst.instanceType == "world" or inst.instanceType == "zone"
end

---@param enc table
---@return number
local function EncounterSortRank(enc)
    if enc.sectionHeader then
        if enc.encounterID == WORLD_BOSSES_SECTION_ID then
            return 0
        end
        if enc.encounterID == WORLD_RARES_SECTION_ID then
            return 2
        end
    end
    if enc.worldRare then
        return 3
    end
    if enc.encounterID == ACHIEVEMENT_ENC_ID then
        return 5
    end
    if enc.encounterID == QUEST_ENC_ID or enc.questCategory then
        return 6
    end
    if enc.extrasCategory or enc.encounterID == 0 then
        return 7
    end
    return 1
end

---@param a table
---@param b table
---@return boolean
local function SortEncounters(a, b)
    local ra, rb = EncounterSortRank(a), EncounterSortRank(b)
    if ra ~= rb then
        return ra < rb
    end
    local ai = a.bossIndex or 999
    local bi = b.bossIndex or 999
    if ai ~= bi then
        return ai < bi
    end
    return (a.name or "") < (b.name or "")
end

---@param npcID number|nil
---@param shippedName string|nil
---@return string
---@return boolean resolved
local function ResolveRareName(npcID, shippedName)
    if type(shippedName) == "string" and shippedName ~= "" then
        return shippedName, true
    end
    npcID = tonumber(npcID)
    if not npcID then
        return L["JOURNAL_UNKNOWN_INST"], false
    end
    local npcAPI = OneWoW_CatDB_NPCDB_API
    if npcAPI then
        local name = npcAPI.GetCachedNPCName(npcID)
        if name and name ~= "" then
            return name, true
        end
    end
    return format(L["JOURNAL_NPC_UNNAMED"], npcID), false
end

---@param items table
---@return table
local function LeftoverEncounter(items)
    return {
        encounterID = 0,
        name = L["JOURNAL_GENERAL_LOOT"],
        nameResolved = true,
        bossIndex = 999,
        items = items,
        extrasCategory = true,
    }
end

---@param encounterID number
---@param name string
---@return table
local function SectionHeader(encounterID, name)
    return {
        encounterID = encounterID,
        name = name,
        nameResolved = true,
        bossIndex = 0,
        items = {},
        sectionHeader = true,
    }
end

---@param mapID number|nil
---@return string|nil
local function MapName(mapID)
    if type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end
    local cached = mapNameCache[mapID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local info = C_Map.GetMapInfo(mapID)
    local name = info and info.name
    mapNameCache[mapID] = name or false
    return name
end

local function EnsurePlaceLookups()
    if placeByInstanceID then
        return
    end
    placeByInstanceID = {}
    placeByUiMapID = {}
    for placeKey, place in pairs(ns.Places) do
        local kind, keyID = ParsePlaceKey(placeKey)
        if (kind == "instance" or kind == "delve" or kind == "hub") and keyID then
            placeByInstanceID[keyID] = placeKey
        elseif kind == "zone" and keyID then
            placeByUiMapID[keyID] = placeKey
        end
        local instanceID = place.instanceID
        if instanceID and instanceID > 0 and not placeByInstanceID[instanceID] then
            placeByInstanceID[instanceID] = placeKey
        end
        local uiMapID = place.uiMapID
        if kind == "zone" and uiMapID and uiMapID > 0 then
            placeByUiMapID[uiMapID] = placeKey
        end
    end
end

---@param enc table
---@return string|nil placeKey
local function PlaceKeyForEncounter(enc)
    EnsurePlaceLookups()
    local uiMapID = enc.uiMapID
    if uiMapID and uiMapID > 0 then
        local key = placeByUiMapID[uiMapID]
        if key then
            return key
        end
    end
    local instanceID = enc.instanceID
    if instanceID and instanceID > 0 then
        return placeByInstanceID[instanceID]
    end
    return nil
end

local function AddAchievementForItem(itemID, achievementID)
    achievementID = tonumber(achievementID)
    if not itemID or not achievementID then
        return
    end
    local set = achievementIndex[itemID]
    if not set then
        set = {}
        achievementIndex[itemID] = set
    end
    set[achievementID] = true
end

local function EnsureDropIndex()
    if dropIndex then
        return
    end
    dropIndex = {}
    achievementIndex = {}
    EnsurePlaceLookups()
    for encounterID, enc in pairs(ns.Encounters) do
        local loot = enc.loot
        if loot then
            local placeKey = PlaceKeyForEncounter(enc)
            local place = placeKey and ns.Places[placeKey]
            local npcIDs = enc.npcIDs
            for i = 1, #loot do
                local row = loot[i]
                local itemID = row.itemID
                if itemID then
                    local diffs = row.diffs
                    if type(diffs) ~= "table" or #diffs == 0 then
                        diffs = enc.difficultyIDs
                    end
                    local list = dropIndex[itemID]
                    if not list then
                        list = {}
                        dropIndex[itemID] = list
                    end
                    tinsert(list, {
                        placeKey = placeKey,
                        instanceID = enc.instanceID,
                        instanceType = place and place.instanceType,
                        uiMapID = enc.uiMapID,
                        instanceName = place and place.name,
                        encounterID = encounterID,
                        encounterName = enc.name,
                        npcID = npcIDs and npcIDs[1],
                        difficulties = DiffRowsFromIDs(diffs),
                    })
                    AddAchievementForItem(itemID, row.achievementID)
                end
            end
        end
    end
end

local function CreatureHyperlink(npcID)
    return ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
end

--- Returns the store settings.
---@return table settings
function OneWoW_CatDB_ZoneDB_API.GetSettings()
    return ns:GetSettings()
end

--- One place row by place key (for example "instance:63" or "zone:84").
---@param placeKey string
---@return table|nil place
function OneWoW_CatDB_ZoneDB_API.GetPlace(placeKey)
    return ns.Places[placeKey]
end

--- One encounter row by encounterID.
---@param encounterID number
---@return table|nil encounter
function OneWoW_CatDB_ZoneDB_API.GetEncounter(encounterID)
    return ns.Encounters[encounterID]
end

--- Places sorted for the Catalog Zones / Journal tab.
---@param expansionFilter number|nil
---@param searchText string|nil
---@param instanceTypeFilter string|nil
---@return table instances
function OneWoW_CatDB_ZoneDB_API.GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
    local result = {}
    local search = searchText and searchText:lower() or ""
    for placeKey, place in pairs(ns.Places) do
        local expansions = ListingExpansions(placeKey, place)
        for i = 1, #expansions do
            local inst = GetCard(placeKey, expansions[i])
            if inst then
                local passesExpansion = (not expansionFilter or expansionFilter == 0 or inst.expansionID == expansionFilter)
                local passesSearch = (search == ""
                    or (inst.name and inst.name:lower():find(search, 1, true))
                    or (inst.expansionName and inst.expansionName:lower():find(search, 1, true)))
                if passesExpansion and passesSearch and InstancePassesTypeFilter(inst, instanceTypeFilter) then
                    tinsert(result, inst)
                end
            end
        end
    end
    sort(result, function(a, b)
        if a.expansionID ~= b.expansionID then
            return (a.expansionID or 0) > (b.expansionID or 0)
        end
        if (a.orderIndex or 0) ~= (b.orderIndex or 0) then
            return (a.orderIndex or 0) < (b.orderIndex or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    return result
end

--- Expansion IDs that have at least one place row.
---@param typeFilter string|nil
---@return table expansions
function OneWoW_CatDB_ZoneDB_API.GetAvailableExpansions(typeFilter)
    local present = {}
    for placeKey, place in pairs(ns.Places) do
        local expansions = ListingExpansions(placeKey, place)
        for i = 1, #expansions do
            local inst = GetCard(placeKey, expansions[i])
            if inst and InstancePassesTypeFilter(inst, typeFilter) then
                present[inst.expansionID] = true
            end
        end
    end
    local result = {}
    for _, exp in ipairs(EXPANSIONS) do
        if present[exp.expansionID] then
            tinsert(result, { expansionID = exp.expansionID, displayName = exp.displayName })
        end
    end
    return result
end

--- Preferred place for a world map ID (highest expansion; not a zone card).
---@param mapID number
---@return table|nil place
function OneWoW_CatDB_ZoneDB_API.GetInstanceByMapID(mapID)
    local all = OneWoW_CatDB_ZoneDB_API.GetInstancesByMapID(mapID)
    if #all == 0 then
        return nil
    end
    local inst = all[#all]
    OneWoW_CatDB_ZoneDB_API.EnsureEncounters(inst)
    return inst
end

--- Zone / city card for a UiMap ID.
---@param expansionID number|nil
---@param mapID number
---@return table|nil place
function OneWoW_CatDB_ZoneDB_API.GetZoneInstance(expansionID, mapID)
    if not mapID then
        return nil
    end
    local best
    for placeKey, place in pairs(ns.Places) do
        if place.instanceType == "zone" and (place.mapID == mapID or place.uiMapID == mapID) then
            if expansionID then
                local expansions = ListingExpansions(placeKey, place)
                for i = 1, #expansions do
                    if expansions[i] == expansionID then
                        local card = GetCard(placeKey, expansionID)
                        if card then
                            return card
                        end
                    end
                end
            end
            if not best then
                best = GetCard(placeKey)
            end
        end
    end
    return best
end

--- All instance cards for a world map ID.
---@param mapID number
---@return table places
function OneWoW_CatDB_ZoneDB_API.GetInstancesByMapID(mapID)
    local out = {}
    if not mapID then
        return out
    end
    for placeKey, place in pairs(ns.Places) do
        if place.instanceType ~= "zone" and (place.mapID == mapID or place.uiMapID == mapID) then
            local expansions = ListingExpansions(placeKey, place)
            for i = 1, #expansions do
                local card = GetCard(placeKey, expansions[i])
                if card then
                    tinsert(out, card)
                end
            end
        end
    end
    sort(out, function(a, b)
        return (a.expansionID or 0) < (b.expansionID or 0)
    end)
    return out
end

--- Instance / encounter names for every place an item drops.
---@param itemID number
---@return table drops
function OneWoW_CatDB_ZoneDB_API.GetItemDropLocations(itemID)
    local out = {}
    if not itemID then
        return out
    end
    EnsureDropIndex()
    local rows = dropIndex[itemID]
    if not rows then
        return out
    end
    local seen = {}
    for i = 1, #rows do
        local row = rows[i]
        local key = tostring(row.instanceID) .. ":" .. tostring(row.encounterID)
        if not seen[key] then
            seen[key] = true
            local instanceName = row.instanceName
            if (not instanceName or instanceName == "") and row.uiMapID then
                instanceName = MapName(row.uiMapID)
            end
            local encounterName = row.encounterName
            if (not encounterName or encounterName == "") and row.npcID then
                local npcAPI = OneWoW_CatDB_NPCDB_API
                encounterName = npcAPI and npcAPI.GetCachedNPCName(row.npcID)
            end
            local encKind = ClassifyEncounterID(row.encounterID)
            tinsert(out, {
                placeKey = row.placeKey,
                instanceID = row.instanceID,
                instanceType = row.instanceType,
                instanceName = instanceName,
                encounterID = row.encounterID,
                encounterName = encounterName,
                uiMapID = row.uiMapID,
                npcID = row.npcID,
                worldRare = encKind == "rare",
                difficulties = row.difficulties,
            })
        end
    end
    return out
end

--- Achievement IDs for this item (ItemDB join, plus any loot.achievementID).
---@param itemID number
---@return number[]
function OneWoW_CatDB_ZoneDB_API.GetAchievementsForItem(itemID)
    local out = {}
    if not itemID then
        return out
    end
    local seen = {}
    local itemAPI = OneWoW_CatDB_ItemDB_API
    if itemAPI then
        local shipped = itemAPI.GetAchievementsForItem(itemID)
        for i = 1, #shipped do
            local achievementID = shipped[i]
            if not seen[achievementID] then
                seen[achievementID] = true
                tinsert(out, achievementID)
            end
        end
    end
    EnsureDropIndex()
    local set = achievementIndex[itemID]
    if set then
        for achievementID in pairs(set) do
            if not seen[achievementID] then
                seen[achievementID] = true
                tinsert(out, achievementID)
            end
        end
    end
    sort(out)
    return out
end

--- Place card for a Journal instanceID. Does not walk all places after the
--- first EnsurePlaceLookups.
---@param instanceID number
---@return table|nil place
function OneWoW_CatDB_ZoneDB_API.GetInstanceByInstanceID(instanceID)
    instanceID = tonumber(instanceID)
    if not instanceID or instanceID <= 0 then
        return nil
    end
    EnsurePlaceLookups()
    local placeKey = placeByInstanceID[instanceID]
    if not placeKey then
        return nil
    end
    local inst = GetCard(placeKey)
    if inst then
        OneWoW_CatDB_ZoneDB_API.EnsureEncounters(inst)
    end
    return inst
end

--- Place card for a shipped place key (for example "instance:63").
---@param placeKey string
---@param expansionID number|nil
---@return table|nil place
function OneWoW_CatDB_ZoneDB_API.GetInstanceByPlaceKey(placeKey, expansionID)
    if type(placeKey) ~= "string" or placeKey == "" then
        return nil
    end
    local inst = GetCard(placeKey, expansionID)
    if inst then
        OneWoW_CatDB_ZoneDB_API.EnsureEncounters(inst)
    end
    return inst
end

--- Drop name index if Item Search or another tab already built it. Never builds.
---@return table<number, string>|nil
function OneWoW_CatDB_ZoneDB_API.GetItemNameIndexIfReady()
    return dropNameIndex
end

--- Flat itemID -> name for journal drops only (old Journal GetItemNameIndex).
--- ItemDB is the name lookup; walking all ItemDB rows here made Item Search
--- treat every item as a drop and stall.
---@return table<number, string>
function OneWoW_CatDB_ZoneDB_API.GetItemNameIndex()
    if dropNameIndex then
        return dropNameIndex
    end
    EnsureDropIndex()
    dropNameIndex = {}
    local itemAPI = OneWoW_CatDB_ItemDB_API
    for itemID in pairs(dropIndex) do
        local name
        if itemAPI then
            name = itemAPI.GetItemName(itemID)
        end
        if type(name) == "string" and name ~= "" then
            dropNameIndex[itemID] = name
        end
    end
    return dropNameIndex
end

local TEXT_WITH_STATE = Enum.UIWidgetVisualizationType.TextWithState

---@param info table|nil
---@return string|nil
local function ReadStoryWidgetText(info)
    if not info or not info.tooltipWidgetSet then
        return nil
    end
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(info.tooltipWidgetSet)
    if not widgets then
        return nil
    end
    for i = 1, #widgets do
        local widget = widgets[i]
        if widget.widgetType == TEXT_WITH_STATE then
            local viz = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widget.widgetID)
            if viz and viz.orderIndex == 0 and viz.text and viz.text ~= "" then
                return viz.text
            end
        end
    end
    return nil
end

---@param delveMapID number
---@param info table|nil
local function AbsorbLivePOI(delveMapID, info)
    if not info then
        return
    end
    local atlas = info.atlasName
    if atlas and atlas:lower():find("bountiful", 1, true) then
        bountifulMapIDs[delveMapID] = true
    end
    if not storyByMapID[delveMapID] then
        local text = ReadStoryWidgetText(info)
        if text then
            storyByMapID[delveMapID] = text
        end
    end
end

function OneWoW_CatDB_ZoneDB_API.RefreshBountiful()
    wipe(bountifulMapIDs)
    wipe(storyByMapID)
    for _, place in pairs(ns.Places) do
        if place.instanceType == "delve" and place.entrance then
            for i = 1, #place.entrance do
                local ent = place.entrance[i]
                local uiMapID = ent.uiMapID
                if uiMapID then
                    if ent.bountifulPoiID then
                        local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, ent.bountifulPoiID)
                        if info then
                            bountifulMapIDs[place.mapID] = true
                            AbsorbLivePOI(place.mapID, info)
                        end
                    end
                    if ent.areaPoiID then
                        AbsorbLivePOI(place.mapID, C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, ent.areaPoiID))
                    end
                end
            end
        end
    end
end

---@param mapID number|nil
---@return boolean
function OneWoW_CatDB_ZoneDB_API.IsDelveBountiful(mapID)
    return mapID ~= nil and bountifulMapIDs[mapID] == true
end

---@param mapID number|nil
---@return string|nil
function OneWoW_CatDB_ZoneDB_API.GetDelveStoryText(mapID)
    return mapID and storyByMapID[mapID] or nil
end

---@param itemData table|nil
---@param itemID number|nil
---@return number|nil
local function ResolveQuestIDFromItemData(itemData, itemID)
    if itemData then
        local questID = tonumber(itemData.questID or itemData.questId)
        if questID then
            return questID
        end
        local sources = itemData.questSources
        if type(sources) == "table" then
            local faction = UnitFactionGroup("player")
            local fallback
            for i = 1, #sources do
                local qs = sources[i]
                local id = tonumber(type(qs) == "table" and qs.id or qs)
                if id then
                    if not fallback then
                        fallback = id
                    end
                    if type(qs) == "table" and qs.faction == faction then
                        return id
                    end
                end
            end
            if fallback then
                return fallback
            end
        end
    end
    if itemID then
        local questAPI = OneWoW:GetCatalogPackAPI("quests")
        local ids = questAPI and questAPI.GetQuestsRewardingItem(itemID)
        if type(ids) == "table" then
            return tonumber(ids[1])
        end
    end
    return nil
end

---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return boolean|nil
function OneWoW_CatDB_ZoneDB_API.IsItemCollected(itemID, itemData, specialType)
    if not specialType then
        return nil
    end
    if specialType == "Quest" then
        local questID = ResolveQuestIDFromItemData(itemData, itemID)
        if not questID then
            return nil
        end
        local questAPI = OneWoW:GetCatalogPackAPI("quests")
        if questAPI then
            return questAPI.IsCompletedByCurrentChar(questID) == true
        end
        return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
    end
    if not itemID or not COLLECTIBLES_SPECIAL_TYPES[specialType] then
        return nil
    end
    local status = OneWoW.Collectibles.GetItemCollectionStatus(itemID)
    if status and status.applicable then
        return status.collected == true
    end
    if status then
        return nil
    end
    if specialType == "Recipe" then
        return nil
    end
    return false
end

---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return string|nil
function OneWoW_CatDB_ZoneDB_API.DetermineItemStatus(itemID, itemData, specialType)
    if not specialType then
        return nil
    end
    local collected = OneWoW_CatDB_ZoneDB_API.IsItemCollected(itemID, itemData, specialType)
    if collected == nil then
        return nil
    end
    if specialType == "TMog" then
        return collected and COLLECTED or NOT_COLLECTED
    end
    return collected and COLLECTED or NOT_COLLECTED
end

function OneWoW_CatDB_ZoneDB_API.ClearCache()
    wipe(cardsByKey)
    dropIndex = nil
    dropNameIndex = nil
    achievementIndex = nil
    placeByInstanceID = nil
    placeByUiMapID = nil
    ns.EJLiveLoot:OnJournalCacheCleared()
end

function OneWoW_CatDB_ZoneDB_API.RefreshLiveJournalLoot()
    OneWoW_CatDB_ZoneDB_API.ClearCache()
end

---@param inst table
---@return table inst
function OneWoW_CatDB_ZoneDB_API.EnsureEncounters(inst)
    if not inst then
        return inst
    end
    -- ItemSpecial classifies TMog / Mount / Recipe / ... from ItemDB.
    -- Catalog stores are lazy; toast and ESC pull journal without opening Catalog.
    OneWoW:EnsureCatalogPack("items")
    if inst.encountersHydrated then
        return inst
    end
    local bosses, rares, leftoverItems = {}, {}, {}
    local ids = inst.encounterIDs
    if ids then
        for i = 1, #ids do
            local encID = ids[i]
            local enc = ns.Encounters[encID]
            if enc then
                local items = BuildEncounterItems(enc)
                if #items > 0 then
                    local kind = ClassifyEncounterID(encID)
                    if kind == "general" then
                        for j = 1, #items do
                            tinsert(leftoverItems, items[j])
                        end
                    elseif kind == "rare" then
                        local npcIDs = enc.npcIDs
                        local npcID = npcIDs and npcIDs[1] or (encID - RARE_BASE)
                        local name, resolved = ResolveRareName(npcID, enc.name)
                        tinsert(rares, {
                            encounterID = encID,
                            name = name,
                            nameResolved = resolved,
                            items = items,
                            order = enc.order or 0,
                            bossIndex = 0,
                            npcID = npcID,
                            npcIDs = npcIDs,
                            displayID = enc.displayIDs and enc.displayIDs[1],
                            displayIDs = enc.displayIDs,
                            worldRare = true,
                            zoneMapID = enc.uiMapID,
                            pin = enc.pin,
                        })
                    else
                        local npcIDs = enc.npcIDs
                        local encName = enc.name
                        tinsert(bosses, {
                            encounterID = enc.encounterID or encID,
                            name = (encName and encName ~= "") and encName or L["JOURNAL_UNKNOWN_INST"],
                            nameResolved = encName ~= nil and encName ~= "",
                            items = items,
                            order = enc.order,
                            bossIndex = enc.order,
                            npcID = npcIDs and npcIDs[1],
                            npcIDs = npcIDs,
                            displayID = enc.displayIDs and enc.displayIDs[1],
                            displayIDs = enc.displayIDs,
                            zoneMapID = enc.uiMapID,
                            pin = enc.pin,
                        })
                    end
                end
            end
        end
    end

    if #leftoverItems > 1 then
        sort(leftoverItems, function(a, b)
            return (a.name or "") < (b.name or "")
        end)
    end

    local encounters = {}
    for i = 1, #bosses do
        tinsert(encounters, bosses[i])
    end
    for i = 1, #rares do
        tinsert(encounters, rares[i])
    end
    if UsesWorldLayout(inst) then
        if #bosses > 0 then
            tinsert(encounters, SectionHeader(WORLD_BOSSES_SECTION_ID, L["JOURNAL_WORLD_BOSSES"]))
        end
        if #rares > 0 then
            tinsert(encounters, SectionHeader(WORLD_RARES_SECTION_ID, L["JOURNAL_WORLD_RARES"]))
        end
    end
    local leftoverGeneral, leftoverQuest, leftoverAch = {}, {}, {}
    for i = 1, #leftoverItems do
        local item = leftoverItems[i]
        if item.questSources and item.questSources[1] then
            tinsert(leftoverQuest, item)
        elseif item.special == "Achievement" then
            tinsert(leftoverAch, item)
        else
            tinsert(leftoverGeneral, item)
        end
    end
    if #leftoverGeneral > 0 then
        tinsert(encounters, LeftoverEncounter(leftoverGeneral))
    end
    if #leftoverAch > 0 then
        tinsert(encounters, {
            encounterID = ACHIEVEMENT_ENC_ID,
            name = L["ACHIEVEMENT"],
            nameResolved = true,
            bossIndex = 0,
            items = leftoverAch,
        })
    end
    if #leftoverQuest > 0 then
        tinsert(encounters, {
            encounterID = QUEST_ENC_ID,
            name = L["JOURNAL_QUEST_LOOT"],
            nameResolved = true,
            bossIndex = 0,
            items = leftoverQuest,
            questCategory = true,
        })
    end
    sort(encounters, SortEncounters)

    inst.encounters = encounters
    inst.encountersHydrated = true
    inst.bossCount = #bosses
    inst.rareCount = #rares
    local total = 0
    local seen = {}
    for i = 1, #encounters do
        local items = encounters[i].items
        if items then
            for j = 1, #items do
                local item = items[j]
                local itemID = item.itemID
                if itemID and not seen[itemID] and item.special ~= "Achievement" then
                    seen[itemID] = true
                    total = total + 1
                end
            end
        end
    end
    inst.totalItems = total
    return inst
end

---@param inst table
function OneWoW_CatDB_ZoneDB_API.MergeInstance(inst)
    ns.EJLiveLoot:MergeInstance(inst)
end

---@param inst table|nil
function OneWoW_CatDB_ZoneDB_API.SetLiveMergeTarget(inst)
    ns.EJLiveLoot:SetMergeTarget(inst)
end

---@param fn fun()|nil
function OneWoW_CatDB_ZoneDB_API.RegisterScanCallback(fn)
    ns:RegisterScanCallback(fn)
end

---@param itemID number
---@return table|nil
function OneWoW_CatDB_ZoneDB_API.GetCachedItem(itemID)
    return ItemSnapshot(itemID)
end

---@param itemID number
---@param callback fun(itemID: number, result: table|nil)|nil
---@return table|nil
function OneWoW_CatDB_ZoneDB_API.LoadItemData(itemID, callback)
    if ns.DataLoader then
        return ns.DataLoader:LoadItemData(itemID, callback)
    end
    local cached = ItemSnapshot(itemID)
    if callback then
        callback(itemID, cached)
    end
    return cached
end

---@param instanceID number
---@param encounterID number
---@param diffID number
---@param itemID number
---@return string|nil
function OneWoW_CatDB_ZoneDB_API.GetScaledLootLink(instanceID, encounterID, diffID, itemID)
    return ns.EJLiveLoot:GetScaledLootLink(instanceID, encounterID, diffID, itemID)
end

---@param inst table
---@return boolean
function OneWoW_CatDB_ZoneDB_API.MergeLiveATTExtras(inst)
    return ns.ATTLiveExtras:MergeLiveATTExtras(inst)
end

---@param npcID number
---@return string|nil
function OneWoW_CatDB_ZoneDB_API.ResolveNPCName(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return nil
    end
    local npcAPI = OneWoW_CatDB_NPCDB_API
    if npcAPI then
        return npcAPI.GetCachedNPCName(npcID)
    end
    return nil
end

local function ScanCreatureTooltipName(npcID)
    local tooltipData = C_TooltipInfo.GetHyperlink(CreatureHyperlink(npcID))
    if not tooltipData or not tooltipData.lines then
        return nil
    end
    for i = 1, #tooltipData.lines do
        local text = tooltipData.lines[i].leftText
        if text and not OneWoW.Restriction.IsSecretValue(text) and text ~= ""
            and text ~= RETRIEVING_DATA and text ~= RETRIEVING_ITEM_INFO
            and text ~= "???" and text ~= "?" then
            return text
        end
    end
    return nil
end

local pendingNPCNames = {}

local function DeliverNPCName(npcID, name)
    local cbs = pendingNPCNames[npcID]
    if not cbs then
        return
    end
    pendingNPCNames[npcID] = nil
    local info = name and { name = name } or nil
    for i = 1, #cbs do
        xpcall(cbs[i], CallErrorHandler, npcID, info)
    end
end

local function RequestNPCName(npcID, cb)
    local npcAPI = OneWoW_CatDB_NPCDB_API
    if npcAPI then
        npcAPI.RequestNPCName(npcID, cb)
        return
    end
    local name = OneWoW_CatDB_ZoneDB_API.ResolveNPCName(npcID)
    if name then
        cb(npcID, { name = name })
        return
    end
    local scanned = ScanCreatureTooltipName(npcID)
    if scanned then
        cb(npcID, { name = scanned })
        return
    end
    C_TooltipInfo.GetHyperlink(CreatureHyperlink(npcID))
    local list = pendingNPCNames[npcID]
    if not list then
        list = {}
        pendingNPCNames[npcID] = list
        C_Timer.After(1, function()
            if pendingNPCNames[npcID] then
                DeliverNPCName(
                    npcID,
                    OneWoW_CatDB_ZoneDB_API.ResolveNPCName(npcID) or ScanCreatureTooltipName(npcID)
                )
            end
        end)
    end
    tinsert(list, cb)
end

OneWoW_GUI:RegisterEntityResolver("npc", {
    Resolve = function(id)
        return OneWoW_CatDB_ZoneDB_API.ResolveNPCName(id)
    end,
    RequestAsync = RequestNPCName,
})

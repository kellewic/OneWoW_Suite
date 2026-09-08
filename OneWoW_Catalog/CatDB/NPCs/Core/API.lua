local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local pairs, type = pairs, type
local tonumber, tostring = tonumber, tostring
local tinsert, sort = tinsert, sort
local time = time
local wipe = wipe
local C_Item = C_Item
local C_Map = C_Map
local C_Timer = C_Timer
local C_TooltipInfo = C_TooltipInfo
local CreateFrame = CreateFrame
local RETRIEVING_DATA = RETRIEVING_DATA
local RETRIEVING_ITEM_INFO = RETRIEVING_ITEM_INFO
local COLLECTED = COLLECTED
local NOT_COLLECTED = NOT_COLLECTED
local UNKNOWNOBJECT = UNKNOWNOBJECT

-- Public, cross-addon read surface for NPCDB. ns stays private.
OneWoW_CatDB_NPCDB_API = {}

local Location = OneWoW.Location
local PERCENT_COORDS = { format = "percent", openMap = true }

local viewsByID = {}
local allVendorsCache
local allNPCsCache

local function GetNameCache()
    return ns:GetNPCDB().nameCache
end

local function GetVendorCategories()
    return ns:GetNPCDB().vendorCategories
end

local function GetVendorVisits()
    return ns:GetNPCDB().vendorVisits
end

---@param name string|nil
---@param npcID number|nil
---@return boolean
local function IsUnresolvedNPCName(name, npcID)
    if not name then
        return true
    end
    -- Instanced creature tooltip lines are secret: any compare errors.
    if OneWoW.Restriction.IsSecretValue(name) then
        return true
    end
    if name == "" then
        return true
    end
    if name == RETRIEVING_DATA or name == RETRIEVING_ITEM_INFO then
        return true
    end
    if name == UNKNOWNOBJECT then
        return true
    end
    if name == "???" or name == "?" then
        return true
    end
    if name:find("^NPC #%d") or name:find("^NPC %d") then
        return true
    end
    if npcID and name == tostring(npcID) then
        return true
    end
    return false
end

---@param name string|nil
---@return boolean
local function IsUnresolvedItemName(name)
    if not name or name == "" then
        return true
    end
    return name == RETRIEVING_DATA or name == RETRIEVING_ITEM_INFO
        or name == "???" or name == "?"
end

---@param text string|nil
---@return string|nil
local function NormalizeSubtitle(text)
    if not text or text == "" then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:match("^%s*(.-)%s*$")
    if not text or text == "" or IsUnresolvedNPCName(text) then
        return nil
    end
    local inner = text:match("^<(.*)>$")
    if inner then
        text = inner:match("^%s*(.-)%s*$")
    end
    if not text or text == "" then
        return nil
    end
    return text
end

---@param roles table|nil
---@return string|nil
local function CategoryFromRoles(roles)
    if not roles then
        return nil
    end
    local quest
    for i = 1, #roles do
        local role = roles[i]
        if role == "trainer" then
            return "profession_trainer"
        end
        if role == "quest_giver" then
            quest = "quest_giver"
        end
    end
    return quest
end

---@param npc table
---@param npcID number|nil
---@return string|nil
local function ResolveRowCategory(npc, npcID)
    local stored = npcID and GetVendorCategories()[npcID]
    if stored ~= nil then
        return stored
    end
    if npc.category and npc.category ~= "" then
        return npc.category
    end
    local title = NormalizeSubtitle(npc.title or npc.subtitle)
    if title then
        local resolved = ns.VendorCategoryMap.Resolve(title)
        if resolved then
            return resolved
        end
    end
    return CategoryFromRoles(npc.roles)
end

---@param npcID number
---@param subtitle string|nil
---@param canRepair boolean|nil
---@param persist boolean|nil
---@return string|nil
local function ApplyAutoCategory(npcID, subtitle, canRepair, persist)
    local resolved = ns.VendorCategoryMap.Resolve(NormalizeSubtitle(subtitle), canRepair)
    if not resolved or not npcID then
        return nil
    end
    local stored = GetVendorCategories()[npcID]
    if stored ~= nil then
        return stored
    end
    local npc = ns.NPCs[npcID]
    if npc and npc.category and ns.VendorCategoryMap.IsSpecial(npc.category)
        and not ns.VendorCategoryMap.IsSpecial(resolved) then
        return npc.category
    end
    local view = viewsByID[npcID]
    if view then
        view.category = resolved
        if not view.subtitle or view.subtitle == "" then
            view.subtitle = NormalizeSubtitle(subtitle)
        end
    end
    if persist then
        GetVendorCategories()[npcID] = resolved
    end
    return resolved
end

local function CreatureHyperlink(npcID)
    return ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
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
            if IsUnresolvedItemName(cached.name) then
                ns:GetNPCDB().itemCache[itemID] = nil
            else
                return cached
            end
        end
    end
    local itemAPI = OneWoW_CatDB_ItemDB_API
    if itemAPI then
        local rec = itemAPI.GetItem(itemID)
        if rec then
            local name = rec.name or itemAPI.GetItemName(itemID)
            if name and not IsUnresolvedItemName(name) then
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
        if shipped and not IsUnresolvedItemName(shipped) then
            return {
                name = shipped,
                quality = C_Item.GetItemQualityByID(itemID),
                icon = C_Item.GetItemIconByID(itemID),
            }
        end
    end
    local name = C_Item.GetItemNameByID(itemID)
    if not name or IsUnresolvedItemName(name) then
        return nil
    end
    return {
        name = name,
        quality = C_Item.GetItemQualityByID(itemID),
        icon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID)),
    }
end

local mapNameCache = {}

---@param mapID number
---@return string|nil
local function MapName(mapID)
    local cached = mapNameCache[mapID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local info = C_Map.GetMapInfo(mapID)
    local name = info and info.name
    mapNameCache[mapID] = name or false
    return name
end

---@param locations table|nil
---@return table|nil
local function CopyLocations(locations)
    if not locations then
        return nil
    end
    local out = {}
    for mapID, loc in pairs(locations) do
        out[mapID] = {
            x = loc.x,
            y = loc.y,
            mapID = loc.mapID or mapID,
            zone = loc.zone,
            subzone = loc.subzone,
        }
    end
    return out
end

---@param locations table|nil
---@return table|nil
local function OverlayLocations(locations)
    if not locations then
        return nil
    end
    local out = {}
    for mapID, loc in pairs(locations) do
        local zone = loc.zone
        if (not zone or zone == "") and type(mapID) == "number" then
            zone = MapName(mapID)
        end
        out[mapID] = {
            x = loc.x,
            y = loc.y,
            mapID = loc.mapID or mapID,
            zone = zone,
            subzone = loc.subzone,
        }
    end
    return out
end

---@param pin table|nil
---@return number|nil
---@return number|nil
local function EncounterPinPercent(pin)
    if not pin then
        return nil
    end
    local x = Location.ToPercent(Location.ToFraction(pin.x))
    local y = Location.ToPercent(Location.ToFraction(pin.y))
    if not x or not y then
        return nil
    end
    return x, y
end

---@param dest table
---@param mapID number
---@param x number|nil
---@param y number|nil
---@param zone string|nil
local function PutLocation(dest, mapID, x, y, zone)
    local cur = dest[mapID]
    if not cur then
        dest[mapID] = {
            mapID = mapID,
            x = x,
            y = y,
            zone = zone,
        }
        return
    end
    if (not cur.x or cur.x == 0) and x then
        cur.x = x
        cur.y = y
    end
    if (not cur.zone or cur.zone == "") and zone then
        cur.zone = zone
    end
end

-- Creature shards often omit xy for dungeon / raid / Delve bosses. The pin
-- lives on the ZoneDB encounter; placeKeys name the instance map. Join those
-- onto the overlay view only — never write the shipped row.
---@param npc table
---@param base table|nil
---@param resolveZones boolean|nil
---@return table|nil
local function MergeEncounterLocations(npc, base, resolveZones)
    local ids = npc.encounterIDs
    local keys = npc.placeKeys
    if not ids and not keys then
        return base
    end
    local out = base
    local zoneAPI = OneWoW:GetCatalogPackAPI("journal")
    if zoneAPI and ids then
        for i = 1, #ids do
            local enc = zoneAPI.GetEncounter(ids[i])
            local mapID = enc and tonumber(enc.uiMapID)
            if mapID and mapID > 0 then
                if not out then
                    out = {}
                end
                local x, y = EncounterPinPercent(enc.pin)
                PutLocation(out, mapID, x, y, resolveZones and MapName(mapID) or nil)
            end
        end
    end
    if keys then
        for i = 1, #keys do
            local mapID = tonumber(tostring(keys[i]):match("^zone:(%d+)$"))
            if mapID and mapID > 0 then
                if not out then
                    out = {}
                end
                PutLocation(out, mapID, nil, nil, resolveZones and MapName(mapID) or nil)
            end
        end
    end
    return out
end

---@param npc table
---@param resolveZones boolean|nil
---@return table|nil
local function OverlayVendor(npc, resolveZones)
    if not npc then
        return nil
    end
    local npcID = npc.npcID
    local view = npcID and viewsByID[npcID]
    if view then
        local cachedName = npcID and GetNameCache()[npcID]
        if cachedName and IsUnresolvedNPCName(cachedName, npcID) then
            GetNameCache()[npcID] = nil
            cachedName = nil
        end
        if cachedName then
            view.name = cachedName
        elseif view.name and IsUnresolvedNPCName(view.name, npcID) then
            view.name = nil
        end
        view.category = ResolveRowCategory(npc, npcID)
        view.encounterIDs = npc.encounterIDs
        view.questIDs = npc.questIDs
        view.trackingQuestIDs = npc.trackingQuestIDs
        view.rewardQuestIDs = npc.rewardQuestIDs
        view.achievementIDs = npc.achievementIDs
        view.learned = npc.learned
        view.sync = npc.sync
        if npcID then
            view.lastScanned = GetVendorVisits()[npcID] or npc.lastScanned
        end
        view.locations = MergeEncounterLocations(
            npc,
            resolveZones and OverlayLocations(npc.locations) or CopyLocations(npc.locations),
            resolveZones
        )
        return view
    end

    local cachedName = npcID and GetNameCache()[npcID]
    if cachedName and IsUnresolvedNPCName(cachedName, npcID) then
        GetNameCache()[npcID] = nil
        cachedName = nil
    end
    if not cachedName and npc.name and not IsUnresolvedNPCName(npc.name, npcID) then
        cachedName = npc.name
    end

    view = {
        npcID = npcID,
        name = cachedName,
        expansion = npc.expansion,
        displayID = npc.displayID,
        title = npc.title,
        subtitle = npc.subtitle or npc.title,
        creatureType = npc.creatureType,
        classification = npc.classification,
        category = ResolveRowCategory(npc, npcID),
        roles = npc.roles,
        encounterIDs = npc.encounterIDs,
        items = npc.items,
        locations = MergeEncounterLocations(
            npc,
            resolveZones and OverlayLocations(npc.locations) or CopyLocations(npc.locations),
            resolveZones
        ),
        placeKeys = npc.placeKeys,
        questIDs = npc.questIDs,
        trackingQuestIDs = npc.trackingQuestIDs,
        rewardQuestIDs = npc.rewardQuestIDs,
        achievementIDs = npc.achievementIDs,
        lastScanned = (npcID and GetVendorVisits()[npcID]) or npc.lastScanned,
        learned = npc.learned,
        sync = npc.sync,
    }
    if npcID then
        viewsByID[npcID] = view
    end
    return view
end

--- Returns the store settings.
---@return table settings
function OneWoW_CatDB_NPCDB_API.GetSettings()
    return ns:GetSettings()
end

--- One NPC / vendor record by NPC ID.
---@param npcID number
---@return table|nil vendor
function OneWoW_CatDB_NPCDB_API.GetVendor(npcID)
    return OverlayVendor(ns.NPCs[npcID], true)
end

--- Alias used by newer Catalog / CatDB callers.
---@param npcID number
---@return table|nil npc
function OneWoW_CatDB_NPCDB_API.GetNPC(npcID)
    return OverlayVendor(ns.NPCs[npcID], true)
end

--- True for the Catalog NPCs list: interactable or encounter roles, or learned.
---@param npc table|nil
---@return boolean
function OneWoW_CatDB_NPCDB_API.IsListVendor(npc)
    return ns.IsListVendor(npc)
end

--- Listed Catalog NPC rows keyed by NPC ID.
--- List path does not call C_Map; GetVendor / GetVendorsByItem resolve zone names.
---@return table vendors
function OneWoW_CatDB_NPCDB_API.GetAllVendors()
    if allVendorsCache then
        return allVendorsCache
    end
    local out = {}
    for npcID in pairs(ns.VendorIDs) do
        local view = OverlayVendor(ns.NPCs[npcID], false)
        if view then
            out[npcID] = view
        end
    end
    allVendorsCache = out
    return out
end

--- Every shipped NPC row keyed by NPC ID (all roles, not just vendors).
--- List path does not call C_Map; GetNPC resolves zone names.
---@return table npcs
function OneWoW_CatDB_NPCDB_API.GetAllNPCs()
    if allNPCsCache then
        return allNPCsCache
    end
    local out = {}
    for npcID, npc in pairs(ns.NPCs) do
        local view = OverlayVendor(npc, false)
        if view then
            out[npcID] = view
        end
    end
    allNPCsCache = out
    return out
end

--- NPCs that have the given role (vendor, trainer, service, quest_giver, rare, boss, vignette).
---@param role string
---@return table npcs
function OneWoW_CatDB_NPCDB_API.GetNPCsByRole(role)
    local out = {}
    if not role or role == "" then
        return out
    end
    for npcID, npc in pairs(ns.NPCs) do
        local roles = npc.roles
        if roles then
            for i = 1, #roles do
                if roles[i] == role then
                    local view = OverlayVendor(npc, false)
                    if view then
                        out[npcID] = view
                    end
                    break
                end
            end
        end
    end
    return out
end

--- Search vendors by name, zone, or NPC ID.
---@param term string
---@return table results
function OneWoW_CatDB_NPCDB_API.SearchVendors(term)
    if not term or term == "" then
        return OneWoW_CatDB_NPCDB_API.GetAllVendors()
    end
    local needle = term:lower()
    local results = {}
    for npcID, vendor in pairs(OneWoW_CatDB_NPCDB_API.GetAllVendors()) do
        local matched = false
        if vendor.name and vendor.name:lower():find(needle, 1, true) then
            matched = true
        end
        if not matched and vendor.title and vendor.title:lower():find(needle, 1, true) then
            matched = true
        end
        if not matched and vendor.locations then
            for _, loc in pairs(vendor.locations) do
                if loc.zone and loc.zone:lower():find(needle, 1, true) then
                    matched = true
                    break
                end
                if loc.subzone and loc.subzone:lower():find(needle, 1, true) then
                    matched = true
                    break
                end
            end
        end
        if not matched and tostring(npcID):find(needle, 1, true) then
            matched = true
        end
        if matched then
            results[npcID] = vendor
        end
    end
    return results
end

--- NPCs sorted for list display.
---@param term string|nil
---@return table vendors
function OneWoW_CatDB_NPCDB_API.GetSortedVendors(term)
    local vendors = term and OneWoW_CatDB_NPCDB_API.SearchVendors(term)
        or OneWoW_CatDB_NPCDB_API.GetAllVendors()
    local sorted = {}
    for _, vendor in pairs(vendors) do
        tinsert(sorted, vendor)
    end
    sort(sorted, function(a, b)
        if a.lastScanned and not b.lastScanned then
            return true
        end
        if not a.lastScanned and b.lastScanned then
            return false
        end
        if a.lastScanned and b.lastScanned then
            return a.lastScanned > b.lastScanned
        end
        return (a.npcID or 0) < (b.npcID or 0)
    end)
    return sorted
end

--- True when at least one list vendor that stocks this item lists it.
---@param itemID number
---@return boolean
function OneWoW_CatDB_NPCDB_API.ItemIsSold(itemID)
    local map = ns.NPCsByItem[itemID]
    if not map then
        return false
    end
    for npcID in pairs(map) do
        if ns.VendorIDs[npcID] then
            return true
        end
    end
    return false
end

--- NPCs that sell a given item. Drop / rare NPCs that also list loot are
--- not vendors; only VendorIDs that stock the item.
---@param itemID number
---@return table vendors
function OneWoW_CatDB_NPCDB_API.GetVendorsByItem(itemID)
    local out = {}
    local map = ns.NPCsByItem[itemID]
    if not map then
        return out
    end
    for npcID in pairs(map) do
        if ns.VendorIDs[npcID] then
            local npc = OverlayVendor(ns.NPCs[npcID], true)
            if npc then
                tinsert(out, npc)
            end
        end
    end
    return out
end

--- NPCs that list this item as stock or loot (vendors, rares, bosses).
--- Locations keep map IDs; zone names are not resolved.
---@param itemID number
---@return table npcs
function OneWoW_CatDB_NPCDB_API.GetNPCsByItem(itemID)
    local out = {}
    local map = ns.NPCsByItem[itemID]
    if not map then
        return out
    end
    for npcID in pairs(map) do
        local npc = OverlayVendor(ns.NPCs[npcID], false)
        if npc then
            tinsert(out, npc)
        end
    end
    return out
end

--- Aggregate store statistics.
---@return table stats
function OneWoW_CatDB_NPCDB_API.GetStats()
    local vendorCount = 0
    local uniqueItems = 0
    for _ in pairs(ns.VendorIDs) do
        vendorCount = vendorCount + 1
    end
    for _ in pairs(ns.NPCsByItem) do
        uniqueItems = uniqueItems + 1
    end
    return { vendorCount = vendorCount, uniqueItems = uniqueItems }
end

--- Expansions that have at least one vendor row.
---@return table expansions
function OneWoW_CatDB_NPCDB_API.GetAvailableExpansions()
    local found = {}
    for npcID in pairs(ns.VendorIDs) do
        local npc = ns.NPCs[npcID]
        if npc and npc.expansion ~= nil then
            found[npc.expansion] = true
        end
    end
    local result = {}
    for expID in pairs(found) do
        local name = OneWoW:GetExpansionName(expID)
        if name then
            tinsert(result, { id = expID, name = name })
        end
    end
    sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

---@param npcID number
---@param categoryKey string|nil
function OneWoW_CatDB_NPCDB_API.SetCategory(npcID, categoryKey)
    if not npcID then
        return
    end
    if categoryKey == "" then
        categoryKey = nil
    end
    GetVendorCategories()[npcID] = categoryKey
    local view = viewsByID[npcID]
    if view then
        view.category = categoryKey
    end
end

---@param fn fun()|nil
function OneWoW_CatDB_NPCDB_API.RegisterScanCallback(fn)
    ns:RegisterScanCallback(fn)
end

---@param npcID number
---@return string|nil name
function OneWoW_CatDB_NPCDB_API.GetCachedNPCName(npcID)
    if not npcID then
        return nil
    end
    local cache = GetNameCache()
    local name = cache[npcID]
    if name and IsUnresolvedNPCName(name, npcID) then
        cache[npcID] = nil
        name = nil
    end
    if name then
        return name
    end
    local view = viewsByID[npcID]
    if view and view.name then
        if IsUnresolvedNPCName(view.name, npcID) then
            view.name = nil
        else
            return view.name
        end
    end
    local npc = ns.NPCs[npcID]
    local shipped = npc and npc.name
    if shipped and not IsUnresolvedNPCName(shipped, npcID) then
        return shipped
    end
    return nil
end

---@param npcID number
---@param name string
function OneWoW_CatDB_NPCDB_API.RememberNPCName(npcID, name)
    if not npcID or IsUnresolvedNPCName(name, npcID) then
        return
    end
    GetNameCache()[npcID] = name
    local view = viewsByID[npcID]
    if view then
        view.name = name
    end
end

---@param npcID number
---@return string|nil name
function OneWoW_CatDB_NPCDB_API.ResolveNPCName(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return nil
    end
    local cached = OneWoW_CatDB_NPCDB_API.GetCachedNPCName(npcID)
    if cached then
        return cached
    end
    local tooltipData = C_TooltipInfo.GetHyperlink(CreatureHyperlink(npcID))
    if not tooltipData or not tooltipData.lines then
        return cached
    end
    local name, subtitle
    for i = 1, #tooltipData.lines do
        local text = tooltipData.lines[i].leftText
        if not IsUnresolvedNPCName(text, npcID) then
            if not name then
                name = text
            else
                subtitle = text
                break
            end
        end
    end
    if name then
        OneWoW_CatDB_NPCDB_API.RememberNPCName(npcID, name)
        if subtitle then
            ApplyAutoCategory(npcID, subtitle, nil, true)
        end
        return name
    end
    return cached
end

local pendingNPCNames = {}
-- Creature hyperlink tooltips often land after 1s. A single timeout used to
-- Deliver(nil) and drop TOOLTIP_DATA_UPDATE, so a later name never cached.
local NPC_NAME_RETRY = { 0.1, 0.25, 0.5, 1.0, 2.0, 3.0 }

local function DeliverNPCName(npcID, name)
    local cbs = pendingNPCNames[npcID]
    if not cbs then
        return
    end
    pendingNPCNames[npcID] = nil
    if name then
        OneWoW_CatDB_NPCDB_API.RememberNPCName(npcID, name)
    end
    local info = name and { name = name } or nil
    for i = 1, #cbs do
        xpcall(cbs[i], CallErrorHandler, npcID, info)
    end
end

---@param npcID number
---@param cb fun(npcID: number, info: table|nil)
function OneWoW_CatDB_NPCDB_API.RequestNPCName(npcID, cb)
    npcID = tonumber(npcID)
    if not npcID or not cb then
        return
    end
    local name = OneWoW_CatDB_NPCDB_API.ResolveNPCName(npcID)
    if name then
        cb(npcID, { name = name })
        return
    end
    C_TooltipInfo.GetHyperlink(CreatureHyperlink(npcID))
    local list = pendingNPCNames[npcID]
    if not list then
        list = {}
        pendingNPCNames[npcID] = list
        local attempt = 1
        local function retry()
            if not pendingNPCNames[npcID] then
                return
            end
            local resolved = OneWoW_CatDB_NPCDB_API.ResolveNPCName(npcID)
            if resolved then
                DeliverNPCName(npcID, resolved)
                return
            end
            attempt = attempt + 1
            local delay = NPC_NAME_RETRY[attempt]
            if delay then
                C_TooltipInfo.GetHyperlink(CreatureHyperlink(npcID))
                C_Timer.After(delay, retry)
            else
                DeliverNPCName(npcID, nil)
            end
        end
        C_Timer.After(NPC_NAME_RETRY[1], retry)
    end
    tinsert(list, cb)
end

local npcNameFrame = CreateFrame("Frame")
npcNameFrame:RegisterEvent("TOOLTIP_DATA_UPDATE")
npcNameFrame:SetScript("OnEvent", function()
    if not next(pendingNPCNames) then
        return
    end
    for npcID in pairs(pendingNPCNames) do
        local name = OneWoW_CatDB_NPCDB_API.ResolveNPCName(npcID)
        if name then
            DeliverNPCName(npcID, name)
        end
    end
end)

---@param itemID number
---@return table|nil
function OneWoW_CatDB_NPCDB_API.GetCachedItem(itemID)
    local snap = ItemSnapshot(itemID)
    if snap and IsUnresolvedItemName(snap.name) then
        if ns.DataLoader then
            local db = ns:GetNPCDB()
            if db.itemCache then
                db.itemCache[itemID] = nil
            end
        end
        return nil
    end
    return snap
end

local COLLECTIBLE_TO_SPECIAL = {
    appearance = "TMog",
    set = "TMog",
    mount = "Mount",
    pet = "Pet",
    toy = "Toy",
    recipe = "Recipe",
    decor = "Housing",
}

---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return boolean|nil collected
---@return string|nil special
local function ItemCollection(itemID, itemData, specialType)
    specialType = specialType or (itemData and itemData.special)
    local status = OneWoW.Collectibles.GetItemCollectionStatus(itemID)
    if not specialType then
        if status and status.applicable and status.type then
            specialType = COLLECTIBLE_TO_SPECIAL[status.type]
        end
    end
    if not specialType then
        return nil, nil
    end
    if status and status.applicable then
        return status.collected == true, specialType
    end
    if status then
        return nil, specialType
    end
    if specialType == "Recipe" then
        return nil, specialType
    end
    return false, specialType
end

--- Whether a vendor stock item is collected. Derives Journal special from Collectibles when omitted.
---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return boolean|nil
function OneWoW_CatDB_NPCDB_API.IsItemCollected(itemID, itemData, specialType)
    local collected = ItemCollection(itemID, itemData, specialType)
    return collected
end

--- Journal-shaped collected/not-collected label for a vendor stock row.
---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return string|nil
function OneWoW_CatDB_NPCDB_API.DetermineItemStatus(itemID, itemData, specialType)
    local collected = ItemCollection(itemID, itemData, specialType)
    if collected == nil then
        return nil
    end
    return collected and COLLECTED or NOT_COLLECTED
end

local LIST_ROLE = {
    vendor = true,
    trainer = true,
    service = true,
    quest_giver = true,
}

local function NormalizeLearnedCategory(category)
    if type(category) ~= "string" or category == "" then
        return nil
    end
    if category == "Quest Givers" or category == "Quest Giver" then
        return "quest_giver"
    end
    return category
end

local function HasRole(roles, role)
    if type(roles) ~= "table" then
        return false
    end
    for i = 1, #roles do
        if roles[i] == role then
            return true
        end
    end
    return false
end

local function MergeRoles(dst, src)
    if type(src) ~= "table" then
        return dst, false
    end
    dst = dst or {}
    local added = false
    local incoming = src
    if src[1] == nil then
        incoming = {}
        for role, flag in pairs(src) do
            if type(role) == "string" and flag then
                tinsert(incoming, role)
            end
        end
    end
    for i = 1, #incoming do
        local role = incoming[i]
        if type(role) == "string" and role ~= "" and not HasRole(dst, role) then
            tinsert(dst, role)
            added = true
        end
    end
    return dst, added
end

local function MergeQuestIDs(dst, src)
    if src == nil then
        return dst, false
    end
    dst = dst or {}
    local seen = {}
    for i = 1, #dst do
        seen[dst[i]] = true
    end
    local added = false
    local function add(id)
        id = tonumber(id)
        if id and not seen[id] then
            seen[id] = true
            tinsert(dst, id)
            added = true
        end
    end
    if type(src) == "number" then
        add(src)
    elseif type(src) == "table" then
        for i = 1, #src do
            add(src[i])
        end
        add(src.questID or src.id)
    end
    return dst, added
end

local function HasItems(items)
    if type(items) ~= "table" then
        return false
    end
    for _ in pairs(items) do
        return true
    end
    return false
end

local function InvalidateNPCView(npcID)
    if npcID then
        viewsByID[npcID] = nil
    else
        wipe(viewsByID)
    end
    allVendorsCache = nil
    allNPCsCache = nil
end

local function AddPlaceKey(npc, mapID)
    if not mapID then
        return
    end
    local key = "zone:" .. tostring(mapID)
    npc.placeKeys = npc.placeKeys or {}
    for i = 1, #npc.placeKeys do
        if npc.placeKeys[i] == key then
            return
        end
    end
    tinsert(npc.placeKeys, key)
end

local function LocationIsNew(existing, mapID, x, y)
    if not mapID then
        return false
    end
    local loc = existing and existing[mapID]
    if not loc then
        return true
    end
    if (not loc.x or not loc.y) and x and y then
        return true
    end
    return false
end

---@param npcID number
---@param rec table
local function MergeLearnedIntoStore(npcID, rec)
    local npc = ns.NPCs[npcID]
    if not npc then
        npc = { npcID = npcID, roles = {}, locations = {} }
        ns.NPCs[npcID] = npc
    end
    npc.npcID = npc.npcID or npcID
    npc.learned = true
    if rec.sync then
        npc.sync = true
    end
    if rec.displayID and (not npc.displayID or npc.displayID == 0) then
        npc.displayID = rec.displayID
    end
    if rec.title and (not npc.title or npc.title == "") then
        npc.title = rec.title
    end
    if rec.category and (not npc.category or npc.category == "") then
        npc.category = rec.category
    end
    if rec.creatureType and (not npc.creatureType or npc.creatureType == "") then
        npc.creatureType = rec.creatureType
    end
    if rec.classification and not npc.classification then
        npc.classification = rec.classification
    end
    if rec.expansion and not npc.expansion then
        npc.expansion = rec.expansion
    end
    npc.roles = select(1, MergeRoles(npc.roles, rec.roles))
    npc.questIDs = select(1, MergeQuestIDs(npc.questIDs, rec.questIDs))
    if rec.lastScanned then
        npc.lastScanned = rec.lastScanned
    end
    if type(rec.locations) == "table" then
        npc.locations = npc.locations or {}
        for mapID, loc in pairs(rec.locations) do
            if type(loc) == "table" and type(mapID) == "number" then
                local cur = npc.locations[mapID]
                if not cur then
                    npc.locations[mapID] = {
                        x = loc.x,
                        y = loc.y,
                        mapID = loc.mapID or mapID,
                    }
                    AddPlaceKey(npc, mapID)
                elseif (not cur.x or not cur.y) and loc.x and loc.y then
                    cur.x = loc.x
                    cur.y = loc.y
                    cur.mapID = cur.mapID or mapID
                end
            end
        end
    end
    if HasItems(rec.items) and not HasItems(npc.items) then
        npc.items = rec.items
        for itemID in pairs(rec.items) do
            if type(itemID) == "number" then
                ns.NPCsByItem[itemID] = ns.NPCsByItem[itemID] or {}
                ns.NPCsByItem[itemID][npcID] = true
            end
        end
    end
    if ns.IsListVendor(npc) then
        ns.VendorIDs[npcID] = true
    end
end

---@param npcID number
---@param info table|nil
---@return table|nil view
function OneWoW_CatDB_NPCDB_API.EnsureLearnedNPC(npcID, info)
    npcID = tonumber(npcID)
    if not npcID or npcID == 0 then
        return nil
    end
    info = info or {}
    local db = ns:GetNPCDB()
    db.learned = db.learned or {}

    local shipped = ns.NPCs[npcID]
    local isUnknown = shipped == nil
    local rec = db.learned[npcID]
    if not rec then
        rec = { npcID = npcID, learnedAt = time() }
        db.learned[npcID] = rec
    end
    rec.npcID = npcID
    rec.learned = true

    local newFacts = isUnknown
    rec.roles = select(1, MergeRoles(rec.roles, info.roles))
    if shipped then
        local incoming = info.roles
        if type(incoming) == "table" then
            for i = 1, #(incoming[1] and incoming or {}) do
                if not HasRole(shipped.roles, incoming[i]) and LIST_ROLE[incoming[i]] then
                    newFacts = true
                end
            end
            if incoming[1] == nil then
                for role, flag in pairs(incoming) do
                    if flag and not HasRole(shipped.roles, role) and LIST_ROLE[role] then
                        newFacts = true
                    end
                end
            end
        end
    elseif type(info.roles) == "table" then
        newFacts = true
    end

    rec.questIDs = select(1, MergeQuestIDs(rec.questIDs, info.questIDs))
    rec.questIDs = select(1, MergeQuestIDs(rec.questIDs, info.questID))
    if rec.questIDs then
        for i = 1, #rec.questIDs do
            if not HasRole(shipped and shipped.questIDs, rec.questIDs[i]) then
                newFacts = true
                break
            end
        end
    end

    local category = NormalizeLearnedCategory(info.category)
    if category then
        rec.category = rec.category or category
    end
    if info.displayID and (not rec.displayID or rec.displayID == 0) then
        rec.displayID = info.displayID
        if not (shipped and shipped.displayID and shipped.displayID > 0) then
            newFacts = true
        end
    end
    if info.title and info.title ~= "" then
        rec.title = rec.title or info.title
    end
    if info.subtitle and info.subtitle ~= "" then
        rec.title = rec.title or info.subtitle
    end
    if info.creatureType and info.creatureType ~= "" then
        rec.creatureType = rec.creatureType or info.creatureType
    end
    if info.classification then
        rec.classification = rec.classification or info.classification
    end
    if info.expansion then
        rec.expansion = rec.expansion or info.expansion
    end
    if info.lastScanned then
        rec.lastScanned = info.lastScanned
        GetVendorVisits()[npcID] = info.lastScanned
    end

    rec.locations = rec.locations or {}
    local mapID = tonumber(info.mapID)
    local x, y = info.x, info.y
    if type(info.locations) == "table" then
        for locMapID, loc in pairs(info.locations) do
            if type(loc) == "table" and type(locMapID) == "number" then
                if LocationIsNew(shipped and shipped.locations, locMapID, loc.x, loc.y) then
                    newFacts = true
                end
                if not rec.locations[locMapID] then
                    rec.locations[locMapID] = {
                        x = loc.x,
                        y = loc.y,
                        mapID = loc.mapID or locMapID,
                    }
                end
            end
        end
    end
    if mapID then
        x = OneWoW.Location.ToPercent(OneWoW.Location.ToFraction(x))
        y = OneWoW.Location.ToPercent(OneWoW.Location.ToFraction(y))
        if LocationIsNew(shipped and shipped.locations, mapID, x, y) then
            newFacts = true
        end
        local cur = rec.locations[mapID]
        if not cur then
            rec.locations[mapID] = { x = x, y = y, mapID = mapID }
        elseif (not cur.x or not cur.y) and x and y then
            cur.x = x
            cur.y = y
        end
    end

    if HasItems(info.items) and not HasItems(rec.items) then
        rec.items = info.items
        if not (shipped and HasItems(shipped.items)) then
            newFacts = true
        end
    end

    if isUnknown or newFacts then
        rec.sync = true
    end
    if info.name and info.name ~= "" then
        rec.name = rec.name or info.name
    end

    MergeLearnedIntoStore(npcID, rec)
    if info.name then
        OneWoW_CatDB_NPCDB_API.RememberNPCName(npcID, info.name)
    end
    InvalidateNPCView(npcID)
    local view = OverlayVendor(ns.NPCs[npcID], true)
    if view and info.lastScanned then
        view.lastScanned = info.lastScanned
    end
    ns:FireScanCallbacks(view or rec)
    return view
end

function ns:ApplyLearnedNPCs()
    local learned = ns:GetNPCDB().learned
    if type(learned) ~= "table" then
        return
    end
    for npcID, rec in pairs(learned) do
        if type(npcID) == "number" and type(rec) == "table" then
            MergeLearnedIntoStore(npcID, rec)
        end
    end
    InvalidateNPCView()
end

---@return table
function OneWoW_CatDB_NPCDB_API.GetSyncQueue()
    local out = {}
    local learned = ns:GetNPCDB().learned
    if type(learned) ~= "table" then
        return out
    end
    for npcID, rec in pairs(learned) do
        if type(rec) == "table" and rec.sync then
            out[npcID] = rec
        end
    end
    return out
end

--- Merge one Merchant funnel snapshot into name / category / visit overlay.
---@param scan table|nil
function OneWoW_CatDB_NPCDB_API.MergeMerchantScan(scan)
    if not scan or not scan.npcID or scan.npcID == 0 then
        return
    end
    local npcID = scan.npcID
    if scan.name and not IsUnresolvedNPCName(scan.name, npcID) then
        OneWoW_CatDB_NPCDB_API.RememberNPCName(npcID, scan.name)
    end
    GetVendorVisits()[npcID] = scan.scannedAt or time()
    if scan.subtitle or scan.canRepair then
        ApplyAutoCategory(npcID, scan.subtitle, scan.canRepair, true)
    end
    if not ns.NPCs[npcID] then
        local loc = scan.location
        OneWoW_CatDB_NPCDB_API.EnsureLearnedNPC(npcID, {
            name = scan.name,
            title = scan.subtitle,
            subtitle = scan.subtitle,
            displayID = scan.displayID,
            creatureType = scan.creatureType,
            classification = scan.classification,
            roles = { "vendor" },
            mapID = loc and loc.mapID,
            x = loc and loc.x,
            y = loc and loc.y,
            items = scan.items,
            lastScanned = scan.scannedAt,
        })
        return
    end
    local npc = ns.NPCs[npcID]
    ns.VendorIDs[npcID] = true
    local view = OverlayVendor(npc, true)
    if view then
        view.lastScanned = GetVendorVisits()[npcID]
        if scan.displayID and scan.displayID > 0 then
            view.displayID = scan.displayID
        end
        if scan.subtitle and scan.subtitle ~= "" then
            view.subtitle = NormalizeSubtitle(scan.subtitle) or view.subtitle
        end
    end
    if allVendorsCache and view then
        allVendorsCache[npcID] = view
    end
    if allNPCsCache and view then
        allNPCsCache[npcID] = view
    end
    ns:FireScanCallbacks(viewsByID[npcID] or scan)
end

---@param itemID number
---@param callback fun(itemID: number, result: table|nil)|nil
---@return table|nil
function OneWoW_CatDB_NPCDB_API.LoadItemData(itemID, callback)
    if ns.DataLoader then
        return ns.DataLoader:LoadItemData(itemID, callback)
    end
    local cached = ItemSnapshot(itemID)
    if callback then
        callback(itemID, cached)
    end
    return cached
end

---@param vendor table
---@param mapID number|nil
---@return boolean created
function OneWoW_CatDB_NPCDB_API.CreateWaypoint(vendor, mapID)
    if not vendor or not vendor.locations then
        return false
    end
    local location = mapID and vendor.locations[mapID]
    if not location then
        for locMapID, loc in pairs(vendor.locations) do
            location = loc
            mapID = loc.mapID or locMapID
            break
        end
    end
    if not location or not mapID then
        return false
    end
    return Location.SetWaypoint(mapID, location.x or 0, location.y or 0, PERCENT_COORDS)
end

OneWoW_GUI:RegisterEntityResolver("npc", {
    Resolve = function(id)
        return OneWoW_CatDB_NPCDB_API.ResolveNPCName(id)
    end,
    RequestAsync = OneWoW_CatDB_NPCDB_API.RequestNPCName,
})

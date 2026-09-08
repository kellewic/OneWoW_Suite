local _, ns = ...

local C_AddOns = C_AddOns

-- ============================================================================
-- Catalog pack resolver
-- ============================================================================
-- Consumers pass a role (journal, vendors, quests, tradeskills, items) or a
-- CatDB folder name. Home / Manage Features list CatDB as the Catalog
-- data stores. This lives on core so QoL / Notes / ShoppingList / toasts can
-- resolve without loading Catalog. Always returns the CatDB addon (`pack.cat`).
--
-- Roles: journal/zones, vendors/npcs, quests, archive, tradeskills, items.
-- ============================================================================

local PACKS = {
    journal = {
        cat = "OneWoW_CatDB_ZoneDB",
    },
    zones = {
        cat = "OneWoW_CatDB_ZoneDB",
    },
    vendors = {
        cat = "OneWoW_CatDB_NPCDB",
    },
    npcs = {
        cat = "OneWoW_CatDB_NPCDB",
    },
    quests = {
        cat = "OneWoW_CatDB_QuestDBCurrent",
    },
    archive = {
        cat = "OneWoW_CatDB_QuestDBArchive",
    },
    tradeskills = {
        cat = "OneWoW_CatDB_TradeSkillDB",
    },
    items = {
        cat = "OneWoW_CatDB_ItemDB",
    },
}

local ADDON_TO_ROLE = {
    OneWoW_CatDB_ZoneDB = "journal",
    OneWoW_CatDB_NPCDB = "vendors",
    OneWoW_CatDB_QuestDBCurrent = "quests",
    OneWoW_CatDB_QuestDBArchive = "archive",
    OneWoW_CatDB_TradeSkillDB = "tradeskills",
    OneWoW_CatDB_ItemDB = "items",
}

--- Resolve a pack role or CatDB addon name to the CatDB addon to load.
---@param roleOrName string
---@return string|nil addonName
function ns:ResolveCatalogPack(roleOrName)
    if not roleOrName then
        return nil
    end
    local role = PACKS[roleOrName] and roleOrName or ADDON_TO_ROLE[roleOrName]
    local pack = role and PACKS[role]
    if not pack then
        return roleOrName
    end
    return pack.cat
end

--- Cross-unit API table for the resolved pack (`AddonName_API`).
---@param roleOrName string
---@return table|nil api
function ns:GetCatalogPackAPI(roleOrName)
    local addon = self:ResolveCatalogPack(roleOrName)
    if not addon then
        return nil
    end
    return _G[addon .. "_API"]
end

--- EnsureLoaded the resolved CatDB pack. Explicit user actions only.
---@param roleOrName string
---@return string|nil addonName
function ns:EnsureCatalogPack(roleOrName)
    local addon = self:ResolveCatalogPack(roleOrName)
    if addon then
        self:EnsureLoaded(addon)
    end
    return addon
end

--- Load Journal places. Explicit user actions only.
function ns:EnsureCatalogJournalPlaces()
    self:EnsureCatalogPack("journal")
end

--- True when Journal place data is loaded and can answer this-place lookups.
function ns:AreWantedJournalPlacesLoaded()
    return self:GetCatalogPackAPI("journal") ~= nil
end

--- True if the resolved CatDB pack exists and is enabled (not necessarily loaded).
---@param roleOrName string
---@return boolean
function ns:IsCatalogPackAvailable(roleOrName)
    local name = self:ResolveCatalogPack(roleOrName)
    if not name then
        return false
    end
    if not C_AddOns.DoesAddOnExist(name) then
        return false
    end
    return self:IsAddonEnabled(name)
end

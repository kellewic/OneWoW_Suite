local _, ns = ...

-- ============================================================================
-- Catalog pack resolver
-- ============================================================================
-- Consumers pass a role (journal, vendors, quests, tradeskills, items) or a
-- CatDB folder name. Era shards live in OneWoW_CatDB_<Era>; query APIs live
-- on OneWoW_Catalog. Tradeskills stay OneWoW_CatDB_TradeSkillDB.
-- This lives on core so QoL / Notes / ShoppingList / toasts can resolve
-- without opening Catalog tabs.
--
-- Roles: journal/zones, vendors/npcs, quests, archive, tradeskills, items.
-- ============================================================================

--- Resolve a pack role or CatDB addon name to the addon EnsureLoaded should
--- treat as the provider (runtime for journal/vendors/quests/items).
---@param roleOrName string
---@return string|nil addonName
function ns:ResolveCatalogPack(roleOrName)
    if not roleOrName then
        return nil
    end
    return ns.CatalogData:ResolveRoleAddon(roleOrName) or roleOrName
end

--- Cross-unit API table for the resolved pack role.
---@param roleOrName string
---@return table|nil api
function ns:GetCatalogPackAPI(roleOrName)
    if not roleOrName then
        return nil
    end
    local api = ns.CatalogData:GetRoleAPI(roleOrName)
    if api then
        return api
    end
    local addon = self:ResolveCatalogPack(roleOrName)
    if not addon then
        return nil
    end
    return _G[addon .. "_API"]
end

--- Load runtime + enabled era topics for this role. Explicit user actions only.
---@param roleOrName string
---@return string|nil addonName
function ns:EnsureCatalogPack(roleOrName)
    if not roleOrName then
        return nil
    end
    return ns.CatalogData:EnsureRole(roleOrName)
end

--- Load Journal places for every wanted expansion, including older packs.
function ns:EnsureCatalogJournalPlaces()
    ns.CatalogData:EnsureWantedJournalPlaces()
end

--- Load Journal hubs + zone for one suite expansion (no-op for All / 0).
---@param expansionID number
function ns:EnsureJournalShards(expansionID)
    ns.CatalogData:EnsureJournalShards(expansionID)
end

--- Load the Zones expansion filter: one pack now, or this expansion plus the rest across frames.
---@param expansionID number
---@param onUpdate function|nil
function ns:EnsureJournalShardsForFilter(expansionID, onUpdate)
    ns.CatalogData:EnsureJournalShardsForFilter(expansionID, onUpdate)
end

--- True when wanted expansion Journal place shards are loaded and activated.
function ns:AreWantedJournalPlacesLoaded()
    return ns.CatalogData:AreWantedJournalPlacesLoaded()
end

--- True if the resolved CatDB provider exists and is enabled.
---@param roleOrName string
---@return boolean
function ns:IsCatalogPackAvailable(roleOrName)
    if not roleOrName then
        return false
    end
    return ns.CatalogData:IsRoleAvailable(roleOrName)
end

--- True when this role can query loaded expansion data (not merely that the API table exists).
---@param roleOrName string
---@return boolean
function ns:IsCatalogRoleReady(roleOrName)
    if not roleOrName then
        return false
    end
    return ns.CatalogData:IsRoleQueryReady(roleOrName)
end

--- True when every wanted expansion for this role is loaded.
---@param roleOrName string
---@return boolean
function ns:IsCatalogRoleFullyLoaded(roleOrName)
    if not roleOrName then
        return false
    end
    return ns.CatalogData:IsRoleFullyLoaded(roleOrName)
end

--- "Catalog not enabled" when a Catalog-backed surface cannot populate. Nil when it can.
---@param roleOrRoles string|string[]
---@return string|nil
function ns:GetCatalogUnavailableNotice(roleOrRoles)
    return ns.CatalogData:GetUnavailableNotice(roleOrRoles)
end

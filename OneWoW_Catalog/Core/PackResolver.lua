local _, ns = ...

local tinsert = tinsert

-- ============================================================================
-- Catalog pack resolver (Catalog-side wrappers)
-- ============================================================================
-- Pack maps live on OneWoW (core) so QoL and other hubs can resolve without
-- this unit loaded. Catalog tabs keep calling ns.*. Always CatDB.
-- ============================================================================

--- Resolve a pack role or old/new addon name to the CatDB addon to load.
---@param roleOrName string
---@return string|nil addonName
function ns.ResolveCatalogPack(roleOrName)
    return OneWoW:ResolveCatalogPack(roleOrName)
end

--- Cross-unit API table for the resolved pack (`AddonName_API`).
---@param roleOrName string
---@return table|nil api
function ns.GetCatalogPackAPI(roleOrName)
    return OneWoW:GetCatalogPackAPI(roleOrName)
end

--- EnsureLoaded the resolved pack. Explicit user actions only.
---@param roleOrName string
---@return string|nil addonName
function ns.EnsureCatalogPack(roleOrName)
    return OneWoW:EnsureCatalogPack(roleOrName)
end

function ns.IsCatalogRoleReady(roleOrName)
    return OneWoW:IsCatalogRoleReady(roleOrName)
end

function ns.GetCatalogUnavailableNotice(roleOrRoles)
    return OneWoW:GetCatalogUnavailableNotice(roleOrRoles)
end

--- Deduped list of addons Item Search watches for data-ready.
---@return string[]
function ns.GetCatalogItemSearchAddons()
    local seen = {}
    local out = {}
    local function add(name)
        if name and not seen[name] then
            seen[name] = true
            tinsert(out, name)
        end
    end
    add(OneWoW:ResolveCatalogPack("journal"))
    add(OneWoW:ResolveCatalogPack("vendors"))
    add(OneWoW:ResolveCatalogPack("tradeskills"))
    add(OneWoW:ResolveCatalogPack("quests"))
    add(OneWoW:ResolveCatalogPack("items"))
    add("OneWoW_AltTracker_Storage")
    return out
end

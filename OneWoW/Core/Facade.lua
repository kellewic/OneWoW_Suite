-- Publishes the curated OneWoW orchestrator global (colon API + public services).
-- Internal addon state lives on ns; only declared surfaces are wired here.
local _, ns = ...

OneWoW = {}

local SERVICE_KEYS = {
    "Lifecycle",
    "UI",
    "Restriction",
    "PredicateEngine",
    "SearchCatalog",
    "SearchExpand",
    "TooltipScanner",
    "OverlayEngine",
    "Overlays2Defs",
    "Overlays2Renderer",
    "TooltipEngine",
    "Toasts",
    "SettingsFeatureRegistry",
    "ModuleRegistry",
    "Profiles",
    "CharProfiles",
    "Locale",
    "L",
    "Constants",
    "Format",
    "CopyPaste",
    "Search",
    "SearchRegistry",
    "Minimap",
    "ModuleManifest",
    "LoadOrchestrator",
    "FirstRun",
    "ExternalTooltipSync",
    "ItemStatus",
    "OverlayIcons",
    "AHItemKeys",
    "ItemPrices",
    "ProfessionRecipe",
    "RecipeKnownUtil",
    "Collectibles",
    "GearProficiency",
    "Location",
    "StatusCards",
    "Merchant",
    "CatDBSync",
    "Inventory",
    "GuildBankTransfer",
    "UpgradeDetection",
    "Disenchant",
    "AltScope",
    "ItemLevel",
    "ChunkedJob",
    "UIParent",
}

for _, key in ipairs(SERVICE_KEYS) do
    OneWoW[key] = ns[key]
end

local COLON_METHODS = {
    "RegisterMinimap",
    "RegisterLoadComponent",
    "OnAddonLoaded",
    "GetLoadFailureText",
    "IsAddonEnabled",
    "SetAddonEnabled",
    "GetFeatureUnitStatusLabel",
    "GetAddonStatus",
    "IsFeatureOptedOut",
    "IsFeatureOptedOutInScope",
    "SetFeatureOptOut",
    "IsFeatureWanted",
    "IsFeatureOptedOutForCharKey",
    "IsFeatureWantedForCharKey",
    "GetFeatureWantedAggregate",
    "GetFeatureUnitState",
    "EnsureLoaded",
    "ResolveCatalogPack",
    "GetCatalogPackAPI",
    "EnsureCatalogPack",
    "IsCatalogPackAvailable",
    "IsManifestUnit",
    "BringUp",
    "WithAddon",
    "GetModuleTabOrder",
    "GetAlwaysShowModules",
    "GetLoadedModuleCount",
    "GetManifestByAddon",
    "GetManifestParentsWithStores",
    "GetManifestStoreOwner",
    "GetCatalogDatastores",
    "GetStoreCatalogConsumers",
    "GetStoreLabelKey",
    "IsLazyStore",
    "StoreRequiresParent",
    "EvaluateSuiteAttention",
    "DismissFeatureAttention",
    "BootStore",
    "GetSettingsDefaults",
    "InitializeDatabase",
    "TraceRecord",
    "DispatchUnitOnAddonLoaded",
    "RegisterAddonLoadedWatcher",
    "SignalDataReady",
    "RegisterDataReadyWatcher",
    "IsDataReady",
    "CreateItemDataLoader",
    "RegisterCoreLoginHandler",
    "RegisterCoreEnteringWorldHandler",
    "FireCoreLoginHandlers",
    "FireCoreEnteringWorldHandlers",
    "NotifyAddonLoadedWatchers",
    "DispatchAddonLoaded",
    "RunManifestLoginPhase",
    "DispatchEnteringWorld",
    "RegisterModule",
    "RegisterSettingsPanel",
    "GetAddonVersion",
    "GetExpansionName",
    "InitializeContextMenus",
    "MarkItemJunkKeybind",
    "MarkItemProtectedKeybind",
}

for _, name in ipairs(COLON_METHODS) do
    OneWoW[name] = function(_, ...)
        return ns[name](ns, ...)
    end
end

--- Portal hub settings live on core OneWoW_DB outside SettingsFeatureRegistry.
function OneWoW:GetPortalHub()
    return ns.db.global.portalHub
end

--- Global-scope core settings root (portalHub, instanceStats*, lastSubTabs, …).
function OneWoW:GetCoreGlobal()
    return ns.db.global
end

--- Loaded suite components ({ name, ver, cmd, addon }), filled as units register.
function OneWoW:GetLoadedComponents()
    return ns._loadedComponents
end

--- Suite feature face for a load-unit folder name ({ texture?, atlas?, texCoords?, plate? }).
---@param addonName string
---@return table|nil
function OneWoW:GetFeatureIcon(addonName)
    return ns:GetFeatureIcon(addonName)
end

function OneWoW:FeatureIconHasAlert(addonName)
    return ns:FeatureIconHasAlert(addonName)
end

function OneWoW:ApplyFeatureIconAlert(texture, addonName)
    return ns:ApplyFeatureIconAlert(texture, addonName)
end

function OneWoW:ResolveFeatureIconClick(addonName, fallback)
    return ns:ResolveFeatureIconClick(addonName, fallback)
end

function OneWoW:GetFeatureIconAlertEvent()
    return ns:GetFeatureIconAlertEvent()
end

--- Registered minimap launcher entries ({ addon, label, tabKey, callback }).
function OneWoW:GetMinimapEntries()
    return ns._minimapEntries
end

_G["OneWoW"] = OneWoW

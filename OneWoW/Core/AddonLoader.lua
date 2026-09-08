-- Centralized on-demand addon loader. One loader serves both the login orchestrator
-- and lazy point-of-use loads, so no addon hand-rolls its own LoadAddOn wrapper.
-- GUI-free on purpose: it loads early, before anything that consumes it.
local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local C_AddOns = C_AddOns
local CreateFrame = CreateFrame
local ipairs = ipairs
local tinsert = tinsert
local print = print
local _G = _G
local UnitName = UnitName
local type = type

-- Pending loads deferred until combat ends, and a per-addon "already told the
-- user" guard so a repeated failure isn't reprinted on every attempt.
local pendingCombat = {}
local warned = {}

-- True while ns:BringUp is driving a batch load. The LoadAddOn hook checks
-- this so it only runs OnAddonLoaded during the batch; BringUp drives the login
-- and entering-world passes itself, once, after the whole set is loaded.
local inBringUp = false

local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if #pendingCombat == 0 then return end
    local queue = pendingCombat
    pendingCombat = {}
    ns:TraceRecord("combat.flush", nil, { count = #queue })
    for _, entry in ipairs(queue) do
        ns:WithAddon(entry.name, entry.onReady, entry.onFail, entry.opts)
    end
end)

--- Maps a raw LoadAddOn failure token to a localized, user-facing string.
--- Falls back to Blizzard's ADDON_* constants, then to the raw token.
---@param reason string|nil LoadAddOn failure token (e.g. "DISABLED", "MISSING", "COMBAT")
---@return string text localized failure description
function ns:GetLoadFailureText(reason)
    if reason then
        -- Optional: only some tokens have a LOAD_FAIL_<reason> string. GetOptional
        -- returns nil (not the key name) when absent, so we fall through to
        -- Blizzard's ADDON_<reason> constant, then the raw token.
        local text = ns.Locale:GetOptional(ADDON_NAME, "LOAD_FAIL_" .. reason)
        if text then return text end
        if _G["ADDON_" .. reason] then
            return _G["ADDON_" .. reason]
        end
    end
    return reason or ns.L["LOAD_FAIL_UNKNOWN"]
end

-- Shared addon enable-state API. Both settings surfaces (the Home tab and the
-- Manage Features panel) query and mutate Blizzard's per-addon enable flag the
-- same way; these helpers are the single implementation. `perCharacter` selects
-- the scope: the Home tab passes false (account-wide / all characters) and
-- Manage Features passes true (a current-character override, which can re-enable
-- an addon disabled account-wide). Scope is intentional, not a default.

--- Reads whether an addon is enabled in the requested scope.
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? true = current-character scope; false/nil = account-wide
---@return boolean enabled true when enabled in the requested scope
function ns:IsAddonEnabled(name, perCharacter)
    if not name then return false end
    local state
    if perCharacter then
        state = C_AddOns.GetAddOnEnableState(name, UnitName("player"))
    else
        state = C_AddOns.GetAddOnEnableState(name)
    end
    return state ~= nil and state > 0
end

--- Enables or disables an addon in the requested scope. Takes effect on the next
--- load (reload/relog) — WoW cannot load or unload addon Lua mid-session.
---@param name string addon (folder/TOC) name
---@param enabled boolean desired enabled state
---@param perCharacter boolean? true = current-character scope; false/nil = account-wide
function ns:SetAddonEnabled(name, enabled, perCharacter)
    if not name then return end
    if perCharacter then
        local char = UnitName("player")
        if enabled then
            C_AddOns.EnableAddOn(name, char)
        else
            C_AddOns.DisableAddOn(name, char)
        end
    else
        if enabled then
            C_AddOns.EnableAddOn(name)
        else
            C_AddOns.DisableAddOn(name)
        end
    end
end

local FEATURE_UNIT_STATUS_KEYS = {
    missing    = "FEATURE_UNIT_STATUS_MISSING",
    disabled   = "FEATURE_UNIT_STATUS_DISABLED",
    not_loaded = "FEATURE_UNIT_STATUS_NOT_LOADED",
    pending_disable = "FEATURE_UNIT_STATUS_PENDING_DISABLE",
    all        = "FEATURE_UNIT_STATUS_ALL",
    some       = "FEATURE_UNIT_STATUS_SOME",
}

--- Short inline status text for placeholder tabs and similar surfaces.
---@param state string return value from GetFeatureUnitState
---@return string label localized short status
function ns:GetFeatureUnitStatusLabel(state)
    local key = FEATURE_UNIT_STATUS_KEYS[state]
    if key then
        return ns.L[key]
    end
    return ns.L["FEATURE_UNIT_STATUS_MISSING"]
end

--- When a unit is enabled but not in memory, returns a load-failure token if
--- GetAddOnInfo reports something other than DISABLED/DEMAND_LOADED.
---@param name string addon (folder/TOC) name
---@return string? reason raw failure token, or nil when healthy-not-loaded
local function GetFeatureUnitUnloadReason(name)
    if not name or C_AddOns.IsAddOnLoaded(name) then return nil end
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(name)
    if not loadable and reason and reason ~= "DISABLED" and reason ~= "DEMAND_LOADED" then
        return reason
    end
    return nil
end

--- Classifies an addon for status display. A loaded or DEMAND_LOADED unit is
--- "enabled" (healthy): every suite unit is LoadOnDemand: 1 and force-loaded by
--- the orchestrator, so GetAddOnInfo reports loadable=false/reason=DEMAND_LOADED
--- even while the unit is loaded and working — that is not an error.
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? scope of the enable check; false/nil = account-wide
---@return string status "not_found" | "disabled" | "enabled" | "warning"
---@return string? reason raw load-failure token when status is "warning"
function ns:GetAddonStatus(name, perCharacter)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "not_found", nil
    end
    if not self:IsAddonEnabled(name, perCharacter) then
        return "disabled", nil
    end
    if C_AddOns.IsAddOnLoaded(name) then
        return "enabled", nil
    end
    local warnReason = GetFeatureUnitUnloadReason(name)
    if warnReason then
        return "warning", warnReason
    end
    return "enabled", nil
end

-- OneWoW "soft disable" (feature opt-out). Layered OVER Blizzard's enable flag,
-- not a replacement: an opted-out unit stays Blizzard-ENABLED (so the built-in
-- addon list shows it enabled with a "Load Addon" button), but the startup
-- orchestrator skips loading it. Because it stays enabled it can be LoadAddOn'd
-- later the same session with no reload. Stored in OneWoW_DB.global
-- (account-wide SV) with a per-character override map; current-character
-- resolution mirrors Blizzard's char-overrides-account model (char entry:
-- true = out, false = in; nil = inherit account). GUI-free: the char key is
-- built locally so the loader keeps no GUI dependency.
local function OptOutStore()
    return ns.db.global.featureOptOut
end

--- Effective opt-out for the current character (char override wins, else account).
---@param name string addon (folder/TOC) name
---@return boolean optedOut true when OneWoW should not load this unit for this character
function ns:IsFeatureOptedOut(name)
    if not name then return false end
    local oo = OptOutStore()
    local charMap = oo.char[OneWoW_GUI:BuildCharKey()]
    local charVal = charMap and charMap[name]
    if charVal ~= nil then return charVal end
    return oo.account[name] == true
end

--- Opt-out as it applies in a specific scope (drives the Manage Features checkboxes).
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? true = current-character scope (resolved); false/nil = account-wide
---@return boolean optedOut
function ns:IsFeatureOptedOutInScope(name, perCharacter)
    if perCharacter then
        return self:IsFeatureOptedOut(name)
    end
    if not name then return false end
    return OptOutStore().account[name] == true
end

--- Writes the opt-out flag in the requested scope. Char scope stores an explicit
--- boolean so it can re-enable an account-wide opt-out for one character.
---@param name string addon (folder/TOC) name
---@param optedOut boolean desired opt-out state
---@param perCharacter boolean? true = current-character override; false/nil = account-wide
function ns:SetFeatureOptOut(name, optedOut, perCharacter)
    if not name then return end
    local oo = OptOutStore()
    if perCharacter then
        local key = OneWoW_GUI:BuildCharKey()
        oo.char[key] = oo.char[key] or {}
        oo.char[key][name] = optedOut and true or false
    else
        oo.account[name] = optedOut and true or nil
    end
    -- Opt-out changes "wanted" state even when nothing loads/unloads this session;
    -- let read-only surfaces (Home) re-query.
    EventRegistry:TriggerEvent("ns.FeatureStateChanged", name)
end

--- Blizzard-enabled in scope AND not soft-opted-out in that scope.
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? true = current-character scope; false/nil = account-wide
---@return boolean wanted
function ns:IsFeatureWanted(name, perCharacter)
    if not name then return false end
    if not self:IsAddonEnabled(name, perCharacter) then return false end
    return not self:IsFeatureOptedOutInScope(name, perCharacter)
end

--- Effective opt-out for a stored character key (char override wins, else account).
---@param name string addon (folder/TOC) name
---@param charKey string canonical or legacy character key
---@return boolean optedOut
function ns:IsFeatureOptedOutForCharKey(name, charKey)
    if not name or not charKey then return false end
    local oo = OptOutStore()
    local key = OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    if not key then return false end
    local charMap = oo.char[key]
    local charVal = charMap and charMap[name]
    if charVal ~= nil then return charVal end
    return oo.account[name] == true
end

--- Wanted for one character: Blizzard-enabled for that toon AND not soft-opted-out.
---@param name string addon (folder/TOC) name
---@param charKey string canonical or legacy character key
---@return boolean wanted
function ns:IsFeatureWantedForCharKey(name, charKey)
    if not name or not charKey then return false end
    local key = OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    if not key then return false end
    local charName = key:match("^(.-)%-")
    if not charName or charName == "" then return false end
    if C_AddOns.GetAddOnEnableState(name, charName) == 0 then return false end
    return not self:IsFeatureOptedOutForCharKey(name, key)
end

--- Char keys that can affect aggregate wanted state: current toon plus any toon
--- with an explicit opt-out entry for this addon.
---@param name string addon (folder/TOC) name
---@return string[] keys canonical character keys
local function CollectCharKeysForFeature(name)
    local keys = {}
    local seen = {}
    local function add(rawKey)
        if not rawKey then return end
        local key = OneWoW_GUI:CanonicalizeCharacterKey(rawKey)
        if key and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end
    add(OneWoW_GUI:BuildCharKey())
    local oo = OptOutStore()
    for charKey, charMap in pairs(oo.char) do
        if charMap[name] ~= nil then
            add(charKey)
        end
    end
    return keys
end

--- Aggregate wanted scope across known characters (Blizzard + soft opt-out).
---@param name string addon (folder/TOC) name
---@return string scope "all"|"some"|"none"
function ns:GetFeatureWantedAggregate(name)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "none"
    end
    local keys = CollectCharKeysForFeature(name)
    if #keys == 0 then
        if not self:IsFeatureWanted(name, false) then return "none" end
        if C_AddOns.GetAddOnEnableState(name) == 2 then return "all" end
        return "some"
    end
    local wanted, unwanted = 0, 0
    for _, key in ipairs(keys) do
        if self:IsFeatureWantedForCharKey(name, key) then
            wanted = wanted + 1
        else
            unwanted = unwanted + 1
        end
    end
    if wanted > 0 and unwanted > 0 then return "some" end
    if wanted > 0 then return "all" end
    return "none"
end

--- Canonical lifecycle state for a suite feature unit (TOC/addon folder name).
--- Combines Blizzard enable flags and OneWoW soft opt-out. Used by Home,
--- placeholder tabs, and similar read-only surfaces.
---@param name string addon (folder/TOC) name
---@return string state "missing"|"disabled"|"not_loaded"|"pending_disable"|"all"|"some"
function ns:GetFeatureUnitState(name)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "missing"
    end
    if not self:IsAddonEnabled(name, true) then
        return "disabled"
    end
    if not self:IsFeatureWanted(name, true) then
        if C_AddOns.IsAddOnLoaded(name) then
            return "pending_disable"  -- loaded this session; won't load next reload
        end
        return "not_loaded"
    end
    if not C_AddOns.IsAddOnLoaded(name) then
        return "not_loaded"
    end
    if C_AddOns.GetAddOnEnableState(name) == 1 then
        return "some"
    end
    local agg = self:GetFeatureWantedAggregate(name)
    if agg == "some" then return "some" end
    if agg == "all" then return "all" end
    return "some"
end

---@class ns.LoadOpts
---@field deferInCombat boolean? report "COMBAT" instead of loading while in combat (WithAddon queues the retry)

--- Manifest entry that owns a store load unit, or nil.
---@param storeAddon string
---@return table|nil
function ns:GetManifestStoreOwner(storeAddon)
    if not storeAddon then return nil end
    for _, m in ipairs(ns.ModuleManifest) do
        local stores = m.stores
        if stores then
            for _, store in ipairs(stores) do
                if store == storeAddon then
                    return m
                end
            end
        end
    end
    return nil
end

--- Manifest parent addon name for a store load unit (nil when name is a root).
---@param storeName string
---@return string|nil parentAddon
local function GetManifestParent(storeName)
    local owner = ns:GetManifestStoreOwner(storeName)
    return owner and owner.addon or nil
end

--- True when a store still TOC-depends on its manifest parent (soft opt-out of
--- the parent must block EnsureLoaded). Most AltTracker stores load with OneWoW
--- only; Endgame and all Catalog packs remain parent-required.
---@param storeName string
---@return boolean
function ns:StoreRequiresParent(storeName)
    local parent = GetManifestParent(storeName)
    if not parent then return false end
    local m = self:GetManifestByAddon(parent)
    return m and m.parentRequiredStores and m.parentRequiredStores[storeName] and true or false
end

--- FirstRun.CATALOG datastores pulled by a feature (consumer graph), or empty.
--- Catalog pack names are resolved (role or CatDB folder)
--- so BringUp loads the Home-listed CatDB store (TradeSkillDB for ShoppingList).
---@param addonName string
---@return string[]
function ns:GetCatalogDatastores(addonName)
    local catalog = ns.FirstRun and ns.FirstRun.CATALOG
    if not catalog or not addonName then return {} end
    for _, entry in ipairs(catalog) do
        if entry.addonName == addonName and entry.datastores then
            local resolved = {}
            for _, ds in ipairs(entry.datastores) do
                resolved[#resolved + 1] = self:ResolveCatalogPack(ds) or ds
            end
            return resolved
        end
    end
    return {}
end

--- CATALOG roots that list this store in datastores (consumer graph reverse).
---@param storeAddon string
---@return string[] consumerAddonNames
function ns:GetStoreCatalogConsumers(storeAddon)
    local result = {}
    local catalog = ns.FirstRun and ns.FirstRun.CATALOG
    if not catalog or not storeAddon then return result end
    for _, entry in ipairs(catalog) do
        for _, ds in ipairs(entry.datastores) do
            if (self:ResolveCatalogPack(ds) or ds) == storeAddon then
                result[#result + 1] = entry.addonName
                break
            end
        end
    end
    return result
end

--- Ensures an addon is loaded. Idempotent; LoadAddOn pulls the addon's
--- RequiredDeps chain. Returns the raw failure token so callers can localize
--- via GetLoadFailureText.
---@param name string addon (folder/TOC) name to load
---@param opts ns.LoadOpts? optional behavior flags
---@return boolean ok true if the addon is loaded (or already was)
---@return string? reason raw failure token when ok is false ("DISABLED" | "MISSING" | "DEP_DISABLED" | "COMBAT" | "OPTED_OUT" | ...)
function ns:EnsureLoaded(name, opts)
    if not name then return false, "MISSING" end
    if C_AddOns.IsAddOnLoaded(name) then
        return true
    end
    if self:IsFeatureOptedOut(name) then
        self:TraceRecord("ensureLoaded.skip", name, { reason = "OPTED_OUT" })
        return false, "OPTED_OUT"
    end
    if self:StoreRequiresParent(name) then
        local parent = GetManifestParent(name)
        if parent and self:IsFeatureOptedOut(parent) then
            self:TraceRecord("ensureLoaded.skip", name, { reason = "OPTED_OUT_PARENT" })
            return false, "OPTED_OUT"
        end
    end
    if opts and opts.deferInCombat and ns.Restriction.IsInCombat() then
        self:TraceRecord("ensureLoaded.skip", name, { reason = "COMBAT" })
        return false, "COMBAT"
    end
    local ok, reason = C_AddOns.LoadAddOn(name)
    self:TraceRecord("ensureLoaded", name, { ok = ok and true or false, reason = reason })
    if not ok then
        return false, reason
    end
    -- Core-driven init runs in the C_AddOns.LoadAddOn hook below (single driver
    -- for every load path, including Blizzard's "Load Addon" button), so it has
    -- already fired synchronously by the time LoadAddOn returns here.
    return true
end

-- Lazy: ModuleManifest is defined later in this file, but only at file scope --
-- it always exists by the time any load event can call IsManifestUnit.
local manifestUnits

--- True for ModuleManifest roots and their data-store units -- the set of load
--- units whose lifecycle hooks core is allowed to dispatch.
---@param name string addon folder / _G key
---@return boolean
function ns:IsManifestUnit(name)
    if not name then return false end
    if not manifestUnits then
        manifestUnits = {}
        for _, m in ipairs(ns.ModuleManifest) do
            if m.addon and m.addon ~= "" then
                manifestUnits[m.addon] = true
            end
            if m.stores then
                for _, store in ipairs(m.stores) do
                    manifestUnits[store] = true
                end
            end
        end
    end
    return manifestUnits[name] == true
end

--- Append unique names from `extra` onto `units`.
---@param units string[]
---@param extra string[]|nil
local function AppendUnique(units, extra)
    if not extra then return end
    local seen = {}
    for _, name in ipairs(units) do
        seen[name] = true
    end
    for _, name in ipairs(extra) do
        if not seen[name] then
            units[#units + 1] = name
            seen[name] = true
        end
    end
end

--- Manifest unit set for a feature: { addon, ...owned stores, ...consumer pulls }.
--- Returns nil when name is not a manifest root (caller falls back to { name } plus
--- any FirstRun.CATALOG datastores for that addon).
---@param addonName string
---@return string[]|nil
local function ManifestUnitsFor(addonName)
    local manifest = ns.ModuleManifest
    if not manifest then return nil end
    for _, m in ipairs(manifest) do
        if m.addon == addonName then
            local units = { m.addon }
            -- lazyStores stay out of BringUp: Catalog packs parse on the tab /
            -- quest event / Item Search source that needs them, not at login.
            if m.stores and not m.lazyStores then
                for _, store in ipairs(m.stores) do
                    units[#units + 1] = store
                end
            end
            local pulls = ns:GetCatalogDatastores(addonName)
            if #pulls > 0 then
                AppendUnique(units, pulls)
            end
            return units
        end
    end
    return nil
end

-- Login pass over an already-loaded set. No-ops before PLAYER_LOGIN (cold start
-- defers OnPlayerLogin to RunManifestLoginPhase). The units' one-shot didLogin
-- guards make a repeat call safe.
local function Settle(units)
    if not ns._playerLoginFired then return end
    for _, name in ipairs(units) do
        ns.Lifecycle.RunUnitHook(name, "OnPlayerLogin")
    end
end

-- Synthetic entering-world catch-up for units loaded mid-session: they missed the
-- real PLAYER_ENTERING_WORLD, so core delivers one now. isLogin=true mirrors the
-- cold-start OnPlayerLogin -> PEW(isLogin) sequence; isZoning stays false so
-- zone-refresh logic does not spuriously fire (the player did not zone). No-ops
-- before PLAYER_LOGIN: at cold start the real event delivers PEW with true args.
local function CatchUpEnteringWorld(units)
    if not ns._playerLoginFired then return end
    for _, name in ipairs(units) do
        ns:TraceRecord("catchUpPEW", name)
        ns.Lifecycle.RunUnitHook(name, "OnPlayerEnteringWorld", true, false, false)
    end
end

-- Core-driven post-load init. The unit's own ADDON_LOADED is never delivered when
-- it is LoadAddOn'd inside another addon's dispatch, so core drives init via a
-- standardized one-shot OnAddonLoaded() hook. OnPlayerLogin / OnPlayerEnteringWorld
-- are NOT fired here: Settle / CatchUpEnteringWorld drive them once the whole set
-- is loaded (see ns:BringUp), or the LoadAddOn hook catches up a lone load.
local function RunPostLoadInit(name)
    ns:DispatchUnitOnAddonLoaded(name)
    -- Symmetry with DispatchAddonLoaded: LoD/force-loaded units never deliver
    -- their own ADDON_LOADED, so notify addon-loaded watchers here too. Dedup in
    -- NotifyAddonLoadedWatchers collapses the mid-session double-path (this hook
    -- plus the real ADDON_LOADED) to a single fan-out.
    ns:NotifyAddonLoadedWatchers(name)
end

-- Single post-load init driver: every load path funnels through C_AddOns.LoadAddOn
-- (the orchestrator, EnsureLoaded, on-demand WithAddon, and Blizzard's addon-list
-- "Load Addon" button on a soft-disabled-but-enabled unit). Post-hooking it here
-- means a manual button click runs the unit through its full init for free. This
-- hook makes no policy decisions about persisted state: opt-out clearing lives on
-- the explicit-enable surfaces (Manage Features, the AddonList_LoadAddOn hook
-- below), never in the generic load path.
hooksecurefunc(C_AddOns, "LoadAddOn", function(nameOrIndex)
    local name = nameOrIndex
    if type(name) ~= "string" then
        name = C_AddOns.GetAddOnInfo(nameOrIndex)
    end
    if not name or not C_AddOns.IsAddOnLoaded(name) then return end
    ns:TraceRecord("loadAddOn.hook", name, { inBringUp = inBringUp })
    RunPostLoadInit(name)
    -- Single chokepoint for every load path; let read-only surfaces (Home) re-query.
    EventRegistry:TriggerEvent("ns.FeatureStateChanged", name)
    -- A lone load outside a BringUp batch (e.g. Blizzard's addon-list "Load Addon"
    -- button) that happens after login must catch the unit up on the login and
    -- entering-world hooks it missed. BringUp drives these itself for batches, so
    -- skip while inBringUp to avoid firing them before the whole set is loaded.
    if not inBringUp and ns._playerLoginFired then
        local single = { name }
        Settle(single)
        CatchUpEnteringWorld(single)
    end
end)

-- The Blizzard addon list's "Load Addon" button is an explicit user enable:
-- clear any per-character soft opt-out so the choice sticks across reloads.
-- Programmatic C_AddOns.LoadAddOn calls (ours or third-party) never touch
-- opt-out -- user intent is only ever expressed through this button or
-- Manage Features, and each surface owns its own clear. If a future patch
-- renames AddonList_LoadAddOn this hook silently stops clearing (the unit
-- still loads and inits via the generic hook); Manage Features remains the
-- in-suite path to clear opt-out.
hooksecurefunc("AddonList_LoadAddOn", function(index)
    local name = C_AddOns.GetAddOnInfo(index)
    if not name or not C_AddOns.IsAddOnLoaded(name) then return end
    if ns:IsFeatureOptedOut(name) then
        ns:TraceRecord("optOut.clear", name, { scope = "char", source = "addonList" })
        ns:SetFeatureOptOut(name, false, true)
    end
end)

--- Brings up a manifest feature and its data stores as one batch: load the whole
--- set (each unit's OnAddonLoaded fires via the LoadAddOn hook), then a single
--- OnPlayerLogin pass, then -- only mid-session -- a synthetic OnPlayerEnteringWorld
--- catch-up. At cold start (before PLAYER_LOGIN) Settle / CatchUpEnteringWorld
--- no-op and the manifest login phase plus the real PLAYER_ENTERING_WORLD drive
--- those hooks with authoritative args. Opted-out / disabled units are skipped by
--- EnsureLoaded and excluded from the settle/catch-up passes.
---@param addonName string manifest feature (or any addon) to bring up
function ns:BringUp(addonName)
    if not addonName then return end
    -- Non-manifest roots (should be rare) still pull CATALOG datastores when listed.
    local units = ManifestUnitsFor(addonName)
    if not units then
        units = { addonName }
        local pulls = self:GetCatalogDatastores(addonName)
        if #pulls > 0 then
            AppendUnique(units, pulls)
        end
    end
    local midSession = ns._playerLoginFired
    self:TraceRecord("bringUp.begin", addonName, { midSession = midSession and true or false, units = #units })
    inBringUp = true
    for _, name in ipairs(units) do
        self:EnsureLoaded(name)
    end
    inBringUp = false
    local loaded = {}
    for _, name in ipairs(units) do
        if C_AddOns.IsAddOnLoaded(name) then
            loaded[#loaded + 1] = name
        end
    end
    Settle(loaded)
    if midSession then
        CatchUpEnteringWorld(loaded)
    end
    self:TraceRecord("bringUp.end", addonName, { loaded = #loaded })
end

--- Loads an addon and dispatches a callback, removing the if/else at the call
--- site. On success runs onReady(); on failure runs onFail(reason), or prints the
--- localized reason once if onFail is nil. A "COMBAT" deferral is queued to
--- PLAYER_REGEN_ENABLED rather than failed.
---@param name string addon (folder/TOC) name to load
---@param onReady fun()? called once the addon is loaded
---@param onFail fun(reason: string?)? called on failure; if nil, the reason is printed once
---@param opts ns.LoadOpts? optional behavior flags
---@return boolean ok true if onReady ran this call (false when failed or deferred to combat end)
function ns:WithAddon(name, onReady, onFail, opts)
    local ok, reason = self:EnsureLoaded(name, opts)
    if ok then
        if onReady then onReady() end
        return true
    end
    if reason == "COMBAT" then
        self:TraceRecord("defer.combat", name)
        tinsert(pendingCombat, { name = name, onReady = onReady, onFail = onFail, opts = opts })
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end
    if onFail then
        onFail(reason)
    elseif not warned[name] then
        warned[name] = true
        print("|cFFFFD100OneWoW:|r " .. self:GetLoadFailureText(reason))
    end
    return false
end

-- Authoritative list of suite load units the core knows about. Single source of
-- truth for both the startup orchestrator (loads `loadPhase`-tagged entries) and
-- the load banner (reports any that are present). Entries without a `loadPhase`
-- are skipped by the orchestrator.
-- `module` is the RegisterModule name for hub modules (used by the lazy-tab hook).
-- `tabOrder` is the row-1 hub tab sort key (required on hub entries; load order
-- remains array-driven). `stores` lists a parent's data-store load units.
-- `lazyStores = true` skips those stores at login BringUp and the startup
-- store pass; a pack-backed tab, quest event, or Item Search source loads them.
ns.ModuleManifest = {
    { addon = "OneWoW_Notes",           display = "Notes",         cmd = "/1wn",   module = "notes",      tabOrder = 1, loadPhase = "login" },
    { addon = "OneWoW_AltTracker",      display = "AltTracker",    cmd = "/1wat",  module = "alttracker", tabOrder = 2, loadPhase = "login",
        storePolicy = "optional",
        -- Endgame still TOC-Depends on the hub (season/progress config API).
        parentRequiredStores = {
            OneWoW_AltTracker_Endgame = true,
        },
        stores = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
            "OneWoW_AltTracker_Professions",
            "OneWoW_AltTracker_Collections",
            "OneWoW_AltTracker_Endgame",
            "OneWoW_AltTracker_Accounting",
            "OneWoW_AltTracker_Auctions",
        } },
    { addon = "OneWoW_Catalog",         display = "Catalog",       cmd = "/1wcat", module = "catalog",    tabOrder = 3, loadPhase = "login",
        storePolicy = "optional",
        lazyStores = true,
        -- Era packs, Other, and Tradeskills. Catalog itself is the query runtime.
        parentRequiredStores = {
            OneWoW_CatDB_Classic = true,
            OneWoW_CatDB_BurningCrusade = true,
            OneWoW_CatDB_WrathoftheLichKing = true,
            OneWoW_CatDB_Cataclysm = true,
            OneWoW_CatDB_MistsofPandaria = true,
            OneWoW_CatDB_WarlordsofDraenor = true,
            OneWoW_CatDB_Legion = true,
            OneWoW_CatDB_BattleforAzeroth = true,
            OneWoW_CatDB_Shadowlands = true,
            OneWoW_CatDB_Dragonflight = true,
            OneWoW_CatDB_TheWarWithin = true,
            OneWoW_CatDB_Midnight = true,
            OneWoW_CatDB_Other = true,
            OneWoW_CatDB_TradeSkillDB = true,
        },
        stores = {
            "OneWoW_CatDB_Classic",
            "OneWoW_CatDB_BurningCrusade",
            "OneWoW_CatDB_WrathoftheLichKing",
            "OneWoW_CatDB_Cataclysm",
            "OneWoW_CatDB_MistsofPandaria",
            "OneWoW_CatDB_WarlordsofDraenor",
            "OneWoW_CatDB_Legion",
            "OneWoW_CatDB_BattleforAzeroth",
            "OneWoW_CatDB_Shadowlands",
            "OneWoW_CatDB_Dragonflight",
            "OneWoW_CatDB_TheWarWithin",
            "OneWoW_CatDB_Midnight",
            "OneWoW_CatDB_Other",
            "OneWoW_CatDB_TradeSkillDB",
        } },
    { addon = "OneWoW_Trackers",        display = "Trackers",      cmd = "/1wt",   module = "trackers",   tabOrder = 4, loadPhase = "login" },
    { addon = "OneWoW_QoL",             display = "QoL",           cmd = "/1wqol", module = "qol",        tabOrder = 5, loadPhase = "login" },
    { addon = "OneWoW_DirectDeposit",   display = "DirectDeposit", cmd = "/1wdd",  loadPhase = "login" },
    { addon = "OneWoW_ShoppingList",    display = "ShoppingList",  cmd = "/1wsl",  loadPhase = "login" },
    { addon = "OneWoW_Mail",            display = "Mail",          cmd = "/1wmail", loadPhase = "login" },
    { addon = "OneWoW_Bags",            display = "Bags",          cmd = "/1wbags", loadPhase = "login" },
    { addon = "OneWoW_Utility_DevTool", display = "DevTools",      cmd = "/1wdt",  loadPhase = "login" },
}
local Manifest = ns.ModuleManifest

-- Manage Features sub-row titles (existing Home / scoped locale keys).
local STORE_LABEL_KEYS = {
    OneWoW_AltTracker_Storage     = "DATA_MOD_STORAGE",
    OneWoW_AltTracker_Character     = "DATA_MOD_CHARACTER",
    OneWoW_AltTracker_Professions   = "DATA_MOD_PROFESSIONS",
    OneWoW_AltTracker_Collections   = "DATA_MOD_COLLECTIONS",
    OneWoW_AltTracker_Endgame       = "DATA_MOD_ENDGAME",
    OneWoW_AltTracker_Accounting    = "DATA_MOD_ACCOUNTING",
    OneWoW_AltTracker_Auctions      = "DATA_MOD_AUCTIONS",
    OneWoW_CatDB_Classic            = "CAT_MOD_ERA_CLASSIC",
    OneWoW_CatDB_BurningCrusade     = "CAT_MOD_ERA_BURNINGCRUSADE",
    OneWoW_CatDB_WrathoftheLichKing = "CAT_MOD_ERA_WOTLK",
    OneWoW_CatDB_Cataclysm          = "CAT_MOD_ERA_CATACLYSM",
    OneWoW_CatDB_MistsofPandaria    = "CAT_MOD_ERA_MOP",
    OneWoW_CatDB_WarlordsofDraenor  = "CAT_MOD_ERA_WOD",
    OneWoW_CatDB_Legion             = "CAT_MOD_ERA_LEGION",
    OneWoW_CatDB_BattleforAzeroth   = "CAT_MOD_ERA_BFA",
    OneWoW_CatDB_Shadowlands        = "CAT_MOD_ERA_SHADOWLANDS",
    OneWoW_CatDB_Dragonflight       = "CAT_MOD_ERA_DRAGONFLIGHT",
    OneWoW_CatDB_TheWarWithin       = "CAT_MOD_ERA_TWW",
    OneWoW_CatDB_Midnight           = "CAT_MOD_ERA_MIDNIGHT",
    OneWoW_CatDB_Other              = "CAT_MOD_ERA_OTHER",
    OneWoW_CatDB_TradeSkillDB       = "CAT_MOD_TRADESKILLDB",
}

--- Manifest entry for a root load unit, or nil.
---@param addonName string
---@return table|nil
function ns:GetManifestByAddon(addonName)
    if not addonName then return nil end
    for _, entry in ipairs(Manifest) do
        if entry.addon == addonName then
            return entry
        end
    end
    return nil
end

--- Manifest roots that own data stores, in manifest order.
---@return table[]
function ns:GetManifestParentsWithStores()
    local result = {}
    for _, entry in ipairs(Manifest) do
        if entry.stores and #entry.stores > 0 then
            result[#result + 1] = entry
        end
    end
    return result
end

--- Locale key for a store load unit's display name in Manage Features.
---@param storeAddon string
---@return string|nil
function ns:GetStoreLabelKey(storeAddon)
    return STORE_LABEL_KEYS[storeAddon]
end

--- Runtime CatDB query addon is always pulled with an era; hide it in Manage Features.
---@param storeAddon string
---@return boolean
function ns:IsHiddenStore(storeAddon)
    return C_AddOns.GetAddOnMetadata(storeAddon, "X-OneWoW-CatDB-Runtime") == "1"
end

--- True when a store is owned by a `lazyStores` hub (Catalog packs today).
--- Login BringUp and the startup store pass skip these; a pack-backed tab,
--- quest event, or Item Search source loads them on demand.
---@param storeName string
---@return boolean
function ns:IsLazyStore(storeName)
    if not storeName then return false end
    local owner = ns:GetManifestStoreOwner(storeName)
    return owner and owner.lazyStores and true or false
end

-- Row-1 tab order comes from each hub entry's tabOrder; placeholder labels from module.
local MODULE_TAB_LOCALE_KEYS = {
    notes      = "MODULE_NOTES",
    alttracker = "MODULE_ALTTRACKER",
    catalog    = "MODULE_CATALOG",
    trackers   = "MODULE_TRACKERS",
    qol        = "MODULE_QOL",
}

--- Tab sort order for a hub module name (RegisterModule `name` field).
---@param moduleName string e.g. "notes", "alttracker"
---@return number order explicit tabOrder from manifest, or 99 when unknown/missing
function ns:GetModuleTabOrder(moduleName)
    for _, entry in ipairs(ns.ModuleManifest) do
        if entry.module == moduleName then
            return entry.tabOrder or 99
        end
    end
    return 99
end

--- Placeholder row-1 tabs for hub modules not yet registered (not loaded).
--- Order from tabOrder via GetModuleTabOrder; addon names from manifest hub entries.
---@return table[] list of { name, addonName, order, localeKey }
function ns:GetAlwaysShowModules()
    local result = {}
    for _, entry in ipairs(ns.ModuleManifest) do
        if entry.module then
            result[#result + 1] = {
                name      = entry.module,
                addonName = entry.addon,
                order     = self:GetModuleTabOrder(entry.module),
                localeKey = MODULE_TAB_LOCALE_KEYS[entry.module],
            }
        end
    end
    return result
end

--- Count of currently-loaded suite root modules. Iterates ModuleManifest roots
--- only, so it excludes core (`OneWoW`, not in the manifest) and every data-store
--- unit (those live under a root's `stores`). Reflects live opt-out / LoD state.
--- Drives the addon-compartment tooltip count.
---@return number
function ns:GetLoadedModuleCount()
    local n = 0
    for _, m in ipairs(ns.ModuleManifest) do
        if m.addon and m.addon ~= "" and C_AddOns.IsAddOnLoaded(m.addon) then
            n = n + 1
        end
    end
    return n
end

-- Startup orchestrator. Tier-2 modules and data stores are `LoadOnDemand: 1`
-- (they no longer auto-load), so core pulls the enabled ones from the manifest.
ns.LoadOrchestrator = ns.LoadOrchestrator or {}
local Orchestrator = ns.LoadOrchestrator

--- Loads every `login`-phase manifest module, then each module's data stores,
--- in dependency order. Called from core's ADDON_LOADED (before PLAYER_LOGIN):
--- EnsureLoaded drives each unit's OnAddonLoaded hook synchronously, so every
--- DB is built in core-controlled order before the one-shot PLAYER_LOGIN fires.
--- A Blizzard-disabled (incl. per-character) module just fails EnsureLoaded with
--- "DISABLED" and is skipped; parent-required stores (Endgame, Catalog packs) are
--- also skipped when their hub is soft-opted-out via StoreRequiresParent.
--- Catalog `lazyStores` are skipped here; they load on the tab / quest event /
--- Item Search source that needs them.
function Orchestrator:RunStartupPhase()
    ns:TraceRecord("startup.begin")
    for _, m in ipairs(Manifest) do
        if m.loadPhase == "login" and m.addon and m.addon ~= "" then
            -- BringUp loads the feature and its stores as one set. A soft opt-out
            -- (OneWoW SavedVariables) skips the unit and its stores via EnsureLoaded
            -- without touching Blizzard's enable flag, so it can be loaded later
            -- this session (Manage Features / the Blizzard "Load Addon" button)
            -- with no reload. Pre-login, BringUp's Settle / catch-up no-op; the
            -- manifest login phase and the real PLAYER_ENTERING_WORLD drive those.
            if not ns:IsFeatureOptedOut(m.addon) then
                ns:BringUp(m.addon)
            end
        end
    end
    -- Independent stores opted in while their owning hub is soft-opted-out
    -- (e.g. Storage without AltTracker). BringUp skipped them with the hub;
    -- parent-required stores still refuse via StoreRequiresParent.
    -- lazyStores (Catalog packs) stay unloaded until a tab / quest event /
    -- Item Search source asks for them.
    for _, m in ipairs(Manifest) do
        if m.stores and not m.lazyStores then
            for _, store in ipairs(m.stores) do
                if not ns:IsFeatureOptedOut(store) then
                    ns:EnsureLoaded(store)
                end
            end
        end
    end
    ns:TraceRecord("startup.end")
end

--- Used by the lazy-tab hook: loads a `lazy` module's addon the first time its
--- tab is opened. Dormant today (every manifest module is `login`-phase); ready
--- for when a pure-window module is tagged `lazy`.
---@param moduleName string module name (RegisterModule name) whose tab was opened
function Orchestrator:EnsureModuleForTab(moduleName)
    -- Already-loaded modules self-registered; nothing to pull.
    local registry = ns.ModuleRegistry
    if registry and registry:GetModule(moduleName) then return end
    for _, m in ipairs(Manifest) do
        if m.module == moduleName and m.loadPhase == "lazy" and m.addon and m.addon ~= "" then
            ns:EnsureLoaded(m.addon)
            return
        end
    end
end

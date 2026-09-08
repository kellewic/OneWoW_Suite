-- OneWoW/Core/FirstRunWizard.lua
-- First-login feature picker + a reusable "Manage Features" panel that the
-- Settings tab exposes. Two ways to turn features off/on:
--   * Apply (soft) - writes OneWoW's opt-out layer only; the addon stays
--     Blizzard-enabled (so the built-in list shows it with a "Load Addon"
--     button) while OneWoW skips loading it. Reload-free: a per-row Load Addon
--     button (or re-checking + Apply) loads it back this session.
--   * Apply & Reload (hard) - writes Blizzard's Enable/DisableAddOn flags and
--     reloads (the only way to truly evict a loaded addon, or to re-enable a
--     Blizzard-disabled one).
-- Shared/dependency datastores follow the consumer graph (and BringUp pulls).
-- Parent-required stores (Endgame and Catalog packs) still TOC-require their owning hub.

local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local C = OneWoW_GUI.Constants.GUI

local L = ns.L

local C_AddOns = C_AddOns
local UnitName = UnitName

ns.FirstRun = ns.FirstRun or {}
local FirstRun = ns.FirstRun

-- Authoritative feature catalog. Each entry:
--   addonName      - the WoW addon folder / TOC name (what DisableAddOn sees)
--   labelKey       - localized display name key
--   summaryKey     - localized short description key
--   group          - "feature" | "standalone" | "utility" - grouping in the UI
--   datastores     - list of sibling data addons this feature needs loaded
-- Feature faces come from OneWoW:GetFeatureIcon(addonName) (Core/FeatureIcons.lua).
-- Datastores are "pulled in" if any checked feature needs them.
FirstRun.CATALOG = {
    -- Core features
    {
        addonName   = "OneWoW_AltTracker",
        labelKey    = "WIZARD_FEATURE_ALTTRACKER",
        summaryKey  = "WIZARD_FEATURE_ALTTRACKER_DESC",
        group       = "feature",
        datastores  = {},
    },
    {
        addonName   = "OneWoW_Catalog",
        labelKey    = "WIZARD_FEATURE_CATALOG",
        summaryKey  = "WIZARD_FEATURE_CATALOG_DESC",
        group       = "feature",
        datastores  = {
            "OneWoW_AltTracker_Storage",
        },
    },
    {
        addonName   = "OneWoW_Notes",
        labelKey    = "WIZARD_FEATURE_NOTES",
        summaryKey  = "WIZARD_FEATURE_NOTES_DESC",
        group       = "feature",
        datastores  = {},
        -- In-unit toggles (not TOC load units). Same sub-row chrome as stores;
        -- Apply calls setEnabled instead of SetFeatureOptOut / EnsureLoaded.
        inUnitFeatures = {
            {
                id         = "waypins",
                labelKey   = "WIZARD_FEATURE_WAYPINS",
                summaryKey = "WIZARD_FEATURE_WAYPINS_DESC",
                iconKey    = "OneWoW_Notes_WayPins",
                isEnabled  = function()
                    if OneWoW_Notes_API then
                        return OneWoW_Notes_API.IsWayPinsEnabled()
                    end
                    return true
                end,
                setEnabled = function(enabled)
                    if OneWoW_Notes_API then
                        OneWoW_Notes_API.SetWayPinsEnabled(enabled)
                    end
                end,
            },
        },
    },
    {
        addonName   = "OneWoW_Trackers",
        labelKey    = "WIZARD_FEATURE_TRACKERS",
        summaryKey  = "WIZARD_FEATURE_TRACKERS_DESC",
        group       = "feature",
        datastores  = {},
    },
    {
        addonName   = "OneWoW_QoL",
        labelKey    = "WIZARD_FEATURE_QOL",
        summaryKey  = "WIZARD_FEATURE_QOL_DESC",
        group       = "feature",
        datastores  = {},
    },

    -- Standalone addons
    {
        addonName   = "OneWoW_Bags",
        labelKey    = "WIZARD_FEATURE_BAGS",
        summaryKey  = "WIZARD_FEATURE_BAGS_DESC",
        group       = "standalone",
        datastores  = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
        },
    },
    {
        addonName   = "OneWoW_ShoppingList",
        labelKey    = "WIZARD_FEATURE_SHOPPINGLIST",
        summaryKey  = "WIZARD_FEATURE_SHOPPINGLIST_DESC",
        group       = "standalone",
        datastores  = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_CatDB_TradeSkillDB",
        },
    },
    {
        addonName   = "OneWoW_DirectDeposit",
        labelKey    = "WIZARD_FEATURE_DIRECTDEPOSIT",
        summaryKey  = "WIZARD_FEATURE_DIRECTDEPOSIT_DESC",
        group       = "standalone",
        datastores  = {},
    },
    {
        addonName   = "OneWoW_Mail",
        labelKey    = "WIZARD_FEATURE_MAIL",
        summaryKey  = "WIZARD_FEATURE_MAIL_DESC",
        group       = "standalone",
        datastores  = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
        },
    },

    -- Utilities
    {
        addonName   = "OneWoW_Utility_DevTool",
        labelKey    = "WIZARD_FEATURE_DEVTOOL",
        summaryKey  = "WIZARD_FEATURE_DEVTOOL_DESC",
        group       = "utility",
        datastores  = {},
    },
}

-- Per-data-module icons (numeric file IDs) so sub-rows mirror the parent's icon slot.
local STORE_ICONS = {
    OneWoW_CatDB_TradeSkillDB       = 136241,
    OneWoW_AltTracker_Accounting    = 413573,   -- achievement_guildperk_cashflow_rank2
    OneWoW_AltTracker_Auctions      = 413570,   -- achievement_guildperk_bartering
    OneWoW_AltTracker_Character     = 134148,   -- inv_misc_grouplooking
    OneWoW_AltTracker_Collections   = 1418621,  -- item_shop_giftbox01
    OneWoW_AltTracker_Endgame       = 255347,   -- achievement_dungeon_heroic_gloryoftheraider
    OneWoW_AltTracker_Professions   = 4624728,  -- inv_10_specialization_professionbook_engineering_color1
    OneWoW_AltTracker_Storage       = 1542852,  -- inv_misc_treasurechest03b
}

-- Sub-row copy and "What's affected?" modal keys (Catalog optional stores only).
local STORE_DESC_KEYS = {
    OneWoW_CatDB_TradeSkillDB      = "WIZARD_CAT_DATA_TRADESKILLS_DESC",
}

local function ForEachInUnitFeature(fn)
    for _, entry in ipairs(FirstRun.CATALOG) do
        local feats = entry.inUnitFeatures
        if feats then
            for _, feat in ipairs(feats) do
                fn(entry, feat)
            end
        end
    end
end

function FirstRun:GetInUnitFeatureSelections()
    local selections = {}
    ForEachInUnitFeature(function(_, feat)
        selections[feat.id] = feat.isEnabled() and true or false
    end)
    return selections
end

function FirstRun:ApplyInUnitFeatures(featureSelections)
    if not featureSelections then return end
    ForEachInUnitFeature(function(_, feat)
        local want = featureSelections[feat.id]
        if want ~= nil then
            feat.setEnabled(want and true or false)
        end
    end)
end

local STORE_AFFECTED_KEYS = {
    OneWoW_Catalog = {
        title = "WIZARD_AFFECTED_CATALOG_TITLE",
        body  = "WIZARD_AFFECTED_CATALOG_BODY",
    },
    OneWoW_CatDB_TradeSkillDB = {
        title = "WIZARD_AFFECTED_TRADESKILLS_TITLE",
        body  = "WIZARD_AFFECTED_TRADESKILLS_BODY",
    },
}

local TOPIC_LABEL_KEYS = {
    hubs = "CAT_MOD_TOPIC_HUBS",
    zone = "CAT_MOD_TOPIC_ZONE",
    zone_extra = "CAT_MOD_TOPIC_ZONE_EXTRA",
    npc = "CAT_MOD_TOPIC_NPC",
    quest = "CAT_MOD_TOPIC_QUEST",
    item = "CAT_MOD_TOPIC_ITEM",
    achievement = "CAT_MOD_TOPIC_ACHIEVEMENT",
    mappin = "CAT_MOD_TOPIC_MAPPIN",
}

local function StoreTitle(store)
    local title = ns.CatalogData:GetStoreTitle(store)
    if title and title ~= "" then
        return title
    end
    local labelKey = ns:GetStoreLabelKey(store)
    return labelKey and L[labelKey] or store
end

local function StoreDescKey(store)
    if STORE_DESC_KEYS[store] then
        return STORE_DESC_KEYS[store]
    end
    if store == "OneWoW_CatDB_Other" then
        return "WIZARD_CAT_DATA_OTHER_DESC"
    end
    if ns.CatalogData:IsEraAddon(store) then
        return "WIZARD_CAT_DATA_ERA_DESC"
    end
    return nil
end

local function TopicLabel(topic)
    if topic == "item" then
        return ITEMS
    end
    if topic == "achievement" then
        return ACHIEVEMENTS
    end
    local key = TOPIC_LABEL_KEYS[topic]
    return key and L[key] or topic
end

-- CATALOG.datastores may name a pack role or CatDB folder.
-- Resolve at consume time so ShoppingList always pulls TradeSkillDB.
local function ResolveCatalogDatastore(name)
    return ns:ResolveCatalogPack(name) or name
end

local PARENT_MODULE_LABEL_KEYS = {
    OneWoW_Catalog    = "MODULE_CATALOG",
    OneWoW_AltTracker = "MODULE_ALTTRACKER",
}

local PARENT_DATA_TOOLTIP_KEYS = {
    OneWoW_Catalog    = "WIZARD_DATA_TOOLTIP_CATALOG",
    OneWoW_AltTracker = "WIZARD_DATA_TOOLTIP_ALTTRACKER",
}

local function BuildDatastoreAddonList()
    local seen = {}
    local list = {}
    local function add(name)
        if name and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    for _, entry in ipairs(ns.ModuleManifest) do
        if entry.stores then
            for _, store in ipairs(entry.stores) do
                add(store)
            end
        end
    end
    for _, entry in ipairs(FirstRun.CATALOG) do
        for _, ds in ipairs(entry.datastores) do
            add(ds)
        end
    end
    return list
end

local DATASTORE_ADDONS = BuildDatastoreAddonList()

-- Loads a feature module and its manifest data stores now, so a reload-free enable
-- arms this session. ns:BringUp loads the whole set (OnAddonLoaded each) before
-- a single OnPlayerLogin pass and a mid-session entering-world catch-up, matching
-- the cold-start orchestrator's ordering.
local function LoadFeatureNow(addonName)
    ns:BringUp(addonName)
end

-- Consumer feature that forces a store on. Parent soft-opt-out only blocks
-- stores that still TOC-require their owner (StoreRequiresParent); other stores
-- can be consumer-pulled with the owning hub off. Uses staged checkbox
-- selections (not live IsFeatureWanted) for Apply preview.
local function GetStoreConsumerForced(storeAddon, selections)
    local owner = ns:GetManifestStoreOwner(storeAddon)
    if owner and ns:StoreRequiresParent(storeAddon) and not selections[owner.addon] then
        return nil
    end
    for _, entry in ipairs(FirstRun.CATALOG) do
        if selections[entry.addonName] then
            for _, ds in ipairs(entry.datastores) do
                if ResolveCatalogDatastore(ds) == storeAddon then
                    if owner and owner.addon ~= entry.addonName then
                        return entry.addonName
                    end
                end
            end
        end
    end
    return nil
end

-- Denominator pool: owned stores visible under a selected parent, independent
-- (non-parent-required) stores always, plus consumer pulls.
local function ComputeEligibleDatastorePool(selections)
    local pool = {}
    for _, entry in ipairs(ns.ModuleManifest) do
        if entry.stores then
            for _, store in ipairs(entry.stores) do
                if selections[entry.addon] or not ns:StoreRequiresParent(store) then
                    pool[store] = true
                end
            end
        end
    end
    for _, entry in ipairs(FirstRun.CATALOG) do
        if selections[entry.addonName] then
            for _, ds in ipairs(entry.datastores) do
                ds = ResolveCatalogDatastore(ds)
                local owner = ns:GetManifestStoreOwner(ds)
                if not owner
                    or selections[owner.addon]
                    or not ns:StoreRequiresParent(ds) then
                    pool[ds] = true
                end
            end
        end
    end
    return pool
end

-- Effective wanted set: consumer graph + optional storeSelections.
-- Parent-required stores (Endgame, Catalog packs) only count when the hub is on.
-- Other AltTracker stores follow storeSelections even with the hub off.
local function ComputeDatastoreState(selections, storeSelections)
    storeSelections = storeSelections or {}
    local wanted = {}
    for _, ds in ipairs(DATASTORE_ADDONS) do
        wanted[ds] = false
    end
    for _, entry in ipairs(FirstRun.CATALOG) do
        if selections[entry.addonName] then
            for _, ds in ipairs(entry.datastores) do
                ds = ResolveCatalogDatastore(ds)
                local owner = ns:GetManifestStoreOwner(ds)
                if not owner
                    or selections[owner.addon]
                    or not ns:StoreRequiresParent(ds) then
                    wanted[ds] = true
                end
            end
        end
    end
    for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
        if manifest.storePolicy == "optional" then
            for _, store in ipairs(manifest.stores) do
                if storeSelections[store] then
                    if not ns:StoreRequiresParent(store) or selections[manifest.addon] then
                        wanted[store] = true
                    end
                end
            end
        elseif manifest.storePolicy == "bundled" and selections[manifest.addon] then
            for _, store in ipairs(manifest.stores) do
                wanted[store] = true
            end
        end
    end
    return wanted
end

function FirstRun:GetCurrentSelections(perCharacter)
    local selections = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        selections[entry.addonName] = ns:IsFeatureWanted(entry.addonName, perCharacter)
    end
    return selections
end

function FirstRun:GetCurrentStoreSelections(perCharacter)
    local selections = {}
    for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
        if manifest.storePolicy == "optional" then
            for _, store in ipairs(manifest.stores) do
                if ns:IsHiddenStore(store) then
                    selections[store] = true
                else
                    selections[store] = ns:IsFeatureWanted(store, perCharacter)
                end
            end
        end
    end
    return selections
end

-- Apply the staged selections in `perCharacter` scope.
--
-- `hard == false` (soft, the "Apply" button): writes only OneWoW's opt-out layer,
-- never Blizzard's flag. Unchecked features are opted out (they drop next reload;
-- a loaded one stays this session since WoW can't evict it). Checked features are
-- opted in and, if Blizzard-enabled but not loaded, loaded on the fly + their
-- stores, so the enable arms reload-free. Never reloads.
--
-- `hard == true` (the "Apply & Reload" button): writes Blizzard's enable flags
-- (the only way to truly unload, or to re-enable a Blizzard-disabled unit) and
-- clears the soft opt-out (Blizzard becomes authoritative for these), then prompts
-- a reload. Returns true when a reload was prompted.
function FirstRun:Apply(selections, perCharacter, hard, storeSelections, featureSelections)
    storeSelections = storeSelections or {}

    local datastoreState = ComputeDatastoreState(selections, storeSelections)

    if hard then
        local desired = {}
        for _, entry in ipairs(FirstRun.CATALOG) do
            desired[entry.addonName] = selections[entry.addonName] and true or false
        end
        for _, ds in ipairs(DATASTORE_ADDONS) do
            desired[ds] = datastoreState[ds] and true or false
        end
        for name, want in pairs(desired) do
            ns:SetAddonEnabled(name, want, perCharacter)
            ns:SetFeatureOptOut(name, false, perCharacter)
        end

        StaticPopupDialogs["ONEWOW_MANAGE_FEATURES_RELOAD"] = {
            text = L["WIZARD_RELOAD_TEXT"],
            button1 = L["WIZARD_RELOAD_NOW"],
            button2 = LATER,
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        -- In-unit setters need the parent loaded so they can write SavedVariables
        -- before the reload (hard Apply does not otherwise BringUp opted-in units).
        for _, entry in ipairs(FirstRun.CATALOG) do
            if entry.inUnitFeatures and selections[entry.addonName]
                and not C_AddOns.IsAddOnLoaded(entry.addonName) then
                LoadFeatureNow(entry.addonName)
            end
        end
        FirstRun:ApplyInUnitFeatures(featureSelections)
        StaticPopup_Show("ONEWOW_MANAGE_FEATURES_RELOAD")
        return true
    end

    for _, entry in ipairs(FirstRun.CATALOG) do
        local want = selections[entry.addonName] and true or false
        ns:SetFeatureOptOut(entry.addonName, not want, perCharacter)
    end
    for _, ds in ipairs(DATASTORE_ADDONS) do
        ns:SetFeatureOptOut(ds, not datastoreState[ds], perCharacter)
    end

    for _, entry in ipairs(FirstRun.CATALOG) do
        local name = entry.addonName
        if selections[name] and ns:IsAddonEnabled(name, perCharacter)
            and not C_AddOns.IsAddOnLoaded(name) then
            LoadFeatureNow(name)
        end
    end
    -- Wanted consumer-pulled stores when the feature was already loaded (BringUp
    -- skipped): EnsureLoaded each datastore that Apply just opted in.
    -- Catalog lazyStores stay unloaded until a tab / quest event / Item Search
    -- source asks; ShoppingList still BringUp-pulls the resolved tradeskills pack.
    for _, ds in ipairs(DATASTORE_ADDONS) do
        if datastoreState[ds] and not C_AddOns.IsAddOnLoaded(ds) and not ns:IsLazyStore(ds) then
            ns:EnsureLoaded(ds)
        end
    end
    FirstRun:ApplyInUnitFeatures(featureSelections)
    return false
end

--- Soft-opt-out CATALOG utility addons on a fresh account (DevTools today).
--- Account-wide; leaves the Blizzard enable flag alone so Manage Features can
--- LoadAddOn later this session. Not a MergeMissing default: account "wanted"
--- is stored as absence of the key.
function FirstRun:SeedUtilityOptOuts()
    for _, entry in ipairs(FirstRun.CATALOG) do
        if entry.group == "utility" then
            ns:SetFeatureOptOut(entry.addonName, true, false)
        end
    end
end

-- Apply a "recommended set": every feature except utility entries. Account-wide,
-- soft (reload-free).
function FirstRun:ApplyRecommended()
    local sel = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        sel[entry.addonName] = (entry.group ~= "utility")
    end
    local storeSel = {}
    for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
        if manifest.storePolicy == "optional" then
            for _, store in ipairs(manifest.stores) do
                storeSel[store] = sel[manifest.addon] and true or false
            end
        end
    end
    self:Apply(sel, false, false, storeSel)
end

function FirstRun:ShowStoreAffectedDialog(storeAddon)
    local keys = STORE_AFFECTED_KEYS[storeAddon]
    if not keys then return end

    local dialogKey = "OneWoW_StoreAffectedDialog"
    if FirstRun._affectedDialog and FirstRun._affectedDialog:IsShown() then
        FirstRun._affectedDialog:Hide()
    end

    local result = OneWoW_GUI:CreateDialog({
        name            = dialogKey,
        title           = L[keys.title],
        width           = 480,
        height          = 360,
        showScrollFrame = true,
        buttons         = {
            { text = CLOSE, onClick = function(frame) frame:Hide() end },
        },
    })
    FirstRun._affectedDialog = result.frame

    local body = OneWoW_GUI:CreateFS(result.scrollContent, 12)
    body:SetPoint("TOPLEFT", result.scrollContent, "TOPLEFT", 12, -12)
    body:SetPoint("TOPRIGHT", result.scrollContent, "TOPRIGHT", -12, -12)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    body:SetText(L[keys.body] or "")
    result.scrollContent:SetHeight(math.max(40, body:GetStringHeight() + 24))

    result.frame:Show()
    result.frame:Raise()
end

-- Build the Manage Features panel into `parent` (a Frame). This is reused by
-- both the first-run popup and the Settings > Manage Features sub-tab.
--
-- All themed widgets go through OneWoW_GUI helpers so the panel matches the
-- rest of the addon's UI standards: no raw SetBackdrop, no UICheckButtonTemplate.
function FirstRun:BuildPanel(parent, opts)
    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_ManageFeaturesScroll" })
    content:SetHeight(1)

    -- Scope of every read/write in this panel. First-run defaults to account-wide
    -- (initial setup intent); the Settings sub-tab defaults to the current
    -- character (mirrors Blizzard's addon list). Owned here, read by Apply.
    local perCharacter = not (opts and opts.defaultScope == "all")
    local function ScopeText(pc)
        return pc and UnitName("player") or L["MANAGE_SCOPE_ALL"]
    end

    local selections = FirstRun:GetCurrentSelections(perCharacter)
    local storeSelections = FirstRun:GetCurrentStoreSelections(perCharacter)
    for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
        if manifest.storePolicy == "optional" then
            for _, store in ipairs(manifest.stores) do
                if storeSelections[store] == nil then
                    storeSelections[store] = false
                end
            end
        end
    end
    local originalSelections = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        originalSelections[entry.addonName] = selections[entry.addonName] and true or false
    end
    local originalStoreSelections = {}
    for store, wanted in pairs(storeSelections) do
        originalStoreSelections[store] = wanted and true or false
    end
    for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
        if manifest.storePolicy == "optional" then
            for _, store in ipairs(manifest.stores) do
                if originalStoreSelections[store] == nil then
                    originalStoreSelections[store] = storeSelections[store] and true or false
                end
            end
        end
    end

    local featureSelections = FirstRun:GetInUnitFeatureSelections()
    local originalFeatureSelections = {}
    ForEachInUnitFeature(function(_, feat)
        originalFeatureSelections[feat.id] = featureSelections[feat.id] and true or false
    end)

    local cards = {}
    local storeCards = {}
    local storeMeta = {}
    local featureCards = {}
    local featureMeta = {}
    local topicSelections = {}
    local originalTopics = {}
    local topicRows = {}

    for _, era in ipairs(ns.CatalogData:GetEras()) do
        topicSelections[era.addon] = {}
        originalTopics[era.addon] = {}
        for _, topic in ipairs(ns.CatalogData:GetTopics()) do
            local on = ns.CatalogData:IsTopicEnabled(era.addon, topic)
            topicSelections[era.addon][topic] = on
            originalTopics[era.addon][topic] = on
        end
    end

    local function CommitTopics()
        for addon, topics in pairs(topicSelections) do
            for topic, on in pairs(topics) do
                ns.CatalogData:SetTopicEnabled(addon, topic, on)
            end
        end
    end

    local function TopicsChanged()
        for addon, topics in pairs(topicSelections) do
            local orig = originalTopics[addon]
            if orig then
                for topic, on in pairs(topics) do
                    if (on and true or false) ~= (orig[topic] and true or false) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function CountSelected()
        local count = 0
        for _, entry in ipairs(FirstRun.CATALOG) do
            if selections[entry.addonName] then
                count = count + 1
            end
        end
        return count
    end

    local function CountWantedDatastores()
        local effective = ComputeDatastoreState(selections, storeSelections)
        local pool = ComputeEligibleDatastorePool(selections)
        local enabled, total = 0, 0
        for store in pairs(pool) do
            if not ns:IsHiddenStore(store) then
                total = total + 1
                if effective[store] then
                    enabled = enabled + 1
                end
            end
        end
        return enabled, total
    end

    local function HasChanges()
        for _, entry in ipairs(FirstRun.CATALOG) do
            local addonName = entry.addonName
            if (selections[addonName] and true or false) ~= originalSelections[addonName] then
                return true
            end
        end
        for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
            if manifest.storePolicy == "optional" then
                for _, store in ipairs(manifest.stores) do
                    if not ns:IsHiddenStore(store) then
                        local cur = storeSelections[store] and true or false
                        local orig = originalStoreSelections[store] and true or false
                        if cur ~= orig then
                            return true
                        end
                    end
                end
            end
        end
        local featureChanged = false
        ForEachInUnitFeature(function(_, feat)
            local cur = featureSelections[feat.id] and true or false
            local orig = originalFeatureSelections[feat.id] and true or false
            if cur ~= orig then
                featureChanged = true
            end
        end)
        if featureChanged then
            return true
        end
        return TopicsChanged()
    end

    local hero = OneWoW_GUI:CreateHeroPanel(content, {
        title = L["WIZARD_HERO_TITLE"],
        subtitle = L["WIZARD_HERO_SUBTITLE"],
        description = L["WIZARD_HERO_DESC"],
        calloutText = L["WIZARD_HERO_CALLOUT"],
        iconTexture = OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme")),
        yOffset = -10,
    })

    local summary = OneWoW_GUI:CreateSummaryStrip(content, {
        yOffset = hero.bottomY - 8,
        items = {
            { label = L["WIZARD_SUMMARY_SELECTED"] },
            { label = L["WIZARD_SUMMARY_DATA"] },
            { label = L["WIZARD_SUMMARY_RELOAD"] },
        },
    })

    local actionBar = OneWoW_GUI:CreateActionBar(content, {
        yOffset  = summary.bottomY - 8,
        insetX   = 12,
        gap      = OneWoW_GUI:GetSpacing("MD"),
        rowHeight = C.ACTION_BAR_HEIGHT,
    })

    local presetItems = {
        { text = RECOMMENDED, value = "recommended" },
        { text = L["WIZARD_PRESET_MINIMAL"],     value = "minimal" },
        { text = L["WIZARD_PRESET_MANUAL"],      value = "manual", isActive = true },
    }
    local presetGap = OneWoW_GUI:GetSpacing("XS")
    local presetHeight = 26
    local presetButtons = {}

    local function ApplyPresetVisual(btn)
        if btn.isActive then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    local maxBtnWidth = 0
    for i, item in ipairs(presetItems) do
        local btn = OneWoW_GUI:CreateFitTextButton(actionBar.left, {
            text     = item.text,
            height   = presetHeight,
            minWidth = 80,
        })
        btn.itemValue = item.value
        btn.isActive  = item.isActive or false
        ApplyPresetVisual(btn)
        btn:HookScript("OnEnter", function(myself)
            if not myself.isActive then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            end
        end)
        btn:HookScript("OnLeave", function(myself) ApplyPresetVisual(myself) end)
        local w = btn:GetWidth() or 0
        if w > maxBtnWidth then maxBtnWidth = w end
        presetButtons[i] = btn
    end

    local prevBtn
    for _, btn in ipairs(presetButtons) do
        btn:SetWidth(maxBtnWidth)
        if prevBtn then
            btn:SetPoint("LEFT", prevBtn, "RIGHT", presetGap, 0)
        else
            btn:SetPoint("TOPLEFT", actionBar.left, "TOPLEFT", 0, 0)
        end
        prevBtn = btn
    end
    local clusterWidth = (#presetButtons * maxBtnWidth) + ((#presetButtons - 1) * presetGap)

    function presetButtons.SetActiveByValue(value)
        for _, btn in ipairs(presetButtons) do
            btn.isActive = (btn.itemValue == value)
            ApplyPresetVisual(btn)
        end
    end

    actionBar.left:SetWidth(clusterWidth)
    actionBar.left:SetHeight(presetHeight)

    -- Two commit buttons: soft "Apply" (reload-free; writes only OneWoW's opt-out)
    -- and hard "Apply & Reload" (writes Blizzard flags + reload). Soft Apply greys
    -- out when the only way to satisfy the edit is a reload (re-enabling a
    -- Blizzard-disabled unit), which the soft path cannot do.
    local btnGap = OneWoW_GUI:GetSpacing("XS")

    local hardApplyBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = L["WIZARD_APPLY_RELOAD"],
        height = 26,
        minWidth = 130,
    })
    hardApplyBtn:SetPoint("TOPRIGHT", actionBar.right, "TOPRIGHT", 0, 0)
    hardApplyBtn._enabled = false
    hardApplyBtn._hasChanges = false
    hardApplyBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        local key
        if myself._enabled then
            key = "WIZARD_APPLY_RELOAD_TOOLTIP"
        elseif myself._hasChanges then
            key = "WIZARD_APPLY_RELOAD_SOFT_ONLY_TOOLTIP"
        else
            key = "WIZARD_APPLY_NO_CHANGES_TOOLTIP"
        end
        GameTooltip:SetText(L[key], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    hardApplyBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local softApplyBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = APPLY,
        height = 26,
        minWidth = 80,
    })
    softApplyBtn:SetPoint("TOPRIGHT", hardApplyBtn, "TOPLEFT", -btnGap, 0)
    softApplyBtn._enabled = false
    softApplyBtn._blocked = false
    softApplyBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        local key
        if not myself._enabled and not myself._blocked then
            key = "WIZARD_APPLY_NO_CHANGES_TOOLTIP"
        elseif not myself._enabled then
            key = "WIZARD_APPLY_BLOCKED_TOOLTIP"
        else
            key = "WIZARD_APPLY_TOOLTIP"
        end
        GameTooltip:SetText(L[key], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    softApplyBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local function SetHardApplyEnabled(enabled)
        hardApplyBtn._enabled = enabled and true or false
        hardApplyBtn:SetAlpha(enabled and 1 or 0.4)
    end

    -- Greys/un-greys the soft Apply button and gates its click.
    local function SetSoftApplyEnabled(enabled, blocked)
        softApplyBtn._enabled = enabled and true or false
        softApplyBtn._blocked = blocked and true or false
        softApplyBtn:SetAlpha(enabled and 1 or 0.4)
    end

    actionBar.right:SetWidth(hardApplyBtn:GetWidth() + btnGap + softApplyBtn:GetWidth())
    actionBar:Refresh()

    -- One row: "Do not show again" on the left, the scope selector on the right
    -- (across from the checkbox). The scope menu is attached later (after the
    -- refresh helpers it drives are defined).
    local initialDontShow = ns.db.global.wizardShown ~= false
    ns.db.global.wizardShown = initialDontShow
    local dontShowRow = OneWoW_GUI:CreateLayoutFrame(content, { height = 28 })
    local dontShowCB = OneWoW_GUI:CreateCheckbox(dontShowRow, {
        label   = L["WIZARD_DONT_SHOW_AGAIN"],
        checked = initialDontShow,
        onClick = function(myself)
            ns.db.global.wizardShown = myself:GetChecked() and true or false
        end,
    })
    dontShowCB:SetPoint("LEFT", dontShowRow, "LEFT", 0, 0)

    local scopeDD, scopeDDText = OneWoW_GUI:CreateDropdown(dontShowRow, {
        width = 180,
        height = 24,
        text = ScopeText(perCharacter),
    })
    scopeDD:SetPoint("RIGHT", dontShowRow, "RIGHT", 0, 0)

    local scopeLabel = dontShowRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(scopeLabel, OneWoW_GUI:GetFont(), 12)
    scopeLabel:SetText(L["MANAGE_SCOPE_LABEL"])
    scopeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    scopeLabel:SetPoint("RIGHT", scopeDD, "LEFT", -8, 0)

    local listContainer = OneWoW_GUI:CreateLayoutFrame(content, {})
    listContainer:SetHeight(1)

    local groupLabels = {
        feature = L["WIZARD_GROUP_FEATURES"],
        standalone = L["HOME_STANDALONE_ADDONS"],
        utility = L["HOME_UTILITIES"],
    }
    local groupOrder  = { "feature", "standalone", "utility" }

    -- Forward-declared; closures below capture these.
    local RefreshRow, RefreshAllRows, RefreshStoreRow, RefreshStoreRowsForParent, RefreshAllStoreRows, RefreshTopicRow, RefreshAllTopicRows, RefreshFeatureRow, RefreshFeatureRowsForParent, RefreshAllFeatureRows, RefreshActions

    local function GetCatalogLabel(addonName)
        for _, entry in ipairs(FirstRun.CATALOG) do
            if entry.addonName == addonName then
                return L[entry.labelKey]
            end
        end
        return addonName
    end

    local function BuildDataSummaryTooltip()
        local effective = ComputeDatastoreState(selections, storeSelections)
        local pool = ComputeEligibleDatastorePool(selections)
        local lines = {}
        for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
            local tooltipKey = PARENT_DATA_TOOLTIP_KEYS[manifest.addon]
            if tooltipKey then
                local enabled, total = 0, 0
                for _, store in ipairs(manifest.stores) do
                    if pool[store] then
                        total = total + 1
                        if effective[store] then
                            enabled = enabled + 1
                        end
                    end
                end
                if total > 0 then
                    local parentLabel = L[PARENT_MODULE_LABEL_KEYS[manifest.addon]] or manifest.addon
                    lines[#lines + 1] = format("%s: %s", parentLabel, format(L[tooltipKey], enabled, total))
                end
            end
        end
        local alsoRequired = {}
        for _, ds in ipairs(DATASTORE_ADDONS) do
            if effective[ds] and not pool[ds] then
                local consumer = GetStoreConsumerForced(ds, selections)
                if consumer then
                    local storeLabel = L[ns:GetStoreLabelKey(ds)] or ds
                    alsoRequired[#alsoRequired + 1] = format("%s (%s)", storeLabel, GetCatalogLabel(consumer))
                end
            end
        end
        if #alsoRequired > 0 then
            lines[#lines + 1] = format(L["WIZARD_DATA_TOOLTIP_ALSO_REQUIRED"], table.concat(alsoRequired, ", "))
        end
        return table.concat(lines, "\n")
    end

    local function RefreshSummary()
        local enabled, total = CountWantedDatastores()
        summary:SetItemValue(1, format(L["WIZARD_SUMMARY_SELECTED_FORMAT"], CountSelected(), #FirstRun.CATALOG))
        summary:SetItemValue(2, format(L["WIZARD_SUMMARY_DATA_FORMAT"], enabled, total))
        summary:SetItemValue(3, HasChanges() and L["WIZARD_SUMMARY_PENDING"] or READY)
    end

    local dataSummaryBox = summary.itemBoxes[2]
    dataSummaryBox:EnableMouse(true)
    dataSummaryBox:SetScript("OnEnter", function(box)
        GameTooltip:SetOwner(box, "ANCHOR_BOTTOM")
        GameTooltip:SetText(BuildDataSummaryTooltip(), nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    dataSummaryBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function ApplyPreset(preset)
        for _, entry in ipairs(FirstRun.CATALOG) do
            local want = false
            if preset == "recommended" then
                want = (entry.group ~= "utility")
            elseif preset == "minimal" then
                want = false
            else
                want = selections[entry.addonName] and true or false
            end
            selections[entry.addonName] = want
            if cards[entry.addonName] then
                cards[entry.addonName]:SetChecked(want, true)
            end
        end
        for _, manifest in ipairs(ns:GetManifestParentsWithStores()) do
            if manifest.storePolicy == "optional" then
                for _, store in ipairs(manifest.stores) do
                    if preset == "recommended" then
                        storeSelections[store] = selections[manifest.addon] and true or false
                    elseif preset == "minimal" then
                        storeSelections[store] = false
                    end
                end
            end
        end
        ForEachInUnitFeature(function(entry, feat)
            if preset == "recommended" then
                featureSelections[feat.id] = selections[entry.addonName] and true or false
            elseif preset == "minimal" then
                featureSelections[feat.id] = false
            end
        end)
        for addon, topics in pairs(topicSelections) do
            for topic in pairs(topics) do
                if preset == "recommended" then
                    topicSelections[addon][topic] = ns.CatalogData:GetDefaultTopicEnabled(addon, topic)
                elseif preset == "minimal" then
                    topicSelections[addon][topic] = false
                end
            end
        end
        RefreshSummary()
        RefreshAllRows()
        RefreshAllStoreRows()
        RefreshAllTopicRows()
        RefreshAllFeatureRows()
        RefreshActions()
    end

    local listItems = {}
    local subRowTightAfter = {}
    local extraGapForHeader = OneWoW_GUI:GetSpacing("MD")
    local headerIndices = {}
    for _, group in ipairs(groupOrder) do
        local groupHeader = OneWoW_GUI:CreateSectionHeader(listContainer, {
            title   = groupLabels[group],
            yOffset = 0,
        })
        groupHeader:ClearAllPoints()
        table.insert(listItems, groupHeader)
        headerIndices[#listItems] = true

        for _, entry in ipairs(FirstRun.CATALOG) do
            if entry.group == group then
                local addon = entry.addonName
                local iconInfo = ns:GetFeatureIcon(addon) or {}
                local affectedKeys = STORE_AFFECTED_KEYS[addon]
                local card = OneWoW_GUI:CreateSelectableCard(listContainer, {
                    title = L[entry.labelKey],
                    summary = L[entry.summaryKey],
                    iconTexture = iconInfo.texture,
                    iconAtlas = iconInfo.atlas,
                    iconTexCoords = iconInfo.texCoords,
                    iconPlate = iconInfo.plate,
                    checked = selections[addon],
                    affectedText = affectedKeys and L["WIZARD_WHATS_AFFECTED"] or nil,
                    onAffectedClick = affectedKeys and function()
                        FirstRun:ShowStoreAffectedDialog(addon)
                    end or nil,
                    onToggle = function(_, checked)
                        selections[addon] = checked and true or false
                        local manifest = ns:GetManifestByAddon(addon)
                        if manifest and manifest.storePolicy == "optional" and manifest.stores then
                            if not checked then
                                -- Unticking the hub only clears parent-required
                                -- stores (Endgame / Catalog packs). Independent
                                -- AltTracker stores keep their own selection.
                                for _, store in ipairs(manifest.stores) do
                                    if ns:StoreRequiresParent(store) then
                                        storeSelections[store] = false
                                    end
                                end
                            else
                                -- Enabling the hub defaults all owned stores on
                                -- when none are selected yet.
                                local anySelected = false
                                for _, store in ipairs(manifest.stores) do
                                    if storeSelections[store] then
                                        anySelected = true
                                        break
                                    end
                                end
                                if not anySelected then
                                    for _, store in ipairs(manifest.stores) do
                                        storeSelections[store] = true
                                    end
                                end
                            end
                        end
                        presetButtons.SetActiveByValue("manual")
                        RefreshRow(addon)
                        RefreshAllStoreRows()
                        RefreshFeatureRowsForParent(addon)
                        RefreshActions()
                        RefreshSummary()
                    end,
                })
                card:ClearAllPoints()

                -- Blizzard-style per-row "Load Addon" button. Shown only when the
                -- card is checked + Blizzard-enabled + not yet loaded (RefreshRow).
                -- Clicking loads it reload-free and commits the opt-in for scope.
                local loadBtn = OneWoW_GUI:CreateFitTextButton(card, {
                    text = L["WIZARD_LOAD_ADDON"],
                    height = 20,
                    minWidth = 60,
                    paddingX = 14,
                })
                loadBtn:SetPoint("RIGHT", card.checkbox, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
                if card.affectedBtn then
                    card.affectedBtn:ClearAllPoints()
                    card.affectedBtn:SetPoint("RIGHT", loadBtn, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
                end
                loadBtn:Hide()
                loadBtn.tooltipText = L["WIZARD_LOAD_ADDON_TOOLTIP"]
                loadBtn:HookScript("OnEnter", function(myself)
                    GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                    GameTooltip:SetText(myself.tooltipText, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end)
                loadBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
                loadBtn:SetScript("OnClick", function()
                    ns:SetFeatureOptOut(addon, false, perCharacter)
                    -- Clear soft opt-out on owned stores and CATALOG consumer pulls
                    -- so BringUp's EnsureLoaded can load them.
                    local effective = ComputeDatastoreState(selections, storeSelections)
                    local manifest = ns:GetManifestByAddon(addon)
                    if manifest and manifest.stores then
                        for _, store in ipairs(manifest.stores) do
                            if effective[store] then
                                ns:SetFeatureOptOut(store, false, perCharacter)
                                originalStoreSelections[store] = storeSelections[store] and true or false
                            end
                        end
                    end
                    for _, catalogEntry in ipairs(FirstRun.CATALOG) do
                        if catalogEntry.addonName == addon then
                            for _, ds in ipairs(catalogEntry.datastores) do
                                ds = ResolveCatalogDatastore(ds)
                                if effective[ds] then
                                    ns:SetFeatureOptOut(ds, false, perCharacter)
                                end
                            end
                            break
                        end
                    end
                    LoadFeatureNow(addon)
                    originalSelections[addon] = true
                    RefreshRow(addon)
                    RefreshStoreRowsForParent(addon)
                    RefreshAllStoreRows()
                    RefreshFeatureRowsForParent(addon)
                    RefreshActions()
                    RefreshSummary()
                end)
                card.loadBtn = loadBtn

                cards[addon] = card
                table.insert(listItems, card)

                local manifest = ns:GetManifestByAddon(addon)
                if manifest and manifest.stores then
                    local visibleStores = {}
                    for _, store in ipairs(manifest.stores) do
                        if not ns:IsHiddenStore(store) and C_AddOns.DoesAddOnExist(store) then
                            visibleStores[#visibleStores + 1] = store
                        end
                    end
                    for si, store in ipairs(visibleStores) do
                        local title = StoreTitle(store)
                        local descKey = StoreDescKey(store)
                        local rowSummary = descKey and L[descKey] or ""
                        local isOptional = manifest.storePolicy == "optional"
                        local affectedKeys = STORE_AFFECTED_KEYS[store]

                        local sub = OneWoW_GUI:CreateSelectableSubCard(listContainer, {
                            title = title,
                            summary = rowSummary,
                            iconTexture = STORE_ICONS[store] or 5341597,
                            checked = storeSelections[store] and true or false,
                            interactive = isOptional,
                            affectedText = (isOptional and affectedKeys) and L["WIZARD_WHATS_AFFECTED"] or nil,
                            onAffectedClick = (isOptional and affectedKeys) and function()
                                FirstRun:ShowStoreAffectedDialog(store)
                            end or nil,
                            onToggle = isOptional and function(_, checked)
                                storeSelections[store] = checked and true or false
                                if checked and not selections[addon] and ns:StoreRequiresParent(store) then
                                    selections[addon] = true
                                    if cards[addon] then
                                        cards[addon]:SetChecked(true, true)
                                    end
                                    RefreshStoreRowsForParent(addon)
                                end
                                presetButtons.SetActiveByValue("manual")
                                RefreshStoreRow(store)
                                RefreshTopicRow(store)
                                RefreshRow(addon)
                                RefreshActions()
                                RefreshSummary()
                            end or nil,
                        })
                        sub:ClearAllPoints()
                        storeCards[store] = sub
                        storeMeta[store] = { parent = addon, optional = isOptional }
                        table.insert(listItems, sub)

                        if ns.CatalogData:IsEraAddon(store) then
                            subRowTightAfter[#listItems] = true
                            local topicRow = CreateFrame("Frame", nil, listContainer)
                            topicRow._cbs = {}
                            topicRow._byTopic = {}
                            local topics = ns.CatalogData:GetTopics()
                            for ti = 1, #topics do
                                local topic = topics[ti]
                                local cb = OneWoW_GUI:CreateCheckbox(topicRow, {
                                    label = TopicLabel(topic),
                                    checked = topicSelections[store] and topicSelections[store][topic],
                                    onClick = function(self)
                                        local on = self:GetChecked() and true or false
                                        topicSelections[store] = topicSelections[store] or {}
                                        topicSelections[store][topic] = on
                                        if on and not storeSelections[store] then
                                            storeSelections[store] = true
                                            if storeCards[store] then
                                                storeCards[store]:SetChecked(true, true)
                                            end
                                            RefreshStoreRow(store)
                                            RefreshRow(addon)
                                        end
                                        presetButtons.SetActiveByValue("manual")
                                        RefreshActions()
                                        RefreshSummary()
                                    end,
                                })
                                topicRow._cbs[#topicRow._cbs + 1] = cb
                                topicRow._byTopic[topic] = cb
                            end
                            topicRow:SetScript("OnSizeChanged", function(row)
                                if row._layingOut then
                                    return
                                end
                                row._layingOut = true
                                local cbs = row._cbs
                                local x = 12
                                local y = -2
                                local rowH = 26
                                local maxW = row:GetWidth() or 520
                                if maxW < 80 then
                                    maxW = 520
                                end
                                local lines = 1
                                for i = 1, #cbs do
                                    local box = cbs[i]
                                    local w = box:GetMeasuredWidth() + 16
                                    if x + w > maxW - 4 and x > 12 then
                                        x = 12
                                        y = y - rowH
                                        lines = lines + 1
                                    end
                                    box:ClearAllPoints()
                                    box:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
                                    x = x + w
                                end
                                row:SetHeight(lines * rowH + 6)
                                row._layingOut = nil
                            end)
                            topicRows[store] = topicRow
                            table.insert(listItems, topicRow)
                            if si < #visibleStores then
                                subRowTightAfter[#listItems] = true
                            end
                        elseif si < #visibleStores then
                            subRowTightAfter[#listItems] = true
                        end
                    end
                end

                if entry.inUnitFeatures then
                    for fi, feat in ipairs(entry.inUnitFeatures) do
                        local featIconInfo = ns:GetFeatureIcon(feat.iconKey) or {}
                        local sub = OneWoW_GUI:CreateSelectableSubCard(listContainer, {
                            title = L[feat.labelKey],
                            summary = L[feat.summaryKey],
                            iconTexture = featIconInfo.texture,
                            iconAtlas = featIconInfo.atlas,
                            iconTexCoords = featIconInfo.texCoords,
                            iconPlate = featIconInfo.plate,
                            checked = featureSelections[feat.id] and true or false,
                            interactive = true,
                            onToggle = function(_, checked)
                                featureSelections[feat.id] = checked and true or false
                                presetButtons.SetActiveByValue("manual")
                                RefreshFeatureRow(feat.id)
                                RefreshActions()
                                RefreshSummary()
                            end,
                        })
                        sub:ClearAllPoints()
                        featureCards[feat.id] = sub
                        featureMeta[feat.id] = { parent = addon, feat = feat }
                        table.insert(listItems, sub)
                        if fi < #entry.inUnitFeatures then
                            subRowTightAfter[#listItems] = true
                        end
                    end
                end
            end
        end
    end

    -- True when a unit is checked + Blizzard-enabled but not actually loaded in this
    -- session (never loaded, or soft-opted-out so it was skipped at startup).
    local function NeedsSoftLoad(unit)
        return ns:IsAddonEnabled(unit, perCharacter)
            and (
                not C_AddOns.IsAddOnLoaded(unit)
                or ns:IsFeatureOptedOutInScope(unit, perCharacter)
            )
    end

    -- Per-row Load button. Shows when the feature itself needs a soft load, or when
    -- it owns wanted-but-unloaded data stores (a parent-only control that pulls its
    -- children). Relabels to "Load Data Addons" whenever children are what's pending.
    RefreshRow = function(addonName)
        local card = cards[addonName]
        if not card or not card.loadBtn then return end

        local parentNeedsLoad = card._checked and NeedsSoftLoad(addonName)

        local childNeedsLoad = false
        if card._checked and ns:IsAddonEnabled(addonName, perCharacter) then
            local effective = ComputeDatastoreState(selections, storeSelections)
            local manifest = ns:GetManifestByAddon(addonName)
            if manifest and manifest.stores then
                for _, store in ipairs(manifest.stores) do
                    if effective[store] and not ns:IsLazyStore(store) and NeedsSoftLoad(store) then
                        childNeedsLoad = true
                        break
                    end
                end
            end
            if not childNeedsLoad then
                for _, entry in ipairs(FirstRun.CATALOG) do
                    if entry.addonName == addonName then
                        for _, ds in ipairs(entry.datastores) do
                            ds = ResolveCatalogDatastore(ds)
                            if effective[ds] and NeedsSoftLoad(ds) then
                                childNeedsLoad = true
                                break
                            end
                        end
                        break
                    end
                end
            end
        end

        card.loadBtn:SetShown(parentNeedsLoad or childNeedsLoad)
        if parentNeedsLoad or childNeedsLoad then
            if childNeedsLoad then
                card.loadBtn:SetFitText(L["WIZARD_LOAD_DATA_ADDONS"])
                card.loadBtn.tooltipText = L["WIZARD_LOAD_DATA_ADDONS_TOOLTIP"]
            else
                card.loadBtn:SetFitText(L["WIZARD_LOAD_ADDON"])
                card.loadBtn.tooltipText = L["WIZARD_LOAD_ADDON_TOOLTIP"]
            end
        end
    end

    RefreshAllRows = function()
        for _, entry in ipairs(FirstRun.CATALOG) do
            RefreshRow(entry.addonName)
        end
    end

    RefreshStoreRow = function(storeAddon)
        local sub = storeCards[storeAddon]
        local meta = storeMeta[storeAddon]
        if not sub or not meta then return end

        local manifest = ns:GetManifestByAddon(meta.parent)
        if not manifest then return end

        local parentWanted = selections[meta.parent] and true or false
        local effective = ComputeDatastoreState(selections, storeSelections)
        local forcedConsumer = GetStoreConsumerForced(storeAddon, selections)
        local requiresParent = ns:StoreRequiresParent(storeAddon)
        local checked, muted, interactive, badgeText

        if requiresParent and not parentWanted then
            -- Endgame / Catalog packs: dead without their hub.
            checked = false
            muted = true
            interactive = false
            badgeText = nil
        elseif forcedConsumer and not (parentWanted and storeSelections[storeAddon]) then
            -- Bags/ShoppingList (etc.) force the store on.
            checked = effective[storeAddon] and true or false
            muted = false
            interactive = false
            badgeText = format(L["WIZARD_STORE_REQUIRED_BY"], GetCatalogLabel(forcedConsumer))
        elseif manifest.storePolicy == "bundled" then
            checked = parentWanted
            muted = not parentWanted
            interactive = false
            badgeText = parentWanted and L["WIZARD_STORE_BUNDLED"] or nil
        else
            -- Independent optional store (most AltTracker packs): toggle with or
            -- without the owning hub.
            checked = storeSelections[storeAddon] and true or false
            muted = false
            interactive = true
            badgeText = nil
        end

        sub:SetChecked(checked, true)
        sub:SetMuted(muted)
        sub:SetInteractive(interactive)
        sub:SetBadgeText(badgeText)
        RefreshTopicRow(storeAddon)
    end

    RefreshTopicRow = function(storeAddon)
        local row = topicRows[storeAddon]
        if not row then
            return
        end
        local eraOn = storeSelections[storeAddon] and true or false
        local topics = topicSelections[storeAddon]
        for topic, cb in pairs(row._byTopic) do
            local on = topics and topics[topic]
            cb:SetChecked(on and true or false)
            cb:Enable()
            cb:SetAlpha(eraOn and 1 or 0.7)
        end
    end

    RefreshAllTopicRows = function()
        for store in pairs(topicRows) do
            RefreshTopicRow(store)
        end
    end

    RefreshStoreRowsForParent = function(parentAddon)
        local manifest = ns:GetManifestByAddon(parentAddon)
        if not manifest or not manifest.stores then return end
        for _, store in ipairs(manifest.stores) do
            RefreshStoreRow(store)
        end
    end

    RefreshAllStoreRows = function()
        for store in pairs(storeCards) do
            RefreshStoreRow(store)
        end
    end

    RefreshFeatureRow = function(featureId)
        local sub = featureCards[featureId]
        local meta = featureMeta[featureId]
        if not sub or not meta then return end
        local parentWanted = selections[meta.parent] and true or false
        sub:SetChecked(featureSelections[featureId] and true or false, true)
        sub:SetMuted(not parentWanted)
        sub:SetInteractive(parentWanted)
    end

    RefreshFeatureRowsForParent = function(parentAddon)
        ForEachInUnitFeature(function(entry, feat)
            if entry.addonName == parentAddon then
                RefreshFeatureRow(feat.id)
            end
        end)
    end

    RefreshAllFeatureRows = function()
        for featureId in pairs(featureCards) do
            RefreshFeatureRow(featureId)
        end
    end

    -- Commit buttons: soft Apply for opt-out toggles; Apply & Reload when a pending
    -- change needs a Blizzard flag write (hard disable or re-enable). Soft re-enable
    -- alone greys out Apply & Reload; Blizzard-disabled re-enable greys out Apply.
    RefreshActions = function()
        local hasChanges = HasChanges()
        local needsHardApply = false
        local softApplyBlocked = false
        if hasChanges then
            for _, entry in ipairs(FirstRun.CATALOG) do
                local name = entry.addonName
                local want = selections[name] and true or false
                local was = originalSelections[name] and true or false
                if want == was then
                    -- skip unchanged rows
                else
                    local blizz = ns:IsAddonEnabled(name, perCharacter)
                    if want and not blizz then
                        needsHardApply = true
                        softApplyBlocked = true
                    elseif not want and blizz then
                        needsHardApply = true
                    end
                end
            end
        end
        hardApplyBtn._hasChanges = hasChanges
        SetHardApplyEnabled(needsHardApply)
        SetSoftApplyEnabled(hasChanges and not softApplyBlocked, softApplyBlocked)
    end

    local stackGaps = {}
    for i = 1, #listItems do
        if headerIndices[i + 1] then
            stackGaps[i] = extraGapForHeader
        elseif subRowTightAfter[i] then
            stackGaps[i] = 4
        else
            stackGaps[i] = OneWoW_GUI:GetSpacing("XS")
        end
    end

    OneWoW_GUI:StackVertically(listContainer, listItems, {
        gap = OneWoW_GUI:GetSpacing("XS"),
        gaps = stackGaps,
        topPadding = 0,
        sidePadding = 0,
        autoHeight = true,
    })

    local mainStackGap = OneWoW_GUI:GetSpacing("SM")
    local mainStackGaps = {
        [1] = mainStackGap,                 -- hero -> summary
        [2] = mainStackGap,                 -- summary -> actionBar
        [3] = OneWoW_GUI:GetSpacing("XS"),  -- actionBar -> dontShowRow
        [4] = OneWoW_GUI:GetSpacing("MD"),  -- dontShowRow -> listContainer
    }
    OneWoW_GUI:StackVertically(content, {
        hero,
        summary,
        actionBar,
        dontShowRow,
        listContainer,
    }, {
        gap = mainStackGap,
        gaps = mainStackGaps,
        topPadding = 10,
        sidePadding = OneWoW_GUI:GetSpacing("MD"),
        autoHeight = true,
    })

    presetButtons[1]:SetScript("OnClick", function()
        presetButtons.SetActiveByValue("recommended")
        ApplyPreset("recommended")
    end)
    presetButtons[2]:SetScript("OnClick", function()
        presetButtons.SetActiveByValue("minimal")
        ApplyPreset("minimal")
    end)
    presetButtons[3]:SetScript("OnClick", function()
        presetButtons.SetActiveByValue("manual")
    end)

    local function RebaseOriginal()
        for _, entry in ipairs(FirstRun.CATALOG) do
            originalSelections[entry.addonName] = selections[entry.addonName] and true or false
        end
        for store, wanted in pairs(storeSelections) do
            originalStoreSelections[store] = wanted and true or false
        end
        ForEachInUnitFeature(function(_, feat)
            originalFeatureSelections[feat.id] = featureSelections[feat.id] and true or false
        end)
        for addon, topics in pairs(topicSelections) do
            originalTopics[addon] = originalTopics[addon] or {}
            for topic, on in pairs(topics) do
                originalTopics[addon][topic] = on and true or false
            end
        end
    end

    -- Re-read the live enable state for `pc` into the staged selections and push
    -- it onto the cards (each scope can have different per-addon flags).
    local function LoadSelectionsForScope(pc)
        local fresh = FirstRun:GetCurrentSelections(pc)
        local freshStores = FirstRun:GetCurrentStoreSelections(pc)
        for _, entry in ipairs(FirstRun.CATALOG) do
            local want = fresh[entry.addonName] and true or false
            selections[entry.addonName] = want
            if cards[entry.addonName] then
                cards[entry.addonName]:SetChecked(want, true)
            end
        end
        for store, want in pairs(freshStores) do
            storeSelections[store] = want and true or false
        end
        for store in pairs(storeCards) do
            if storeSelections[store] == nil then
                storeSelections[store] = false
            end
        end
        local freshFeatures = FirstRun:GetInUnitFeatureSelections()
        ForEachInUnitFeature(function(_, feat)
            featureSelections[feat.id] = freshFeatures[feat.id] and true or false
        end)
        presetButtons.SetActiveByValue("manual")
        RefreshAllRows()
        RefreshAllStoreRows()
        RefreshAllTopicRows()
        RefreshAllFeatureRows()
    end

    -- Commit a scope change. keepChanges = carry the staged checkbox intent into
    -- the new scope (rebase baseline to the new scope's live state); otherwise
    -- discard staged edits and reload the new scope's actual state.
    local function SwitchScope(newPC, keepChanges)
        perCharacter = newPC
        if keepChanges then
            RebaseOriginal()
        else
            LoadSelectionsForScope(newPC)
            RebaseOriginal()
        end
        scopeDDText:SetText(ScopeText(newPC))
        RefreshAllRows()
        RefreshAllFeatureRows()
        RefreshActions()
        RefreshSummary()
    end

    local pendingScopePC
    StaticPopupDialogs["ONEWOW_MANAGE_SCOPE_SWITCH"] = {
        text = L["MANAGE_SCOPE_SWITCH_TEXT"],
        button1 = L["KEEP"],
        button2 = L["DISCARD"],
        OnAccept = function()
            if pendingScopePC ~= nil then SwitchScope(pendingScopePC, true) end
            pendingScopePC = nil
        end,
        OnCancel = function()
            if pendingScopePC ~= nil then SwitchScope(pendingScopePC, false) end
            pendingScopePC = nil
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    OneWoW_GUI:AttachFilterMenu(scopeDD, {
        searchable = false,
        getActiveValue = function() return perCharacter and "char" or "all" end,
        buildItems = function()
            return {
                { value = "all",  text = L["MANAGE_SCOPE_ALL"] },
                { value = "char", text = UnitName("player") },
            }
        end,
        onSelect = function(value)
            local newPC = (value == "char")
            if newPC == perCharacter then return end
            if HasChanges() then
                pendingScopePC = newPC
                StaticPopup_Show("ONEWOW_MANAGE_SCOPE_SWITCH")
            else
                SwitchScope(newPC, false)
            end
        end,
    })

    softApplyBtn:SetScript("OnClick", function()
        if not softApplyBtn._enabled then return end
        CommitTopics()
        FirstRun:Apply(selections, perCharacter, false, storeSelections, featureSelections)
        RebaseOriginal()
        RefreshAllRows()
        RefreshAllStoreRows()
        RefreshAllTopicRows()
        RefreshAllFeatureRows()
        RefreshActions()
        RefreshSummary()
    end)

    hardApplyBtn:SetScript("OnClick", function()
        if not hardApplyBtn._enabled then return end
        CommitTopics()
        FirstRun:Apply(selections, perCharacter, true, storeSelections, featureSelections)
    end)

    RefreshAllRows()
    RefreshAllStoreRows()
    RefreshAllTopicRows()
    RefreshAllFeatureRows()
    RefreshActions()
    RefreshSummary()
end

function FirstRun:ShouldShowWizard()
    return not ns.db.global.wizardShown
end

-- First-run popup: a themed dialog that wraps BuildPanel. Triggered from
-- OneWoW's PLAYER_LOGIN init sequence when wizardShown is false.
function FirstRun:ShowWizard()
    if FirstRun._activeDialog and FirstRun._activeDialog:IsShown() then
        FirstRun._activeDialog:Raise()
        return
    end

    local result = OneWoW_GUI:CreateDialog({
        name      = "OneWoW_FirstRunWizard",
        title     = ns.L["WIZARD_TITLE"],
        width     = C.WIZARD_DIALOG_WIDTH,
        height    = C.WIZARD_DIALOG_HEIGHT,
        showBrand = true,
        buttons   = nil,
    })
    local dialog = result.frame
    FirstRun._activeDialog = dialog

    FirstRun:BuildPanel(result.contentFrame, { defaultScope = "all" })

    dialog:SetFrameStrata("DIALOG")
    dialog:Show()
    dialog:Raise()
end

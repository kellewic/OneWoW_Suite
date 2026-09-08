local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

local strfind = string.find
local strmatch = string.match
local strgsub = string.gsub

local DEFAULTS = {
    language = GetLocale(),
    theme = "green",
    font = "default",
    fontSizeOffset = 0,
    minimap = {
        hide = false,
        minimapPos = 220,
        theme = "horde",
    },
    featureIcons = {
        style = "ring", -- "ring" | "ringless"
    },
    moneyDisplay = {
        useLetters = false,
        useGrouping = true,
        useRegionalNumbers = true,
        useWhiteValues = false,
    },
    mainFrameSize = {
        width = 1400,
        height = 900,
    },
    lastModuleTab = "home",
    lastSubTabs = {},
    -- Per item-ID list display sort ("name" | "id"). Missing key = name.
    itemListSort = {},
    -- Per-section ordered favorite sub-tab ids (hub row-2 pins).
    subTabFavorites = {},
    debugTrace = false,
    -- TOC Version string last dismissed in the What's New dialog (account-wide).
    whatsNewDismissedVersion = "",
    -- Newest peer core TOC seen this account (cleared when local >= seen).
    remoteUpdateLatestSeen = "",
    -- Remote TOC the update popup was silenced for (newer remotes nag again).
    remoteUpdatePopupDismissedVersion = "",
    -- Account-dismissed FeatureHealth attention ids (load_pending / diminished).
    featureHealthDismissed = {},
    -- Named search expressions (#token, SAVED) for suite-wide SearchExpand.
    -- Bags contributes CATEGORY entries from its own SV via a catalog provider.
    searchCatalog = {
        schemaVersion = 0,
        entries = {}, -- [id] = { id, kind, name, formerNames, body, created }
    },
    portalHub = {
        escEnabled = true,
        randomHearthstone = true,
        hearthstoneChoice = "random",
        seasonalOnly = false,
        useLivePathFlyouts = true,
        lfgTeleportPrompt = false,
        lfgPromptPosition = {},
        showAll = true,
        showAllOnEsc = false,
        escShowUnknown = true,
        showSeasonal = true,
        showSeason1 = true,
        showSeason2 = true,
        showMageTeleports = true,
        showMagePortals = true,
        showEscTopRow = true,
        escFavoritesAlwaysExpanded = false,
        showDalaranHearth = true,
        showGarrisonHearth = true,
        showFlightWhistle = true,
        showHousingPortal = true,
        escShowZoneNotes = true,
        escHideZoneNotesWhenEmpty = false,
        escShowAlerts = true,
        escPortalsEnabled = true,
        escShowCharacterInfo = true,
        escShowEndeavors = true,
        escPanelsSide = "left",
        escPortalsSide = "right",
        allFavorites = {},
        escFavorites = {},
        customItems = {},
        iconSize = 36,
        escIconSize = 40,
        escIconFontSize = 11,
        escShowIconText = true,
        gridColumns = 8,
    },
    instanceStatsEsc = { enabled = false },
    instanceStatsPosition = {},
    settings = {
        -- Overlay system 2.0: predicate-driven user overlays plus the
        -- itemlevel / qualityborder / upgrade built-ins. Legacy 1.0
        -- per-feature tables (consumables, junk, soulbound, ...) are
        -- converted into userOverlays entries by ns:MigrateOverlays2().
        overlays = {
            general = { enabled = true },
            itemlevel = {
                enabled = false,
                position = "TOPRIGHT",
                fontSize = 10,
                fontFamily = "default",
                fontOutline = "OUTLINE",
                colorMode = "custom", -- "custom" | "quality" | "theme"
                customColor = { 1, 1, 1 },
                showPetLevel = true,
                showContainerSlots = true,
                applyToVendorItems = true,
                applyToAuctionHouse = false,
            },
            qualityborder = {
                enabled = true,
                scale = 2,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            -- User-added overlays, keyed by generated id:
            -- userOverlays[id] = { preset|nil, name|nil, enabled, order,
            --   expression, icon = { kind = "list"|"atlas"|"file", value,
            --   tint = {r,g,b}|nil }, position, scale, alpha, effect,
            --   bg = { enabled, style, scale, color, useRarityColor, effect },
            --   applyToVendorItems, applyToAuctionHouse,
            --   plus preset extras (showInTooltip, includeGreyItems,
            --   includeWUE, onlyNeeded) }.
            --
            -- Built-in presets are stored as normal userOverlays entries so
            -- every 1.0 overlay option remains visible in 2.0. Users can
            -- enable, reorder, tint, restyle, or delete them like any other
            -- overlay; the Add Overlay dialog can recreate deleted presets.
            userOverlays = {
                ov_junk = {
                    preset = "junk", enabled = false, order = 1,
                    position = "CENTER", scale = 1.5, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "bags-junkcoin" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                    showInTooltip = true, includeGreyItems = false,
                },
                ov_protected = {
                    preset = "protected", enabled = false, order = 2,
                    position = "CENTER", scale = 1.5, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "questlog-questtypeicon-lock" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                    showInTooltip = true,
                },
                ov_consumables = {
                    preset = "consumables", enabled = false, order = 3,
                    position = "TOPRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "VignetteEvent-SuperTracked" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_housingdecor = {
                    preset = "housingdecor", enabled = false, order = 4,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "shop-icon-housing-beds-selected" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_knownitems = {
                    preset = "knownitems", enabled = false, order = 5,
                    position = "TOPRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "warband-completed-icon" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_altcollected = {
                    preset = "altcollected", enabled = false, order = 6,
                    position = "TOPRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "transmog-icon-warning", tint = {1, 0.82, 0} },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_unknownitems = {
                    preset = "unknownitems", enabled = false, order = 7,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_transmog = {
                    preset = "transmog", enabled = false, order = 8,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_mounts = {
                    preset = "mounts", enabled = false, order = 9,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "icon-mount" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_pets = {
                    preset = "pets", enabled = false, order = 10,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "icon-pet" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_quest = {
                    preset = "quest", enabled = false, order = 11,
                    position = "CENTER", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "Quest-Campaign-Available" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_reagents = {
                    preset = "reagents", enabled = false, order = 12,
                    position = "TOPRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "Bonus-Objective-Star" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_recipe = {
                    preset = "recipe", enabled = false, order = 13,
                    position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "icon-recipe" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_soulbound = {
                    preset = "soulbound", enabled = false, order = 14,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "VignetteKill" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_toys = {
                    preset = "toys", enabled = false, order = 15,
                    position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "icon-toy" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_warbound = {
                    preset = "warbound", enabled = false, order = 16,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "warbands-icon" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                    includeWUE = true,
                },
                ov_wue = {
                    preset = "wue", enabled = false, order = 17,
                    position = "TOPLEFT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "warband-completed-icon" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_boe = {
                    preset = "boe", enabled = false, order = 18,
                    position = "TOPRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "icon-flag" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                },
                ov_shoppinglist = {
                    preset = "shoppinglist", enabled = true, order = 19,
                    position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0, effect = "none",
                    icon = { kind = "list", value = "Perks-ShoppingCart" },
                    applyToVendorItems = false, applyToAuctionHouse = false,
                    onlyNeeded = false,
                },
            },
            -- Detector-backed built-in (ns.UpgradeDetection). Also stores
            -- the Gear Upgrades tooltip settings mirrored from the
            -- tooltips/gearupgrades catalog entry.
            upgrade = {
                enabled = false,
                icon = "Professions-Icon-Quality-Tier3-Small",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
                mode = "ILVL",
                pawnEnforceReqLevel = true,
                showInTooltip = false,
                tooltipDetail = "FULL",
                tooltipOnlyUpgrade = false,
                tooltipShowSkipReason = false,
                tooltipShowAlts = true,
                tooltipIgnoreSoulbound = false,
                tooltipAltLimit = 10,
                tooltipAltSort = "UPGRADE_DESC",
                altScope = { mode = "all", chars = {}, roles = {} },
                showPawnPrompt = true,
                altSpecMatch = false,
                selfSpecMatch = false,
            },
            integrations = {
                arkinventory = { enabled = true },
                baganator    = { enabled = true },
                bagnon       = { enabled = true },
                betterbags   = { enabled = true },
                elvui        = { enabled = true },
                onewow_bags  = { enabled = true },
            },
        },
        -- Toast runtime config (relocated from the legacy db.global.toasts
        -- root in legacy minimap layout). "anchor" is a storage-only id — not in the
        -- SettingsFeatureRegistry catalog; its x/y are dynamic keys written
        -- on drag.
        toastalerts = {
            general        = { enabled = false },
            detectiontypes = {
                enabled = false,
                mounts  = false,
                pets    = false,
                toys    = false,
                recipes = false,
                recipesOnlyMyProfessions = false,
                tmogs   = false,
                housing = false,
                heirlooms = false,
                suppressBlizzardAlerts = false,
                sound   = SOUNDKIT.READY_CHECK,
            },
            instances      = { enabled = false, sound = 0 },
            notealerts     = {
                enabled = false,
                npcs    = false,
                players = false,
                zones   = false,
                items   = false,
                sound   = SOUNDKIT.ACHIEVEMENT_MENU_OPEN,
            },
            upgrades       = { enabled = false, sound = SOUNDKIT.READY_CHECK },
            anchor         = { visible = true, locked = false },
        },
        tooltips = {
            general = { enabled = true },
            technicalids = {
                enabled = false,
                showItemID = true,
                showSpellID = true,
                showNpcID = true,
                showAchievementID = true,
                showQuestID = true,
                showCurrencyID = true,
                showMountID = true,
                showPetID = true,
                showEnchantID = true,
                showIconID = true,
                showExpansionID = true,
                showSetID = true,
                showDecorEntryID = true,
                showRecipeID = true,
                showEquipmentSetID = true,
                showEssenceID = true,
                showConduitID = true,
                showOutfitID = true,
                showMacroID = true,
                showObjectID = true,
                showAbilityID = true,
                showAreaPoiID = true,
                showArtifactPowerID = true,
                showBonusID = true,
                showCompanionID = true,
                showCriteriaID = true,
                showGemID = true,
                showSourceID = true,
                showTalentID = true,
                showTraitDefinitionID = false,
                showTraitEntryID = false,
                showTraitNodeID = false,
                showVignetteID = true,
                showVisualID = true,
            },
            itemtracker = {
                enabled = true,
                colorByClass = true,
                characterLimit = 10,
                showAlts        = true,
                showBags        = true,
                showBank        = true,
                showEquipped    = true,
                showAuctions    = true,
                showWarbandBank = true,
                showGuildBanks  = true,
                showVendors     = true,
                showInstances   = true,
                showQuests      = true,
                showCrafted     = true,
                altScope        = { mode = "all", chars = {}, roles = {} },
            },
            recipeknowledge = {
                enabled = true,
                altScope = { mode = "all", chars = {}, roles = {} },
            },
            reagents = { enabled = true },
            collections = {
                enabled = true,
                recipeAltDisplay = "differentiated",
                showNonCollectable = false,
            },
            customnotes = { enabled = true },
            enhancements = {
                removeBlizzardVendorValue = true,
            },
            talentmods = {},
            value = {
                enabled = true,
                showVendorPrice = true,
                showAHValue = true,
                ahPriceSource = "onewow",
                showTSMValue = false,
                tsmPriceString = "dbmarket",
            },
            pets = {
                enabled = true,
                showCollectionStatus = true,
                showPetInfo = true,
                showSource = true,
                showDescription = true,
                showValue = true,
                showAHValue = true,
                showItemStatus = true,
                showTechnicalIDs = true,
            },
        },
    },
    itemStatus = {},
    -- Runtime state of Integrations/ExternalTooltipSync.lua (Auctionator option
    -- backups, one-time notice flags). Machine state, not user settings — kept
    -- outside the settings funnel.
    externalTooltipSync = {
        auctionatorBackup = {},
        auctionatorPopupShown = false,
        tsmNoticeShown = false,
    },
    profiles = {},
    charProfiles = {},
    defaultProfile = "Default",
    -- User-defined character roles for the Roles & Alts tab and tooltip alt
    -- scoping. Map keyed by generated role id: roles[id] = { id, name,
    -- members = { [charKey] = true } }. Owned by OneWoW.AltScope.
    roles = {},
    -- Soft feature opt-out (Manage Features). Account map + per-character
    -- override maps; owned by AddonLoader OptOutStore.
    featureOptOut = { account = {}, char = {} },
    -- Pending CatDB facts while LoD packs are not loaded. Flushed into each
    -- pack's learned overlay; CompSync Contribute reads rows with sync = true.
    -- See OneWoW/Docs/CATDB_CONTRIBUTE.md.
    catdbLearn = {
        npc = {},
        quest = {},
        recipe = {},
    },
}

--- Fresh copy of the shipped defaults subtree for one settings tab
--- ("overlays", "tooltips", "toastalerts"). Used by
--- SettingsFeatureRegistry:ResetTab. Errors on unknown tab names.
---@param tabName string
---@return table
function ns:GetSettingsDefaults(tabName)
    return CopyTable(DEFAULTS.settings[tabName])
end

function ns:InitializeDatabase()
    -- OneWoW_DB was historically a flat root — the root WAS the global table
    -- (`self.db = { global = OneWoW_DB }`). DB:Init single mode expects
    -- root.global plus scope roots, so wrap a legacy flat SV once before
    -- Init. Shape-detected: runs once when the SV is still flat.
    local sv = OneWoW_DB
    if sv and not sv.global and next(sv) ~= nil then
        local oldData = {}
        for k, v in pairs(sv) do
            oldData[k] = v
        end
        wipe(sv)
        sv.global = oldData
    end

    self.db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_DB",
        defaults = { global = DEFAULTS },
    })

    self:MigrateAltScope()
    self:MigrateOverlays2()
    ns.SearchCatalog:MigrateFromSearchShortcuts()

    -- Custom overlays are the core-owned store of user-authored expressions.
    -- Registered here rather than beside the overlay engine because the
    -- settings tree is only reachable from this file (see the settings funnel).
    -- Preset-backed overlays carry a canned expression from the preset catalog,
    -- not one the user wrote, so only entries with their own expression count.
    ns.SearchCatalog:RegisterExpressionSource("core_overlays", {
        sourceLabel = "OneWoW — Overlays",
        Enumerate = function()
            local out = {}
            local overlays = ns.db.global.settings.overlays
            for id, entry in pairs(overlays and overlays.userOverlays or {}) do
                if type(entry) == "table" and type(entry.expression) == "string"
                    and entry.expression ~= "" then
                    tinsert(out, { expression = entry.expression, label = entry.name or id })
                end
            end
            return out
        end,
    })

    ns:RegisterProfileExpressionSources()
end

-- Profile snapshots are frozen copies of settings — account profiles hold core
-- overlays, and character profiles hold whole SavedVariables trees from other
-- units. Restoring one brings its expressions back, so a former name those
-- expressions rely on must not be pruned while the snapshot exists.
--
-- Scanned generically rather than per-shape: a snapshot is opaque nested data
-- whose layout changes whenever any unit adds a setting, and a walker that
-- silently missed a branch would make pruning unsafe. Over-reporting is the
-- safe direction here — the worst case is keeping a former name a little
-- longer, where the worst case of under-reporting is breaking a restore.
--
-- Known-impossible neighborhoods are skipped so Reference check is not flooded
-- by packed CVar blobs (`v21##…##0G##…`) or macro `#showtooltip` text — search
-- syntax never lives there. Real expression fields under addonSettings /
-- searchCatalog keep being walked.
local MAX_SNAPSHOT_DEPTH = 12

local SNAPSHOT_SKIP_KEYS = {
    cvars = true,
    accountMacros = true,
    characterMacros = true,
    macros = true,
}

-- Blizzard packed UI-state CVars (reputation headers, currency categories, …).
local function IsPackedBlizzardState(text)
    return strmatch(text, "^v%d+#+") ~= nil
end

-- Macro UI directives are not catalog tokens.
local function StripMacroDirectives(text)
    return (strgsub(text, "#[Ss][Hh][Oo][Ww][%w_]*", ""))
end

-- A snapshot is mostly strings that cannot possibly hold a reference — cvar
-- values, texture names, anchor points, addon names. Keeping only the ones
-- carrying a reference marker turns hundreds of candidates into a handful
-- without narrowing what is found: a string with no `#`, `SAVED(`, or
-- `CATEGORY(` in it cannot reference anything by construction.
local function MayReference(text)
    if IsPackedBlizzardState(text) then return false end
    text = StripMacroDirectives(text)
    return strfind(text, "#", 1, true) ~= nil
        or strfind(text, "SAVED(", 1, true) ~= nil
        or strfind(text, "CATEGORY(", 1, true) ~= nil
end

local function CollectSnapshotStrings(value, out, label, depth)
    if depth > MAX_SNAPSHOT_DEPTH or type(value) ~= "table" then return end
    for k, v in pairs(value) do
        local t = type(v)
        if t == "string" then
            if v ~= "" and MayReference(v) then
                -- Store directive-stripped text so Lint does not re-parse #showtooltip.
                tinsert(out, { expression = StripMacroDirectives(v), label = label })
            end
        elseif t == "table" and not SNAPSHOT_SKIP_KEYS[k] then
            CollectSnapshotStrings(v, out, label, depth + 1)
        end
    end
end

-- A profile is a state the user can switch back to, not one that is running.
-- Deleting a named expression a profile mentions breaks nothing today; it breaks
-- when that profile is next loaded. Counting those alongside live rules would
-- overstate every warning by the number of profiles kept, so they are classed
-- `restorable` and reported on their own line. Pruning still counts them, which
-- is what keeps a former name alive as long as a profile depends on it.
local function SnapshotSource(sourceLabel, getStore)
    return {
        sourceLabel = sourceLabel,
        class = "restorable",
        Enumerate = function()
            local out = {}
            for name, snapshot in pairs(getStore() or {}) do
                CollectSnapshotStrings(snapshot, out, name, 1)
            end
            return out
        end,
    }
end

function ns:RegisterProfileExpressionSources()
    ns.SearchCatalog:RegisterExpressionSource("core_profiles",
        SnapshotSource("OneWoW — Saved Profiles", function()
            return ns.db.global.profiles
        end))

    ns.SearchCatalog:RegisterExpressionSource("core_charprofiles",
        SnapshotSource("OneWoW — Character Profiles", function()
            return ns.db.global.charProfiles
        end))
end

-- Legacy 1.0 overlay feature ids in their catalog order. Every legacy entry
-- is converted into its matching 2.0 preset row so disabled-but-customized
-- overlay settings are preserved, not silently dropped.
local LEGACY_OVERLAY_IDS = {
    "consumables", "housingdecor", "junk", "protected", "knownitems",
    "unknownitems", "mounts", "pets", "quest", "reagents", "recipe",
    "soulbound", "toys", "warbound", "wue", "boe", "transmog",
}

-- Extra per-feature keys that survive migration onto the preset entry.
local LEGACY_OVERLAY_EXTRAS = {
    junk      = { "showInTooltip", "includeGreyItems" },
    protected = { "showInTooltip" },
    warbound  = { "includeWUE" },
}

-- One-time migration from overlay system 1.0 (fixed per-feature tables) to
-- 2.0 (userOverlays entries). Runs every load but is a no-op once the legacy
-- feature tables are gone.
function ns:MigrateOverlays2()
    local overlays = self.db.global.settings.overlays
    if not overlays then return end

    local order = 0
    for _, id in ipairs(LEGACY_OVERLAY_IDS) do
        local old = overlays[id]
        if type(old) == "table" then
            order = order + 1
            local existing = overlays.userOverlays["ov_" .. id] or {}
            local entry = {
                preset = id,
                enabled = old.enabled == true,
                order = existing.order or order,
                position = old.position or existing.position,
                scale = old.scale or existing.scale,
                alpha = old.alpha or existing.alpha,
                effect = old.effect or existing.effect,
                applyToVendorItems = old.applyToVendorItems,
                applyToAuctionHouse = old.applyToAuctionHouse,
                icon = {
                    kind = "list",
                    value = old.icon or (existing.icon and existing.icon.value),
                    tint = old.iconColor and CopyTable(old.iconColor)
                        or (existing.icon and existing.icon.tint and CopyTable(existing.icon.tint) or nil),
                },
            }
            if old.bgEnabled ~= nil or old.bgStyle ~= nil or existing.bg then
                entry.bg = {
                    enabled = old.bgEnabled or (existing.bg and existing.bg.enabled) or false,
                    style = old.bgStyle or (existing.bg and existing.bg.style),
                    scale = old.bgScale or (existing.bg and existing.bg.scale),
                    color = old.bgColor and CopyTable(old.bgColor)
                        or (existing.bg and existing.bg.color and CopyTable(existing.bg.color) or nil),
                    useRarityColor = old.bgUseRarityColor ~= nil and old.bgUseRarityColor
                        or (existing.bg and existing.bg.useRarityColor),
                }
            end
            local extras = LEGACY_OVERLAY_EXTRAS[id]
            if extras then
                for _, key in ipairs(extras) do
                    entry[key] = old[key]
                    if entry[key] == nil then entry[key] = existing[key] end
                end
            end
            overlays.userOverlays["ov_" .. id] = entry
            overlays[id] = nil
        end
    end

    -- itemlevel 1.0 -> 2.0: useQualityColors collapses into colorMode; the
    -- remaining shared keys keep their stored values, new keys come from the
    -- defaults merge.
    local il = overlays.itemlevel
    if il and il.useQualityColors ~= nil then
        if il.colorMode == nil then
            il.colorMode = il.useQualityColors and "quality" or "custom"
        end
        il.useQualityColors = nil
    end
end

-- One-time migration of the legacy Gear Upgrades per-alt whitelist
-- (tooltipAltWhitelistEnabled / tooltipAltWhitelist) into the shared altScope
-- shape. Runs every load but is a no-op once the legacy keys are gone.
function ns:MigrateAltScope()
    local up = self.db.global.settings.overlays and self.db.global.settings.overlays.upgrade
    if not up then return end
    if up.tooltipAltWhitelistEnabled == nil and up.tooltipAltWhitelist == nil then return end

    if up.tooltipAltWhitelistEnabled and (type(up.altScope) ~= "table" or up.altScope.mode ~= "selected") then
        up.altScope = {
            mode = "selected",
            chars = CopyTable(up.tooltipAltWhitelist or {}),
            roles = {},
        }
    end
    up.tooltipAltWhitelistEnabled = nil
    up.tooltipAltWhitelist = nil
end

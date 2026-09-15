local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

local pairs, ipairs, type, tremove = pairs, ipairs, type, tremove

local defaults = {
    global = {
        language               = nil,
        theme                  = "green",
        lastTab                = "notes",
        mainFrameSize          = nil,
        mainFramePosition      = nil,
        minimap                = { hide = false, minimapPos = 220, theme = "horde" },
        notes                  = {},
        items                  = {},
        zones                  = {},
        players                = {},
        npcs                   = {},
        collectibles           = {},
        waypins                = {},
        waypinWorldSize        = 22,
        waypinMinimapSize      = 16,
        waypinEnabled          = true,
        waypinShowWorld        = true,
        waypinShowMinimap      = true,
        waypinMinimapAnimate   = false,
        waypinShowMapPanel     = true,
        waypinShowZoneList     = true,
        waypinHideInInstances  = true,
        waypinHideInDelves     = true,
        waypinHideInPetBattles = true,
        waypinHideInBattlegrounds = true,
        waypinPackPrefs        = {},
        waypinCompanionPos     = nil,
        waypinMapClickEnabled  = true,
        waypinMapClick         = "ctrlRight",
        pinPacks               = {},
        waypinShowDisabledPacks = true,
        notesCustomCategories  = {},
        itemCustomCategories   = {},
        zoneCustomCategories   = {},
        playerCustomCategories = {},
        npcCustomCategories    = {},
        collectibleCustomCategories = {},
        notePinPositions       = {},
        zonePinPositions       = {},
        tabSortPrefs = {
            notes   = { by = "modified", ascending = false },
            npcs    = { by = "name",     ascending = true  },
            players = { by = "name",     ascending = true  },
            zones   = { by = "name",     ascending = true  },
            items   = { by = "name",     ascending = true  },
            collectibles = { by = "name", ascending = true },
            waypins = { by = "name", ascending = true },
        },
        zoneAlertsEnabled  = true,
        zonePinnedWindowEnabled = true,
        sortCompletedTasks = false,
        -- Vendor collectible capture: off | prompt | auto. A subscription
        -- decision, reconciled by ns.CollectiblesMerchant:ApplySubscription().
        collectibleCaptureMode = "off",
        -- Recycle bin: when on, collected items you were tracking move to the Delete
        -- List and are permanently purged after collectiblePurgeTTLDays (0 = immediate).
        collectibleAutoDelete    = false,
        collectiblePurgeTTLDays  = 7,
        -- Percent scale for pinned notes and zone windows (50-200).
        pinnedScale              = 100,
        -- One-time legacy mount-blob migration guard (set true after the pass).
        collectibleMountMigrated = false,
        -- One-time guard for remapping the retired "Mount"/"Transmog" built-in
        -- collectible categories onto "General" (set true after the pass).
        collectibleCategoriesMigrated = false,
        -- One-shot guards: NPC/Player catch-all category "Other" → "General".
        npcCategoryOtherMigrated    = false,
        playerCategoryOtherMigrated = false,
        -- One-shot: Items builtin "Collectible" retired → remap notes to "General".
        itemCategoryCollectibleMigrated = false,
        -- One-time: zone notes title-keys → opaque ids with zone/subzone fields.
        zoneStructuredMigrated = false,
    },
    char = {
        notes        = {},
        items        = {},
        zones        = {},
        players      = {},
        npcs         = {},
        collectibles = {},
        waypins      = {},
    },
}

--- Remap saved category "Other" → "General" on NPC and Player records (one-time).
--- Also drops "Other" from the matching custom-category lists so it does not
--- reappear after the builtin rename / removal.
function ns:MigrateNpcAndPlayerOtherCategories()
    local function remapStore(store)
        if type(store) ~= "table" then return end
        for _, record in pairs(store) do
            if type(record) == "table" and record.category == "Other" then
                record.category = "General"
            end
        end
    end

    local function dropOtherFromCustom(list)
        if type(list) ~= "table" then return end
        for i = #list, 1, -1 do
            if list[i] == "Other" then
                tremove(list, i)
            end
        end
    end

    if not ns.db.global.npcCategoryOtherMigrated then
        remapStore(ns.db.global.npcs)
        remapStore(ns.db.char.npcs)
        dropOtherFromCustom(ns.db.global.npcCustomCategories)
        ns.db.global.npcCategoryOtherMigrated = true
        if ns.NPCs then ns.NPCs:InvalidateCache() end
    end

    if not ns.db.global.playerCategoryOtherMigrated then
        remapStore(ns.db.global.players)
        remapStore(ns.db.char.players)
        dropOtherFromCustom(ns.db.global.playerCustomCategories)
        ns.db.global.playerCategoryOtherMigrated = true
        if ns.Players then ns.Players:InvalidateCache() end
    end
end

--- Remap Items category "Collectible" → "General" (one-time). Drops
--- "Collectible" from custom categories so it does not linger after the
--- builtin was removed (Collectibles tab owns that domain now).
function ns:MigrateItemCollectibleCategory()
    if ns.db.global.itemCategoryCollectibleMigrated then
        return
    end

    local function remapStore(store)
        if type(store) ~= "table" then return end
        for _, record in pairs(store) do
            if type(record) == "table" and record.category == "Collectible" then
                record.category = "General"
            end
        end
    end

    local function dropCollectibleFromCustom(list)
        if type(list) ~= "table" then return end
        for i = #list, 1, -1 do
            if list[i] == "Collectible" then
                tremove(list, i)
            end
        end
    end

    remapStore(ns.db.global.items)
    remapStore(ns.db.char.items)
    dropCollectibleFromCustom(ns.db.global.itemCustomCategories)
    ns.db.global.itemCategoryCollectibleMigrated = true
    if ns.Items then ns.Items:InvalidateCache() end
end

--- Rekey legacy title-keyed zone notes to opaque ids with zone/subzone fields.
--- Also remaps zonePinPositions keys. One-time per account SV.
function ns:MigrateZoneStructuredNotes()
    if ns.db.global.zoneStructuredMigrated then
        return
    end
    if not ns.Zones then
        return
    end

    local function migrateStore(store)
        if type(store) ~= "table" then return end
        local moves = {}
        for oldKey, data in pairs(store) do
            if type(data) == "table" then
                -- Already migrated (opaque id + zone field).
                if type(oldKey) == "string"
                    and oldKey:match("^zn_")
                    and data.zone
                    and data.zone ~= ""
                then
                    -- ensure subzone field exists
                    if data.subzone == nil then
                        data.subzone = ""
                    end
                    data.id = oldKey
                else
                    local zone = data.zone
                    local subzone = data.subzone
                    if not zone or zone == "" then
                        zone, subzone = ns.Zones:ParseLegacyKey(oldKey)
                    end
                    subzone = subzone or ""
                    local newId = data.id
                    if type(newId) ~= "string" or not newId:match("^zn_") then
                        newId = ns.Zones:MakeNewId()
                    end
                    data.id = newId
                    data.zone = zone
                    data.subzone = subzone
                    if newId ~= oldKey then
                        moves[#moves + 1] = { oldKey = oldKey, newId = newId, data = data }
                    end
                end
            end
        end
        for _, m in ipairs(moves) do
            store[m.newId] = m.data
            if store[m.oldKey] == m.data or store[m.oldKey] ~= nil then
                store[m.oldKey] = nil
            end
            local pinPos = ns.db.global.zonePinPositions
            if type(pinPos) == "table" and pinPos[m.oldKey] ~= nil then
                pinPos[m.newId] = pinPos[m.oldKey]
                pinPos[m.oldKey] = nil
            end
        end
    end

    migrateStore(ns.db.global.zones)
    migrateStore(ns.db.char.zones)
    ns.db.global.zoneStructuredMigrated = true
    ns.Zones:InvalidateCache()
end

function ns:InitializeDatabase()
    -- Bridge from legacy DB:NewCompat (sv.char[charKey]) layout to DB:Init single mode (sv.chars[charKey]).
    local sv = OneWoW_Notes_DB
    if sv and sv.char and not sv.chars then
        sv.chars = sv.char
        sv.char = nil
        sv.profileKeys = nil
    end

    -- Consolidate legacy char-key variants into the canonical OneWoW_GUI form.
    -- Snapshot keys before mutating because pairs() over a table while inserting
    -- previously-absent keys is undefined behavior in Lua 5.1.
    if sv and type(sv.chars) == "table" then
        local oldKeys = {}
        for k in pairs(sv.chars) do oldKeys[#oldKeys + 1] = k end
        for _, oldKey in ipairs(oldKeys) do
            local oldData = sv.chars[oldKey]
            local name, realm = oldKey:match("^(.-)%s*-%s*(.+)$")
            local canonical = name and realm and OneWoW_GUI:GetCharacterKey(name, realm)
            if canonical and canonical ~= oldKey and type(oldData) == "table" then
                local target = sv.chars[canonical]
                if type(target) ~= "table" then
                    sv.chars[canonical] = oldData
                else
                    for k, v in pairs(oldData) do
                        if target[k] == nil then
                            target[k] = v
                        elseif type(target[k]) == "table" and type(v) == "table" then
                            for k2, v2 in pairs(v) do
                                if target[k][k2] == nil then
                                    target[k][k2] = v2
                                end
                            end
                        end
                    end
                end
                sv.chars[oldKey] = nil
            end
        end
    end

    local db = DB:Init({
        addonName = addonName,
        savedVar  = "OneWoW_Notes_DB",
        defaults  = defaults,
    })
    -- Pre-toggle map-click stored Off as a combo value. Split that into the
    -- boolean and keep Ctrl-Right as the remembered combination.
    if db.global.waypinMapClick == "off" then
        db.global.waypinMapClickEnabled = false
        db.global.waypinMapClick = "ctrlRight"
    end
    ns.db = db
end

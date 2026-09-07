local _, ns = ...

-- Notes-side user data for collectibles. Rows are keyed by the canonical
-- collectible KEY string ("mount:2240", "appearance:source:5678") produced by
-- the core OneWoW.Collectibles service — NOT a numeric id like the other data
-- modules. This module owns only user content (category, intent, notes,
-- acquisition metadata); identity + live collection state stay in core and are
-- resolved at display time (never persisted here).
--
-- Note the deliberate name split: `ns.Collectibles` (below) is this Notes data
-- module; `OneWoW.Collectibles` is the core identity service. They are separate
-- namespaces and both are referenced in this file.

local Collectibles = ns.DataModule:New("collectibles", "collectibleCustomCategories", {
    "General", "Want List", "Delete List", "Other"
})
ns.Collectibles = Collectibles

local pairs, ipairs, wipe = pairs, ipairs, wipe

-- Valid intent values (user-facing meaning): none | want | spotted | farming |
-- delete. The `delete` intent is the recycle bin: items sort to the bottom, render
-- dimmed, and are permanently purged after a TTL (see the cleanup section below).
local DELETE_INTENT   = "delete"
local DELETE_CATEGORY = "Delete List"
-- Active-pursuit intents: the ones auto-recycled when their collectible becomes
-- collected (a "none" library entry is left alone).
local ACTIVE_INTENTS  = { want = true, spotted = true, farming = true }
local SECONDS_PER_DAY = 86400

Collectibles.DELETE_INTENT  = DELETE_INTENT
Collectibles.ACTIVE_INTENTS = ACTIVE_INTENTS

--- Returns a collectible record by key (canonicalized), or nil.
---@param key string
---@return table|nil record
function Collectibles:GetCollectible(key)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return nil end
    return self:GetAll()[key]
end

--- Persists a record under its canonical key, honoring its `storage` scope.
---@param key string
---@param data table
function Collectibles:SaveCollectible(key, data)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key or not data then return end

    data.key = key
    data.modified = GetServerTime()

    if (data.storage or "account") == "character" then
        ns.db.char.collectibles[key] = data
    else
        ns.db.global.collectibles[key] = data
    end

    self:InvalidateCache()
end

--- Create-or-update a collectible record. On update, only non-nil `fields`
--- overwrite. On create, a record is built from the key descriptor + core
--- display resolution (name is a search/fallback convenience only — live
--- display comes from OneWoW.Collectibles.ResolveDisplay at render time).
---@param key string
---@param fields table|nil
---@return boolean ok, table|nil record
function Collectibles:UpsertCollectible(key, fields)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return false end
    fields = fields or {}

    local existing = self:GetCollectible(key)
    if existing then
        for k, v in pairs(fields) do
            if v ~= nil then existing[k] = v end
        end
        self:SaveCollectible(key, existing)
        if fields.intent == "farming" then
            self:SyncFarmListIntent(key, existing.intent)
        end
        return true, existing
    end

    local descriptor = OneWoW.Collectibles.ParseKey(key)
    local display = OneWoW.Collectibles.ResolveDisplay(key)

    local record = {
        key          = key,
        type         = descriptor.type,
        name         = fields.name or (display and display.name),
        category     = fields.category or "General",
        storage      = fields.storage or "account",
        content      = fields.content or "",
        intent       = fields.intent or "none",
        acquisition  = fields.acquisition or { vendorOffers = {}, achievements = {} },
        created      = GetServerTime(),
        modified     = GetServerTime(),
        tooltipLines = fields.tooltipLines or {"", "", "", ""},
    }

    self:SaveCollectible(key, record)
    if fields.intent == "farming" then
        self:SyncFarmListIntent(key, record.intent)
    end
    return true, record
end

--- Removes a collectible record by key.
---@param key string
function Collectibles:RemoveCollectible(key)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return end
    self:Remove(key)
end

--- Set a record's intent, applying recycle-bin bookkeeping. Moving *into* the
--- delete intent stamps `deletedAt` (the purge clock) and files the record under
--- the "Delete List" category, stashing its prior category in `prevCategory` so a
--- later restore is lossless. Moving *out* restores the prior category and clears
--- both fields. Mirrors how capture files a want under "Want List".
---@param key string
---@param intent string
function Collectibles:SetIntent(key, intent)
    local record = self:GetCollectible(key)
    if not record then return end

    local wasDelete = record.intent == DELETE_INTENT
    record.intent = intent

    if intent == DELETE_INTENT then
        if not wasDelete then
            record.prevCategory = record.category
            record.category     = DELETE_CATEGORY
            record.deletedAt    = GetServerTime()
        end
    elseif wasDelete then
        if record.prevCategory ~= nil then
            record.category = record.prevCategory
        end
        record.prevCategory = nil
        record.deletedAt    = nil
    end

    self:SaveCollectible(key, record)
    if intent == "farming" then
        self:SyncFarmListIntent(key, intent)
    end
end

-- Shopping List is LoD and not a Notes RequiredDep. Push Farming-intent
-- items when the API is present; otherwise queue until data-ready. Want
-- stays on the Notes record.
local pendingFarmPushes = {}
local farmWatcherRegistered = false

local function ResolveCollectibleItemID(key)
    local desc = OneWoW.Collectibles.ParseKey(key)
    if not desc then return nil end

    local collType, subtype, id = desc.type, desc.subtype, desc.id
    if collType == "toy" or collType == "heirloom" or collType == "recipe" then
        return id
    end
    if collType == "appearance" then
        if subtype == "item" then
            return id
        end
        if subtype == "source" or subtype == "ima" then
            local itemID = C_TransmogCollection.GetSourceItemID(id)
            if itemID and itemID > 0 then return itemID end
            local info = C_TransmogCollection.GetSourceInfo(id)
            if info and info.itemID and info.itemID > 0 then
                return info.itemID
            end
        end
    end

    local record = Collectibles:GetCollectible(key)
    local offers = record and record.acquisition and record.acquisition.vendorOffers
    if offers then
        for i = 1, #offers do
            local itemID = offers[i].itemID
            if itemID and itemID > 0 then
                return itemID
            end
        end
    end
    return nil
end

local function FlushPendingFarmPushes()
    local api = OneWoW_ShoppingList_API
    if not api or not api.AddFarmItem then return end
    for i = 1, #pendingFarmPushes do
        local pending = pendingFarmPushes[i]
        api.AddFarmItem(pending.itemID, pending.style, pending.extras)
    end
    wipe(pendingFarmPushes)
end

--- Add or update the Shopping List Farming List when this collectible
--- resolves to an itemID. No-op when Shopping List is not ready yet
--- (queued until OneWoW_ShoppingList signals data-ready).
---@param key string
---@param intent string
function Collectibles:SyncFarmListIntent(key, intent)
    if intent ~= "farming" then return end
    local itemID = ResolveCollectibleItemID(key)
    if not itemID then return end

    local style = "farming"
    local display = OneWoW.Collectibles.ResolveDisplay(key)
    local extras = {
        name = display and display.name or "",
        mergeQuantity = false,
    }

    local record = self:GetCollectible(key)
    local offers = record and record.acquisition and record.acquisition.vendorOffers
    if offers and offers[1] then
        local loc = offers[1].location
        if type(loc) == "string" then
            extras.instance_name = loc
        elseif type(loc) == "table" then
            extras.instance_name = loc.zone or loc.name or ""
        end
    end

    local api = OneWoW_ShoppingList_API
    if api and api.AddFarmItem then
        api.AddFarmItem(itemID, style, extras)
        return
    end

    for i = 1, #pendingFarmPushes do
        if pendingFarmPushes[i].itemID == itemID then
            pendingFarmPushes[i] = {
                itemID = itemID,
                style = style,
                extras = extras,
            }
            return
        end
    end
    pendingFarmPushes[#pendingFarmPushes + 1] = {
        itemID = itemID,
        style = style,
        extras = extras,
    }
    if not farmWatcherRegistered then
        farmWatcherRegistered = true
        OneWoW:RegisterDataReadyWatcher("OneWoW_ShoppingList", FlushPendingFarmPushes)
    end
end

-- ---------------------------------------------------------------------------
-- One-time legacy category migration
-- ---------------------------------------------------------------------------
-- The "Mount" and "Transmog" built-in categories were retired because Type
-- already conveys that distinction. Remap any record still filed under them (and
-- any recycle-bin `prevCategory` stash) onto "General" so nothing is stranded in
-- a category the UI no longer offers. Runs once, guarded by an account flag.
local LEGACY_CATEGORY_REMAP = { Mount = "General", Transmog = "General" }

function Collectibles:MigrateLegacyCategories()
    if ns.db.global.collectibleCategoriesMigrated then return end

    -- Snapshot keys first: SaveCollectible invalidates the merged cache, so
    -- mutating while iterating GetAll() would be undefined.
    local keys = {}
    for key, record in pairs(self:GetAll()) do
        if type(record) == "table" then keys[#keys + 1] = key end
    end

    for _, key in ipairs(keys) do
        local record = self:GetCollectible(key)
        if record then
            local changed = false
            local mapped = LEGACY_CATEGORY_REMAP[record.category]
            if mapped then
                record.category = mapped
                changed = true
            end
            local mappedPrev = LEGACY_CATEGORY_REMAP[record.prevCategory]
            if mappedPrev then
                record.prevCategory = mappedPrev
                changed = true
            end
            if changed then
                self:SaveCollectible(key, record)
            end
        end
    end

    ns.db.global.collectibleCategoriesMigrated = true
end

-- ---------------------------------------------------------------------------
-- Recycle bin: auto-delete of collected items + TTL purge
-- ---------------------------------------------------------------------------
-- "Auto-delete collected items" is a soft, reversible flow, not an immediate
-- destroy: a collected item you were tracking (active intent) is moved to the
-- Delete List, then permanently removed once it has sat there longer than the
-- purge TTL. Settings live in account-scoped SavedVariables; the sweep is run on
-- login and whenever the Collectibles tab is shown (no background timer).

--- Whether auto-delete of collected items is enabled (default off).
---@return boolean
function Collectibles:IsAutoDeleteEnabled()
    return ns.db.global.collectibleAutoDelete == true
end

--- Enable/disable auto-delete of collected items.
---@param flag boolean
function Collectibles:SetAutoDeleteEnabled(flag)
    ns.db.global.collectibleAutoDelete = flag and true or false
end

--- Purge delay in days before a Delete-List item is permanently removed. 0 means
--- "Immediate" (purged on the same sweep it is recycled).
---@return number
function Collectibles:GetPurgeTTLDays()
    local n = ns.db.global.collectiblePurgeTTLDays
    if type(n) ~= "number" or n < 0 then return 7 end
    return n
end

--- Set the purge delay in days (0 = immediate).
---@param days number
function Collectibles:SetPurgeTTLDays(days)
    if type(days) ~= "number" or days < 0 then days = 7 end
    ns.db.global.collectiblePurgeTTLDays = days
end

--- Number of records currently in the Delete List.
---@return number
function Collectibles:CountDeleteList()
    local n = 0
    for _, record in pairs(self:GetAll()) do
        if type(record) == "table" and record.intent == DELETE_INTENT then
            n = n + 1
        end
    end
    return n
end

--- Permanently remove every record in the Delete List (manual "empty bin").
---@return number purged count
function Collectibles:EmptyDeleteList()
    local keys = {}
    for key, record in pairs(self:GetAll()) do
        if type(record) == "table" and record.intent == DELETE_INTENT then
            keys[#keys + 1] = key
        end
    end
    for _, key in ipairs(keys) do
        self:RemoveCollectible(key)
    end
    return #keys
end

--- Run one auto-delete pass: (1) recycle collected active-intent records into the
--- Delete List, then (2) purge Delete-List records older than the TTL. No-op when
--- auto-delete is disabled. Collection state is read live from core, so a journal
--- that has not finished loading simply defers a recycle to a later sweep (it can
--- never wrongly recycle an uncollected item). Snapshots keys before mutating so
--- the live merged view is safe to iterate.
---@return number recycled, number purged
function Collectibles:RunCleanup()
    if not self:IsAutoDeleteEnabled() then return 0, 0 end

    local now = GetServerTime()
    local ttl = self:GetPurgeTTLDays() * SECONDS_PER_DAY

    local keys = {}
    for key, record in pairs(self:GetAll()) do
        if type(record) == "table" then keys[#keys + 1] = key end
    end

    local recycled, purged = 0, 0
    for _, key in ipairs(keys) do
        local record = self:GetCollectible(key)
        if record then
            if ACTIVE_INTENTS[record.intent] then
                local state = OneWoW.Collectibles.GetCollectionState(key)
                if state and state.collected then
                    self:SetIntent(key, DELETE_INTENT)
                    recycled = recycled + 1
                    record = self:GetCollectible(key)
                end
            end
            if record and record.intent == DELETE_INTENT then
                if (now - (record.deletedAt or now)) >= ttl then
                    self:RemoveCollectible(key)
                    purged = purged + 1
                end
            end
        end
    end

    return recycled, purged
end

-- ---------------------------------------------------------------------------
-- Vendor offers (merchant capture)
-- ---------------------------------------------------------------------------
-- A vendor offer is a slim junction recording that a collectible's granting item
-- was seen for sale at a vendor: { npcID, npcName, itemID, cost, currencies,
-- isPurchasable, blockReason, location, lastSeen }. It is a *snapshot at sighting* — live
-- affordability + the full vendor encyclopedia are resolved elsewhere (core
-- OneWoW.Collectibles.GetOfferAffordability / vendors pack). Deduped by
-- npcID + itemID so repeated/idempotent merchant scans refresh rather than stack.

--- True if the record already carries a vendor offer for this npc+item pair.
---@param key string
---@param npcID number
---@param itemID number
---@return boolean
function Collectibles:HasVendorOffer(key, npcID, itemID)
    local record = self:GetCollectible(key)
    if not record or not record.acquisition or not record.acquisition.vendorOffers then
        return false
    end
    for _, offer in ipairs(record.acquisition.vendorOffers) do
        if offer.npcID == npcID and offer.itemID == itemID then
            return true
        end
    end
    return false
end

--- Merge a vendor offer onto a collectible, creating the record (intent "want",
--- category "Want List") if it does not yet exist. Existing records keep the
--- user's chosen category/intent; only the offer list is touched. Idempotent:
--- an offer for the same npc+item is refreshed in place, not duplicated.
---@param key string canonical collectible key
---@param offer table `{ npcID, npcName?, itemID, cost?, currencies?, isPurchasable?, blockReason?, location?, lastSeen? }`
---@return boolean ok, boolean|nil isNewOffer
function Collectibles:MergeVendorOffer(key, offer)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key or type(offer) ~= "table" then return false end

    local record = self:GetCollectible(key)
    if not record then
        local ok
        ok, record = self:UpsertCollectible(key, { intent = "want", category = "Want List" })
        if not ok or not record then return false end
    end

    record.acquisition = record.acquisition or { vendorOffers = {}, achievements = {} }
    record.acquisition.vendorOffers = record.acquisition.vendorOffers or {}
    local offers = record.acquisition.vendorOffers

    local isNew = true
    for _, existing in ipairs(offers) do
        if existing.npcID == offer.npcID and existing.itemID == offer.itemID then
            existing.npcName       = offer.npcName
            existing.cost          = offer.cost
            existing.currencies    = offer.currencies
            existing.isPurchasable = offer.isPurchasable
            existing.blockReason   = offer.blockReason
            existing.location      = offer.location
            existing.lastSeen      = offer.lastSeen
            isNew = false
            break
        end
    end
    if isNew then
        offers[#offers + 1] = offer
    end

    self:SaveCollectible(key, record)
    return true, isNew
end

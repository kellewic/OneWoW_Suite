local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local defaults = {
    global = {
        language = GetLocale(),
        theme = "green",
        mainFramePosition = {},
        minimap = {
            hide = true,
            minimapPos = 200,
            theme = "horde",
        },
        mail = {
            keepFreeSlots = 1,
            autoCollectGold = false,
            autoCollectItems = false,
            sortByExpiry = false,
            mirrorLogToChat = false,
            sendAckTimeout = 8,
            useBlizzardUI = false,
            autoFillLastRecipient = false,
            lastRecipient = "",
            favorites = {},
            contacts = {}, -- { { name = "Name-Realm", note = "" }, ... }
            recent = {}, -- up to 20 "Name-Realm"
            blacklistItemIDs = {}, -- [itemID] = true
            shipments = {}, -- array of shipment tables
            selected = {}, -- selected inbox indices (session; not persisted meaningfully)
        },
    },
}

function ns:InitializeDatabase()
    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar  = "OneWoW_Mail_DB",
        defaults  = defaults,
    })
    ns.db = db

    if #db.global.mail.shipments == 0 then
        ns:EnsurePresetShipments()
    end

    local shipments = db.global.mail.shipments
    if shipments.schema_version == nil then
        shipments.schema_version = ns.Constants.SHIPMENTS_SCHEMA_VERSION
    end

    for _, shipment in ipairs(shipments) do
        -- Soulbound exclusion is applied at plan time; strip leftover suffixes from older saves.
        if type(shipment.match) == "string" then
            shipment.match = shipment.match:gsub("%s*&%s*!#soulbound%s*$", "")
        end
        -- Tri-state auto-run `mode` replaced the `enabled` boolean (Jul 2026).
        -- Old `enabled` only gated the bulk-run path, which auto_preview now
        -- subsumes (runs on mailbox open, user confirms before sending).
        if not shipment.mode then
            shipment.mode = shipment.enabled and "auto_preview" or "manual"
        end
        shipment.enabled = nil
        if not shipment.frequency then
            shipment.frequency = "session"
        end
        if not shipment.kind then
            shipment.kind = "items"
        end
        if not shipment.targetKind then
            shipment.targetKind = "char"
        end
        if not shipment.roleDistribute then
            shipment.roleDistribute = "fill_first"
        end
        if shipment.crossRealm ~= "send" and shipment.crossRealm ~= "cancel" and shipment.crossRealm ~= "warbound" then
            shipment.crossRealm = "send"
        end
        shipment.targetRoleId = shipment.targetRoleId or ""
        if shipment.kind == "gold" then
            shipment.keepCopper = shipment.keepCopper or 0
            shipment.maxCopper = shipment.maxCopper or 0
            shipment.maxCopperEnabled = shipment.maxCopperEnabled and true or false
            shipment.restockCopper = shipment.restockCopper or shipment.maxCopper or 0
        end
        shipment.restockSources = ns:NormalizeRestockSources(shipment.restockSources)
    end

    -- Shipment match rules are user-authored expressions, so renaming or
    -- deleting a named expression anywhere in the suite can report what it
    -- would cost here instead of silently breaking these.
    OneWoW.SearchCatalog:RegisterExpressionSource("mail_shipments", {
        sourceLabel = "Mail - Shipments",
        Enumerate = function()
            local out = {}
            for i, shipment in ipairs(ns.db.global.mail.shipments) do
                if type(shipment.match) == "string" and shipment.match ~= "" then
                    tinsert(out, {
                        expression = shipment.match,
                        label = shipment.name or ("#" .. i),
                    })
                end
            end
            return out
        end,
    })
end

--- Fresh restockSources table (bags/bank/warband on; guild off).
---@return table
function ns:NewRestockSources()
    return { bags = true, bank = true, guild = false, warband = true }
end

--- Fill missing restock source keys. Missing `warband` becomes true.
---@param sources table|nil
---@return table
function ns:NormalizeRestockSources(sources)
    if type(sources) ~= "table" then
        return self:NewRestockSources()
    end
    if sources.warband == nil then
        sources.warband = true
    end
    return sources
end

--- Seed manual-mode preset shipments once (cloth/leather/metal/herb/DE).
function ns:EnsurePresetShipments()
    local shipments = ns.db.global.mail.shipments
    if #shipments > 0 then
        return
    end

    local presets = {
        {
            id = "preset_cloth",
            name = "Cloth",
            mode = "manual",
            frequency = "session",
            kind = "items",
            match = "#craftingreagentcloth",
            target = "",
            targetKind = "char",
            targetRoleId = "",
            roleDistribute = "fill_first",
            crossRealm = "send",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = ns:NewRestockSources(),
            exclusions = {},
        },
        {
            id = "preset_leather",
            name = "Leather",
            mode = "manual",
            frequency = "session",
            kind = "items",
            match = "#craftingreagentleather",
            target = "",
            targetKind = "char",
            targetRoleId = "",
            roleDistribute = "fill_first",
            crossRealm = "send",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = ns:NewRestockSources(),
            exclusions = {},
        },
        {
            id = "preset_metal",
            name = "Metal / Ore",
            mode = "manual",
            frequency = "session",
            kind = "items",
            match = "#craftingreagentmetal",
            target = "",
            targetKind = "char",
            targetRoleId = "",
            roleDistribute = "fill_first",
            crossRealm = "send",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = ns:NewRestockSources(),
            exclusions = {},
        },
        {
            id = "preset_herb",
            name = "Herbs",
            mode = "manual",
            frequency = "session",
            kind = "items",
            match = "#craftingreagentherb",
            target = "",
            targetKind = "char",
            targetRoleId = "",
            roleDistribute = "fill_first",
            crossRealm = "send",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = ns:NewRestockSources(),
            exclusions = {},
        },
        {
            id = "preset_de",
            name = "Disenchantables",
            mode = "manual",
            frequency = "session",
            kind = "items",
            match = "#disenchantable & quality<=2",
            target = "",
            targetKind = "char",
            targetRoleId = "",
            roleDistribute = "fill_first",
            crossRealm = "send",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = ns:NewRestockSources(),
            exclusions = {},
        },
    }

    for _, p in ipairs(presets) do
        tinsert(shipments, p)
    end
end

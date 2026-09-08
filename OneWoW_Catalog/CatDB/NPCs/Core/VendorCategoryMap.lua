local _, ns = ...

-- Maps NPC SubName (merchant tooltip subtitle / Creature title) → category key.
-- Vendor category map, plus English title
-- needles from the old NpcDB emit so shipped Creature titles classify
-- without a live merchant visit. Never uses suite L[] labels.

ns.VendorCategoryMap = ns.VendorCategoryMap or {}
local Map = ns.VendorCategoryMap

local strlower = strlower
local strfind = strfind
local strsub = strsub
local tinsert = tinsert
local C_TradeSkillUI = C_TradeSkillUI

-- GlobalString name → category key. Values are read at first resolve.
local GLOBAL_SOURCES = {
    { "MINIMAP_TRACKING_VENDOR_FOOD",          "food" },
    { "MINIMAP_TRACKING_VENDOR_REAGENT",       "reagent" },
    { "MINIMAP_TRACKING_REPAIR",               "repair" },
    { "MINIMAP_TRACKING_INNKEEPER",            "innkeeper" },
    { "MINIMAP_TRACKING_BANKER",              "banker" },
    { "MINIMAP_TRACKING_FLIGHTMASTER",        "flight_master" },
    { "MINIMAP_TRACKING_STABLEMASTER",        "stable_master" },
    { "MINIMAP_TRACKING_TRAINER_CLASS",       "class_trainer" },
    { "MINIMAP_TRACKING_TRAINER_PROFESSION",  "profession_trainer" },
    { "MINIMAP_TRACKING_AUCTIONEER",          "auction_house" },
    { "MINIMAP_TRACKING_BARBER",              "barbershop" },
    { "MINIMAP_TRACKING_TRANSMOGRIFIER",      "transmog" },
    { "MINIMAP_TRACKING_ITEM_UPGRADE_MASTER", "item_upgrade" },
    { "AUCTION_CATEGORY_HOUSING",            "decor" },
}

-- Exact subtitle → key (client SubName strings with no GlobalString).
-- Machine-drafted for non-enUS; exact match only.
local EXACT_CURATED = {
    ["General Goods"] = "general",
    ["Gemischtwaren"] = "general",
    ["Fournitures générales"] = "general",
    ["Pertrechos"] = "general",
    ["Bens Diversos"] = "general",
    ["Beni Generici"] = "general",
    ["Хозяйственные товары"] = "general",
    ["일용품 상인"] = "general",
    ["杂货商"] = "general",
    ["雜貨商"] = "general",
    ["Quartermaster"] = "quartermaster",
    ["Rüstmeister"] = "quartermaster",
    ["Intendant"] = "quartermaster",
    ["Intendente"] = "quartermaster",
    ["Quartiermeister"] = "quartermaster",
    ["Intendencia"] = "quartermaster",
    ["Quartel-mestre"] = "quartermaster",
    ["Quartiermastro"] = "quartermaster",
    ["Интендант"] = "quartermaster",
    ["병참장교"] = "quartermaster",
    ["军需官"] = "quartermaster",
    ["軍需官"] = "quartermaster",
}

-- Lowercased needle → key. Specials first so "Renown Quartermaster"
-- stays quartermaster. English emit needles follow for shipped titles.
local NEEDLE_CURATED = {
    { "quartermaster", "quartermaster" },
    { "rüstmeister", "quartermaster" },
    { "intendant", "quartermaster" },
    { "intendente", "quartermaster" },
    { "quartiermeister", "quartermaster" },
    { "intendencia", "quartermaster" },
    { "quartel-mestre", "quartermaster" },
    { "quartiermastro", "quartermaster" },
    { "интендант", "quartermaster" },
    { "병참장교", "quartermaster" },
    { "军需官", "quartermaster" },
    { "軍需官", "quartermaster" },
    { "renown", "quartermaster" },
    { "reputation", "reputation" },
    { "guild vendor", "guild_vendor" },
    { "guild page", "guild_vendor" },
    { "guild herald", "guild_vendor" },
    { "guild store", "guild_vendor" },
    { "pvp", "pvp" },
    { "arena", "pvp" },
    { "conquest", "pvp" },
    { "delve", "delve" },
    { "housing", "decor" },
    { "decor", "decor" },
    { "general goods", "general" },
    { "trade goods", "general" },
    { "innkeeper", "innkeeper" },
    { "reagents", "reagent" },
    { "reagent", "reagent" },
    { "repair", "repair" },
    { "food & drink", "food" },
    { "food and drink", "food" },
    { "drink", "food" },
    { "food", "food" },
    { "tabard", "tabard" },
    { "mount", "mount" },
    { "companion", "pet" },
    { "pet", "pet" },
    { "toy", "toy" },
    { "transmog", "transmog" },
    { "heirloom", "heirloom" },
    { "fishing", "fishing" },
    { "bait", "fishing" },
    { "stable", "stable_master" },
    { "flight master", "flight_master" },
    { "gryphon master", "flight_master" },
    { "hippogryph master", "flight_master" },
    { "wyvern master", "flight_master" },
    { "bat handler", "flight_master" },
    { "kite master", "flight_master" },
    { "wind rider", "flight_master" },
    { "banker", "banker" },
    { "auction", "auction_house" },
    { "barber", "barbershop" },
    { "upgrade", "item_upgrade" },
    { "catalyst", "catalyst" },
    { "void storage", "void_storage" },
    { "mailbox", "mailbox" },
    { "class trainer", "class_trainer" },
    { "trainer", "profession_trainer" },
}

Map.SPECIAL = {
    quartermaster = true,
    reputation = true,
    decor = true,
    pvp = true,
    guild_vendor = true,
    delve = true,
}

--- True for Quartermaster, Reputation, Decor, PvP, Guild, and Delve.
---@param key string|nil
---@return boolean
function Map.IsSpecial(key)
    return key ~= nil and Map.SPECIAL[key] == true
end

local PROFESSION_SKILL_IDS = {
    171, 164, 333, 202, 182,
    773, 755, 165, 186, 393,
    197, 185, 356, 129, 794,
}

local SUPPLIES_REMAINDERS = {
    "Supplies",
    "Bedarf",
    "bedarf",
    "Vorräte",
    "Fournitures",
    "suministros",
    "Suministros",
    "suprimentos",
    "Suprimentos",
    "forniture",
    "Forniture",
    "товары",
    "Товары",
    "용품",
    "用品",
}

local exactLookup
local professionNames

local function EnsureLookup()
    if exactLookup then return end
    exactLookup = {}
    professionNames = {}

    for _, entry in ipairs(GLOBAL_SOURCES) do
        local globalName, key = entry[1], entry[2]
        local value = _G[globalName]
        if type(value) == "string" and value ~= "" then
            exactLookup[value] = key
        end
    end
    for text, key in pairs(EXACT_CURATED) do
        exactLookup[text] = key
    end

    for _, skillID in ipairs(PROFESSION_SKILL_IDS) do
        local name = C_TradeSkillUI.GetTradeSkillDisplayName(skillID)
        if type(name) == "string" and name ~= "" then
            tinsert(professionNames, name)
            for _, rem in ipairs(SUPPLIES_REMAINDERS) do
                exactLookup[name .. " " .. rem] = "profession_supplies"
                exactLookup[name .. rem] = "profession_supplies"
            end
        end
    end
end

local function MatchProfessionSupplies(subtitle)
    for _, name in ipairs(professionNames) do
        if strsub(subtitle, 1, #name) == name then
            local rest = strsub(subtitle, #name + 1)
            if rest ~= "" then
                local token = rest
                if strsub(rest, 1, 1) == " " then
                    token = strsub(rest, 2)
                end
                for _, rem in ipairs(SUPPLIES_REMAINDERS) do
                    if token == rem then
                        return "profession_supplies"
                    end
                end
            end
        end
    end
    return nil
end

--- Map an NPC subtitle (and optional canRepair) to a category key.
---@param subtitle string|nil
---@param canRepair boolean|nil
---@return string|nil categoryKey
function Map.Resolve(subtitle, canRepair)
    EnsureLookup()

    if subtitle and subtitle ~= "" then
        local key = exactLookup[subtitle]
        if key then
            return key
        end
        key = MatchProfessionSupplies(subtitle)
        if key then
            return key
        end
        local lower = strlower(subtitle)
        for _, entry in ipairs(NEEDLE_CURATED) do
            if strfind(lower, entry[1], 1, true) then
                return entry[2]
            end
        end
    end

    if canRepair then
        return "repair"
    end
    return nil
end

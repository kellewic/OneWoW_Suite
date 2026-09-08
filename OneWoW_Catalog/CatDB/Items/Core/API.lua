local _, ns = ...

local C_Item = C_Item

-- Public, cross-addon read surface for ItemDB. ns stays private.
OneWoW_CatDB_ItemDB_API = {}

-- Instant-redundant fields are omitted from shards. Fill once on first GetItem.
local function HydrateItem(rec)
    if rec.classID ~= nil then
        return rec
    end
    local _, _, _, _, icon, classID, subclassID = C_Item.GetItemInfoInstant(rec.itemID)
    rec.icon = icon
    rec.classID = classID
    rec.subclassID = subclassID
    rec.inventoryType = C_Item.GetItemInventoryTypeByID(rec.itemID)
    return rec
end

--- Returns the store settings.
---@return table settings
function OneWoW_CatDB_ItemDB_API.GetSettings()
    return ns:GetSettings()
end

--- One item identity row by itemID.
---@param itemID number
---@return table|nil item
function OneWoW_CatDB_ItemDB_API.GetItem(itemID)
    local rec = ns.Items[itemID]
    if not rec then
        return nil
    end
    return HydrateItem(rec)
end

--- Localized name from the shipped index (offline; does not need the client cache).
---@param itemID number
---@return string|nil name
function OneWoW_CatDB_ItemDB_API.GetItemName(itemID)
    local name = ns.ItemNameIndex[itemID]
    if name and name ~= "" then
        return name
    end
    local item = ns.Items[itemID]
    if item and type(item.name) == "string" and item.name ~= "" then
        return item.name
    end
    return nil
end

--- Flat itemID -> localized name for offline search.
---@return table<number, string>
function OneWoW_CatDB_ItemDB_API.GetItemNameIndex()
    return ns.ItemNameIndex
end

--- One currency identity row by currencyID.
---@param currencyID number
---@return table|nil currency
function OneWoW_CatDB_ItemDB_API.GetCurrency(currencyID)
    return ns.Currencies[currencyID]
end

--- Achievement IDs that reward or track this item. Empty if none.
---@param itemID number
---@return number[]
function OneWoW_CatDB_ItemDB_API.GetAchievementsForItem(itemID)
    local ids = ns.ItemAchievements[itemID]
    if type(ids) ~= "table" then
        return {}
    end
    return ids
end

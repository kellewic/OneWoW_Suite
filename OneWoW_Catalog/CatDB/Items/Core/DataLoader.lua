local _, ns = ...

-- ============================================================================
-- ItemDB loader
-- ============================================================================
-- Emit agents call:
--   ns:RegisterItemData{ [itemID] = { ... } }
--   ns:RegisterCurrencyData{ [currencyID] = { name, icon } }
--   ns:RegisterItemAchievementData{ [itemID] = { achievementID, ... } }
--   ns.Items              [itemID] = item record
--   ns.ItemNameIndex      [itemID] = name
--   ns.Currencies         [currencyID] = { name, icon }
--   ns.ItemAchievements   [itemID] = { achievementID, ... }
-- ============================================================================

local pairs = pairs

ns.Items = ns.Items or {}
ns.ItemNameIndex = ns.ItemNameIndex or {}
ns.Currencies = ns.Currencies or {}
ns.ItemAchievements = ns.ItemAchievements or {}

--- Merge item identity rows keyed by itemID.
---@param source table<number, table>
function ns:RegisterItemData(source)
    if type(source) ~= "table" then return end

    for itemID, record in pairs(source) do
        if type(itemID) == "number" and type(record) == "table" then
            ns.Items[itemID] = record
            if type(record.name) == "string" and record.name ~= "" then
                ns.ItemNameIndex[itemID] = record.name
            end
        end
    end
end

--- Merge currency identity rows keyed by currencyID.
---@param source table<number, table>
function ns:RegisterCurrencyData(source)
    if type(source) ~= "table" then return end

    for currencyID, record in pairs(source) do
        if type(currencyID) == "number" and type(record) == "table" then
            ns.Currencies[currencyID] = record
        end
    end
end

--- Merge itemID -> achievementIDs (reward or item criteria).
---@param source table<number, number[]>
function ns:RegisterItemAchievementData(source)
    if type(source) ~= "table" then return end

    for itemID, ids in pairs(source) do
        if type(itemID) == "number" and type(ids) == "table" then
            ns.ItemAchievements[itemID] = ids
        end
    end
end

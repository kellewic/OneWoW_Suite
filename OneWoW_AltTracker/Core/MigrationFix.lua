local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local CopyTable = CopyTable
local next, pairs, type = next, pairs, type

ns.MigrationFix = {}
local MigrationFix = ns.MigrationFix

local function CompletionBucket(sv)
    if type(sv) ~= "table" then
        return nil
    end
    if type(sv.global) == "table" and type(sv.global.completion) == "table" then
        return sv.global.completion
    end
    if type(sv.completion) == "table" then
        return sv.completion
    end
    return nil
end

local function OldVendorRows(sv)
    if type(sv) ~= "table" then
        return nil
    end
    if type(sv.global) == "table" and type(sv.global.vendors) == "table" then
        return sv.global.vendors
    end
    if type(sv.vendors) == "table" then
        return sv.vendors
    end
    return nil
end

-- Leftover CatalogData WTF files stay after the folders are gone. Destination
-- CatDB TOCs still declare those SV names so WoW loads them; copy if present.
local function CopyLegacyCatalogDataSVs()
    if OneWoW_CatalogData_Quests_DB and OneWoW_CatDB_QuestDBCurrent_DB then
        local destSV = OneWoW_CatDB_QuestDBCurrent_DB
        if type(destSV.global) ~= "table" then
            destSV.global = {}
        end
        if type(destSV.global.completion) ~= "table" then
            destSV.global.completion = {}
        end
        local dest = destSV.global.completion
        local src = CompletionBucket(OneWoW_CatalogData_Quests_DB)
        if src then
            for charKey, completedMap in pairs(src) do
                if type(charKey) == "string" and type(completedMap) == "table" then
                    local existing = dest[charKey]
                    if type(existing) ~= "table" or next(existing) == nil then
                        dest[charKey] = CopyTable(completedMap)
                    end
                end
            end
        end
    end

    if OneWoW_CatalogData_Vendors_DB and OneWoW_CatDB_NPCDB_DB then
        local destSV = OneWoW_CatDB_NPCDB_DB
        if type(destSV.global) ~= "table" then
            destSV.global = {}
        end
        if type(destSV.global.vendorCategories) ~= "table" then
            destSV.global.vendorCategories = {}
        end
        local dest = destSV.global.vendorCategories
        local vendors = OldVendorRows(OneWoW_CatalogData_Vendors_DB)
        if vendors then
            for npcID, row in pairs(vendors) do
                if type(row) == "table" and row.categorySource == "user"
                    and type(row.category) == "string" and row.category ~= ""
                    and dest[npcID] == nil then
                    dest[npcID] = row.category
                end
            end
        end
    end
end

-- Consolidates cross-reference tables that key by charKey but don't live in any
-- submodule DB (so they aren't reached by the per-submodule consolidator pass).
function MigrationFix:ConsolidateCrossReferenceCharKeys()
    local total = 0
    total = total + DB:ConsolidateCharacterKeys(ns.db.global.favorites)

    if not ns.db.global.legacyCatalogDataCopied then
        local catOk = OneWoW:EnsureLoaded("OneWoW_Catalog")
        if catOk then
            CopyLegacyCatalogDataSVs()
            ns.db.global.legacyCatalogDataCopied = true
        end
    end

    if OneWoW_CatalogData_Quests_DB then
        total = total + DB:ConsolidateCharacterKeys(OneWoW_CatalogData_Quests_DB.completion)
        if type(OneWoW_CatalogData_Quests_DB.global) == "table" then
            total = total + DB:ConsolidateCharacterKeys(OneWoW_CatalogData_Quests_DB.global.completion)
        end
    end

    if OneWoW_CatDB_QuestDBCurrent_DB and type(OneWoW_CatDB_QuestDBCurrent_DB.global) == "table" then
        total = total + DB:ConsolidateCharacterKeys(OneWoW_CatDB_QuestDBCurrent_DB.global.completion)
    end

    if total > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. total .. " duplicate character key(s) across favorites / catalog data.")
        end)
    end

    return total
end

local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.ZoneDefaults = {
    global = {
        settings = { enabled = true },
        itemCache = {},
    },
}
ns.NPCDefaults = {
    global = {
        settings = { enabled = true },
        nameCache = {},
        itemCache = {},
        vendorCategories = {},
        vendorVisits = {},
        learned = {},
    },
}
ns.ItemDefaults = {
    global = {
        settings = { enabled = true },
    },
}
ns.QuestDefaults = {
    global = {
        settings = { enabled = true },
        completion = {},
        learned = {},
    },
}

function ns:InitializeCatDB()
    if not OneWoW_CatDB_ZoneDB_DB then OneWoW_CatDB_ZoneDB_DB = {} end
    if not OneWoW_CatDB_NPCDB_DB then OneWoW_CatDB_NPCDB_DB = {} end
    if not OneWoW_CatDB_ItemDB_DB then OneWoW_CatDB_ItemDB_DB = {} end
    if not OneWoW_CatDB_QuestDBCurrent_DB then OneWoW_CatDB_QuestDBCurrent_DB = {} end

    ns.zoneDb = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatDB_ZoneDB_DB",
        defaults = ns.ZoneDefaults,
    })
    ns.npcDb = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatDB_NPCDB_DB",
        defaults = ns.NPCDefaults,
    })
    ns.itemDb = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatDB_ItemDB_DB",
        defaults = ns.ItemDefaults,
    })
    ns.questDb = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatDB_QuestDBCurrent_DB",
        defaults = ns.QuestDefaults,
    })
end

function ns:GetSettings()
    return ns.zoneDb.global.settings
end

function ns:GetDB()
    return ns.zoneDb.global
end

function ns:GetNPCDB()
    return ns.npcDb.global
end

function ns:GetItemDB()
    return ns.itemDb.global
end

function ns:GetQuestDB()
    return ns.questDb.global
end

-- Catalog settings: Database Manager via shared OneWoW_GUI row helper.
local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local L = ns.L
ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, { width = parent:GetWidth(), height = parent:GetHeight() })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local sharedL = OneWoW.Locale:GetTable("shared")
    local yOffset = -10

    local dbSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = sharedL["DATABASE_MANAGER_TITLE"], yOffset = yOffset })
    yOffset = dbSection.bottomY - 8

    local dbDesc = OneWoW_GUI:CreateFS(scrollContent, 12)
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText(sharedL["DATABASE_MANAGER_DESC"])
    dbDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    dbDesc:SetSpacing(3)
    yOffset = yOffset - 30

    local coreL = OneWoW.Locale:GetTable("OneWoW")
    -- Reset CatDB learned SavedVariables (runtime overlay) plus TradeSkill.
    local databases = {
        { key = "OneWoW_Catalog",              name = L["SETTINGS_DB_NAME_CATALOG"], desc = L["SETTINGS_DB_DESC_CATALOG"] },
        { key = "OneWoW_CatDB_ZoneDB",         name = coreL["CAT_MOD_TOPIC_ZONE"], desc = coreL["WIZARD_CAT_DATA_ERA_DESC"] },
        { key = "OneWoW_CatDB_NPCDB",          name = coreL["CAT_MOD_TOPIC_NPC"], desc = coreL["WIZARD_CAT_DATA_ERA_DESC"] },
        { key = "OneWoW_CatDB_ItemDB",         name = ITEMS, desc = coreL["WIZARD_CAT_DATA_ERA_DESC"] },
        { key = "OneWoW_CatDB_QuestDBCurrent", name = coreL["CAT_MOD_TOPIC_QUEST"], desc = coreL["WIZARD_CAT_DATA_ERA_DESC"] },
        { key = "OneWoW_CatDB_TradeSkillDB",   name = coreL["CAT_MOD_TRADESKILLDB"], desc = coreL["WIZARD_CAT_DATA_TRADESKILLS_DESC"] },
    }

    local function GetEntryCount(dbKey)
        local svGlobal = _G[dbKey .. "_DB"]
        if not svGlobal then return nil end
        local size = 0
        for _ in pairs(svGlobal) do size = size + 1 end
        return math.max(0, size - 5)
    end

    for _, dbData in ipairs(databases) do
        local key = dbData.key
        yOffset = yOffset - OneWoW_GUI:CreateDatabaseManagerRow(scrollContent, {
            name = dbData.name,
            description = dbData.desc,
            addonKey = key,
            yOffset = yOffset,
            getEntryCount = function()
                return GetEntryCount(key)
            end,
        })
    end

    yOffset = yOffset - 20
    scrollContent:SetHeight(math.abs(yOffset) + 20)
end

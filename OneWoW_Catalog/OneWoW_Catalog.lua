local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

OneWoW_Catalog = {}
local OneWoW_Catalog = OneWoW_Catalog

local function RegisterWithOneWoW()
    OneWoW:RegisterModule({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName   = ADDON_NAME,
        order       = OneWoW:GetModuleTabOrder("catalog"),
        tabs = {
            { name = "journal",     displayName = function() return ns.L["TAB_JOURNAL"]     end, requiresCatalogRole = "journal", requiresAddon = ns.ResolveCatalogPack("journal"),     create = function(p) ns.UI.CreateJournalTab(p)    end },
            { name = "vendors",     displayName = function() return ns.L["TAB_VENDORS"]     end, requiresCatalogRole = "vendors", requiresAddon = ns.ResolveCatalogPack("vendors"),     create = function(p) ns.UI.CreateVendorsTab(p)    end },
            { name = "tradeskills", displayName = function() return TRADESKILLS end, requiresAddon = ns.ResolveCatalogPack("tradeskills"), create = function(p) ns.UI.CreateTradeskillsTab(p) end },
            { name = "quests",      displayName = function() return ns.L["TAB_QUESTS"]      end, requiresCatalogRole = "quests", requiresAddon = ns.ResolveCatalogPack("quests"),      create = function(p) ns.UI.CreateQuestsTab(p)     end },
            { name = "itemsearch",  displayName = function() return ns.L["TAB_ITEMSEARCH"]  end, create = function(p) ns.UI.CreateItemSearchTab(p) end },
            { name = "collectibles", displayName = function() return ns.L["TAB_COLLECTIBLES"] end, create = function(p) ns.UI.CreateCollectiblesTab(p) end },
            { name = "housing",     displayName = function() return ns.L["JOURNAL_FILTER_HOUSING"] end, create = function(p) ns.UI.CreateHousingTab(p) end },
        },
    })
    OneWoW:RegisterSettingsPanel({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("catalog"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()
    ns:InitializeCatDB()
    OneWoW_GUI:MigrateSettings(ns.db.global)
    OneWoW_Catalog:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end

    DB:RegisterSlashCommand("1wcat", function(msg) OneWoW_Catalog:SlashCommandHandler(msg) end)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Catalog, function(self)
        self:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Catalog, function()
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_Catalog, function()
        local mainFrame = OneWoWMainWindow
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_Catalog, function()
        local mainFrame = OneWoWMainWindow
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", OneWoW_Catalog, function()
        if ns.UI.RefreshItemSearchList then ns.UI.RefreshItemSearchList() end
        if ns.UI.RefreshVendorsList then ns.UI.RefreshVendorsList() end
        if ns.UI.RefreshQuestsList then ns.UI.RefreshQuestsList() end
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    OneWoW:RegisterLoadComponent("Catalog", _ver, "/1wcat", ADDON_NAME)
end

local function OnEnable()
    RegisterWithOneWoW()

    OneWoW:RegisterMinimap("OneWoW_Catalog",
        ns.L["CTX_OPEN_CATALOG"],
        "catalog", nil)

    ns.ArmCatalogDataPacks()
end

function OneWoW_Catalog:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoW_Catalog:ApplyLanguage()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
end

function OneWoW_Catalog:SlashCommandHandler()
    OneWoW.UI:Show("catalog")
end

function OneWoW_Catalog.EnsureCatDBVendorRuntime()
    ns:EnsureCatDBVendorRuntime()
end

function OneWoW_Catalog.EnsureCatDBQuestRuntime()
    ns:EnsureCatDBQuestRuntime()
end

-- Core-driven init: the suite loader calls _G["OneWoW_Catalog"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- DispatchUnitOnAddonLoaded guarantees at-most-once init per session.
function OneWoW_Catalog:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Catalog)
    OnInitialize()
end

-- Login-phase arming via RunManifestLoginPhase (cold start) or Settle
-- (mid-session enable). didLogin guard: Settle may re-invoke OnPlayerLogin.
local didLogin = false
function OneWoW_Catalog:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    ns:StartCatDBRuntime()
    if OneWoW_Catalog.FireLoginHandlers then
        OneWoW_Catalog:FireLoginHandlers()
    end
end

local ADDON_NAME, ns = ...

ns.UI = ns.UI or {}

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

OneWoW_QoL = {}
local OneWoW_QoL = OneWoW_QoL

local function RegisterWithOneWoW()
    local tabs = {
        { name = "features",    displayName = function() return ns.L["TAB_FEATURES"] end, create = function(p) ns.UI.CreateFeaturesTab(p) end },
        { name = "toggles",     displayName = function() return ns.L["TAB_TOGGLES"]  end, create = function(p) ns.UI.CreateTogglesTab(p) end },
        -- Feature settings tabs owned by QoL scope; strings live in the QoL scope
        -- (TOAST_ALERTS_SUBTAB resolves via the shared scope).
        { name = "toastalerts", displayName = function() return ns.L["TOAST_ALERTS_SUBTAB"] end, create = function(p) ns.UI.CreateToastAlertsTab(p) end },
        { name = "tooltips",    displayName = function() return ns.L["TOOLTIPS_SUBTAB"]     end, create = function(p) ns.UI.CreateTooltipsTab(p) end },
        { name = "portals",     displayName = function() return ns.L["PORTALS_SUBTAB"]      end, create = function(p) ns.UI.CreatePortalsTab(p) end },
        { name = "overlays",    displayName = function() return ns.L["OVERLAYS_SUBTAB"]     end, create = function(p) ns.UI.CreateOverlaysTab(p) end },
    }
    OneWoW:RegisterModule({
        name = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName = ADDON_NAME,
        order = OneWoW:GetModuleTabOrder("qol"),
        tabs = tabs,
    })
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    OneWoW_QoL:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end

    local function slashHandler() OneWoW_QoL:SlashCommandHandler() end
    DB:RegisterSlashCommand("1wqol", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_QoL, function(self)
        OneWoW_GUI:ApplyTheme(self)
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_QoL, function()
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)

    OneWoW:RegisterLoadComponent("QoL", OneWoW:GetAddonVersion(ADDON_NAME), "/1wqol", ADDON_NAME)
end

function OneWoW_QoL:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoW_QoL:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

local function OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    OneWoW:RegisterMinimap("OneWoW_QoL", ns.L["CTX_OPEN_QOL"], "qol", nil)
end

function OneWoW_QoL:SlashCommandHandler()
    OneWoW.UI:Show("qol")
end

function OneWoW_QoL:CopyTextKeybind()
    local ct = ns.ModuleRegistry:GetById("copytext")
    if ct then
        ct:Capture()
    end
end

-- Core-driven init: the suite loader calls _G["OneWoW_QoL"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- DispatchUnitOnAddonLoaded guarantees at-most-once init per session.
function OneWoW_QoL:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_QoL)
    -- Toast types export their arming functions on ns; the handler registry
    -- doesn't exist at their file scope.
    OneWoW_QoL:RegisterLoginHandler("toast-loot", ns.ToastLoot.OnLogin)
    OneWoW_QoL:RegisterLoginHandler("toast-upgrade", ns.ToastUpgrade.OnLogin)
    OneWoW_QoL:RegisterEnteringWorldHandler("toast-instance", ns.ToastInstance.OnEnteringWorld)
    -- Portal Hub: module before esc-menu integration.
    OneWoW_QoL:RegisterLoginHandler("portalhub", function() ns.PortalHubModule:Initialize() end)
    OneWoW_QoL:RegisterLoginHandler("portalhub-esc", function() ns.PortalHubEsc:Initialize() end)
    OneWoW_QoL:RegisterLoginHandler("portalhub-lfg", function() ns.PortalHubLFG:Initialize() end)
    OnInitialize()
end

-- Login-phase arming via RunManifestLoginPhase (cold start) or Settle
-- (mid-session enable). didLogin guard: Settle may re-invoke OnPlayerLogin.
local didLogin = false
function OneWoW_QoL:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if OneWoW_QoL.FireLoginHandlers then
        OneWoW_QoL:FireLoginHandlers()
    end
end

function OneWoW_QoL:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if OneWoW_QoL.FireEnteringWorldHandlers then
        OneWoW_QoL:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end

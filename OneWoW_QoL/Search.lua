local _, ns = ...

local Search = OneWoW.Search
local SR = OneWoW.SearchRegistry

local portalsNav = { module = "qol", subtab = "portals" }
local waypointsNav = { module = "qol", subtab = "waypoints" }

Search:Register({
    id = "qol:waypoints-arrow",
    title = "WAYPOINT_ARROW",
    description = "WAYPOINTS_CARD_DESC",
    scope = "OneWoW_QoL",
    tags = { "waypoint", "tomtom", "arrow", "map", "pin" },
    addonKey = "OneWoW_QoL",
    path = {
        SR.ModuleLabel("qol"),
        SR.TabLabel("qol", "waypoints"),
        function() return ns.L["WAYPOINT_ARROW"] end,
    },
    nav = waypointsNav,
})

local function PortalsPath(leafKey)
    return {
        SR.ModuleLabel("qol"),
        SR.TabLabel("qol", "portals"),
        function() return ns.L[leafKey] end,
    }
end

Search:Register({
    id = "qol:portals-hearth-choice",
    title = "PORTAL_HEARTHSTONE_CHOICE",
    description = "PORTAL_HEARTHSTONE_CHOICE_DESC",
    scope = "OneWoW_QoL",
    tags = { "hearthstone", "random", "toy", "esc", "disabled" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_HEARTHSTONE_CHOICE"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-seasonal-only",
    title = "PORTAL_SEASONAL_ONLY",
    description = "PORTAL_SEASONAL_ONLY_DESC",
    scope = "OneWoW_QoL",
    tags = { "season", "dungeon", "raid", "esc", "hide" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_SEASONAL_ONLY"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-live-path",
    title = "PORTAL_LIVE_PATH_FLYOUTS",
    description = "PORTAL_LIVE_PATH_FLYOUTS_DESC",
    scope = "OneWoW_QoL",
    tags = { "dungeon", "raid", "path", "teleport", "esc" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_LIVE_PATH_FLYOUTS"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-lfg-prompt",
    title = "PORTAL_LFG_PROMPT",
    description = "PORTAL_LFG_PROMPT_DESC",
    scope = "OneWoW_QoL",
    tags = { "lfg", "group finder", "dungeon", "teleport", "popup" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_LFG_PROMPT"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-display",
    title = "PORTAL_DISPLAY_OPTIONS",
    tags = { "portals", "display", "esc" },
    addonKey = "OneWoW_QoL",
    scope = "OneWoW_QoL",
    path = PortalsPath("PORTAL_DISPLAY_OPTIONS"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-mage-teleports",
    title = "PORTAL_SHOW_MAGE_TELEPORTS",
    description = "PORTAL_SHOW_MAGE_TELEPORTS_DESC",
    scope = "OneWoW_QoL",
    tags = { "mage", "teleport", "esc", "hide" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_SHOW_MAGE_TELEPORTS"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-mage-portals",
    title = "PORTAL_SHOW_MAGE_PORTALS",
    description = "PORTAL_SHOW_MAGE_PORTALS_DESC",
    scope = "OneWoW_QoL",
    tags = { "mage", "portal", "esc", "hide" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_SHOW_MAGE_PORTALS"),
    nav = portalsNav,
})

local escScope = "OneWoW_QoL.escpanel"

local function EscPanelText(key)
    return function()
        return OneWoW.Locale:GetTable(escScope)[key]
    end
end

Search:Register({
    id = "qol-mod:escpanel:gold-only",
    title = "ESCPANEL_GOLD_ONLY",
    description = "ESCPANEL_GOLD_ONLY_DESC",
    scope = escScope,
    tags = { "gold", "money", "silver", "copper", "character", "esc" },
    addonKey = "OneWoW_QoL",
    path = {
        SR.ModuleLabel("qol"),
        function() return ns.L["TAB_FEATURES"] end,
        EscPanelText("ESCPANEL_TITLE"),
        EscPanelText("ESCPANEL_GOLD_ONLY"),
    },
    nav = { module = "qol", subtab = "features" },
})

local questScope = "OneWoW_QoL.questtools"

local function QuestToolsText(key)
    return function()
        return OneWoW.Locale:GetTable(questScope)[key]
    end
end

Search:Register({
    id = "qol-mod:questtools:modifier-key",
    title = "QUESTTOOLS_MODIFIER_KEY",
    description = "QUESTTOOLS_MODIFIER_KEY_DESC",
    scope = questScope,
    tags = { "shift", "ctrl", "alt", "modifier" },
    addonKey = "OneWoW_QoL",
    path = {
        SR.ModuleLabel("qol"),
        function() return ns.L["TAB_FEATURES"] end,
        QuestToolsText("QUESTTOOLS_TITLE"),
        QuestToolsText("QUESTTOOLS_AUTOMATION_HEADER"),
        QuestToolsText("QUESTTOOLS_MODIFIER_KEY"),
    },
    nav = { module = "qol", subtab = "features" },
})

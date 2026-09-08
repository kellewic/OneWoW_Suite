local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "escpanel",
    title       = "ESCPANEL_TITLE",
    category    = "INTERFACE",
    description = "ESCPANEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {
        { id = "esc_show_character_info", label = "ESCPANEL_TOGGLE_SHOW_CHARACTER", description = "ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC", default = true },
        { id = "esc_show_here",           label = "ESCPANEL_TOGGLE_SHOW_HERE",      description = "ESCPANEL_TOGGLE_SHOW_HERE_DESC",      default = true },
        { id = "esc_show_portals",        label = "ESCPANEL_TOGGLE_SHOW_PORTALS",   description = "ESCPANEL_TOGGLE_SHOW_PORTALS_DESC",   default = true },
        { id = "esc_skin_game_menu",      label = "ESCPANEL_TOGGLE_SKIN_MENU",      description = "ESCPANEL_TOGGLE_SKIN_MENU_DESC",      default = true },
    },
    tags           = { "esc", "you", "here", "character", "zone", "portals", "theme" },
    preview        = true,
    defaultEnabled = true,
})

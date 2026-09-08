local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["ESCPANEL_TITLE"] = "ESC Menu Panel",
    ["ESCPANEL_DESC"] = "Adds a Character Card, a Zone Card, and a Travel card beside the ESC menu. Optional Suite theme paints the Game Menu and wraps the columns in one panel. The Character Card shows your character, mail, durability, auction attention, Great Vault, Trading Post, and Housing Endeavors. The Zone Card shows this place's collections and Item Alert icons for Shopping List, Notes, Trackers, and Farming. Hover an icon for details; click it to open that window. Click the Character Card for the character screen, or the Zone Card to open this place in Catalog.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Character Card",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "Portrait, mail, durability, auction attention, Great Vault, Trading Post, and Housing Endeavors. Hover mail, durability, or the cart for details; click to open that window.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "Zone Card",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "This place's collections and Item Alert icons. Hover an icon for the list or note; click to open Shopping List, Notes, Trackers, or Farming.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portals",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "Hearthstones and teleport flyouts on a Travel card beside the menu. More portal options live on the Portals tab.",
    ["ESCPANEL_TOGGLE_SKIN_MENU"] = "Suite theme on Game Menu",
    ["ESCPANEL_TOGGLE_SKIN_MENU_DESC"] = "Paint the Game Menu with the OneWoW theme and wrap the cards in one panel. Turn this off if ElvUI, W2UI, or another UI already skins the Game Menu.",
    ["ESCPANEL_LAYOUT_HEADER"] = "Layout",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Cards side",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Portals side",
    ["ESCPANEL_SIDE_LEFT"] = "Left of menu",
    ["ESCPANEL_SIDE_RIGHT"] = "Right of menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Turn Character Card, Zone Card, and Portals on or off above. Pictures of the two cards are below. When cards and portals share a side, they stack in that column (cards above Travel).",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Portal icon size",
})

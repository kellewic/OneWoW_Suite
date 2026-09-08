local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["MMBTNS_TITLE"] = "Minimap Button Collector",
    ["MMBTNS_DESC"] = "Collects minimap addon buttons into a single themed container. Uses the OneWoW brand icon and supports grid layout, auto-close, and an enhanced OneWoW quick-launch row.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r Button Collector",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "%d button(s) collected",
    ["MMBTNS_TOOLTIP_HINT"] = "Left-click to toggle",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "Right-click for menu",
    ["MMBTNS_TOOLTIP_DRAG"] = "Drag to move",

    ["MMBTNS_CLOSE_MODE"] = "Close Behavior",
    ["MMBTNS_STAY_OPEN"] = "Stay Open",
    ["MMBTNS_AUTO_CLOSE"] = "Auto Close",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "Auto-Close Delay (seconds)",

    ["MMBTNS_ENHANCED_MENU"] = "Enhanced OneWoW Menu",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "Adds a top row of OneWoW quick-launch icons. Pick which ones to show below.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "Every OneWoW icon is listed. Uncheck any you do not want on that row. An icon only appears when its addon is loaded.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "Enhanced icon style",
    ["MMBTNS_FEATURE_ICON_RING"] = "With ring",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "Ringless",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "With ring keeps the gold circle. Ringless is just the symbol. Home and Manage Features use the same choice.",

    ["MMBTNS_MAX_COLUMNS"] = "Max Columns",
    ["MMBTNS_MAX_ROWS"] = "Max Rows",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = unlimited. Cannot be 1x1 if multiple buttons exist.",
    ["MMBTNS_BUTTON_SCALE"] = "Collected icon scale",
    ["MMBTNS_BUTTON_SPACING"] = "Button Spacing",

    ["MMBTNS_LOCK_POSITION"] = "Lock Position",
    ["MMBTNS_GROW_LEFT"] = "Left",
    ["MMBTNS_GROW_RIGHT"] = "Right",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "Also Show on Minimap",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "Keep collected buttons on the minimap as well, shown as click-through copies inside the collector.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "Show Tooltips",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "Display original addon tooltips when hovering buttons in the container.",

    ["MMBTNS_ICONS_HEADER"] = "Minimap Icons",
    ["MMBTNS_ICONS_DESC"] = "Every minimap icon detected is listed below. Pick where each one lives: Collector = inside the OneWoW panel, Map = back on the minimap, Hide = removed from sight entirely. The X removes a stale entry (only enabled once the owning addon is disabled). Your choice is remembered across reloads and addon enable/disable cycles.",
    ["MMBTNS_ICONS_EMPTY"] = "No minimap icons detected yet. Open the collector once so it can scan, then reopen Settings.",
    ["MMBTNS_ICONS_MINI"] = "Collector",
    ["MMBTNS_ICONS_MAP"] = "Map",
    ["MMBTNS_ICONS_ENABLED"] = "Enabled",
    ["MMBTNS_ICONS_DISABLED"] = "Disabled",
    ["MMBTNS_ICONS_REMOVE_TT"] = "Remove this entry from the list",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "This addon is currently loaded. Switch its icon to Hide if you don't want to see it; you can only remove the entry once the addon is disabled or uninstalled.",

    ["MMBTNS_SETTINGS_HEADER"] = "Collector Settings",
    ["MMBTNS_LAYOUT_HEADER"] = "Layout",
    ["MMBTNS_BEHAVIOR_HEADER"] = "Behavior",

    ["MMBTNS_CONTEXT_LOCK"] = "Lock Position",
    ["MMBTNS_CONTEXT_REFRESH"] = "Refresh Buttons",

    ["MMBTNS_1X1_WARNING"] = "Cannot set 1x1 layout with multiple buttons. Max rows reset to unlimited.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "Turning off the Minimap Button Collector leaves LibDBIcon and other minimap hooks in a bad state until the UI reloads (icons may not drag on a square map, and re-enabling may not show the container).\n\nReload the interface now to restore normal minimap buttons?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "Reload UI",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "Reload later with |cFFFFD100/reload|r to fully restore minimap buttons.",
})

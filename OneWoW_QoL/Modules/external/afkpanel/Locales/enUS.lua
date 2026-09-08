local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AFKPANEL_TITLE"] = "AFK Panel",
    ["AFKPANEL_DESC"] = "Full-screen AFK overlay with the same Character Card and Zone Card as the ESC menu, plus an Info card for alerts, reset timers, professions, and more. Optional dock background.",
    ["AFKPANEL_CAMERA_SPIN"] = "Camera Spin",
    ["AFKPANEL_SHOW_DOCK"] = "Show dock background",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Show the gold bar behind the AFK cards. Turn this off to float the cards on your character.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - AFK Mode",
})

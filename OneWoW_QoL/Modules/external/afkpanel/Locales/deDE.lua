local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AFKPANEL_TITLE"] = "AFK-Panel",
    ["AFKPANEL_DESC"] = "Vollbild-AFK-Overlay mit derselben Charakterkarte und Zonenkarte wie das ESC-Menue, plus einer Infokarte fuer Hinweise, Reset-Timer, Berufe und mehr. Optionaler Dock-Hintergrund.",
    ["AFKPANEL_CAMERA_SPIN"] = "Kameradrehung",
    ["AFKPANEL_SHOW_DOCK"] = "Dock-Hintergrund anzeigen",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Die goldene Leiste hinter den AFK-Karten anzeigen. Ausschalten, damit die Karten ueber dem Charakter schweben.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - AFK-Modus",
})

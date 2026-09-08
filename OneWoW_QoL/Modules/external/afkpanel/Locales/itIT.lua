local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AFKPANEL_TITLE"] = "Pannello AFK",
    ["AFKPANEL_DESC"] = "Sovrapposizione AFK a schermo intero con le stesse scheda personaggio e scheda zona del menu ESC, piu una scheda Info per avvisi, timer di reset, professioni e altro. Sfondo del dock opzionale.",
    ["AFKPANEL_CAMERA_SPIN"] = "Rotazione della telecamera",
    ["AFKPANEL_SHOW_DOCK"] = "Mostra sfondo del dock",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Mostra la barra dorata dietro le schede AFK. Disattiva per far fluttuare le schede sul personaggio.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Modalità AFK",
})

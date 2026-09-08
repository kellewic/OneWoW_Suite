local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["AFKPANEL_TITLE"] = "Panel AFK",
    ["AFKPANEL_DESC"] = "Superposicion AFK a pantalla completa con las mismas carta de personaje y carta de zona que el menu ESC, mas una carta Info para alertas, temporizadores de reinicio, profesiones y mas. Fondo del muelle opcional.",
    ["AFKPANEL_CAMERA_SPIN"] = "Giro de cámara",
    ["AFKPANEL_SHOW_DOCK"] = "Mostrar fondo del muelle",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Muestra la barra dorada detras de las cartas AFK. Desactivalo para que las cartas floten sobre tu personaje.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Modo AFK",
})

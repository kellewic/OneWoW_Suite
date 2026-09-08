local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AFKPANEL_TITLE"] = "Panneau AFK",
    ["AFKPANEL_DESC"] = "Superposition AFK plein ecran avec les memes carte Personnage et carte Zone que le menu ECHAP, plus une carte Info pour les alertes, les timers de reset, les metiers et plus. Fond du dock optionnel.",
    ["AFKPANEL_CAMERA_SPIN"] = "Rotation de la caméra",
    ["AFKPANEL_SHOW_DOCK"] = "Afficher le fond du dock",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Afficher la barre doree derriere les cartes AFK. Desactivez pour faire flotter les cartes sur le personnage.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Mode AFK",
})

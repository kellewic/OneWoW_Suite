local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["MMBTNS_TITLE"] = "Collecteur de boutons de minicarte",
    ["MMBTNS_DESC"] = "Rassemble les boutons d'addons de la minicarte dans un seul conteneur thématisé. Utilise l'icône de marque OneWoW et prend en charge la disposition en grille, la fermeture automatique et une rangée de lancement rapide OneWoW améliorée.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r Collecteur de boutons",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "%d bouton(s) rassemblé(s)",
    ["MMBTNS_TOOLTIP_HINT"] = "Clic gauche pour afficher/masquer",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "Clic droit pour le menu",
    ["MMBTNS_TOOLTIP_DRAG"] = "Glisser pour déplacer",

    ["MMBTNS_CLOSE_MODE"] = "Comportement de fermeture",
    ["MMBTNS_STAY_OPEN"] = "Rester ouvert",
    ["MMBTNS_AUTO_CLOSE"] = "Fermeture automatique",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "Délai de fermeture automatique (secondes)",

    ["MMBTNS_ENHANCED_MENU"] = "Menu OneWoW amélioré",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "Ajoute une rangée supérieure d'icônes de lancement rapide OneWoW. Choisissez ci-dessous celles à afficher.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "Toutes les icônes OneWoW sont listées. Décochez celles que vous ne voulez pas sur cette rangée. Une icône n'apparaît que lorsque son addon est chargé.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "Style des icônes améliorées",
    ["MMBTNS_FEATURE_ICON_RING"] = "Avec anneau",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "Sans anneau",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "Anneau garde le cercle doré. Sans anneau n'affiche que le symbole. Accueil et Gérer les fonctionnalités utilisent le même choix.",

    ["MMBTNS_MAX_COLUMNS"] = "Colonnes max.",
    ["MMBTNS_MAX_ROWS"] = "Lignes max.",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = illimité. Ne peut pas être 1x1 s'il existe plusieurs boutons.",
    ["MMBTNS_BUTTON_SCALE"] = "Échelle des icônes rassemblées",
    ["MMBTNS_BUTTON_SPACING"] = "Espacement des boutons",

    ["MMBTNS_LOCK_POSITION"] = "Verrouiller la position",
    ["MMBTNS_GROW_LEFT"] = "Gauche",
    ["MMBTNS_GROW_RIGHT"] = "Droite",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "Afficher aussi sur la minicarte",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "Conserve les boutons rassemblés également sur la minicarte, affichés comme des copies cliquables dans le conteneur.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "Afficher les infobulles",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "Affiche les infobulles d'origine des addons en survolant les boutons dans le conteneur.",

    ["MMBTNS_ICONS_HEADER"] = "Icônes de minicarte",
    ["MMBTNS_ICONS_DESC"] = "Chaque icône de minicarte détectée est listée ci-dessous. Choisissez où chacune réside : Collecteur = dans le panneau OneWoW, Carte = de retour sur la minicarte, Masquer = entièrement retirée de la vue. Le X retire une entrée obsolète (activé uniquement lorsque l'addon propriétaire est désactivé). Votre choix est mémorisé d'un rechargement à l'autre et lors des cycles d'activation/désactivation d'addons.",
    ["MMBTNS_ICONS_EMPTY"] = "Aucune icône de minicarte détectée pour l'instant. Ouvrez le collecteur une fois pour qu'il puisse analyser, puis rouvrez les paramètres.",
    ["MMBTNS_ICONS_MINI"] = "Collecteur",
    ["MMBTNS_ICONS_MAP"] = "Carte",
    ["MMBTNS_ICONS_ENABLED"] = "Activé",
    ["MMBTNS_ICONS_DISABLED"] = "Désactivé",
    ["MMBTNS_ICONS_REMOVE_TT"] = "Retirer cette entrée de la liste",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "Cet addon est actuellement chargé. Basculez son icône sur Masquer si vous ne voulez pas la voir ; vous ne pouvez retirer l'entrée qu'une fois l'addon désactivé ou désinstallé.",

    ["MMBTNS_SETTINGS_HEADER"] = "Paramètres du collecteur",
    ["MMBTNS_LAYOUT_HEADER"] = "Disposition",
    ["MMBTNS_BEHAVIOR_HEADER"] = "Comportement",

    ["MMBTNS_CONTEXT_LOCK"] = "Verrouiller la position",
    ["MMBTNS_CONTEXT_REFRESH"] = "Actualiser les boutons",

    ["MMBTNS_1X1_WARNING"] = "Impossible de définir une disposition 1x1 avec plusieurs boutons. Lignes max. réinitialisées à illimité.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "Désactiver le Collecteur de boutons de minicarte laisse LibDBIcon et d'autres accroches de minicarte dans un mauvais état jusqu'au rechargement de l'interface (les icônes peuvent ne pas se déplacer sur une carte carrée, et la réactivation peut ne pas afficher le conteneur).\n\nRecharger l'interface maintenant pour restaurer les boutons de minicarte normaux ?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "Recharger l'UI",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "Rechargez plus tard avec |cFFFFD100/reload|r pour restaurer entièrement les boutons de minicarte.",
})

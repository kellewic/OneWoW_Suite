local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["ESCPANEL_TITLE"] = "Panneau du menu ECHAP",
    ["ESCPANEL_DESC"] = "Ajoute une carte Personnage, une carte Zone et une bande de portails a cote du menu ECHAP. La carte Personnage montre le personnage, le courrier, la Durabilite, les alertes d'encheres, La grande chambre forte, le Comptoir et les Initiatives. La carte Zone montre les collections de ce lieu et les icones Alerte objet pour Shopping List, Notes, Trackers et Farming. Survolez une icone pour les details ; cliquez pour ouvrir cette fenetre. Cliquez la carte Personnage pour l'ecran du personnage, ou la carte Zone pour ouvrir ce lieu dans le Catalogue.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Carte Personnage",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "Portrait, courrier, Durabilite, alertes d'encheres, La grande chambre forte, Comptoir et Initiatives. Survolez le courrier, la Durabilite ou le panier pour les details ; cliquez pour ouvrir cette fenetre.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "Carte Zone",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "Collections de ce lieu et icones Alerte objet. Survolez une icone pour la liste ou la note ; cliquez pour ouvrir Shopping List, Notes, Trackers ou Farming.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portails",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "Pierres de foyer et menus de teleportation a cote du menu. D'autres options de portail sont dans l'onglet Portails.",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposition",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Cote des cartes",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Cote des portails",
    ["ESCPANEL_SIDE_LEFT"] = "A gauche du menu",
    ["ESCPANEL_SIDE_RIGHT"] = "A droite du menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Activez ou desactivez Carte Personnage, Carte Zone et Portails ci-dessus. Les images des deux cartes sont en dessous. Quand les cartes et les portails sont du meme cote, les portails se placent a l'exterieur (plus loin du menu) et les cartes a cote du menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Taille des icones de portail",
})

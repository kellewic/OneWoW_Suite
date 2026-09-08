local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["ESCPANEL_TITLE"] = "ESC-Menüpanel",
    ["ESCPANEL_DESC"] = "Fügt neben dem ESC-Menü eine Charakterkarte, eine Zonenkarte und eine Reisekarte hinzu. Ein optionales Suite-Design färbt das Spielmenü und fasst die Spalten in einem Panel zusammen. Die Charakterkarte zeigt Charakter, Post, Haltbarkeit, Auktionshinweise, Große Schatzkammer, Handelsposten und Unterfangen. Die Zonenkarte zeigt Sammlungen dieses Orts und Gegenstandsalarm-Symbole für Shopping List, Notizen, Trackers und Farming. Zeige auf ein Symbol für Details; klicke, um das Fenster zu öffnen. Klicke die Charakterkarte für den Charakterbildschirm oder die Zonenkarte, um den Ort im Katalog zu öffnen.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Charakterkarte",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "Porträt, Post, Haltbarkeit, Auktionshinweise, Große Schatzkammer, Handelsposten und Unterfangen. Zeige auf Post, Haltbarkeit oder den Wagen für Details; klicke, um das Fenster zu öffnen.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "Zonenkarte",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "Sammlungen dieses Orts und Gegenstandsalarm-Symbole. Zeige auf ein Symbol für die Liste oder Notiz; klicke, um Shopping List, Notizen, Trackers oder Farming zu öffnen.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portale",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "Ruhesteine und Teleport-Flyouts auf einer Reisekarte neben dem Menü. Weitere Portaloptionen findest du auf dem Portale-Tab.",
    ["ESCPANEL_TOGGLE_SKIN_MENU"] = "Suite-Design für das Spielmenü",
    ["ESCPANEL_TOGGLE_SKIN_MENU_DESC"] = "Färbt das Spielmenü im OneWoW-Design und fasst die Karten in einem Panel zusammen. Schalte das aus, wenn ElvUI, W2UI oder eine andere UI das Spielmenü bereits gestaltet.",
    ["ESCPANEL_LAYOUT_HEADER"] = "Anordnung",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Seite der Karten",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Seite der Portale",
    ["ESCPANEL_SIDE_LEFT"] = "Links vom Menü",
    ["ESCPANEL_SIDE_RIGHT"] = "Rechts vom Menü",
    ["ESCPANEL_LAYOUT_DESC"] = "Schalte Charakterkarte, Zonenkarte und Portale oben ein oder aus. Bilder der beiden Karten stehen darunter. Wenn Karten und Portale auf derselben Seite sind, stapeln sie sich in dieser Spalte (Karten über Reisen).",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Größe der Portalsymbole",
})

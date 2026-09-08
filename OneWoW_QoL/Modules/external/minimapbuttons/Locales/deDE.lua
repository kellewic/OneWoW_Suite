local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["MMBTNS_TITLE"] = "Minimap-Button-Sammler",
    ["MMBTNS_DESC"] = "Sammelt Addon-Buttons der Minikarte in einem einzigen themenbasierten Container. Verwendet das OneWoW-Markensymbol und unterstützt Rasteranordnung, automatisches Schließen und eine erweiterte OneWoW-Schnellstartzeile.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r Button-Sammler",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "%d Button(s) gesammelt",
    ["MMBTNS_TOOLTIP_HINT"] = "Linksklick zum Umschalten",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "Rechtsklick für Menü",
    ["MMBTNS_TOOLTIP_DRAG"] = "Ziehen zum Bewegen",

    ["MMBTNS_CLOSE_MODE"] = "Schließverhalten",
    ["MMBTNS_STAY_OPEN"] = "Offen bleiben",
    ["MMBTNS_AUTO_CLOSE"] = "Automatisch schließen",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "Verzögerung für Auto-Schließen (Sekunden)",

    ["MMBTNS_ENHANCED_MENU"] = "Erweitertes OneWoW-Menü",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "Fügt eine obere Zeile mit OneWoW-Schnellstart-Symbolen hinzu. Wähle darunter, welche angezeigt werden.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "Jedes OneWoW-Symbol ist aufgeführt. Deaktiviere alle, die du in dieser Zeile nicht willst. Ein Symbol erscheint nur, wenn sein Addon geladen ist.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "Stil der erweiterten Symbole",
    ["MMBTNS_FEATURE_ICON_RING"] = "Mit Ring",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "Ohne Ring",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "Ring behält den goldenen Kreis. Ohne Ring zeigt nur das Symbol. Startseite und Funktionen verwalten nutzen dieselbe Wahl.",

    ["MMBTNS_MAX_COLUMNS"] = "Max. Spalten",
    ["MMBTNS_MAX_ROWS"] = "Max. Zeilen",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = unbegrenzt. Kann nicht 1x1 sein, wenn mehrere Buttons vorhanden sind.",
    ["MMBTNS_BUTTON_SCALE"] = "Skalierung gesammelter Symbole",
    ["MMBTNS_BUTTON_SPACING"] = "Button-Abstand",

    ["MMBTNS_LOCK_POSITION"] = "Position sperren",
    ["MMBTNS_GROW_LEFT"] = "Links",
    ["MMBTNS_GROW_RIGHT"] = "Rechts",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "Auch auf Minikarte anzeigen",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "Behält gesammelte Buttons zusätzlich auf der Minikarte und zeigt sie als anklickbare Kopien im Sammler.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "Tooltips anzeigen",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "Zeigt die ursprünglichen Addon-Tooltips an, wenn du im Container über Buttons fährst.",

    ["MMBTNS_ICONS_HEADER"] = "Minikarten-Symbole",
    ["MMBTNS_ICONS_DESC"] = "Jedes erkannte Minikarten-Symbol ist unten aufgeführt. Wähle, wo jedes leben soll: Sammler = im OneWoW-Panel, Karte = zurück auf der Minikarte, Ausblenden = vollständig aus dem Blick entfernt. Das X entfernt einen veralteten Eintrag (nur aktiviert, wenn das zugehörige Addon deaktiviert ist). Deine Wahl wird über Neuladen und Addon-Aktivierungs-/Deaktivierungszyklen hinweg gespeichert.",
    ["MMBTNS_ICONS_EMPTY"] = "Noch keine Minikarten-Symbole erkannt. Öffne den Sammler einmal, damit er scannen kann, und öffne dann die Einstellungen erneut.",
    ["MMBTNS_ICONS_MINI"] = "Sammler",
    ["MMBTNS_ICONS_MAP"] = "Karte",
    ["MMBTNS_ICONS_ENABLED"] = "Aktiviert",
    ["MMBTNS_ICONS_DISABLED"] = "Deaktiviert",
    ["MMBTNS_ICONS_REMOVE_TT"] = "Diesen Eintrag aus der Liste entfernen",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "Dieses Addon ist derzeit geladen. Stelle sein Symbol auf „Ausblenden“, wenn du es nicht sehen möchtest; du kannst den Eintrag erst entfernen, sobald das Addon deaktiviert oder deinstalliert ist.",

    ["MMBTNS_SETTINGS_HEADER"] = "Sammler-Einstellungen",
    ["MMBTNS_LAYOUT_HEADER"] = "Anordnung",
    ["MMBTNS_BEHAVIOR_HEADER"] = "Verhalten",

    ["MMBTNS_CONTEXT_LOCK"] = "Position sperren",
    ["MMBTNS_CONTEXT_REFRESH"] = "Buttons aktualisieren",

    ["MMBTNS_1X1_WARNING"] = "1x1-Anordnung ist mit mehreren Buttons nicht möglich. Max. Zeilen auf unbegrenzt zurückgesetzt.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "Das Ausschalten des Minimap-Button-Sammlers lässt LibDBIcon und andere Minikarten-Hooks bis zum Neuladen der Benutzeroberfläche in einem fehlerhaften Zustand (Symbole lassen sich auf einer quadratischen Karte evtl. nicht ziehen, und das erneute Aktivieren zeigt den Container evtl. nicht).\n\nDie Benutzeroberfläche jetzt neu laden, um normale Minikarten-Buttons wiederherzustellen?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "UI neu laden",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "Lade später mit |cFFFFD100/reload|r neu, um die Minikarten-Buttons vollständig wiederherzustellen.",
})

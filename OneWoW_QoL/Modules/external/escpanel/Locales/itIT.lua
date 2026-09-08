local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT, pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["ESCPANEL_TITLE"] = "Pannello del menu ESC",
    ["ESCPANEL_DESC"] = "Aggiunge una scheda personaggio, una scheda zona e una scheda Viaggio accanto al menu ESC. Un tema Suite opzionale dipinge il menu di gioco e unisce le colonne in un pannello. La scheda personaggio mostra il personaggio, la posta, la durabilita, gli avvisi d'asta, la Gran Camera, il Bazar e le Iniziative. La scheda zona mostra le collezioni di questo luogo e le icone Avviso oggetto per Shopping List, note, Trackers e Farming. Passa il mouse su un'icona per i dettagli; clicca per aprire quella finestra. Clicca la scheda personaggio per lo schermo del personaggio, o la scheda zona per aprire questo luogo nel Catalogo.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Scheda personaggio",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "Ritratto, posta, durabilita, avvisi d'asta, Gran Camera, Bazar e Iniziative. Passa il mouse su posta, durabilita o carrello per i dettagli; clicca per aprire quella finestra.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "Scheda zona",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "Collezioni di questo luogo e icone Avviso oggetto. Passa il mouse su un'icona per l'elenco o la nota; clicca per aprire Shopping List, note, Trackers o Farming.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portali",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "Pietre del ritorno e menu di teletrasporto su una scheda Viaggio accanto al menu. Altre opzioni dei portali sono nella scheda Portali.",
    ["ESCPANEL_TOGGLE_SKIN_MENU"] = "Tema Suite sul menu di gioco",
    ["ESCPANEL_TOGGLE_SKIN_MENU_DESC"] = "Dipinge il menu di gioco con il tema OneWoW e unisce le schede in un pannello. Disattivalo se ElvUI, W2UI o un'altra IU vestono gia il menu di gioco.",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposizione",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Lato delle schede",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Lato dei portali",
    ["ESCPANEL_SIDE_LEFT"] = "A sinistra del menu",
    ["ESCPANEL_SIDE_RIGHT"] = "A destra del menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Attiva o disattiva Scheda personaggio, Scheda zona e Portali qui sopra. Le immagini delle due schede sono sotto. Se schede e portali sono dallo stesso lato, si impilano in quella colonna (schede sopra Viaggio).",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Dimensione icone portale",
})

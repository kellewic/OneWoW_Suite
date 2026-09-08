local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["MMBTNS_TITLE"] = "Raccoglitore di pulsanti della minimappa",
    ["MMBTNS_DESC"] = "Raccoglie i pulsanti degli addon della minimappa in un unico contenitore a tema. Usa l'icona del marchio OneWoW e supporta la disposizione a griglia, la chiusura automatica e una riga di avvio rapido OneWoW migliorata.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r Raccoglitore di pulsanti",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "%d pulsante/i raccolto/i",
    ["MMBTNS_TOOLTIP_HINT"] = "Clic sinistro per attivare/disattivare",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "Clic destro per il menu",
    ["MMBTNS_TOOLTIP_DRAG"] = "Trascina per spostare",

    ["MMBTNS_CLOSE_MODE"] = "Comportamento di chiusura",
    ["MMBTNS_STAY_OPEN"] = "Resta aperto",
    ["MMBTNS_AUTO_CLOSE"] = "Chiusura automatica",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "Ritardo di chiusura automatica (secondi)",

    ["MMBTNS_ENHANCED_MENU"] = "Menu OneWoW migliorato",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "Aggiunge una riga superiore di icone di avvio rapido OneWoW. Scegli sotto quali mostrare.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "Sono elencate tutte le icone OneWoW. Deseleziona quelle che non vuoi in quella riga. Un'icona appare solo quando il suo addon e caricato.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "Stile icone avanzate",
    ["MMBTNS_FEATURE_ICON_RING"] = "Con anello",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "Senza anello",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "Anello mantiene il cerchio dorato. Senza anello mostra solo il simbolo. Home e Gestisci funzioni usano la stessa scelta.",

    ["MMBTNS_MAX_COLUMNS"] = "Colonne max.",
    ["MMBTNS_MAX_ROWS"] = "Righe max.",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = illimitato. Non può essere 1x1 se esistono più pulsanti.",
    ["MMBTNS_BUTTON_SCALE"] = "Scala delle icone raccolte",
    ["MMBTNS_BUTTON_SPACING"] = "Spaziatura dei pulsanti",

    ["MMBTNS_LOCK_POSITION"] = "Blocca posizione",
    ["MMBTNS_GROW_LEFT"] = "Sinistra",
    ["MMBTNS_GROW_RIGHT"] = "Destra",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "Mostra anche sulla minimappa",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "Mantiene i pulsanti raccolti anche sulla minimappa, mostrati come copie cliccabili nel contenitore.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "Mostra descrizioni",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "Mostra le descrizioni originali degli addon passando il cursore sui pulsanti nel contenitore.",

    ["MMBTNS_ICONS_HEADER"] = "Icone della minimappa",
    ["MMBTNS_ICONS_DESC"] = "Ogni icona della minimappa rilevata è elencata qui sotto. Scegli dove vive ciascuna: Raccoglitore = nel pannello OneWoW, Mappa = di nuovo sulla minimappa, Nascondi = rimossa completamente dalla vista. La X rimuove una voce obsoleta (attiva solo quando l'addon proprietario è disattivato). La tua scelta viene ricordata tra i ricaricamenti e i cicli di attivazione/disattivazione degli addon.",
    ["MMBTNS_ICONS_EMPTY"] = "Nessuna icona della minimappa rilevata finora. Apri il raccoglitore una volta affinché possa eseguire la scansione, poi riapri le impostazioni.",
    ["MMBTNS_ICONS_MINI"] = "Raccoglitore",
    ["MMBTNS_ICONS_MAP"] = "Mappa",
    ["MMBTNS_ICONS_ENABLED"] = "Attivato",
    ["MMBTNS_ICONS_DISABLED"] = "Disattivato",
    ["MMBTNS_ICONS_REMOVE_TT"] = "Rimuovi questa voce dalla lista",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "Questo addon è attualmente caricato. Imposta la sua icona su Nascondi se non vuoi vederla; puoi rimuovere la voce solo quando l'addon è disattivato o disinstallato.",

    ["MMBTNS_SETTINGS_HEADER"] = "Impostazioni del raccoglitore",
    ["MMBTNS_LAYOUT_HEADER"] = "Disposizione",
    ["MMBTNS_BEHAVIOR_HEADER"] = "Comportamento",

    ["MMBTNS_CONTEXT_LOCK"] = "Blocca posizione",
    ["MMBTNS_CONTEXT_REFRESH"] = "Aggiorna pulsanti",

    ["MMBTNS_1X1_WARNING"] = "Impossibile impostare la disposizione 1x1 con più pulsanti. Righe max. reimpostate su illimitato.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "Disattivare il Raccoglitore di pulsanti della minimappa lascia LibDBIcon e altri hook della minimappa in uno stato errato fino al ricaricamento dell'interfaccia (le icone potrebbero non trascinarsi su una mappa quadrata e la riattivazione potrebbe non mostrare il contenitore).\n\nRicaricare ora l'interfaccia per ripristinare i normali pulsanti della minimappa?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "Ricarica IU",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "Ricarica più tardi con |cFFFFD100/reload|r per ripristinare completamente i pulsanti della minimappa.",
})

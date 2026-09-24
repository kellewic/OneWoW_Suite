local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["QUESTTOOLS_TITLE"] = "Strumenti missione",
    ["QUESTTOOLS_DESC"] = "Automatizza l'accettazione delle missioni, la consegna, l'evidenziazione della ricompensa e il dialogo etichettato come missione opzionale. Automazione missioni sceglie il modificatore e se tenerlo premuto salta quelle azioni o è richiesto prima che vengano eseguite.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Accetta missioni automaticamente",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Accetta automaticamente le missioni quando appare la finestra della missione. Automazione missioni sceglie il modificatore e se tenerlo premuto salta l'auto-accettazione o è richiesto prima.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Consegna missioni automaticamente",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Completa e consegna automaticamente le missioni quando hai soddisfatto tutti i requisiti. Se sono disponibili più ricompense, attende la tua scelta.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Evidenzia la ricompensa migliore",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Mostra un'icona a forma di moneta d'oro sull'oggetto ricompensa della missione con il valore di vendita più alto dal venditore.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-dialogo (righe etichettate come missione)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Seleziona automaticamente le opzioni di dialogo contrassegnate come etichettate di missione (QuestLabelPrepend), cioè le stesse righe che l'interfaccia mostra con l'etichetta in stile missione. Se più di una è idonea, usa il testo visibile della riga per decidere. Automazione missioni sceglie il modificatore e se tenerlo premuto salta l'auto-dialogo o è richiesto prima. Richiede il supporto di C_GossipInfo e QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) sul tuo client.",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "Automazione missioni",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "Richiedi il modificatore per automatizzare",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "Se attivo, auto-accettazione, consegna e dialogo missione vengono eseguiti solo mentre tieni premuto il modificatore. Se disattivo, vengono eseguiti a meno che tu non tenga premuto il modificatore.",
    ["QUESTTOOLS_MODIFIER_KEY"] = "Modificatore",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "Il tasto controllato da Automazione missioni. Maiusc, Ctrl o Alt.",
})

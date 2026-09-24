local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["QUESTTOOLS_TITLE"] = "Quest-Werkzeuge",
    ["QUESTTOOLS_DESC"] = "Automatisiert Questannahme, Abgabe, Belohnungshervorhebung und optionales quest-markiertes Gespräch. Quest-Automatisierung legt die Modifikatortaste fest und ob sie diese Aktionen überspringt oder vorher gehalten werden muss.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Quests automatisch annehmen",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Nimmt Quests automatisch an, wenn der Questdialog erscheint. Quest-Automatisierung legt die Modifikatortaste fest und ob sie die Auto-Annahme überspringt oder vorher gehalten werden muss.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Quests automatisch abgeben",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Schließt Quests automatisch ab und gibt sie ab, wenn du alle Anforderungen erfüllt hast. Wenn mehrere Belohnungen verfügbar sind, wartet es auf deine Wahl.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Beste Belohnung hervorheben",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Zeigt ein Goldmünzensymbol auf dem Questbelohnungsgegenstand mit dem höchsten Händlerverkaufswert.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-Gespräch (quest-markierte Zeilen)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Wählt automatisch Gesprächsoptionen aus, die als quest-markiert (QuestLabelPrepend) gekennzeichnet sind, also dieselben Zeilen, die die UI mit dem questartigen Label anzeigt. Wenn mehr als eine infrage kommt, wird anhand des sichtbaren Zeilentexts entschieden. Quest-Automatisierung legt die Modifikatortaste fest und ob sie das Auto-Gespräch überspringt oder vorher gehalten werden muss. Erfordert Unterstützung für C_GossipInfo und QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) auf deinem Client.",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "Quest-Automatisierung",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "Modifikator zum Automatisieren verlangen",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "Wenn aktiv, laufen Auto-Annahme, Abgabe und Quest-Gespräch nur, solange der Modifikator gehalten wird. Wenn inaktiv, laufen sie, sofern du den Modifikator nicht hältst.",
    ["QUESTTOOLS_MODIFIER_KEY"] = "Modifikator",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "Die Taste, die Quest-Automatisierung prüft. Umschalt, Strg oder Alt.",
})

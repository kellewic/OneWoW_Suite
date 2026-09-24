local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["QUESTTOOLS_TITLE"] = "Outils de quête",
    ["QUESTTOOLS_DESC"] = "Automatise l'acceptation des quêtes, le rendu, la mise en évidence des récompenses et le dialogue libellé quête en option. Automatisation des quêtes choisit le modificateur et s'il ignore ces actions ou doit être maintenu avant qu'elles s'exécutent.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Accepter les quêtes automatiquement",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Accepte automatiquement les quêtes lorsque le dialogue de quête apparaît. Automatisation des quêtes choisit le modificateur et s'il ignore l'auto-acceptation ou doit être maintenu d'abord.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Rendre les quêtes automatiquement",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Termine et rend automatiquement les quêtes lorsque vous avez rempli toutes les conditions. Si plusieurs récompenses sont disponibles, il attend votre choix.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Mettre en évidence la meilleure récompense",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Affiche une icône de pièce d'or sur l'objet de récompense de quête ayant la plus haute valeur de vente chez le marchand.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-dialogue (lignes libellées quête)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Sélectionne automatiquement les options de dialogue marquées comme libellées quête (QuestLabelPrepend), c.-à-d. les mêmes lignes que l'interface affiche avec le label de style quête. Si plusieurs conviennent, utilise le texte visible de la ligne pour décider. Automatisation des quêtes choisit le modificateur et s'il ignore l'auto-dialogue ou doit être maintenu d'abord. Nécessite la prise en charge de C_GossipInfo et QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) sur votre client.",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "Automatisation des quêtes",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "Exiger le modificateur pour automatiser",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "Si activé, l'auto-acceptation, le rendu et le dialogue de quête ne s'exécutent que tant que le modificateur est maintenu. Sinon, ils s'exécutent sauf si vous maintenez le modificateur.",
    ["QUESTTOOLS_MODIFIER_KEY"] = "Modificateur",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "La touche vérifiée par Automatisation des quêtes. Maj, Ctrl ou Alt.",
})

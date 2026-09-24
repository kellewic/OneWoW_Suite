local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["QUESTTOOLS_TITLE"] = "Quest Tools",
    ["QUESTTOOLS_DESC"] = "Automates quest acceptance, turn-in, reward highlight, and optional quest-labeled gossip. Quest Automation sets the modifier and whether holding it skips those actions or is required before they run.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Auto Accept Quests",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Automatically accept quests when the quest dialog appears. Quest Automation sets the modifier and whether holding it skips auto-accept or is required first.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Auto Turn In Quests",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Automatically complete and turn in quests when you have met all requirements. If multiple rewards are available, it waits for you to choose.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Highlight Best Reward",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Shows a gold coin icon on the quest reward item with the highest vendor sell value.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto Gossip (quest-labeled lines)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Automatically selects gossip options flagged as quest-labeled (QuestLabelPrepend), i.e. the same lines the UI shows with the quest-style label. If more than one qualifies, uses visible line text to decide. Quest Automation sets the modifier and whether holding it skips auto-gossip or is required first. Requires C_GossipInfo and QuestLabelPrepend support (FlagsUtil / Enum.GossipOptionRecFlags) on your client.",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "Quest Automation",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "Require modifier to automate",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "When on, auto-accept, turn-in, and quest gossip run only while the modifier is held. When off, they run unless you hold the modifier.",
    ["QUESTTOOLS_MODIFIER_KEY"] = "Modifier",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "The key Quest Automation checks. Shift, Ctrl, or Alt.",
})

local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["QUESTTOOLS_TITLE"] = "任务工具",
    ["QUESTTOOLS_DESC"] = "自动完成任务接受、交付、奖励高亮以及可选的任务标记对话。任务自动化设定修饰键，以及按住该键是跳过这些操作，还是必须先按住才会执行。",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "自动接受任务",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "当任务对话框出现时自动接受任务。任务自动化设定修饰键，以及按住该键是跳过自动接受，还是必须先按住。",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "自动交付任务",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "当你满足所有要求时自动完成并交付任务。如果有多个奖励可选，则等待你选择。",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "高亮最佳奖励",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "在商人售价最高的任务奖励物品上显示一个金币图标。",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "自动对话（任务标记行）",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "自动选择被标记为任务标签（QuestLabelPrepend）的对话选项，即界面以任务样式标签显示的相同行。如果有多项符合，则根据可见的行文本来决定。任务自动化设定修饰键，以及按住该键是跳过自动对话，还是必须先按住。需要你的客户端支持 C_GossipInfo 和 QuestLabelPrepend（FlagsUtil / Enum.GossipOptionRecFlags）。",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "任务自动化",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "需要修饰键才自动化",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "开启后，自动接受、交付和任务对话仅在按住修饰键时执行。关闭后，除非按住修饰键，否则会执行。",
    ["QUESTTOOLS_MODIFIER_KEY"] = "修饰键",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "任务自动化检查的按键。Shift、Ctrl 或 Alt。",
})

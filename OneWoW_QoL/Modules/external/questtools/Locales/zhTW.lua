local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["QUESTTOOLS_TITLE"] = "任務工具",
    ["QUESTTOOLS_DESC"] = "自動完成任務接受、繳交、獎勵突顯以及可選的任務標記對話。任務自動化設定修飾鍵，以及按住該鍵是跳過這些操作，還是必須先按住才會執行。",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "自動接受任務",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "當任務對話框出現時自動接受任務。任務自動化設定修飾鍵，以及按住該鍵是跳過自動接受，還是必須先按住。",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "自動繳交任務",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "當你滿足所有要求時自動完成並繳交任務。如果有多個獎勵可選，則等待你選擇。",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "突顯最佳獎勵",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "在商人售價最高的任務獎勵物品上顯示一個金幣圖示。",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "自動對話（任務標記行）",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "自動選擇被標記為任務標籤（QuestLabelPrepend）的對話選項，即介面以任務樣式標籤顯示的相同行。如果有多項符合，則根據可見的行文字來決定。任務自動化設定修飾鍵，以及按住該鍵是跳過自動對話，還是必須先按住。需要你的客戶端支援 C_GossipInfo 和 QuestLabelPrepend（FlagsUtil / Enum.GossipOptionRecFlags）。",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "任務自動化",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "需要修飾鍵才自動化",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "開啟後，自動接受、繳交和任務對話僅在按住修飾鍵時執行。關閉後，除非按住修飾鍵，否則會執行。",
    ["QUESTTOOLS_MODIFIER_KEY"] = "修飾鍵",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "任務自動化檢查的按鍵。Shift、Ctrl 或 Alt。",
})

local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["MMBTNS_TITLE"] = "小地圖按鈕收集器",
    ["MMBTNS_DESC"] = "將小地圖插件按鈕收集到一個帶佈景主題的容器中。使用 OneWoW 品牌圖示，支援格狀佈局、自動關閉以及增強的 OneWoW 快速啟動列。",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r 按鈕收集器",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "已收集 %d 個按鈕",
    ["MMBTNS_TOOLTIP_HINT"] = "左鍵點擊以切換",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "右鍵點擊開啟選單",
    ["MMBTNS_TOOLTIP_DRAG"] = "拖曳以移動",

    ["MMBTNS_CLOSE_MODE"] = "關閉行為",
    ["MMBTNS_STAY_OPEN"] = "保持開啟",
    ["MMBTNS_AUTO_CLOSE"] = "自動關閉",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "自動關閉延遲（秒）",

    ["MMBTNS_ENHANCED_MENU"] = "增強的 OneWoW 選單",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "新增一列 OneWoW 快速啟動圖示。在下方選擇要顯示的圖示。",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "列出全部 OneWoW 圖示。取消勾選你不想出現在該列的圖示。僅在對應插件已載入時顯示。",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "增強圖示樣式",
    ["MMBTNS_FEATURE_ICON_RING"] = "帶圓環",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "無圓環",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "圓環保留金色外圈。無圓環只顯示中間的符號。首頁和管理功能使用同一選擇。",

    ["MMBTNS_MAX_COLUMNS"] = "最大欄數",
    ["MMBTNS_MAX_ROWS"] = "最大列數",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = 無限制。當存在多個按鈕時不能為 1x1。",
    ["MMBTNS_BUTTON_SCALE"] = "收集圖示縮放",
    ["MMBTNS_BUTTON_SPACING"] = "按鈕間距",

    ["MMBTNS_LOCK_POSITION"] = "鎖定位置",
    ["MMBTNS_GROW_LEFT"] = "左",
    ["MMBTNS_GROW_RIGHT"] = "右",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "同時顯示在小地圖上",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "在收集器中以可點擊的副本顯示已收集的按鈕，同時將其保留在小地圖上。",
    ["MMBTNS_SHOW_TOOLTIPS"] = "顯示提示資訊",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "將滑鼠游標停在容器中的按鈕上時顯示原始插件的提示資訊。",

    ["MMBTNS_ICONS_HEADER"] = "小地圖圖示",
    ["MMBTNS_ICONS_DESC"] = "偵測到的每個小地圖圖示都列在下方。請選擇每個圖示的歸屬：收集器 = 在 OneWoW 面板內，地圖 = 回到小地圖，隱藏 = 完全從視野中移除。X 用於移除過時項目（僅在所屬插件被停用後可用）。你的選擇會在重新載入以及插件啟用/停用週期間保留。",
    ["MMBTNS_ICONS_EMPTY"] = "尚未偵測到小地圖圖示。先開啟一次收集器讓它掃描，然後重新開啟設定。",
    ["MMBTNS_ICONS_MINI"] = "收集器",
    ["MMBTNS_ICONS_MAP"] = "地圖",
    ["MMBTNS_ICONS_ENABLED"] = "已啟用",
    ["MMBTNS_ICONS_DISABLED"] = "已停用",
    ["MMBTNS_ICONS_REMOVE_TT"] = "從清單中移除此項目",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "此插件目前已載入。如果你不想看到它，請將其圖示切換為隱藏；只有在插件被停用或解除安裝後才能移除該項目。",

    ["MMBTNS_SETTINGS_HEADER"] = "收集器設定",
    ["MMBTNS_LAYOUT_HEADER"] = "佈局",
    ["MMBTNS_BEHAVIOR_HEADER"] = "行為",

    ["MMBTNS_CONTEXT_LOCK"] = "鎖定位置",
    ["MMBTNS_CONTEXT_REFRESH"] = "重新整理按鈕",

    ["MMBTNS_1X1_WARNING"] = "存在多個按鈕時無法設定 1x1 佈局。最大列數已重設為無限制。",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "關閉小地圖按鈕收集器會使 LibDBIcon 和其他小地圖掛勾在介面重新載入前處於異常狀態（在方形地圖上圖示可能無法拖曳，重新啟用時可能不顯示容器）。\n\n現在重新載入介面以恢復正常的小地圖按鈕嗎？",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "重新載入介面",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "稍後用 |cFFFFD100/reload|r 重新載入以完全恢復小地圖按鈕。",
})

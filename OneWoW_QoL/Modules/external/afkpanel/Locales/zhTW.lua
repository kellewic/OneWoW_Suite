local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW, pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AFKPANEL_TITLE"] = "暫離面板",
    ["AFKPANEL_DESC"] = "全螢幕暫離覆蓋層，使用與 ESC 選單相同的角色卡片和區域卡片，外加資訊卡片（提醒、重置計時、專業等）。底部欄背景可選。",
    ["AFKPANEL_CAMERA_SPIN"] = "鏡頭旋轉",
    ["AFKPANEL_SHOW_DOCK"] = "顯示底部欄背景",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "在暫離卡片後面顯示金色底欄。關閉後卡片會浮在角色模型上。",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - 暫離模式",
})

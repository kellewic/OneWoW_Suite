local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW, pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["ESCPANEL_TITLE"] = "ESC 選單面板",
    ["ESCPANEL_DESC"] = "在 ESC 選單旁加入角色卡片、區域卡片和傳送門列。角色卡片顯示角色、郵件、耐久度、拍賣提醒、寶庫、貿易站和住宅事務。區域卡片顯示此地的收藏，以及購物清單、筆記、追蹤器和採集的物品提醒圖示。將滑鼠移到圖示上可查看詳情，點擊即可開啟對應視窗。點擊角色卡片開啟角色畫面，點擊區域卡片在目錄中開啟此地。",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "角色卡片",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "頭像、郵件、耐久度、拍賣提醒、寶庫、貿易站和住宅事務。將滑鼠移到郵件、耐久度或購物車上可查看詳情，點擊即可開啟對應視窗。",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "區域卡片",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "此地的收藏和物品提醒圖示。將滑鼠移到圖示上可查看清單或筆記，點擊即可開啟購物清單、筆記、追蹤器或採集。",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "傳送門",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "選單旁的爐石和傳送彈出選單。更多傳送門選項在傳送門分頁。",
    ["ESCPANEL_LAYOUT_HEADER"] = "配置",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "卡片一側",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "傳送門一側",
    ["ESCPANEL_SIDE_LEFT"] = "選單左側",
    ["ESCPANEL_SIDE_RIGHT"] = "選單右側",
    ["ESCPANEL_LAYOUT_DESC"] = "在上方開關角色卡片、區域卡片和傳送門。兩張卡片的圖片在下方。卡片和傳送門在同一側時，傳送門在外側（離選單較遠），卡片緊鄰選單。",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "傳送門圖示大小",
})

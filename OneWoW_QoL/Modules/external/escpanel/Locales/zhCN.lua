local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["ESCPANEL_TITLE"] = "ESC 菜单面板",
    ["ESCPANEL_DESC"] = "在 ESC 菜单旁加入角色卡片、地区卡片和传送门条。角色卡片显示角色、邮件、耐久度、拍卖提醒、宏伟宝库、商栈和社区事务。地区卡片显示此地的收藏以及购物清单、笔记、追踪器和采集的物品提醒图标。将鼠标悬停在图标上可查看详情，点击即可打开对应窗口。点击角色卡片打开角色界面，点击地区卡片在目录中打开此地。",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "角色卡片",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "头像、邮件、耐久度、拍卖提醒、宏伟宝库、商栈和社区事务。将鼠标悬停在邮件、耐久度或购物车上可查看详情，点击即可打开对应窗口。",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "地区卡片",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "此地的收藏和物品提醒图标。将鼠标悬停在图标上可查看列表或笔记，点击即可打开购物清单、笔记、追踪器或采集。",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "传送门",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "菜单旁的炉石和传送弹出菜单。更多传送门选项在传送门标签页。",
    ["ESCPANEL_LAYOUT_HEADER"] = "布局",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "卡片一侧",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "传送门一侧",
    ["ESCPANEL_SIDE_LEFT"] = "菜单左侧",
    ["ESCPANEL_SIDE_RIGHT"] = "菜单右侧",
    ["ESCPANEL_LAYOUT_DESC"] = "在上方开关角色卡片、地区卡片和传送门。两张卡片的图片在下方。卡片和传送门在同一侧时，传送门在外侧（离菜单更远），卡片紧挨菜单。",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "传送门图标大小",
})

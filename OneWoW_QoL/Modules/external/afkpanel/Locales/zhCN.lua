local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AFKPANEL_TITLE"] = "暂离面板",
    ["AFKPANEL_DESC"] = "全屏暂离覆盖层，使用与 ESC 菜单相同的角色卡片和地区卡片，外加信息卡片（提醒、重置计时、专业等）。底部栏背景可选。",
    ["AFKPANEL_CAMERA_SPIN"] = "镜头旋转",
    ["AFKPANEL_SHOW_DOCK"] = "显示底部栏背景",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "在暂离卡片后面显示金色底栏。关闭后卡片会浮在角色模型上。",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - 暂离模式",
})

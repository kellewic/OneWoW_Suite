local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["MMBTNS_TITLE"] = "小地图按钮收集器",
    ["MMBTNS_DESC"] = "将小地图插件按钮收集到一个带主题的容器中。使用 OneWoW 品牌图标，支持网格布局、自动关闭以及增强的 OneWoW 快速启动栏。",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r 按钮收集器",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "已收集 %d 个按钮",
    ["MMBTNS_TOOLTIP_HINT"] = "左键点击以切换",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "右键点击打开菜单",
    ["MMBTNS_TOOLTIP_DRAG"] = "拖动以移动",

    ["MMBTNS_CLOSE_MODE"] = "关闭行为",
    ["MMBTNS_STAY_OPEN"] = "保持打开",
    ["MMBTNS_AUTO_CLOSE"] = "自动关闭",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "自动关闭延迟（秒）",

    ["MMBTNS_ENHANCED_MENU"] = "增强的 OneWoW 菜单",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "添加一行 OneWoW 快速启动图标。在下方选择要显示的图标。",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "列出全部 OneWoW 图标。取消勾选你不想出现在该行的图标。仅在对应插件已加载时显示。",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "增强图标样式",
    ["MMBTNS_FEATURE_ICON_RING"] = "带圆环",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "无圆环",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "圆环保留金色外圈。无圆环只显示中间的符号。主页和管理功能使用同一选择。",

    ["MMBTNS_MAX_COLUMNS"] = "最大列数",
    ["MMBTNS_MAX_ROWS"] = "最大行数",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = 无限制。当存在多个按钮时不能为 1x1。",
    ["MMBTNS_BUTTON_SCALE"] = "收集图标缩放",
    ["MMBTNS_BUTTON_SPACING"] = "按钮间距",

    ["MMBTNS_LOCK_POSITION"] = "锁定位置",
    ["MMBTNS_GROW_LEFT"] = "左",
    ["MMBTNS_GROW_RIGHT"] = "右",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "同时显示在小地图上",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "在收集器中以可点击的副本显示已收集的按钮，同时将其保留在小地图上。",
    ["MMBTNS_SHOW_TOOLTIPS"] = "显示工具提示",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "将鼠标悬停在容器中的按钮上时显示原始插件的工具提示。",

    ["MMBTNS_ICONS_HEADER"] = "小地图图标",
    ["MMBTNS_ICONS_DESC"] = "检测到的每个小地图图标都列在下方。请选择每个图标的归属：收集器 = 在 OneWoW 面板内，地图 = 回到小地图，隐藏 = 完全从视野中移除。X 用于移除过时条目（仅在所属插件被禁用后可用）。你的选择会在重载以及插件启用/禁用周期间保留。",
    ["MMBTNS_ICONS_EMPTY"] = "尚未检测到小地图图标。先打开一次收集器让它扫描，然后重新打开设置。",
    ["MMBTNS_ICONS_MINI"] = "收集器",
    ["MMBTNS_ICONS_MAP"] = "地图",
    ["MMBTNS_ICONS_ENABLED"] = "已启用",
    ["MMBTNS_ICONS_DISABLED"] = "已禁用",
    ["MMBTNS_ICONS_REMOVE_TT"] = "从列表中移除此条目",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "此插件当前已加载。如果你不想看到它，请将其图标切换为隐藏；只有在插件被禁用或卸载后才能移除该条目。",

    ["MMBTNS_SETTINGS_HEADER"] = "收集器设置",
    ["MMBTNS_LAYOUT_HEADER"] = "布局",
    ["MMBTNS_BEHAVIOR_HEADER"] = "行为",

    ["MMBTNS_CONTEXT_LOCK"] = "锁定位置",
    ["MMBTNS_CONTEXT_REFRESH"] = "刷新按钮",

    ["MMBTNS_1X1_WARNING"] = "存在多个按钮时无法设置 1x1 布局。最大行数已重置为无限制。",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "关闭小地图按钮收集器会使 LibDBIcon 和其他小地图挂钩在界面重载前处于异常状态（在方形地图上图标可能无法拖动，重新启用时可能不显示容器）。\n\n现在重载界面以恢复正常的小地图按钮吗？",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "重载界面",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "稍后用 |cFFFFD100/reload|r 重载以完全恢复小地图按钮。",
})

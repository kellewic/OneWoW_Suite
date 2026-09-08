local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AFKPANEL_TITLE"] = "Панель отошёл",
    ["AFKPANEL_DESC"] = "Полноэкранное наложение AFK с теми же карточкой персонажа и карточкой зоны, что и меню ESC, плюс карточка Инфо для оповещений, таймеров сброса, профессий и прочего. Фон панели по желанию.",
    ["AFKPANEL_CAMERA_SPIN"] = "Вращение камеры",
    ["AFKPANEL_SHOW_DOCK"] = "Показывать фон панели",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Показывать золотую полосу за карточками AFK. Выключите, чтобы карточки парили над персонажем.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Режим отошёл",
})

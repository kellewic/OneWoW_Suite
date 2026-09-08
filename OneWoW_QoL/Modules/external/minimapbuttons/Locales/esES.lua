local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["MMBTNS_TITLE"] = "Colector de botones del minimapa",
    ["MMBTNS_DESC"] = "Reúne los botones de addons del minimapa en un único contenedor con tema. Usa el icono de marca OneWoW y admite disposición en cuadrícula, cierre automático y una fila de inicio rápido de OneWoW mejorada.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r Colector de botones",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "%d botón(es) reunido(s)",
    ["MMBTNS_TOOLTIP_HINT"] = "Clic izquierdo para alternar",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "Clic derecho para el menú",
    ["MMBTNS_TOOLTIP_DRAG"] = "Arrastra para mover",

    ["MMBTNS_CLOSE_MODE"] = "Comportamiento de cierre",
    ["MMBTNS_STAY_OPEN"] = "Permanecer abierto",
    ["MMBTNS_AUTO_CLOSE"] = "Cierre automático",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "Retardo de cierre automático (segundos)",

    ["MMBTNS_ENHANCED_MENU"] = "Menú OneWoW mejorado",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "Añade una fila superior de iconos de inicio rápido de OneWoW. Elige abajo cuáles mostrar.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "Están todos los iconos de OneWoW. Desmarca los que no quieras en esa fila. Un icono solo aparece cuando su addon está cargado.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "Estilo de iconos mejorados",
    ["MMBTNS_FEATURE_ICON_RING"] = "Con anillo",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "Sin anillo",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "Anillo mantiene el circulo dorado. Sin anillo muestra solo el simbolo. Inicio y Administrar funciones usan la misma eleccion.",

    ["MMBTNS_MAX_COLUMNS"] = "Columnas máx.",
    ["MMBTNS_MAX_ROWS"] = "Filas máx.",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = ilimitado. No puede ser 1x1 si existen varios botones.",
    ["MMBTNS_BUTTON_SCALE"] = "Escala de iconos reunidos",
    ["MMBTNS_BUTTON_SPACING"] = "Espaciado de botones",

    ["MMBTNS_LOCK_POSITION"] = "Bloquear posición",
    ["MMBTNS_GROW_LEFT"] = "Izquierda",
    ["MMBTNS_GROW_RIGHT"] = "Derecha",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "Mostrar también en el minimapa",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "Mantiene los botones reunidos también en el minimapa, mostrados como copias en las que se puede hacer clic dentro del colector.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "Mostrar información",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "Muestra la información original de los addons al pasar el cursor por los botones del contenedor.",

    ["MMBTNS_ICONS_HEADER"] = "Iconos del minimapa",
    ["MMBTNS_ICONS_DESC"] = "Cada icono del minimapa detectado aparece a continuación. Elige dónde vive cada uno: Colector = dentro del panel OneWoW, Mapa = de vuelta en el minimapa, Ocultar = retirado por completo de la vista. La X quita una entrada obsoleta (solo se activa cuando el addon propietario está desactivado). Tu elección se recuerda entre recargas y ciclos de activación/desactivación de addons.",
    ["MMBTNS_ICONS_EMPTY"] = "Aún no se han detectado iconos del minimapa. Abre el colector una vez para que pueda escanear y luego vuelve a abrir los ajustes.",
    ["MMBTNS_ICONS_MINI"] = "Colector",
    ["MMBTNS_ICONS_MAP"] = "Mapa",
    ["MMBTNS_ICONS_ENABLED"] = "Activado",
    ["MMBTNS_ICONS_DISABLED"] = "Desactivado",
    ["MMBTNS_ICONS_REMOVE_TT"] = "Quitar esta entrada de la lista",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "Este addon está cargado actualmente. Cambia su icono a Ocultar si no quieres verlo; solo puedes quitar la entrada una vez que el addon esté desactivado o desinstalado.",

    ["MMBTNS_SETTINGS_HEADER"] = "Ajustes del colector",
    ["MMBTNS_LAYOUT_HEADER"] = "Disposición",
    ["MMBTNS_BEHAVIOR_HEADER"] = "Comportamiento",

    ["MMBTNS_CONTEXT_LOCK"] = "Bloquear posición",
    ["MMBTNS_CONTEXT_REFRESH"] = "Actualizar botones",

    ["MMBTNS_1X1_WARNING"] = "No se puede establecer una disposición 1x1 con varios botones. Filas máx. restablecidas a ilimitado.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "Desactivar el Colector de botones del minimapa deja LibDBIcon y otros enganches del minimapa en mal estado hasta que se recargue la interfaz (los iconos pueden no arrastrarse en un mapa cuadrado, y reactivarlo puede no mostrar el contenedor).\n\n¿Recargar la interfaz ahora para restaurar los botones normales del minimapa?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "Recargar IU",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "Recarga más tarde con |cFFFFD100/reload|r para restaurar por completo los botones del minimapa.",
})

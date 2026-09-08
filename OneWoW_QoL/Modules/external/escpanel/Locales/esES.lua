local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["ESCPANEL_TITLE"] = "Panel del menu ESC",
    ["ESCPANEL_DESC"] = "Anade una carta de personaje, una carta de zona y una carta de viaje junto al menu ESC. Un tema Suite opcional pinta el menu del juego y agrupa las columnas en un panel. La carta de personaje muestra el personaje, el correo, la durabilidad, avisos de subasta, la Gran camara, el Puesto comercial y las Iniciativas. La carta de zona muestra las colecciones de este lugar e iconos de alerta de objeto para Shopping List, notas, Trackers y Farming. Pasa el raton por un icono para ver detalles; haz clic para abrir esa ventana. Haz clic en la carta de personaje para abrir la pantalla de personaje, o en la carta de zona para abrir este lugar en el Catalogo.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Carta de personaje",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "Retrato, correo, durabilidad, avisos de subasta, Gran camara, Puesto comercial e Iniciativas. Pasa el raton por el correo, la durabilidad o el carrito para ver detalles; haz clic para abrir esa ventana.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "Carta de zona",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "Colecciones de este lugar e iconos de alerta de objeto. Pasa el raton por un icono para ver la lista o la nota; haz clic para abrir Shopping List, notas, Trackers o Farming.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portales",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "Piedras de hogar y menus de teletransporte en una carta de viaje junto al menu. Hay mas opciones de portales en la pestana Portales.",
    ["ESCPANEL_TOGGLE_SKIN_MENU"] = "Tema Suite en el menu del juego",
    ["ESCPANEL_TOGGLE_SKIN_MENU_DESC"] = "Pinta el menu del juego con el tema OneWoW y agrupa las cartas en un panel. Desactivalo si ElvUI, W2UI u otra IU ya cambia el aspecto del menu del juego.",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposicion",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Lado de las cartas",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Lado de los portales",
    ["ESCPANEL_SIDE_LEFT"] = "A la izquierda del menu",
    ["ESCPANEL_SIDE_RIGHT"] = "A la derecha del menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Activa o desactiva Carta de personaje, Carta de zona y Portales arriba. Las imagenes de las dos cartas estan debajo. Si las cartas y los portales estan en el mismo lado, se apilan en esa columna (cartas encima de Viaje).",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Tamano de icono de portal",
})

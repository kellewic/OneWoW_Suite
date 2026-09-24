local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["QUESTTOOLS_TITLE"] = "Herramientas de misión",
    ["QUESTTOOLS_DESC"] = "Automatiza la aceptación de misiones, la entrega, el resaltado de recompensas y el diálogo etiquetado como misión opcional. Automatización de misiones elige el modificador y si mantenerlo omite esas acciones o es necesario antes de que se ejecuten.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Aceptar misiones automáticamente",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Acepta automáticamente las misiones cuando aparece el diálogo de misión. Automatización de misiones elige el modificador y si mantenerlo omite la auto-aceptación o es necesario primero.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Entregar misiones automáticamente",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Completa y entrega misiones automáticamente cuando has cumplido todos los requisitos. Si hay varias recompensas disponibles, espera a que elijas.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Resaltar la mejor recompensa",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Muestra un icono de moneda de oro en el objeto de recompensa de misión con el mayor valor de venta al vendedor.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-diálogo (líneas etiquetadas como misión)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Selecciona automáticamente las opciones de diálogo marcadas como etiquetadas de misión (QuestLabelPrepend), es decir, las mismas líneas que la interfaz muestra con la etiqueta de estilo misión. Si hay más de una válida, usa el texto visible de la línea para decidir. Automatización de misiones elige el modificador y si mantenerlo omite el auto-diálogo o es necesario primero. Requiere compatibilidad con C_GossipInfo y QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) en tu cliente.",
    ["QUESTTOOLS_AUTOMATION_HEADER"] = "Automatización de misiones",
    ["QUESTTOOLS_REQUIRE_MODIFIER"] = "Exigir modificador para automatizar",
    ["QUESTTOOLS_REQUIRE_MODIFIER_DESC"] = "Si está activo, la auto-aceptación, la entrega y el diálogo de misión solo se ejecutan mientras mantienes el modificador. Si está inactivo, se ejecutan salvo que mantengas el modificador.",
    ["QUESTTOOLS_MODIFIER_KEY"] = "Modificador",
    ["QUESTTOOLS_MODIFIER_KEY_DESC"] = "La tecla que comprueba Automatización de misiones. Mayús, Ctrl o Alt.",
})

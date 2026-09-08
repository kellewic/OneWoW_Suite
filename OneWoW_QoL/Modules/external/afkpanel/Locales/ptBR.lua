local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AFKPANEL_TITLE"] = "Painel AFK",
    ["AFKPANEL_DESC"] = "Sobreposicao AFK em tela cheia com os mesmos cartao de personagem e cartao de zona do menu ESC, mais um cartao Info para alertas, timers de reinicio, profissoes e mais. Fundo da barra opcional.",
    ["AFKPANEL_CAMERA_SPIN"] = "Giro de câmera",
    ["AFKPANEL_SHOW_DOCK"] = "Mostrar fundo da barra",
    ["AFKPANEL_SHOW_DOCK_DESC"] = "Mostra a barra dourada atras dos cartoes AFK. Desative para os cartoes flutuarem sobre o personagem.",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Modo AFK",
})

local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["ESCPANEL_TITLE"] = "Painel do menu ESC",
    ["ESCPANEL_DESC"] = "Adiciona um cartao de personagem, um cartao de zona e uma faixa de portais ao lado do menu ESC. O cartao de personagem mostra o personagem, o correio, a durabilidade, avisos de leilao, o Grande Cofre, o Posto Comercial e as Iniciativas. O cartao de zona mostra as colecoes deste lugar e icones de Alerta de item para Shopping List, notas, Trackers e Farming. Passe o mouse em um icone para detalhes; clique para abrir essa janela. Clique no cartao de personagem para a tela do personagem, ou no cartao de zona para abrir este lugar no Catalogo.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Cartao de personagem",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "Retrato, correio, durabilidade, avisos de leilao, Grande Cofre, Posto Comercial e Iniciativas. Passe o mouse no correio, na durabilidade ou no carrinho para detalhes; clique para abrir essa janela.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "Cartao de zona",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "Colecoes deste lugar e icones de Alerta de item. Passe o mouse em um icone para a lista ou a nota; clique para abrir Shopping List, notas, Trackers ou Farming.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portais",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "Pedras de regresso e menus de teleporte ao lado do menu. Mais opcoes de portal ficam na aba Portais.",
    ["ESCPANEL_LAYOUT_HEADER"] = "Layout",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Lado dos cartoes",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Lado dos portais",
    ["ESCPANEL_SIDE_LEFT"] = "A esquerda do menu",
    ["ESCPANEL_SIDE_RIGHT"] = "A direita do menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Ative ou desative Cartao de personagem, Cartao de zona e Portais acima. As imagens dos dois cartoes ficam abaixo. Quando cartoes e portais ficam do mesmo lado, os portais ficam do lado de fora (mais longe do menu) e os cartoes ao lado do menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Tamanho do icone de portal",
})

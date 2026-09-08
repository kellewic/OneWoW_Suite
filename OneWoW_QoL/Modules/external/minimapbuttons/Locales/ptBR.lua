local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["MMBTNS_TITLE"] = "Coletor de botões do minimapa",
    ["MMBTNS_DESC"] = "Reúne os botões de addons do minimapa em um único contêiner com tema. Usa o ícone da marca OneWoW e oferece suporte a disposição em grade, fechamento automático e uma linha de início rápido OneWoW aprimorada.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r Coletor de botões",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "%d botão(ões) reunido(s)",
    ["MMBTNS_TOOLTIP_HINT"] = "Clique esquerdo para alternar",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "Clique direito para o menu",
    ["MMBTNS_TOOLTIP_DRAG"] = "Arraste para mover",

    ["MMBTNS_CLOSE_MODE"] = "Comportamento de fechamento",
    ["MMBTNS_STAY_OPEN"] = "Permanecer aberto",
    ["MMBTNS_AUTO_CLOSE"] = "Fechamento automático",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "Atraso de fechamento automático (segundos)",

    ["MMBTNS_ENHANCED_MENU"] = "Menu OneWoW aprimorado",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "Adiciona uma linha superior de icones de inicio rapido do OneWoW. Escolha abaixo quais mostrar.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "Todos os icones OneWoW estao na lista. Desmarque os que nao quiser nessa linha. Um icone so aparece quando o addon dele estiver carregado.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "Estilo dos icones aprimorados",
    ["MMBTNS_FEATURE_ICON_RING"] = "Com anel",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "Sem anel",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "Anel mantem o circulo dourado. Sem anel mostra so o simbolo. Inicio e Gerenciar recursos usam a mesma escolha.",

    ["MMBTNS_MAX_COLUMNS"] = "Colunas máx.",
    ["MMBTNS_MAX_ROWS"] = "Linhas máx.",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = ilimitado. Não pode ser 1x1 se houver vários botões.",
    ["MMBTNS_BUTTON_SCALE"] = "Escala dos ícones reunidos",
    ["MMBTNS_BUTTON_SPACING"] = "Espaçamento dos botões",

    ["MMBTNS_LOCK_POSITION"] = "Travar posição",
    ["MMBTNS_GROW_LEFT"] = "Esquerda",
    ["MMBTNS_GROW_RIGHT"] = "Direita",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "Mostrar também no minimapa",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "Mantém os botões reunidos também no minimapa, exibidos como cópias clicáveis no coletor.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "Mostrar dicas",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "Exibe as dicas originais dos addons ao passar o cursor pelos botões no contêiner.",

    ["MMBTNS_ICONS_HEADER"] = "Ícones do minimapa",
    ["MMBTNS_ICONS_DESC"] = "Cada ícone do minimapa detectado é listado abaixo. Escolha onde cada um fica: Coletor = dentro do painel OneWoW, Mapa = de volta no minimapa, Ocultar = removido totalmente da vista. O X remove uma entrada obsoleta (ativado apenas quando o addon proprietário está desativado). Sua escolha é lembrada entre recarregamentos e ciclos de ativação/desativação de addons.",
    ["MMBTNS_ICONS_EMPTY"] = "Nenhum ícone do minimapa detectado ainda. Abra o coletor uma vez para que ele possa escanear e depois reabra as configurações.",
    ["MMBTNS_ICONS_MINI"] = "Coletor",
    ["MMBTNS_ICONS_MAP"] = "Mapa",
    ["MMBTNS_ICONS_ENABLED"] = "Ativado",
    ["MMBTNS_ICONS_DISABLED"] = "Desativado",
    ["MMBTNS_ICONS_REMOVE_TT"] = "Remover esta entrada da lista",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "Este addon está carregado no momento. Mude o ícone dele para Ocultar se não quiser vê-lo; você só pode remover a entrada quando o addon estiver desativado ou desinstalado.",

    ["MMBTNS_SETTINGS_HEADER"] = "Configurações do coletor",
    ["MMBTNS_LAYOUT_HEADER"] = "Disposição",
    ["MMBTNS_BEHAVIOR_HEADER"] = "Comportamento",

    ["MMBTNS_CONTEXT_LOCK"] = "Travar posição",
    ["MMBTNS_CONTEXT_REFRESH"] = "Atualizar botões",

    ["MMBTNS_1X1_WARNING"] = "Não é possível definir disposição 1x1 com vários botões. Linhas máx. redefinidas para ilimitado.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "Desativar o Coletor de botões do minimapa deixa o LibDBIcon e outros ganchos do minimapa em mau estado até a interface recarregar (os ícones podem não arrastar em um mapa quadrado, e reativar pode não mostrar o contêiner).\n\nRecarregar a interface agora para restaurar os botões normais do minimapa?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "Recarregar IU",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "Recarregue mais tarde com |cFFFFD100/reload|r para restaurar totalmente os botões do minimapa.",
})

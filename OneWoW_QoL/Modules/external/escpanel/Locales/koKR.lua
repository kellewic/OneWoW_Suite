local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR, pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["ESCPANEL_TITLE"] = "ESC 메뉴 패널",
    ["ESCPANEL_DESC"] = "ESC 메뉴 옆에 캐릭터 카드, 지역 카드, 차원문 띠를 넣습니다. 캐릭터 카드에는 캐릭터, 우편, 내구도, 경매 알림, 위대한 금고, 교역소, 교류회가 나옵니다. 지역 카드에는 이 장소의 수집품과 Shopping List, 쪽지, Trackers, 파밍용 아이템 알림 아이콘이 나옵니다. 아이콘에 마우스를 올리면 자세한 내용이 나오고, 클릭하면 해당 창이 열립니다. 캐릭터 카드를 클릭하면 캐릭터창이, 지역 카드를 클릭하면 도감에서 이 장소가 열립니다.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "캐릭터 카드",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER_DESC"] = "초상화, 우편, 내구도, 경매 알림, 위대한 금고, 교역소, 교류회. 우편, 내구도, 카트에 마우스를 올리면 자세한 내용이 나오고, 클릭하면 해당 창이 열립니다.",
    ["ESCPANEL_TOGGLE_SHOW_HERE"] = "지역 카드",
    ["ESCPANEL_TOGGLE_SHOW_HERE_DESC"] = "이 장소의 수집품과 아이템 알림 아이콘. 아이콘에 마우스를 올리면 목록이나 쪽지가 나오고, 클릭하면 Shopping List, 쪽지, Trackers, 파밍이 열립니다.",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "차원문",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS_DESC"] = "메뉴 옆의 귀환석과 순간이동 펼침 메뉴. 차원문 탭에서 더 많은 설정을 할 수 있습니다.",
    ["ESCPANEL_LAYOUT_HEADER"] = "배치",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "카드 쪽",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "차원문 쪽",
    ["ESCPANEL_SIDE_LEFT"] = "메뉴 왼쪽",
    ["ESCPANEL_SIDE_RIGHT"] = "메뉴 오른쪽",
    ["ESCPANEL_LAYOUT_DESC"] = "위에서 캐릭터 카드, 지역 카드, 차원문을 켜거나 끕니다. 두 카드 그림이 아래에 있습니다. 카드와 차원문이 같은 쪽이면 차원문은 바깥쪽(메뉴에서 더 멀리)에, 카드는 메뉴 옆에 놓입니다.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "차원문 아이콘 크기",
})

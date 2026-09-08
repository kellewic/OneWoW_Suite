local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["MMBTNS_TITLE"] = "미니맵 버튼 수집기",
    ["MMBTNS_DESC"] = "미니맵 애드온 버튼을 테마가 적용된 단일 컨테이너로 모읍니다. OneWoW 브랜드 아이콘을 사용하며 격자 배치, 자동 닫기, 향상된 OneWoW 빠른 실행 줄을 지원합니다.",

    ["MMBTNS_TOOLTIP_LINE1"] = "|cFFFFD100OneWoW|r 버튼 수집기",
    ["MMBTNS_TOOLTIP_BUTTONS"] = "버튼 %d개 수집됨",
    ["MMBTNS_TOOLTIP_HINT"] = "왼쪽 클릭하여 전환",
    ["MMBTNS_TOOLTIP_HINT_RIGHT"] = "오른쪽 클릭하여 메뉴 열기",
    ["MMBTNS_TOOLTIP_DRAG"] = "끌어서 이동",

    ["MMBTNS_CLOSE_MODE"] = "닫기 동작",
    ["MMBTNS_STAY_OPEN"] = "열린 상태 유지",
    ["MMBTNS_AUTO_CLOSE"] = "자동 닫기",
    ["MMBTNS_AUTO_CLOSE_DELAY"] = "자동 닫기 지연 (초)",

    ["MMBTNS_ENHANCED_MENU"] = "향상된 OneWoW 메뉴",
    ["MMBTNS_ENHANCED_MENU_DESC"] = "OneWoW 빠른 실행 아이콘 상단 줄을 추가합니다. 아래에서 표시할 아이콘을 고르세요.",
    ["MMBTNS_ENHANCED_EXTRAS_DESC"] = "모든 OneWoW 아이콘이 목록에 있습니다. 그 줄에 보고 싶지 않은 항목은 체크를 해제하세요. 아이콘은 해당 애드온이 로드된 경우에만 나타납니다.",
    ["MMBTNS_FEATURE_ICON_STYLE"] = "향상된 아이콘 스타일",
    ["MMBTNS_FEATURE_ICON_RING"] = "테두리 있음",
    ["MMBTNS_FEATURE_ICON_RINGLESS"] = "테두리 없음",
    ["MMBTNS_FEATURE_ICON_STYLE_DESC"] = "테두리는 금색 원을 유지합니다. 테두리 없음은 가운데 상징만 보여 줍니다. 홈과 기능 관리도 같은 선택을 사용합니다.",

    ["MMBTNS_MAX_COLUMNS"] = "최대 열",
    ["MMBTNS_MAX_ROWS"] = "최대 행",
    ["MMBTNS_MAX_ROWS_DESC"] = "0 = 무제한. 버튼이 여러 개면 1x1로 설정할 수 없습니다.",
    ["MMBTNS_BUTTON_SCALE"] = "수집된 아이콘 크기",
    ["MMBTNS_BUTTON_SPACING"] = "버튼 간격",

    ["MMBTNS_LOCK_POSITION"] = "위치 잠금",
    ["MMBTNS_GROW_LEFT"] = "왼쪽",
    ["MMBTNS_GROW_RIGHT"] = "오른쪽",

    ["MMBTNS_ALSO_SHOW_ON_MINIMAP"] = "미니맵에도 표시",
    ["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"] = "수집된 버튼을 미니맵에도 유지하고, 수집기 안에 클릭 가능한 복사본으로 표시합니다.",
    ["MMBTNS_SHOW_TOOLTIPS"] = "툴팁 표시",
    ["MMBTNS_SHOW_TOOLTIPS_DESC"] = "컨테이너의 버튼 위에 마우스를 올리면 원래 애드온 툴팁을 표시합니다.",

    ["MMBTNS_ICONS_HEADER"] = "미니맵 아이콘",
    ["MMBTNS_ICONS_DESC"] = "감지된 모든 미니맵 아이콘이 아래에 나열됩니다. 각 아이콘의 위치를 선택하세요: 수집기 = OneWoW 패널 안, 지도 = 미니맵으로 복귀, 숨기기 = 화면에서 완전히 제거. X는 오래된 항목을 제거합니다(해당 애드온이 비활성화된 경우에만 가능). 선택은 다시 불러오기 및 애드온 활성화/비활성화 주기 동안 유지됩니다.",
    ["MMBTNS_ICONS_EMPTY"] = "아직 감지된 미니맵 아이콘이 없습니다. 수집기를 한 번 열어 검색하게 한 뒤 설정을 다시 여세요.",
    ["MMBTNS_ICONS_MINI"] = "수집기",
    ["MMBTNS_ICONS_MAP"] = "지도",
    ["MMBTNS_ICONS_ENABLED"] = "활성화됨",
    ["MMBTNS_ICONS_DISABLED"] = "비활성화됨",
    ["MMBTNS_ICONS_REMOVE_TT"] = "이 항목을 목록에서 제거",
    ["MMBTNS_ICONS_REMOVE_LOCKED_TT"] = "이 애드온은 현재 불러와져 있습니다. 보고 싶지 않으면 아이콘을 숨기기로 전환하세요. 항목은 애드온이 비활성화되거나 제거된 후에만 삭제할 수 있습니다.",

    ["MMBTNS_SETTINGS_HEADER"] = "수집기 설정",
    ["MMBTNS_LAYOUT_HEADER"] = "배치",
    ["MMBTNS_BEHAVIOR_HEADER"] = "동작",

    ["MMBTNS_CONTEXT_LOCK"] = "위치 잠금",
    ["MMBTNS_CONTEXT_REFRESH"] = "버튼 새로 고침",

    ["MMBTNS_1X1_WARNING"] = "버튼이 여러 개일 때는 1x1 배치를 설정할 수 없습니다. 최대 행이 무제한으로 초기화되었습니다.",

    ["MMBTNS_DISABLE_RELOAD_TEXT"] = "미니맵 버튼 수집기를 끄면 UI를 다시 불러올 때까지 LibDBIcon과 다른 미니맵 후크가 잘못된 상태로 남습니다(정사각형 지도에서 아이콘이 끌리지 않을 수 있고, 다시 켜도 컨테이너가 표시되지 않을 수 있음).\n\n일반 미니맵 버튼을 복원하기 위해 지금 인터페이스를 다시 불러올까요?",
    ["MMBTNS_DISABLE_RELOAD_BTN"] = "UI 다시 불러오기",
    ["MMBTNS_DISABLE_RELOAD_CHAT"] = "나중에 |cFFFFD100/reload|r로 다시 불러와 미니맵 버튼을 완전히 복원하세요.",
})

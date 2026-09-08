# OneWoW_GUI - Quick Reference

- **Global:** `OneWoW_GUI` (plain global, published by `GUI/Core.lua` — not a LibStub library)
- **Location:** `OneWoW/GUI/` (part of the core addon)
- **Loaded by:** Suite addons (via `## RequiredDeps: OneWoW`)
- **Interface:** see `OneWoW.toc` for the authoritative list

---

## How To Get It

```lua
local OneWoW_GUI = OneWoW_GUI
```

Every suite unit has `RequiredDeps: OneWoW`, so the global is guaranteed
present — no existence guard.

## Contents

- [How To Get It](#how-to-get-it)
- [Centralized Settings (Settings.lua)](#centralized-settings-settingslua)
- [Fonts (Fonts.lua)](#fonts-fontslua)
- [Media assets](#media-assets)
- [Theme System](#theme-system)
- [Frames & Layout](#frames--layout)
- [Buttons & Controls](#buttons--controls)
- [Text & Dividers](#text--dividers)
- [Section Headers](#section-headers)
- [Settings Cards](#settings-cards)
- [Stacking & Action Bars](#stacking--action-bars)
- [Scroll Frames](#scroll-frames)
- [Split Panel (List + Detail Layout)](#split-panel-list--detail-layout)
- [Dropdowns](#dropdowns)
- [Icon Skinning System](#icon-skinning-system)
- [Additional Components](#additional-components)
- [Side Bar Tabs](#side-bar-tabs)
- [Utility](#utility)
- [Available Backdrop Templates](#available-backdrop-templates)
- [GUI Dimension Defaults](#gui-dimension-defaults)

---

## Centralized Settings (Settings.lua)

Shared settings live in core's `OneWoW_DB` SavedVariables; the toolkit binds its
settings handle to core's db via `OneWoW_GUI:InitializeSettings(db)`.
All ecosystem addons read/write through GUI. No more duplicate theme/language/minimap storage.

### Settings stored
- `theme` - color theme key (default: "green")
- `language` - locale key (default: GetLocale())
- `font` - font key (default: "default")
- `fontSizeOffset` - global font size adjustment, -3 to +5 (default: 0)
- `minimap.hide` - minimap button visibility (default: false)
- `minimap.theme` - faction icon: "horde", "alliance", or "neutral" (default: "horde")
- `featureIcons.style` - suite feature faces: `"ring"` or `"ringless"` (default: `"ring"`). Ringless files are gold on transparent; `GetFeatureIcon` returns `plate = false` so Home, Manage Features, and collector skip the icon well. DevTools session errors tint that face red (`OneWoW:ApplyFeatureIconAlert`); click opens the Errors tab (`OneWoW:ResolveFeatureIconClick`). The logger fires `OneWoW_DevTool.ErrorAlert` when that state changes.

### Get a setting
```lua
local theme  = OneWoW_GUI:GetSetting("theme")          -- "green", "blue", etc.
local lang   = OneWoW_GUI:GetSetting("language")        -- "enUS", "koKR", etc.
local font   = OneWoW_GUI:GetSetting("font")            -- "default", "expressway", etc.
local offset = OneWoW_GUI:GetSetting("fontSizeOffset")  -- -3 to +5 (default 0)
local hide   = OneWoW_GUI:GetSetting("minimap.hide")    -- true/false
local icon   = OneWoW_GUI:GetSetting("minimap.theme")   -- "horde"/"alliance"/"neutral"
local faces  = OneWoW_GUI:GetSetting("featureIcons.style") -- "ring" / "ringless"
```

### Set a setting (fires callbacks to all registered addons)
```lua
OneWoW_GUI:SetSetting("theme", "blue")
OneWoW_GUI:SetSetting("language", "koKR")
OneWoW_GUI:SetSetting("font", "expressway")
OneWoW_GUI:SetSetting("fontSizeOffset", 2)       -- range: -3 to +5
OneWoW_GUI:SetSetting("minimap.hide", true)
OneWoW_GUI:SetSetting("minimap.theme", "alliance")
OneWoW_GUI:SetSetting("featureIcons.style", "ringless")
```

### Register for settings change callbacks
```lua
OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", myAddon, function(self, newThemeKey)
    OneWoW_GUI:ApplyTheme(self)
    -- rebuild your UI here
end)

OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", myAddon, function(self, newLangKey)
    -- ns.L (your OneWoW.Locale view) refolds automatically; only rebuild any
    -- standalone UI you own (hub tabs are rebuilt for you on a language change)
end)

OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", myAddon, function(self, isHidden)
    -- show/hide your minimap button
end)

OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", myAddon, function(self, newIconTheme)
    -- update your minimap icon
end)

OneWoW_GUI:RegisterSettingsCallback("OnFeatureIconStyleChanged", myAddon, function(self, newStyle)
    -- Home / Manage Features / collector enhanced tiles use GetFeatureIcon
end)

OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", myAddon, function(self, newFontKey)
    -- refresh your UI text with the new font
end)

OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", myAddon, function(self, newOffset)
    -- reapply fonts / rebuild UI to pick up new size offset
    -- SafeSetFont automatically applies the offset, so just re-call your font application
end)
```

## Fonts (Fonts.lua)

Font catalog, `SafeSetFont` / `CreateFS` / `ApplyFont*`, and the font-root registry
live in `OneWoW/GUI/Fonts.lua` (loads after `Settings.lua`). Public API stays on
`OneWoW_GUI`.

**Do not put decorative Unicode in FontStrings** (stars, checkmarks, emoji, etc. as
icon substitutes). Player-selected suite fonts often lack those glyphs. Prefer
textures, atlases, or helpers such as `CreateFavoriteToggleButton`. See agent skill
`onewow-gui-ui`.

Typographic punctuation in player-facing strings (Lua and locale values) uses ASCII:

| Glyph | ASCII |
| --- | --- |
| `→` / `←` | `>>` / `<<` (spaces around) |
| `…` | `...` |
| `—` / `–` in a sentence | ` - ` |
| standalone empty placeholder | `-` |
| `×` | `x` (quantity: `" x"` / `"%s x%d"`) |
| middle dot as a list separator | `\|` with spaces (`gold \| items`) |
| `«` `»` `“` `”` `„` | ASCII `"` |
| `‘` `’` | ASCII `'` |

CJK fullwidth punctuation (`。` `，` `「」`) is legitimate script. Comments may keep
em dashes. Expand carets stay ASCII `>` / `v`.

### Get the current font file path
```lua
local fontPath = OneWoW_GUI:GetFont()
-- Returns the font file path string, or nil if set to "WoW Default"
-- Example: "Interface\AddOns\OneWoW\Media\Fonts\Expressway.ttf"
if fontPath then
    myFontString:SetFont(fontPath, 12)
end
```

## Media assets

All suite textures, fonts, and sounds live under **`OneWoW/Media/`** on disk.
Every load unit has `RequiredDeps: OneWoW`, so runtime paths always use the hub
addon folder — never a per-load-unit `OneWoW_*/Media/` tree.

| Location | Use |
|----------|-----|
| `OneWoW/Media/` (root) | Shared assets: `icon-*.png`, faction minis, `bar.tga`, `OneWoWMini-*.tga`, `Fonts/` |
| `OneWoW/Media/Features/` | Suite feature faces (`ring/` and `ringless/`), resolved by `OneWoW:GetFeatureIcon` |
| `OneWoW/Media/<AddonName>/` | Assets owned by one unit (e.g. `OneWoW_QoL/cursorenhancer/`, `OneWoW_Utility_DevTool/devtools-error.ogg`) |

**Lua:** use `OneWoW_GUI.Constants.MEDIA_BASE` — do not hardcode
`Interface\AddOns\OneWoW\Media\` or ship copies under `OneWoW_Notes\Media\`, etc.

```lua
local OneWoW_GUI = OneWoW_GUI

-- Shared icon at hub root
local icon = OneWoW_GUI.Constants.MEDIA_BASE .. "icon-fav.png"

-- Addon-specific subfolder (trailing segment has no leading backslash; MEDIA_BASE ends with \)
local cursorMedia = OneWoW_GUI.Constants.MEDIA_BASE .. "OneWoW_QoL\\cursorenhancer\\"
outerRing:SetTexture(cursorMedia .. "c1")

-- Faction / brand icons
local brand = OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme"))

-- Overlay custom icons (icon-* keys)
local path = OneWoW.OverlayIcons:GetTexturePath("icon-mount")
```

Enforced by pre-commit `no-per-addon-media` (`bin/check_no_per_addon_media.py`).

### Available font keys

Use `OneWoW_GUI:GetFontList()` for the complete list. Sample:

| Key | Label |
|-----|-------|
| default | WoW Default |
| actionman | Action Man |
| adventure | Adventure |
| bazooka | Bazooka |
| blackchancery | Black Chancery |
| celestia | Celestia Medium Redux |
| continuum | Continuum Medium |
| dejavusans | DejaVu Sans |
| dejavuserif | DejaVu Serif |
| diedidie | DieDieDie |
| dorispp | DorisPP |
| enigmatic | Enigmatic |
| expressway | Expressway |
| fitzgerald | Fitzgerald |
| gentiumplus | Gentium Plus |
| hack | Hack |
| homespun | Homespun |
| hookedup | All Hooked Up |
| liberationmono | Liberation Mono |
| liberationsans | Liberation Sans |
| liberationserif | Liberation Serif |
| ptsansnarrow | PT Sans Narrow |
| sfatarian | SF Atarian System |
| sfcovington | SF Covington |
| sfmovieposter | SF Movie Poster |
| sfwondercomic | SF Wonder Comic |
| swfit | SWF!T |
| texgyreadventor | TeX Gyre Adventor |
| texgyreadventorbold | TeX Gyre Adventor Bold |
| wenquanyi | WenQuanYi Zen Hei |
| yellowjacket | Yellowjacket |

### Font API
```lua
local fontList = OneWoW_GUI:GetFontList()           -- full list of { key, label, file }
local path = OneWoW_GUI:GetFontByKey("expressway") -- path or nil for default
OneWoW_GUI:SafeSetFont(fontString, path, 12, "")  -- applies font with offset, fallback to GameFontNormal
local offset = OneWoW_GUI:GetFontSizeOffset()      -- current offset (-3 to +5, default 0)
local key = OneWoW_GUI:MigrateLSMFontName("Expressway")  -- maps LibSharedMedia names to GUI keys
```

### Font Size Offset (global size adjustment)

`SafeSetFont` automatically adds the user's font size offset to every size it receives.
Addons do NOT need to manually add the offset - just pass your base size to `SafeSetFont`.

- Range: `-3` to `+5` (default `0`)
- Minimum final size: `6px` (enforced in `SafeSetFont`)
- Callback: `OnFontSizeChanged` fires when the user changes the offset
- The offset preserves design hierarchy: a 16px header and 12px body with +2 become 18px and 14px

```lua
OneWoW_GUI:SafeSetFont(myFontString, fontPath, 12)
-- If user set offset to +3, actual size applied = 15
-- If user set offset to -2, actual size applied = 10
```

### Live font updates: font roots

The main OneWoW window re-applies fonts by rebuilding itself on font change. Frames
that live **outside** it — standalone dialogs and panels docked to Blizzard frames
(Auction House, merchant, inspect) — are not caught by that rebuild, so their text
stays the old size until `/reload`. Register such frames as **font roots** and the
toolkit handles them centrally.

```lua
-- Docked / hand-rolled panel: register once at build.
OneWoW_GUI:RegisterFontRoot(panelFrame, RelayoutPanel)  -- relayout is optional
```

- On any font / font-size change, the single internal driver runs
  `ApplyFontToFrame(frame)` across the subtree, then the optional `relayout`.
- **Do not** register your own `OnFontChanged` / `OnFontSizeChanged` for this — the
  registry is the one funnel (it listens to `OnFontChanged`, which also fires for a
  size change, so there's no double work).
- **`CreateDialog` (and everything routed through it — `CreateConfirmDialog`,
  `ShowCopyURLDialog`, `ShowCopyLinksDialog`) auto-registers.** Pass `config.relayout`
  if the dialog has a measured stack to re-flow. Nothing else to wire up.
- `OneWoW_GUI:UnregisterFontRoot(frame)` exists for explicitly torn-down panels;
  keys are weak, so abandoned frames drop out on their own.

**Re-fonting is only half the job.** If a stacked layout hard-codes row heights,
taller text overlaps the next row. Stacked text rows should measure themselves
(`fs:GetStringHeight()`, with a fixed fallback until the width resolves) inside the
`relayout` function. Reference implementation:
`OneWoW_AltTracker_Auctions/UI/AHPricesPanel.lua` (`RelayoutPanel` + `RegisterFontRoot`).

### Shared appearance settings (hub Settings only)

Language, color theme, font, font size, hub minimap visibility, icon theme, and
value-display options live **only** on the OneWoW hub Settings main tab
(`OneWoW/UI/settings-shared-panel.lua`, built from `UI:BuildSharedSettingsPanel`).
Suite units must **not** embed that panel — they keep feature-specific settings
in their own windows or via `OneWoW:RegisterSettingsPanel`.

The panel reads/writes shared settings through `OneWoW_GUI:GetSetting` /
`SetSetting` (`OneWoW_DB`) and fires the usual callbacks.

### Import per-addon settings into shared GUI DB (call once at addon init)
```lua
OneWoW_GUI:MigrateSettings(addon.db.global)
```
On first run, copies theme/language/minimap from the addon's old DB into GUI DB.
Only runs once (sets `_migrated` flag). Safe to call every load.

### Window Position Persistence

Use `SaveWindowPosition` and `RestoreWindowPosition` for movable main windows. Standard DB key: `mainFramePosition` (shape: `{ point, relativePoint, x, y, width?, height? }`). Save on `OnHide` so position persists on close, FullReset, and theme change.

`RestoreWindowPosition` clamps restored width/height to the screen. On first show it nudges the frame if any edge is partially off-screen (UI scale / resolution changes), and only centers when the frame is fully off-screen. Corrected size and point are written back to storage.

```lua
-- In addon DB defaults: mainFramePosition = {}

-- After creating the main frame:
local storage = addon.db.global.mainFramePosition or {}
if not OneWoW_GUI:RestoreWindowPosition(mainFrame, storage) then
    mainFrame:SetPoint("CENTER")
end

mainFrame:SetScript("OnHide", function()
    local db = addon.db.global
    db.mainFramePosition = db.mainFramePosition or {}
    OneWoW_GUI:SaveWindowPosition(mainFrame, db.mainFramePosition)
end)
```

### Adding GUI settings to a new addon (full pattern)
```lua
function addon:OnInitialize()
    self:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(self.db.global)
    OneWoW_GUI:ApplyTheme(self)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        OneWoW_GUI:ApplyTheme(self2)
        -- rebuild UI
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(self2)
        -- locale view auto-updates; rebuild standalone UI you own
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(self2)
        -- update brand icons / title-bar art that use the icon theme
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(self2, newFontKey)
        -- refresh UI text with OneWoW_GUI:GetFont()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", self, function(self2, newOffset)
        -- reapply fonts to pick up new size offset (SafeSetFont handles it automatically)
    end)
end

-- Feature settings only (no shared appearance panel):
-- Prefer OneWoW:RegisterSettingsPanel for hub modules, or a local settings
-- view for stand-alone windows (Bags, ShoppingList, …).
```

---

## Theme System

### Apply a theme (call once at addon startup)
```lua
OneWoW_GUI:ApplyTheme(addon)
```
Checks GUI settings DB first, then OneWoW hub, then addon.db.global.theme, falls back to green.

### Get a theme color
```lua
local r, g, b, a = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))

-- Preview a non-active palette (settings theme picker rows / swatches):
local pr, pg, pb = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY", "blue")
```

### Theme-independent constants (`OneWoW_GUI.Constants`)
Use for colors that must **not** follow the active theme:

| Constant | Use |
| --- | --- |
| `WOW_QUEST_GOLD` | Blizzard quest-title gold (`{1, 0.82, 0}`) |
| `OVERLAY_DIM` | Black dim overlays (`{0, 0, 0, 0.7}`) |
| `ICON_OVERLAY_TEXT` | White text on item icons / progress bar labels |
| `REORDER_BTN_HIGHLIGHT` | Yellow highlight on scroll reorder arrows |

Access via `unpack(OneWoW_GUI.Constants.WOW_QUEST_GOLD)` etc. — **not** `GetThemeColor`.

### Scroll reorder arrow tint
```lua
OneWoW_GUI:TintScrollReorderButtons(upBtn, downBtn)
```
Applies `WOW_QUEST_GOLD` normal + `REORDER_BTN_HIGHLIGHT` on Blizzard collapse/expand atlas buttons.

### Colors intentionally not themed
Leave as literals, module-local palettes, or Blizzard/data-driven APIs:

- `NotesConfig.PIN_COLORS` — user-selectable pin themes
- `afkpanel` `PALETTE` — cinematic fullscreen UI (not suite theme)
- `cursorenhancer` `COLOR_SETTINGS` — user preferences
- `toast-engine` per-toast `data.color` stripes
- `PROGRESS_COLORS` / `GetProgressColor`
- `C_Item.GetItemQualityColor` / class colors
- `Panels.lua` `def.color` caller-supplied action buttons
- `(0,0,0,0)` transparent menu/button backdrops
- **DevTool code editor** — Monokai background/gutter (`EditorTab.lua` `MONOKAI_BG` / `GUTTER_BG` from `EditorSyntaxData`); surrounding DevTool chrome uses `GetThemeColor`

### Wrap text in a theme color (color codes)
```lua
local s = OneWoW_GUI:WrapThemeColor("Hello", "ACCENT_PRIMARY")
-- Uses CreateColor(...):WrapTextInColorCode; suitable for chat or mixed-color strings
```

### Available color keys
BG_PRIMARY, BG_SECONDARY, BG_TERTIARY, BG_HOVER, BG_ACTIVE,
ACCENT_PRIMARY, ACCENT_SECONDARY, ACCENT_HIGHLIGHT, ACCENT_MUTED,
TEXT_PRIMARY, TEXT_SECONDARY, TEXT_MUTED, TEXT_ACCENT,
BORDER_DEFAULT, BORDER_SUBTLE, BORDER_FOCUS, BORDER_ACCENT,
TITLEBAR_BG, TITLEBAR_BORDER,
BTN_NORMAL, BTN_HOVER, BTN_PRESSED, BTN_BORDER, BTN_BORDER_HOVER,
TEXT_FEATURES_ENABLED, TEXT_FEATURES_DISABLED,
DOT_FEATURES_ENABLED, DOT_FEATURES_DISABLED,
TEXT_WARNING,
BTN_DANGER_NORMAL, BTN_DANGER_HOVER, BTN_DANGER_BORDER, BTN_DANGER_BORDER_HOVER,
LINK_IDLE, LINK_HOVER, LINK_UNDERLINE,
QUEST_ROW_SECTION, QUEST_ROW_CHILD, QUEST_ROW_GROUP_TOGGLE,
KIND_TOKEN, KIND_SAVED, KIND_CATEGORY

`CreateEntityIdField` uses TEXT_FEATURES_DISABLED for an invalid ID, TEXT_WARNING while an async name load is in flight, and TEXT_FEATURES_ENABLED when the name resolves.

### Get spacing value
```lua
local px = OneWoW_GUI:GetSpacing("MD")
```
XS=4, SM=8, MD=12, LG=16, XL=24

### Available themes (24 total)
green, blue, purple, red, orange, teal, gold, pink, dark, amber, cyan, slate,
voidblack, charcoal, forestnight, obsidian, monochrome, twilight, neon,
glassmorphic, lightmode, retro, fantasy, nightfae

Order stored in `Constants.THEMES_ORDER`.

### Get faction brand icon
```lua
local texture = OneWoW_GUI:GetBrandIcon("horde")  -- or "alliance" or "neutral"
```

### Hub minimap

The suite uses a single hub minimap button (`OneWoW_MinimapButton`). Suite units
register context-menu entries via `OneWoW:RegisterMinimap` — they do **not**
create per-addon LibDBIcon launchers.

```lua
OneWoW:RegisterMinimap("OneWoW_MyAddon", "Open My Addon", "myaddon", nil)  -- tabKey opens hub tab
-- or
OneWoW:RegisterMinimap("OneWoW_MyAddon", "Open My Addon", nil, function() MyAddon.GUI:Toggle() end)
```

Show/hide and icon theme are shared settings (`minimap.hide`, `minimap.theme`)
edited only on the hub Settings tab.

### Get hub minimap button frame

```lua
local btn = OneWoW_GUI:GetMinimapButton()
-- Returns OneWoW_MinimapButton (or nil before the hub button exists)
-- Use case: attach UI (e.g. error badge) to the minimap button
```

### Register GUI constants with fallback

`OneWoW_GUI.Constants.GUI` is the source of truth for shared hub chrome. Suite defaults:

| Key | Value |
|-----|-------|
| `WINDOW_WIDTH` / `WINDOW_HEIGHT` | 1075 × 900 |
| `MIN_WIDTH` / `MIN_HEIGHT` | 860 × 560 |
| `MAX_WIDTH` / `MAX_HEIGHT` | 2560 × 1600 |
| `LEFT_PANEL_WIDTH` | 320 |
| `SCROLLBAR_WIDTH` | 10 |
| `SCROLLBAR_THUMB_WIDTH` | 8 |
| `SCROLLBAR_CONTENT_GUTTER` | 24 |

Addons can override or add GUI constants via `RegisterGUIConstants`. Missing keys fall back to `Constants.GUI`, then to `0`. The returned table is read-only.

**Hub tab modules** (`OneWoW_Notes`, `OneWoW_QoL`, `OneWoW_Catalog`, `OneWoW_Trackers`, `OneWoW_AltTracker`) render inside `OneWoWMainWindow` and must **not** override `WINDOW_*`, `MIN_*`, `MAX_*`, or `LEFT_PANEL_WIDTH`. Use `RegisterGUIConstants({})` or only unit-specific keys (e.g. `CONTROL_PANEL_HEIGHT`, `SPECIAL_COLORS`).

**Standalone-window addons** (`OneWoW_Bags`, `OneWoW_DirectDeposit`, `OneWoW_ShoppingList`, `OneWoW_Utility_DevTool`) may override window dimensions for their own frames.

**Signature:** `OneWoW_GUI:RegisterGUIConstants(guiConstants)` — takes a table, returns a table with metatable.

**Typical usage** — store as `addon.Constants.GUI` in Core/Constants.lua:

```lua
OneWoW_MyAddon.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH  = 820,
        WINDOW_HEIGHT = 580,
        MIN_WIDTH     = 820,
        MIN_HEIGHT    = 500,
        ROW_HEIGHT    = 38,  -- addon-specific; falls back to 0 if unused
    }),
}
```

**Base GUI keys** (override any; add custom keys as needed):
WINDOW_WIDTH, WINDOW_HEIGHT, MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT,
PADDING, BUTTON_HEIGHT, BUTTON_WIDTH, SEARCH_HEIGHT, SEARCH_WIDTH,
CHECKBOX_SIZE, ROW1_HEIGHT, ROW2_HEIGHT, ROW2_FAVORITE_HEIGHT, LEFT_PANEL_WIDTH, PANEL_GAP, TAB_BUTTON_HEIGHT,
TOGGLE_BUTTON_WIDTH, TOGGLE_BUTTON_HEIGHT, SCROLLBAR_WIDTH, SCROLLBAR_THUMB_WIDTH, SCROLLBAR_CONTENT_GUTTER

**Common overrides (standalone windows only):** WINDOW_WIDTH, WINDOW_HEIGHT, MIN_WIDTH, MIN_HEIGHT, SIDEBAR_WIDTH, SEARCH_HEIGHT, ROW_HEIGHT, SUBTAB_BUTTON_HEIGHT.

---

## Frames & Layout

### Component API Conventions

All component creation functions use the **`(parent, options)`** pattern: parent first (when applicable), all other parameters in an options table. This improves discoverability and extensibility.

```lua
local C = OneWoW_GUI.Constants
local frame = OneWoW_GUI:CreateFrame(parent, {
    name = "MyFrame",
    width = 400,
    height = 300,
    backdrop = C.BACKDROP_SOFT,  -- required; use Constants.BACKDROP_SOFT, BACKDROP_INNER_NO_INSETS, etc.
})
```

### Basic themed frame
```lua
local C = OneWoW_GUI.Constants
local frame = OneWoW_GUI:CreateFrame(parent, {
    name = "MyFrame",
    width = 400,
    height = 300,
    backdrop = C.BACKDROP_SOFT,
})
```
Returns a BackdropTemplate frame with theme BG_PRIMARY + BORDER_DEFAULT.
`backdrop` is required; use `OneWoW_GUI.Constants.BACKDROP_SOFT`, `BACKDROP_INNER_NO_INSETS`, etc.

### Layout frame
```lua
local container = OneWoW_GUI:CreateLayoutFrame(parent, {
    height = OneWoW_GUI.Constants.GUI.ACTION_BAR_HEIGHT,
})
```
Plain invisible `Frame` for positioning child components. Use this instead of raw `CreateFrame` when addon code only needs a layout container.

### Dialog
```lua
local result = OneWoW_GUI:CreateDialog({
    name = "MyDialog",              -- frame name (nil = anonymous, but needed for ESC close)
    title = "Export Profile",       -- title bar text
    width = 620,                    -- required
    height = 500,                   -- required
    strata = "DIALOG",             -- optional, default "DIALOG"
    movable = true,                -- optional, default true
    escClose = true,               -- optional, default true (adds to UISpecialFrames)
    showBrand = false,             -- optional, OneWoW brand icon in title bar
    titleIcon = nil,               -- optional, texture path for icon left of title
    titleHeight = 28,              -- optional, default 28
    onClose = function() end,      -- optional, called when X button or ESC closes
    showScrollFrame = false,       -- optional, creates scroll frame in content area
    buttons = {                    -- optional footer button row
        { text = "Import", onClick = function(dialog) end },
        { text = "Cancel", onClick = function(dialog) dialog:Hide() end, color = {0.6, 0.2, 0.2} },
    },
})
```
Returns a table:
- `result.frame` - main frame (call `:Show()` / `:Hide()`)
- `result.titleBar` - title bar frame from CreateTitleBar
- `result.contentFrame` - area between title bar and button row (add your content here)
- `result.scrollFrame` / `result.scrollContent` - if `showScrollFrame = true`
- `result.buttons` - indexed table of button frames matching `buttons` order

Button `color` option: `{r, g, b}` overrides the button background (useful for green confirm, red destructive).
Buttons are right-aligned in footer. A 1px divider separates content from buttons.
Frame starts hidden - call `result.frame:Show()` when ready.

### Confirm dialog (simple yes/no)
```lua
local result = OneWoW_GUI:CreateConfirmDialog({
    name = "MyConfirm",             -- optional frame name
    title = "Confirm Restore",      -- accent header text
    message = "Are you sure?",      -- body text below title
    width = 420,                    -- optional, default 420
    buttons = {
        { text = "Confirm", color = {0.2, 0.6, 0.2}, onClick = function(dialog) end },
        { text = "Cancel", onClick = function(dialog) dialog:Hide() end },
    },
})
```
Convenience wrapper around `CreateDialog` with `movable = false` and auto-calculated height.
Returns the same table as `CreateDialog` plus:
- `result.titleLabel` - FontString for the title text
- `result.messageLabel` - FontString for the message text

Not movable, centered on screen, ESC closes. Title displayed as large accent text (no title bar).

### Filter bar (horizontal control container)
```lua
local filterBar = OneWoW_GUI:CreateFilterBar(parent, {
    height = 40,              -- optional, default 40
    anchorBelow = someFrame,  -- optional, anchor below this frame instead of parent top
    offset = -5,              -- optional, vertical gap from anchor
})
```
Creates a themed container bar (BG_SECONDARY + BORDER_DEFAULT) anchored across the top of parent.
Add your own controls inside (dropdowns, search boxes, buttons) using existing library functions.

### Sort controls (field dropdown + ascending/descending)
```lua
local sort = OneWoW_GUI:CreateSortControls(parent, {
    sortFields = {
        { key = "name", label = "Name" },
        { key = "level", label = "Level" },
    },
    defaultField = "name",
    defaultAsc = true,
    dropdownWidth = 110,
    onChange = function(field, ascending)
        -- refresh list using field / ascending
    end,
})
sort.dirBtn:SetPoint("LEFT", sort.dropdown, "RIGHT", 4, 0)
local field, asc = sort:GetSort()
sort:SetSort("level", false)
```
Returns a handle: `dropdown`, `dirBtn`, `GetSort()`, `SetSort(field, ascending)`. The direction button toggles ascending vs descending and uses collapse/expand atlases for the icon.

### Title bar
```lua
local titleBar = OneWoW_GUI:CreateTitleBar(parent, {
    title = "My Title",
    height = 20,           -- optional, default 20
    onClose = function() parent:Hide() end,  -- optional close button
    showBrand = true,      -- optional OneWoW brand icon + text
    factionTheme = "horde" -- optional, auto-reads from GUI settings if omitted
})
```
Access title text via `titleBar._titleText`.
Access close button via `titleBar._closeBtn` (nil if no `onClose` provided).
When `showBrand = true` and `factionTheme` is omitted, the icon is auto-read from
`OneWoW_GUI:GetSetting("minimap.theme")` (horde/alliance/neutral). This means all
title bars automatically update when the user changes their faction icon setting.

---

## Buttons & Controls

### Button (base - fixed size)
```lua
local btn = OneWoW_GUI:CreateButton(parent, {
    name = "CloseBtn",
    text = "X",
    width = 20,
    height = 20,
})
```
Fixed-size button. Use only for icon buttons (e.g. "X" close). For text buttons, use FitText or FitFrame.

### Fit Text Button (auto-sizes to text)
```lua
local btn = OneWoW_GUI:CreateFitTextButton(parent, {
    text = "Click Me",
    height = 28,      -- optional, default BUTTON_HEIGHT
    minWidth = 40,    -- optional, default 40
    paddingX = 24,    -- optional, default 24 (12 each side)
    danger = true,    -- optional; BTN_DANGER_* chrome (ignores toggleable)
    toggleable = true,-- optional; mutually exclusive with danger
})
```
Auto-sizes width to fit text content. Handles localization where translated text may be longer.
Call `btn:SetFitText("New Text")` to update text and auto-resize.
Access label via `btn.text`.
`danger = true` uses `BTN_DANGER_NORMAL` / `BTN_DANGER_HOVER` / `BTN_DANGER_BORDER*`. If both `danger` and `toggleable` are set, `danger` wins and `toggleable` is ignored.

### Icon Button (chrome-less)
```lua
local btn = OneWoW_GUI:CreateIconButton(parent, {
    iconTexture = MEDIA .. "icon-gears.png", -- xor atlas
    -- atlas = "talents-button-undo",
    size = 20,              -- optional, default ICON_BUTTON_SIZE
    texCoord = {0.1, 0.9, 0.1, 0.9}, -- optional crop
    tint = true,            -- optional; ACCENT_PRIMARY vertex color (atlases beside gold MEDIA)
    tooltipTitle = EDIT,
    tooltipText = L.HINT,   -- optional second line
    onClick = function() end,
    -- check = true, checked = false, onToggle = function(isActive) end
})
```
No `CreateButton` plate. Use for row/header actions (Notes, Trackers). Check mode adds `btn:SetActiveVisual(bool)` (desaturate + alpha when off).
`CreateAtlasIconButton` / `CreateTextureIconButton` keep plated chrome for title-bar clusters.

### Text Link (backdrop-less clickable label)
```lua
local link = OneWoW_GUI:CreateTextLink(parent, {
    text = "Open in Bags",
    fontSize = 11,    -- optional, default 12
    nav = true,       -- optional: smaller ASCII `>` after the label (in-hub navigation)
    tooltipTitle = L.HINT_TITLE, -- optional
    tooltipText = L.HINT,       -- optional second line
    onClick = function()
        -- handle click
    end,
})
```
Fit-width button with no backdrop. Idle `LINK_IDLE` + subtle `LINK_UNDERLINE`, hover `LINK_HOVER`, Point cursor.
`nav = true` appends a smaller `>` (ASCII — safe across fonts) for “go elsewhere” links; omit for actions / external URLs.
`tooltipTitle` / `tooltipText` show on hover (same as `CreateFitTextButton`). Mutate `link.tooltipTitle` / `link.tooltipText` after create if the label changes.
`link:SetText(s)` refits width; `link:SetEnabled(false)` mutes to `TEXT_MUTED`.
Access label via `link.text` (chevron via `link.chevron` when `nav`).

Theme fill (`Constants.lua` `owgFillThemeSemantics`) supplies `LINK_*` for every theme from `TEXT_ACCENT` / `TEXT_PRIMARY` / accent@0.4 — override per-theme when a palette needs a hand tune.

### Fit Frame Buttons (fill container width)
```lua
local buttons, finalY = OneWoW_GUI:CreateFitFrameButtons(parent, {
    yOffset = 0,
    items = {
        { text = "Option A", value = "a", isActive = true },
        { text = "Option B", value = "b" },
        { text = "Option C", value = "c" },
    },
    height = 26,      -- optional, default 26
    gap = 4,          -- optional, default 4
    marginX = 12,     -- optional, default 12
    width = 400,      -- optional, defaults to parent:GetWidth()
    onSelect = function(value, text, btn)
        -- handle selection
    end,
})
```
Creates N equal-width buttons that fill the available width. Auto-wraps to next row if needed.
Each button also enforces a text-driven minimum width, so translated labels stay inside the button.
Active button: BG_ACTIVE + BORDER_ACCENT + TEXT_ACCENT. Inactive: BTN_NORMAL + TEXT_MUTED.
Clicking a button auto-toggles active state across all buttons.
Use `buttons.SetActiveByValue(value)` to update selection externally.
Returns buttons table and finalY offset for layout continuation.

### On/Off toggle (single-state)
```lua
local btn, refresh = OneWoW_GUI:CreateOnOffToggleButtons(parent, {
    onLabel = "On",
    offLabel = "Off",
    width = 50,
    height = 18,
    isEnabled = true,
    value = true,
    onValueChange = function(newValue)
        -- handle value change
    end,
    -- optional; defaults to shared TOGGLE_CLICK ("Click to turn %s")
    clickTooltipFormat = L["TOGGLE_CLICK"],
})
btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
-- Update state later:
refresh(isEnabled, newValue)
```
Single button shows the current state; click flips it. Tooltip uses `clickTooltipFormat`
with the *destination* label (`%s`).
On: `BG_FEATURES_ENABLED` fill + `TEXT_FEATURES_ENABLED` label.
Off: muted `BTN_NORMAL` chrome + `TEXT_FEATURES_DISABLED` label.
When disabled (`isEnabled=false`): muted / non-interactive (distinct from Off).
Defaults: height `TOGGLE_BUTTON_HEIGHT` (18), horizontal padding `TOGGLE_BUTTON_PADDING_X` (14).
Caller must `SetPoint` the button, or use `CreateToggleRow` below.
Returns `btn, refresh`.

### Feature header toggle (Enabled / Disabled)
```lua
local toggleBtn, refresh = OneWoW_GUI:CreateFeatureHeaderToggle(parent, {
    isEnabled = function()
        return Registry:IsEnabled("tooltips", featureId)
    end,
    onToggle = function(newState)
        Registry:SetEnabled("tooltips", featureId, newState)
    end,
    selectedRow = selectedRow,  -- optional; syncs list-row status dot
    -- optional; defaults to shared FEATURE_ENABLED / FEATURE_DISABLED
    onLabel = L["FEATURE_ENABLED"],
    offLabel = L["FEATURE_DISABLED"],
})
toggleBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
title:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
title:SetPoint("TOPRIGHT", toggleBtn, "TOPLEFT", -8, 0)
local headerHeight = math.max(title:GetStringHeight(), toggleBtn:GetHeight())
yOffset = yOffset - headerHeight - 8
-- After external enable changes:
refresh()
```
Thin wrapper around `CreateOnOffToggleButtons` for feature-master chrome on detail
headers (Toast Alerts, Tooltips, Overlays). Shows current state (not action verbs).
Caller owns layout (Features-style title left / toggle right). Replaces the old
`CreateFeatureStatusBlock` (`Status:` + Enable/Disable button).

### Toggle row (label + description/custom + On/Off)
```lua
local newYOffset, refresh, refs = OneWoW_GUI:CreateToggleRow(parent, {
    yOffset = 0,
    contentWidth = contentWidth, -- optional; required inside CreateCard (host width often 0 at build)
    label = "Show Lockouts Panel",
    description = "Show the lockouts panel when the Group Finder opens.",  -- optional
    value = true,
    isEnabled = true,
    onValueChange = function(newVal) SaveSetting("show_panel", newVal) end,
    onLabel = "On",   -- optional
    offLabel = "Off", -- optional
})
-- Update state later:
refresh(isEnabled, newValue)
-- refs.label, refs.button, refs.contentArea (nil if description used)
```
Two-column layout (default): left = title then description/`createContent`; right = On/Off
top-aligned with the title. Description/`createContent` anchor to the title’s bottom so wrap
changes on resize keep title→desc spacing. Description wraps in the left column only.
When `contentWidth` is set, the left column uses that fixed wrap width (avoids zero-width
truncation inside cards before the detail scroll child is sized). Without it, the label
stretches to the toggle via `RIGHT` anchors (fine when the parent already has a real width).
Use `align = "left"` for [Label] [On/Off] on one line (description still stacks under the label).
Use `createContent` instead of `description` for custom widgets (e.g. mount picker). Must return `(widget, height)`:
```lua
local newYOffset, refresh, refs = OneWoW_GUI:CreateToggleRow(parent, {
    yOffset = 0,
    label = "Ground Mount",
    createContent = function(container)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(220, 30)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        -- ... setup btn ...
        return btn, 30  -- widget, height (required)
    end,
    value = true,
    isEnabled = true,
    onValueChange = function(newVal) ... end,
})
```

### Checkbox
```lua
local cb = OneWoW_GUI:CreateCheckbox(parent, {
    name = "MyCheckbox",        -- optional, global frame name
    label = "Label text",       -- optional, default ""
    checked = true,             -- optional, initial checked state
    labelSide = "right",        -- optional, "right" (default) or "left"
    labelMaxWidth = 220,        -- optional, caps label width to prevent overlap
    wrap = false,               -- optional, allow label to wrap when capped
    onClick = function(self)    -- optional, fires on click
        local isChecked = self:GetChecked()
    end,
})

cb:GetMeasuredWidth()  -- box width + gap + (capped) label width
cb:GetMeasuredHeight() -- max(box height, label height)
```
Uses UICheckButtonTemplate. Access label via `cb.label`. Call `cb:GetChecked()` / `cb:SetChecked(bool)` for state. Use `labelMaxWidth` whenever the checkbox sits next to other widgets so the label cannot extend onto neighbors at large font sizes.

### Edit box
```lua
local box = OneWoW_GUI:CreateEditBox(parent, {
    name = "MyEditBox",
    width = 200,           -- optional, omit for anchor-based width (flexible)
    height = 22,           -- optional, default SEARCH_HEIGHT
    placeholderText = "Search...",  -- optional
    maxLetters = 50,       -- optional
    showClear = true,      -- optional; default on unless width is set and under 80
    clearTooltip = "Clear", -- optional; tooltip on the X (omit for no tooltip)
    onClear = function(box) end,  -- optional; after clear click
    onTextChanged = function(text)  -- optional, text has placeholder filtered out
        FilterMyList(text)
    end,
})
```
Themed with focus border highlight and placeholder text behavior.
When `width` is omitted, only height is set - use anchor points for flexible width.
Use `box:GetSearchText()` to get current text with placeholder filtered out.
`showClear` defaults on for stretch-width boxes and for fixed widths of 80 or more.
Pass `showClear = false` for cramped or numeric fields (gold/qty/id). Explicit
`true`/`false` always wins. With the X, right text inset reserves room so glyphs
do not sit under it.

`CreateScrollEditBox` (multiline notes, mail body, import/export) does not get an X.

For a raw `EditBox` (hub search, dropdown filter), reuse the same X:

```lua
OneWoW_GUI:AttachClearButton(box, {
    onClear = function(box) end,  -- optional; after clear click
    clearTooltip = "Clear",       -- optional
})
```

`AttachClearButton` hides the X when the box is empty or showing `box.placeholderText`,
and bumps the right inset if it is narrower than the X gutter. It wraps
`SetScript("OnTextChanged")` so a later replace (split-panel search filters) still
updates the X while typing. Prefer `onTextChanged` on `CreateEditBox` or
`HookScript` when layering your own filter.

Use `CreateEditBox` with `placeholderText` for search boxes. The deprecated `CreateSearchBox` wrapper has been removed.

### Entity ID field
Numeric ID input plus a resolved-name line. Optional load units register resolvers so `OneWoW_GUI` never depends on Catalog (or any other unit). Unregistered kinds stay a plain numeric edit box at the call site (`HasEntityResolver`).

```lua
OneWoW_GUI:RegisterEntityResolver("quest", {
    Resolve = function(id) ... end,              -- name, icon, quality, link
    RequestAsync = function(id, cb) ... end,     -- cb(id, info|nil)
})

local field = OneWoW_GUI:CreateEntityIdField(parent, {
    width = 160,
    height = 22,                 -- optional; ID box height
    placeholderText = "e.g. 86387",
    maxLetters = 12,
    kind = "quest",              -- must match a registered resolver
    onTextChanged = function(text) end,
})
field:GetText()        -- search text with placeholder filtered out
field:GetSearchText()  -- same
```

Async paints are token-guarded so a reused or hidden field never takes a late write. Name-line colors: TEXT_FEATURES_DISABLED (invalid), TEXT_WARNING (loading), TEXT_FEATURES_ENABLED (resolved).

### Value add row / entry list / item list editor

Shared chrome for “Item ID + Add + drop + list” panels (AutoOpen blacklist, BagBar
manual/blacklist, DirectDeposit keep/deposit). Callers own the data; these own
layout, theme, enable/disable, and refresh.

```lua
-- Add row only (chip drop beside Add, or panel drop via AttachDropTarget)
local addRow = OneWoW_GUI:CreateValueAddRow(parent, {
    yOffset = yOffset,           -- optional; else SetPoint yourself
    x = 12,                      -- optional with yOffset
    label = L["ITEM_ID"],
    addText = ADD,               -- or Keep / Add Item
    input = { kind = "itemId", width = 90, maxLetters = 10 },  -- or kind = "text"
    drop = {
        mode = "chip",           -- "chip" | "panel" | "none"
        text = L["DRAG_ITEM_HERE"],
        align = "right",         -- default: top-right of the row (above the list); "left" packs after Add
    },
    onAdd = function(value)      -- itemID or string; return false to keep input
        Save(value)
    end,
})
-- Panel drop: build outer frame, then:
-- addRow:AttachDropTarget(panelFrame)
addRow:SetEnabled(true)
addRow:Clear()

-- Entry list (grow packs height; height=N uses a scroll frame)
local list = OneWoW_GUI:CreateEntryList(parent, {
    yOffset = yOffset,
    grow = true,                 -- or height = 120 for fixed+scroll
    emptyText = L["NO_ITEMS"],
    getEntries = function()      -- must return an array
        return { { id = 12345, label = "Name", icon = texturePath, data = {} } }
    end,
    onRemove = function(id) Remove(id) end,
    -- optional: createRow(row, entry, api) -> height; api.RequestRefresh / IsEnabled / zebraIndex
    sortKey = "bagbar:blacklist", -- optional Name / Item ID toolbar; per-list preference
})
list:Refresh()
list:SetEnabled(true)

-- Composite (chip add-row + list + optional Clear All) — Features-style detail
local newY, editor = OneWoW_GUI:CreateItemListEditor(parent, {
    yOffset = yOffset,
    label = L["ITEM_ID"],
    addText = ADD,
    emptyText = L["NO_ITEMS"],
    drop = { text = L["DRAG_ITEM_HERE"] },  -- mode defaults to chip
    getEntries = function() ... end,
    onAdd = function(value) ... end,
    onRemove = function(id) ... end,
    sortKey = "autoopen:blacklist", -- forwarded to the inner entry list
    -- optional: onClearAll / clearText for a Clear footer under the list
})
editor:SetEnabled(moduleEnabled)
editor:Refresh()
```

`CreateItemListEditor` returns `(newYOffset, handle)`. Grow lists change height on
refresh; Features detail panels typically rebuild on toggle, so stacking below is fine.

`sortKey` (e.g. `"bagbar:blacklist"`) adds a Name / Item ID dropdown on that list
and stores the choice in core `itemListSort[sortKey]` (default name). Bespoke
lists (Bags category added items) call the same helpers:

```lua
OneWoW_GUI:GetItemListSort(listKey)           -- "name" | "id"
OneWoW_GUI:SetItemListSort(listKey, "id")
OneWoW_GUI:SortItemEntries(entries, listKey)  -- needs entry.id + entry.label
local drop = OneWoW_GUI:CreateItemListSortDropdown(parent, {
    sortKey = listKey,
    onChange = function() list:Refresh() end,
})
```

### Zebra fill (stacked list rows)

Odd rows use `BG_PRIMARY`, even rows `BG_SECONDARY`. Hover / selected / header
override. OnLeave must restore through this helper, not a hardcoded fill.

```lua
local key = OneWoW_GUI:GetZebraThemeKey(index)   -- "BG_PRIMARY" | "BG_SECONDARY"
OneWoW_GUI:ApplyListRowFill(row, {
    zebraIndex = index,     -- idle stripe
    selected = false,
    hover = false,
    header = false,
    fillKey = nil,          -- wins when set (quest section tints, zebra=false idle)
})
```

`CreateEntryList`, `CreateListRowBasic` (default on; `zebra = false` to opt out),
`CreateVirtualizer` (`row._zebraIndex` / `state.zebraIndex`), and Notes list
rows apply this automatically. `ClearFrame` resets the parent stripe sequence
used when `CreateListRowBasic` is not given `zebraIndex`.

### Status dot
```lua
local dot = OneWoW_GUI:CreateStatusDot(parent, {
    size = 8,          -- optional, default 8
    enabled = true,    -- optional, sets initial color (true=green, false=red)
})
dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
dot:SetStatus(true)   -- update: true=DOT_FEATURES_ENABLED, false=DOT_FEATURES_DISABLED
```

### List row (basic)
```lua
local row = OneWoW_GUI:CreateListRowBasic(parent, {
    height = 30,                -- optional, default 30
    label = "Item Name",        -- optional, default ""
    zebra = true,               -- optional, default true; false = flat BG_SECONDARY
    zebraIndex = i,             -- optional; else NextZebraIndex(parent)
    showDot = true,             -- optional, adds status dot on right
    dotEnabled = true,          -- optional, initial dot state
    showValueText = false,      -- optional, adds right-aligned value text
    valueText = "1.50",         -- optional, initial value text
    onClick = function(self)    -- optional
        previousRow:SetActive(false)
        self:SetActive(true)
    end,
})
row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)
```
Returns a Button with themed hover/active states. Properties:
- `row.label` - FontString (GameFontNormal)
- `row.dot` - StatusDot texture (if showDot=true), has `:SetStatus(bool)`
- `row.valueText` - FontString (if showValueText=true)
- `row:SetActive(bool)` - toggle active/selected styling
- `row.isActive` - current active state
- `row._zebraIndex` - stripe index when zebra is on

Future variants: `CreateListRowExtended` (expandable content section on click).

---

## Text & Dividers

### Header (large accent text)
```lua
local header = OneWoW_GUI:CreateHeader(parent, {
    text = "Section Title",
    yOffset = -12,
})
```

### Divider (1px horizontal line)
```lua
local divider = OneWoW_GUI:CreateDivider(parent, {
    yOffset = 0,
})
```

### Section (header + divider combo)
```lua
local newYOffset = OneWoW_GUI:CreateSection(parent, {
    title = "Section Title",
    yOffset = 0,
})
-- Returns updated yOffset to continue laying out below
```
Label + hairline only (not collapsible). Prefer
[Settings Cards](#settings-cards) (`CreateCard` / `CreateCardStack`) for new
multi-section settings detail panes. Keep using `CreateSection` where an
existing caller already depends on it.

### Vertical pane resizer (list + detail columns)
```lua
local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
-- Apply your addon’s backdrop styling to left/right panels before calling.
OneWoW_GUI:CreateVerticalPaneResizer({
    parent = tab,
    leftPanel = leftPanel,
    rightPanel = rightPanel,
    dividerWidth = 6,
    leftMinWidth = 200,
    rightMinWidth = 280,
    splitPadding = 16,              -- optional; default dividerWidth + 10
    bottomOuterInset = 5,
    rightOuterInset = 5,
    resizeCap = 0.95,
    mainFrame = hostWindow,         -- optional: iteratively widen until the tab fits desired left + min right
    getMinRightWidth = function() return 320 end,  -- optional dynamic minimum (e.g. unwrapped text width)
    maxAutoGrowSteps = 12,          -- optional; extra SetWidth passes if child width lags the host
    onWidthChanged = function(leftW) db.listPaneWidth = leftW end,
})
```
Caller anchors the left panel; only `SetWidth` on the left is updated. The right panel is re-anchored from the divider. **Clamp** (max left width and host resize) uses `rightMinWidth` only: `maxLeft = parentWidth - rightMinWidth - splitPadding`. With `mainFrame` and optionally `getMinRightWidth`, each drag tick **grows** the host (up to `resizeCap`) until `parent:GetWidth()` can satisfy `desiredLeft + max(rightMinWidth, getMinRightWidth()) + splitPadding`, so the window widens when the dynamic right column would be too narrow, without locking the divider when `getMinRightWidth()` is very large.

### Horizontal pane resizer (top + bottom stacks)
```lua
OneWoW_GUI:CreateHorizontalPaneResizer({
    parent = tab,
    topPanel = topPanel,
    bottomPanel = bottomPanel,
    dividerHeight = 6,
    topMinHeight = 100,
    bottomMinHeight = 60,
    onHeightChanged = function(bottomHeight)
        -- optional: persist after mouse release (callback receives bottom panel height)
    end,
})
```
Caller anchors the top panel from the parent top; only `SetHeight` on the top panel is updated during drag. The bottom panel is re-anchored from the divider to the parent bottom.

---

## Section Headers

### Themed section header bar
```lua
local section = OneWoW_GUI:CreateSectionHeader(parent, {
    title = "Section Title",
    yOffset = 0,
})
-- section.bottomY = yOffset below the header for continued layout
```
Creates a themed bar with background, border, and accent-colored title text.
Auto-grows in height when the title wraps (e.g. larger fonts).
Optional `fontSize` (default 12) for larger top-level headers.
Not collapsible — for collapsible bordered sections use
[Settings Cards](#settings-cards).

### Database Manager row
```lua
local step = OneWoW_GUI:CreateDatabaseManagerRow(parent, {
    name = "Catalog Core",
    description = "Main addon settings and UI state.",
    addonKey = "OneWoW_Catalog",
    yOffset = yOffset,
    getEntryCount = function()
        -- return number, or nil when the SV is not loaded
        return 2
    end,
})
yOffset = yOffset - step
```
Shared Catalog/AltTracker settings row: left-aligned name + description, right column
Entries + Reset (same width/chrome). Reset is soft-disabled with a tooltip when
`OneWoW:GetFeatureUnitState(addonKey)` is not enabled. Confirm wipe uses shared
`DATABASE_MANAGER_*` locale keys. Implemented in `GUI/DatabaseManager.lua`.

### Hero panel
```lua
local hero = OneWoW_GUI:CreateHeroPanel(parent, {
    title = "Build Your Setup",
    subtitle = "Pick the tools you want.",
    description = "Use a preset, then fine-tune each card.",
    iconTexture = OneWoW_GUI:GetBrandIcon("neutral"),
    calloutText = "Smart setup wizard",
    yOffset = -10,
})
```
Creates a branded accent panel for onboarding, empty states, or feature introductions. The panel **self-measures** its real height after content and any `fontSizeOffset` is applied; `hero.bottomY` is updated automatically. Use `hero:OnHeightChanged(function(panel, h) ... end)` to react to growth.

### Summary strip
```lua
local summary = OneWoW_GUI:CreateSummaryStrip(parent, {
    yOffset = hero.bottomY - 8,
    items = {
        { label = "Selected addons", value = "7 / 9" },
        { label = "Data modules", value = "11" },
        { label = "Reload state", value = "Ready" },
    },
})
summary:SetItemValue(1, "8 / 9")
```
Creates a horizontal row of themed stat boxes. Self-measures and grows in height when the value/label strings would clip. Use `SetItemValue(index, value)` for live updates.

### Selectable card
```lua
local card = OneWoW_GUI:CreateSelectableCard(parent, {
    title = "AltTracker",
    summary = "Cross-character dashboard for progress, gold, professions, bank, auctions, and lockouts.",
    badgeText = "Core Features",
    iconTexture = "Interface\\Icons\\Achievement_Guild_ClassyDwarf",
    iconPlate = true, -- false skips the BG_TERTIARY icon well (ringless feature faces)
    checked = true,
    onToggle = function(card, checked) end,
})
card:SetChecked(false)
```
Creates a checkbox-backed feature card with icon, badge, hover state, and selected styling. The card **self-measures** its real height from the wrapped summary text (and icon), so it never clips at large fonts. Use `card:GetMeasuredHeight()` or `card:OnHeightChanged(...)` if a parent layout needs to re-flow when text wraps.

---

## Settings Cards

Collapsible titled settings sections (`GUI/Cards.lua`). Prefer these over
`CreateSection` / `CreateSectionHeader` for new multi-section settings detail
panes (QoL Overlays is the reference consumer). Distinct from
`CreateSelectableCard` (feature-picker checkboxes above).

### CreateCard
```lua
local card = OneWoW_GUI:CreateCard(parent, {
    title = L["SECTION_TITLE"],
    collapsed = false,  -- optional; default expanded
    onToggle = function(collapsed)
        -- optional; fired after the header click flips state
    end,
})
-- Build into card.content, then size:
card:SetContentHeight(contentHeight)
```
Full-width bordered card: themed header bar (chevron + title) over a padded
`card.content` area. Header click toggles collapse; when collapsed only the
header height remains. Methods: `card:IsCollapsed()`, `card:SetContentHeight(h)`.

Callers usually go through `CreateCardStack` rather than wiring cards by hand.

### CreateCardStack
```lua
-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local stack = OneWoW_GUI:CreateCardStack(detailScrollChild, {
    getCollapsed = function(key) return collapsedCards[key] end,
    setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    -- marginX = 4, startY = -6, gap = 8  -- optional layout knobs
})
stack.OnRelayout = function()
    split.UpdateDetailThumb()  -- when hosted in a split detail pane
end

-- Optional non-card frame above the cards (hero / title block):
stack:AddFrame(heroFrame)

stack:AddCard("detection", L["DETECTION"], function(content, contentWidth)
    -- parent widgets to `content`; return content height
    -- Pass contentWidth into CreateToggleRow / SetWidth wrapped intros before
    -- GetStringHeight. Card hosts often still have width 0 at build time —
    -- LEFT+RIGHT anchors then truncate with "..." and absolute yOffsets explode
    -- on the first detail OnSizeChanged (e.g. clicking the resize handle).
    return height
end)

stack:Finish()  -- Relayout + ApplyFontToFrame + host width reflow hook
```
Owns vertical packing, content-width measurement, and optional collapse
persistence via `getCollapsed` / `setCollapsed`. Default expanded when the
store has no entry for a key. `Relayout` sizes the host flush to the last
card (gap only *between* cards); scroll breathing room stays on the caller
(`SetHeight(... + 20)`). After `Finish`, the stack watches host `OnSizeChanged`
and rebuilds card bodies when width changes (debounced) so wrap/controls track
window resize. Initial build waits for a real host width (or stays hidden for
one frame) so selecting a feature does not flash a fallback-width layout.

**Migration template:** QoL Overlays (`OneWoW_QoL/UI/t-overlays.lua`) —
`NewCardStack` + hero via `AddFrame` + section bodies via `AddCard` +
`Finish`. Keep feature title / Enabled chrome above or in the hero; put only
settings **sections** in cards.

---

## Stacking & Action Bars

These primitives replace hand-rolled `rowY = rowY + fixedHeight` chains and any layout that puts two clusters on the same row at risk of overlapping.

### Stack vertically (no overlap, ever)
```lua
local stack = OneWoW_GUI:StackVertically(content, {
    header,
    card1,
    card2,
    card3,
}, {
    gap = OneWoW_GUI:GetSpacing("SM"),  -- default gap between rows
    topPadding = 8,                      -- initial Y offset
    sidePadding = 12,                    -- horizontal inset
    onLayout = function(totalHeight) end,
    autoHeight = true,                   -- parent:SetHeight(totalHeight)
})

stack:Add(extraCard)         -- append a child later
stack:Refresh()              -- re-measure on demand
```
Anchors each child `TOPLEFT/TOPRIGHT` inside `parent` using its **measured** height (calling `child:GetMeasuredHeight()` if available, else `child:GetHeight()`). Re-runs whenever any child fires `OnSizeChanged` or notifies via `OnHeightChanged`. Use this everywhere instead of `rowY = rowY + SOME_CONSTANT`.

### Action bar (left + right, auto-wraps when narrow)
```lua
local bar = OneWoW_GUI:CreateActionBar(parent, {
    yOffset = -OneWoW_GUI:GetSpacing("MD"),
    insetX = 12,
    gap = OneWoW_GUI:GetSpacing("MD"),
})

-- Fill bar.left and bar.right with widgets:
local presetBtn = OneWoW_GUI:CreateFitTextButton(bar.left, { text = "Preset", height = 26 })
presetBtn:SetPoint("LEFT", bar.left, "LEFT", 0, 0)

local applyBtn = OneWoW_GUI:CreateFitTextButton(bar.right, { text = L.APPLY, height = 26 })
applyBtn:SetPoint("RIGHT", bar.right, "RIGHT", 0, 0)

bar:Refresh()
```
If the combined measured width of `bar.left` and `bar.right` would overflow the bar, the bar automatically stacks them on two rows (left on top, right below) and grows its own height. `bar.bottomY` always reflects the current measured height. Use this any time you have a "checkbox + button" or "left toolbar + right toolbar" pattern that previously used hardcoded TOPLEFT/TOPRIGHT anchors on the same row.

---

## Scroll Frames

### Standalone scroll frame
```lua
local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(parent, {
    name = "MyScroll",  -- optional, nil for anonymous
    width = 400,        -- optional; omit for auto-sync on resize
})
```
Uses UIPanelScrollFrameTemplate (Lesson 3 compliant).
ScrollBar anchored to parent container.
- Without width: content width auto-syncs on resize, minus `SCROLLBAR_CONTENT_GUTTER` only while the bar is shown.
- With width: content width set to (width - 32).
- The bar hides when the child fits (range floors to 0). Mouse wheel still works if content grows. Do not set Blizzard `scrollBarHideable` on these frames — it re-shows the up/down buttons the skin strips. Always-hide surfaces (Bags, Notes pin list, Crafting Orders) call `OneWoW_GUI:SetScrollBarAlwaysHidden(scrollFrame, true)` so the bar stays hidden even when the list overflows.

### Scrollable multiline edit box
```lua
local scrollFrame, editBox = OneWoW_GUI:CreateScrollEditBox(parent, {
    name = "MyEditBox",        -- optional; scrollFrame gets name.."Scroll"
    font = fontPath,           -- optional; falls back to user's chosen GUI font, then ChatFontNormal
    fontSize = 12,             -- optional, default 12 (used when font is set)
    fontFlags = "",            -- optional, default ""
    maxLetters = 0,            -- optional, default 0 (unlimited)
    textInsets = { 4, 4, 4, 4 },  -- optional, {left, right, top, bottom}, default 4px all sides
    textColor = { r, g, b },  -- optional; defaults to TEXT_PRIMARY theme color
    onTextChanged = function(self, userInput)  -- optional
        -- fires on every keystroke
    end,
    onEscapePressed = function(self)  -- optional
        -- fires after ClearFocus() is already called
    end,
})
```
Correct pattern for multiline text entry areas. Fixes the focus dead-zone bug inherent to
`SetHeight(1)` scroll children: clicking anywhere in the visible area always focuses the edit box.
Also wires Blizzard `ScrollingEdit_OnCursorChanged` / `ScrollingEdit_OnUpdate` so the scroll
frame follows the caret while typing.

- ScrollFrame uses `UIPanelScrollFrameTemplate` with styled scrollbar.
- EditBox is the scroll child, starts at height 1 and auto-expands with content.
- Width auto-syncs to scrollFrame on resize, minus `SCROLLBAR_CONTENT_GUTTER` (kept even
  when the bar hides, so glyphs do not jump under a later-appearing thumb). The right
  text inset also clears the thumb.
- `scrollFrame:HookScript("OnMouseDown")` calls `editBox:SetFocus()` so clicks anywhere in the
  visible area work, not just the first pixel row.
- Cursor scroll-follow via `ScrollingEdit_OnCursorChanged` + `ScrollingEdit_OnUpdate`.
- Font defaults to the user's active GUI font setting, then `ChatFontNormal`.
- Default anchor: TOPLEFT +8,-8 / BOTTOMRIGHT -8,8 relative to parent. Override after creation if needed.

Use this instead of manually creating `ScrollFrame + EditBox` pairs. Migrate existing scroll+editbox
combos to this function to get the focus fix and caret scroll-follow for free.

### Virtualized lists (`GUI/Virtualizer.lua`)

Domain-agnostic scroll-windowing for large flat lists (same “engine + callbacks”
shape as `CreateReorderDrag`). The engine owns the scroll frame (or an adopted
one), row pool, scroll→index mapping, content height, selection, and optional
keyboard nav. Consumers own data getters and row chrome.

**Core API — `CreateVirtualizer`:**

```lua
local list = OneWoW_GUI:CreateVirtualizer(listHostFrame, {
    name = "MyList",
    rowHeight = 22,                    -- fixed stride (default)
    -- getRowHeight = function(i) return heights[i] end,  -- optional variable layout
    numVisibleRows = 40,
    getCount = function() return #myData end,            -- required
    getEntry = function(index) return myData[index] end, -- required
    onSelect = function(index, entry) end,               -- optional; enables click-select
    isSelectable = function(index, entry) return true end, -- optional; mixed lists skip headers
    createRow = function(content, api)                   -- optional factory
        local btn = CreateFrame("Button", nil, content)
        -- build child widgets once
        return btn
    end,
    bindRow = function(row, index, entry, state)         -- rebind on scroll
        -- state.selected is true when this index is selected
        row:SetText(entry.displayName or tostring(entry))
        row._tooltipFullText = entry.tooltipText
    end,
    enableKeyboardNav = true,
    focusCompetitor = searchEditBox,
    -- scrollFrame / content = adopt an existing scroll pair (optional)
})
list.Refresh()
list.SetSelectedIndex(1)
```

- **Fixed vs variable height:** omit `getRowHeight` for uniform `rowHeight` stride;
  supply `getRowHeight(index)` to rebuild prefix sums on each `Refresh` (Catalog
  Vendors is the reference consumer).
- **Expand-in-list:** not engine-owned. Flatten child rows into `getEntry` (Catalog
  Quests pattern), then `Refresh()`. Do not use variable-height detail panels under
  a parent row for virtualized surfaces. If the flattened list includes headers
  (groups, sections), pass `isSelectable(index, entry)` so click-select and
  keyboard nav skip those rows. Do not turn `selectOnClick` off and hand-roll
  selection; extra `OnClick` work (expand, shift-click) sits on the row and the
  engine still hooks left-click select.
- **Selection chrome:** `bindRow` reads `state.selected` into `_rowSelected`.
  `OnEnter` / `OnLeave` only re-apply row chrome with that flag. Do not recolor
  title text for hover or select (Catalog Journal / Vendors / Item Search).
- **`createRow` / `bindRow`:** create widgets once; bind on every visible update.
  Nested controls must read `row.entryIndex` (live), not a closed-over create-time index.
- **Reorder on a pooled list:** set `row._reorderIndex` in `bindRow` to the data-bag
  index (not the flattened or pool index). `CreateReorderDrag` prefers that field.
  Attach once in `createRow`. Rows mid-drag (`_oneWoWReorderOrigPoints`) are skipped
  so auto-scroll does not steal the ghost.
- **Tooltips:** set `row._tooltipFullText`; the engine wires `OnEnter`/`OnLeave` when
  the row has no `OnEnter` yet.
- **Adopted scroll:** pass `scrollFrame` + `content` to host inside `CreateSplitPanel`
  (or similar) instead of creating a new scroll frame. When adopting, the engine
  hooks `OnVerticalScroll` rather than replacing it. Catalog Item Search, Quests,
  and Vendors are the reference consumers (Quests also shows flatten-expand via
  `BuildQuestListEntries` + `Refresh`).

### Chunked jobs (large data walks)

For building or filtering very large result sets without hitching the client, use
`OneWoW.ChunkedJob` (`Services/ChunkedJob.lua`) — a time-budgeted coroutine runner
(`budgetMs`, default 8). Pair with a virtualized list: the job fills the data
array progressively; the virtualizer paints only visible rows.

```lua
local job = OneWoW.ChunkedJob.Start({
    budgetMs = 8,
    run = function(shouldYield)
        for i = 1, n do
            doWork(i)
            OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
        end
        -- Large in-place sorts: OneWoW.ChunkedJob.Sort(arr, cmp, shouldYield)
    end,
    onProgress = function() list.Refresh() end,
    onComplete = function() ... end,
})
job:Cancel()
```

Catalog Item Search (`StartQuery`) and DevTool SoundBrowser (all-catalog filter)
are the first consumers.

Returns: `listPanel`, `listScroll`, `listContent`, `Refresh`, `SetSelectedIndex`,
`GetSelectedIndex`, `ownedScroll`.

**Compatibility — `CreateVirtualizedList`:** thin wrapper that still requires
`onSelect` and accepts legacy `renderRow(btn, index, entry, isSelected)` (mapped to
`bindRow`). Prefer `CreateVirtualizer` + `createRow`/`bindRow` for new call sites.
All four DevTool browse tabs (Texture, Sound, Font, Globals) use `CreateVirtualizer`.

### Style an existing scroll bar
```lua
OneWoW_GUI:StyleScrollBar(scrollFrame, {
    container = parentFrame,  -- optional, anchors scrollbar to this
    offset = -2,              -- optional, right offset
    alwaysHidden = false,     -- optional; same as SetScrollBarAlwaysHidden(true)
})
```

Lower-level (same styling as above): `OneWoW_GUI:ApplyScrollBarStyle(scrollFrame.ScrollBar, containerFrame, -2)`

`SetScrollBarAlwaysHidden(scrollFrame, hidden)` — force-hide for a caller-owned “hide scrollbar” toggle. Wheel still scrolls. Pass `false` to return to hide-when-unscrollable.

`CreateScrollFrame` (default and `layoutRightInset`), `CreateSplitPanel`, and owned `CreateVirtualizer` scrolls reclaim the gutter when the bar hides. `CreateScrollEditBox` does not.

---

## Split Panel (List + Detail Layout)

```lua
local panels = OneWoW_GUI:CreateSplitPanel(parent, {
    showSearch = true,              -- optional search box in list panel
    searchPlaceholder = "Search...",-- optional placeholder text for search box
    hideTitles = false,             -- optional; omit Instances/Details-style panel titles and reclaim space
})
```

Returns a table with:
- `panels.listPanel` - left panel frame
- `panels.listTitle` - left title font string
- `panels.listScrollFrame` / `panels.listScrollChild` - left scroll area
- `panels.detailPanel` - right panel frame
- `panels.detailTitle` - right title font string
- `panels.LayoutDetailHeader` - inset `detailContainer` for a panel-anchored control strip (old Catalog 38px header). Controls stay on `detailPanel`; do not re-anchor the scroll frame (that fights `bindSplitScrollGutter`).
- `panels.detailScrollFrame` / `panels.detailScrollChild` - right scroll area
- `panels.searchBox` - search edit box (if showSearch=true)
- `panels.leftStatusBar` / `panels.leftStatusText` - left status bar
- `panels.rightStatusBar` / `panels.rightStatusText` - right status bar

Left panel width: 320px. Gap between panels: 10px.

```lua
panels.LayoutDetailHeader({ height = 38 })   -- reserve the old 38px control strip
panels.LayoutDetailHeader({ height = 0 })    -- restore the default container inset
```

---

## Dropdowns

### Simple dropdown (no search)
```lua
local dropdown, text = OneWoW_GUI:CreateDropdown(parent, {
    width = 200,     -- optional, default 200
    height = 26,     -- optional, default 26
    text = "All",    -- optional, default display text
})
dropdown:SetPoint("LEFT", someFrame, "RIGHT", 8, 0)

OneWoW_GUI:AttachFilterMenu(dropdown, {
    searchable = false,  -- default is true
    buildItems = function()
        return {
            { value = nil, text = "All Characters" },
            { value = "char1", text = "Arthas" },
            { value = "char2", text = "Thrall" },
        }
    end,
    onSelect = function(value, displayText)
        text:SetText(displayText)
        -- do something with value
    end,
    getActiveValue = function() return currentSelection end,
})
```

### Searchable dropdown (with filter box)
```lua
local dropdown, text = OneWoW_GUI:CreateDropdown(parent, {
    width = 200,
    text = "All Zones",
})
dropdown:SetPoint(...)

OneWoW_GUI:AttachFilterMenu(dropdown, {
    searchable = true,  -- default; adds search box at top of menu
    buildItems = function()
        local items = {}
        tinsert(items, { value = nil, text = "All Zones" })
        for _, zone in ipairs(GetZoneList()) do
            tinsert(items, { value = zone, text = zone })
        end
        return items
    end,
    onSelect = function(value, displayText)
        text:SetText(displayText)
    end,
    getActiveValue = function() return currentZone end,
    maxVisible = 20,     -- optional, default 20 (unlimited when searching)
    menuHeight = 314,    -- optional, default 314
    menuWidth = 200,     -- optional; default trigger width + 20 (min 120)
})
```

### Dropdown behavior
- Click to open, click again to close
- Active item highlighted with ACCENT_PRIMARY
- Hover: BG_HOVER + TEXT_ACCENT
- Item labels use 12pt by default (override with per-item `fontSize`); no word wrap
- Optional per-item `filterKey`: string used for searchable filtering (defaults to the label). Use when the visible label differs from what should match (e.g. aliases).
- Optional per-item `tooltip`: string body (title = `text`), or `{ title, desc }`
- Auto-closes after 0.5s when mouse leaves both menu and trigger button
- ESC: clears search text first, closes menu on second press (searchable only)
- Menu opens at DIALOG strata (above the host window)
- buildItems() called fresh each click (supports dynamic lists)
- Scroll uses UIPanelScrollFrameTemplate (Lesson 3 compliant)
- `menuWidth` keeps short triggers (e.g. "New") from crushing item text

### Dismiss architecture (OnUpdate hybrid)

`AttachFilterMenu` uses a two-layer dismiss system to close the menu when the user clicks outside it, without consuming the click:

1. **OnUpdate watcher** — The menu runs an `OnUpdate` script that detects mouse-button-down transitions (via `IsMouseButtonDown`) while `IsMouseOver()` is false. Because WoW processes input (delivering `OnClick` to the topmost control) **before** running `OnUpdate`, the clicked control fires first and then the menu hides — both in the same frame. This gives single-click tab switching, sidebar navigation, etc. while a menu is open.

2. **Game-world overlay** — A fullscreen `UIParent` Button sits **below** the host window (`hostLevel - 2`, same strata). It only catches clicks in areas not covered by the host — primarily the 3D game world — preventing unintended NPC targeting or spell casts while a dropdown is open.

Callers do **not** need to add `CloseAttachFilterMenu()` at navigation boundaries (tab switches, list selection, etc.) — the OnUpdate handles dismiss automatically.

`OneWoW_GUI:CloseAttachFilterMenu()` remains available for programmatic teardown (e.g. before reparenting a host frame) but is not required for normal use.

### Reset dropdown text externally
```lua
text:SetText("All Zones")
dropdown._activeValue = nil
```

---

## Icon Skinning System

Unified icon/item slot skinning for all suite addons. Replaces default WoW icon borders with themed, consistent styling.

### Style presets

| Preset | Border | Trim | Highlight | Use case |
|--------|--------|------|-----------|----------|
| `clean` | 1px | Yes | 0.3 alpha | Default - item slots, gear displays |
| `thick` | 2px | Yes | 0.3 alpha | Emphasized icons, headers |
| `minimal` | 1px | Yes | 0.2 alpha | Compact lists, small icons |
| `none` | 0 | Yes | None | Raw icon, no decoration |

### Create a new skinned icon
```lua
local icon = OneWoW_GUI:CreateSkinnedIcon(parent, {
    size = 36,                -- optional, default 36
    preset = "clean",         -- optional, style preset name
    iconTexture = texturePath,-- optional, icon texture
    itemID = 12345,           -- optional, auto-resolves texture via GetItemIcon
    itemLink = link,          -- optional, enables item tooltip on hover
    quality = 4,              -- optional, colors border by rarity (>1 overrides theme border)
    showIlvl = true,          -- optional, item level text bottom-right
    itemLevel = 623,          -- optional, displayed when showIlvl is true
    showCount = true,         -- optional, stack count text bottom-right
    count = 5,                -- optional, displayed when showCount is true (hidden if <= 1)
    tooltip = "My tooltip",   -- optional, string or function(self) for custom tooltip
    onClick = function(self, button) end,  -- optional, click handler
    onEnter = function(self) end,          -- optional, additional hover behavior
    onLeave = function(self) end,          -- optional, additional leave behavior
    borderColorKey = "BORDER_DEFAULT",     -- optional, theme color key for border
    hoverBorderColorKey = "BORDER_ACCENT", -- optional, theme color key on hover
    desaturate = false,       -- optional, gray out icon
})
icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
```

Returns a frame with skinned internals. Access via:
- `icon._skinnedIcon` — the icon texture
- `icon._skinBorder` — the border frame
- `icon._skinHighlight` — the highlight texture
- `icon._ilvlText` / `icon._countText` — overlay text FontStrings

### Skin an existing icon frame
```lua
OneWoW_GUI:SkinIconFrame(existingFrame, {
    preset = "clean",         -- optional, style preset
    quality = 3,              -- optional, rarity border color
    trimIcon = true,          -- optional, trims blurry WoW icon edges
    bgAlpha = 0.9,            -- optional; 0 hides the black well
    borderSize = 1,           -- optional, override preset border
    desaturate = false,       -- optional, gray out
    iconTexture = newTexture, -- optional, swap texture
    borderColorKey = "BORDER_DEFAULT",
    hoverBorderColorKey = "BORDER_ACCENT",
})
```
Finds the first texture on the frame and applies trimming, border, background, and highlight. Works on any frame that has a texture child (item buttons, action buttons, etc.).

### Update helpers
```lua
OneWoW_GUI:UpdateIconQuality(frame, 4)           -- change rarity border color
OneWoW_GUI:UpdateIconTexture(frame, newTexture)   -- swap icon texture
OneWoW_GUI:SetIconDesaturated(frame, true)        -- toggle grayscale
```

### Create a row of icons
```lua
local row = OneWoW_GUI:CreateIconRow(parent, {
    icons = {
        { iconTexture = tex1, quality = 3, itemLink = link1 },
        { iconTexture = tex2, quality = 4, itemLink = link2 },
    },
    iconSize = 36,        -- optional, default 36
    spacing = 4,          -- optional, gap between icons
    preset = "clean",     -- optional, default preset for all icons
})
row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
-- Access individual icons: row._icons[1], row._icons[2], etc.
```

### Skin a cooldown frame
```lua
OneWoW_GUI:SkinCooldown(cooldownFrame, {
    swipeR = 0, swipeG = 0, swipeB = 0, -- optional, swipe color (default black)
    swipeAlpha = 0.6,    -- optional, swipe opacity
    hideEdge = true,     -- optional, hide edge texture (default true)
    hideBling = true,    -- optional, hide bling texture (default true)
})
```

### Get a preset table
```lua
local preset = OneWoW_GUI:GetIconStylePreset("clean")
-- Returns: { borderSize=1, padding=1, trimIcon=true, showHighlight=true, highlightAlpha=0.3, bgAlpha=0.9 }
```

---

## Additional Components

These components exist in the library but are not fully documented here. See source for option keys.

- **CreateSlider(parent, options)** — minVal, maxVal, step, currentVal, onChange, width, fmt. Optional `getLabel(pos) -> string` overrides the default `string.format(fmt, pos)` display (also used for the Low/High tick labels). Optional `getValue(pos) -> any` maps slider position to a domain value; when provided, `onChange` is called as `onChange(mappedValue, pos)` instead of `onChange(pos)`. Return value: a container frame with `.slider` and `.valLabel` fields for external access (e.g. to `Enable()`/`Disable()` the underlying slider). Uses **`ConfigureOptionsSliderEnds`** internally for Low/High strings.

### ConfigureOptionsSliderEnds (OptionsSliderTemplate)

When building **`OptionsSliderTemplate`** sliders manually (custom layout), call **`OneWoW_GUI:ConfigureOptionsSliderEnds(slider, lowText, highText)`** after **`SetMinMaxValues`** / value setup. It applies **`slider.Low` / `slider.High`** (with **`_G[name.."Low"]`** fallback), **`HookScript("OnShow", …)`** once per slider, and stores texts so endpoints stay correct after **`ClearFrame`** + widget reuse (Blizzard otherwise restores localized “Low”/“High”).
- **CreateProgressBar(parent, options)** — progress bar with theme colors
- **CreateDataTable(parent, options)** — table with `ClearDataRows`, `LayoutDataRows`, `CreateDataRow`, and `SetColumns(newColumns)`. `SetColumns` swaps the column set at runtime: it tears down the old header buttons, rebuilds them for the new columns (re-running `onHeaderCreate`), and relayouts — so one table can switch between column sets / view-modes. Callers re-render their rows against the new layout afterward.
- **CreateOverviewPanel(parent, options)** — overview layout; optional `title` (omit when the hub nav already names the screen)
- **CreateMetricPanel(parent, options)** — Splunk-style single-value panel (`label`, `height`, `ttTitle`, `ttDesc`). Header: label left; optional high/low (`SetRange`) stacked upper-right (H above L). Methods: `SetValue(text, {color})`, `SetDelta(text, {tone})` (`up`/`down`/`neutral`) under the hero value, `SetRange(highText, lowText)`, `SetSparkline(values, {bipolar})` (texture-pool spark, max 48 points, no OnUpdate), `SetTooltipExtra(lines)`, `SetLabel(text)`.
- **CreateStatusBar(parent, anchorFrame, options)** — status bar
- **CreateRosterPanel(parent, anchorFrame)** — roster layout
- **CreateItemIcon(parent, options)** — item icon frame (legacy, use CreateSkinnedIcon for new code)
- **CreateFactionIcon(parent, options)** — faction icon
- **CreatePortraitWithFaction(parent, options)** — player portrait with a corner faction badge (`:SetUnit`, `:SetFaction`, `:SetClassBorder`)
- **CreateItemAlertRow(parent, options)** — one-line Item Alert row (Shopping List, notes, Trackers, Farming). `SetHits` shows `Title: (N)`, hits left of ASCII `|`, idle icons on the right. Empty left uses Blizzard `NONE`; full right uses `manyLabel`. Optional `interactive` + `onClick`.
- **CreateMailIcon(parent, options)** — mail icon
- **CreateExpandedPanelGrid(ef, options)** — expanded panel grid

**Utility:**
- `GetProgressColor(current, max)` — returns color from PROGRESS_COLORS (NONE/LOW/MID/FULL)
- `GetItemQualityColor(quality)` — returns r, g, b, a for item rarity (respects accessibility settings)

Formatting, secret-value, restriction, and addon-version utilities live on the
OneWoW core namespace, not in this library: `OneWoW.Format.FormatNumber` /
`OneWoW.Format.FormatGold`, `OneWoW.Restriction.IsSecret` /
`OneWoW.Restriction.IsAddonRestricted`, `OneWoW:GetAddonVersion`,
`OneWoW:GetExpansionName` (see `OneWoW/Core/Format.lua`, `Restriction.lua`,
`Util.lua`).

---

## Side Bar Tabs

Shared helpers for vertical icon tabs docked to the right edge of a host frame
(e.g. `MerchantFrame`, `AuctionHouseFrame`). Used by QoL vendor panel and
`OneWoW_AltTracker_Auctions` AH Prices panel.

**Source:** `OneWoW/GUI/SideBarTabs.lua`

```lua
local OneWoW_GUI = OneWoW_GUI

local sidebar = OneWoW_GUI:EnsureSideBar(MerchantFrame, "OneWoWMerchantSideBar")

local tab = OneWoW_GUI:CreateSideBarTab(sidebar, {
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
    tooltip = "My panel",
    onToggle = function(show)
        myPanel:SetShown(show)
    end,
    repositionOpts = {
        hostFrame = MerchantFrame,
        dockedPanel = myPanel,
        anchoredTab = tab,
        defaultHost = MerchantFrame,
    },
})

OneWoW_GUI:RepositionSideBar(sidebar, repositionOpts)
```

- **`EnsureSideBar(host, globalName)`** — returns the sidebar frame (`sidebar.Tabs`, `sidebar.selTab`).
- **`CreateSideBarTab(sidebar, opts)`** — returns `tab, tabIndex`; exclusive selection via `DeselectOtherSideBarTabs`.
- **`RepositionSideBar(sidebar, opts)`** — anchors to `dockedPanel` when shown, else `hostFrame`.

---

## Utility

### Clear all children from a frame
```lua
OneWoW_GUI:ClearFrame(frame)
```
Hides and orphans all child frames and regions.

---

## Available Backdrop Templates

```lua
Constants.BACKDROP_SIMPLE        -- just bgFile (white8x8)
Constants.BACKDROP_SOFT          -- tooltip bg + tooltip border, with insets
Constants.BACKDROP_INNER         -- white8x8 bg + 1px edge, with 1px insets
Constants.BACKDROP_INNER_NO_INSETS  -- white8x8 bg + 1px edge, no insets
```

---

## GUI Dimension Defaults

```
WINDOW_WIDTH = 1075     MIN_WIDTH = 1075      MAX_WIDTH = 2000
WINDOW_HEIGHT = 900     MIN_HEIGHT = 700      MAX_HEIGHT = 1200
PADDING = 12            BUTTON_HEIGHT = 28    BUTTON_WIDTH = 100
SEARCH_HEIGHT = 22      SEARCH_WIDTH = 200    CHECKBOX_SIZE = 24      ICON_BUTTON_SIZE = 20
ROW1_HEIGHT = 35        ROW2_HEIGHT = 30        ROW2_FAVORITE_HEIGHT = 22
LEFT_PANEL_WIDTH = 320  PANEL_GAP = 10        TAB_BUTTON_HEIGHT = 30
TOGGLE_BUTTON_WIDTH = 50  TOGGLE_BUTTON_HEIGHT = 18  TOGGLE_BUTTON_PADDING_X = 14
VALUE_ADD_ROW_HEIGHT = 22  VALUE_ADD_INPUT_WIDTH = 90  VALUE_ADD_CHIP_WIDTH = 110
ENTRY_LIST_ROW_HEIGHT = 22  ENTRY_LIST_EMPTY_HEIGHT = 28
HERO_PANEL_HEIGHT = 118  SUMMARY_STRIP_HEIGHT = 66
SELECTABLE_CARD_HEIGHT = 68  SELECTABLE_CARD_ICON_SIZE = 38
BADGE_HEIGHT = 18       ACTION_BAR_HEIGHT = 34
WIZARD_DIALOG_WIDTH = 820  WIZARD_DIALOG_HEIGHT = 680
```

### Adding OneWoW_GUI to a new addon

Add `## RequiredDeps: OneWoW` to your TOC. The toolkit ships inside the core
addon (`OneWoW/GUI/`, listed before all other core files), so the `OneWoW_GUI`
global and its settings DB are guaranteed to exist before your files load.

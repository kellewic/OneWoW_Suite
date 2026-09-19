# OneWoW_Bags — Architecture

> **See also:** [Docs index](README.md) · [Categorization](CATEGORIZATION.md) · [Search syntax](SEARCH_SYNTAX.md) · [Import/export](IMPORT_EXPORT.md) · [Item-button API](ITEM_BUTTON.md) · [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md)

## Contents

- [Overview](#overview)
- [File Tree & Load Order](#file-tree--load-order)
- [Architectural Pattern](#architectural-pattern)
- [Data Flow](#data-flow)
- [Key Components In Detail](#key-components-in-detail)
- [Window Architecture](#window-architecture)
- [Event System](#event-system)
- [Database Schema](#database-schema)
- [Integration Points](#integration-points)
- [Blizzard Frame Suppression](#blizzard-frame-suppression)
- [Refresh Targets](#refresh-targets)
- [Performance Patterns](#performance-patterns)
- [Custom Category System](#custom-category-system)
- [View Context Pattern](#view-context-pattern)

## Overview

OneWoW_Bags is a unified bag/bank/guild bank replacement addon for World of Warcraft. It replaces consolidated Blizzard bag presentation with a single window per context (inventory, bank, guild bank). The addon is part of the OneWoW Suite and depends on `OneWoW` (hub loader, minimap, overlay/junk/upgrade integrations, and the `OneWoW_GUI` toolkit in `OneWoW/GUI/`).

**SavedVariable:** `OneWoW_Bags_DB`, initialized via `OneWoW_GUI.DB:Init` in **single** mode (defaults and persisted data under `db.global`).

**TOC:** `## Interface: 120100` (Retail). `## LoadOnDemand: 1` — the suite core force-loads this unit via `OneWoW:EnsureLoaded` when Bags is enabled; lifecycle init runs through `OnAddonLoaded` / `OnPlayerLogin` on the thin lifecycle root `OneWoW_Bags` (not a per-file `ADDON_LOADED` frame).

**Hard dependencies (`RequiredDeps`):** `OneWoW` (includes `OneWoW_GUI` global).

**Optional integrations (`OptionalDeps`):** `TradeSkillMaster`, `Baganator` (profile import via `CategoryController`), `Masque` (item-icon skinning). Other suite addons (`OneWoW_AltTracker`, `OneWoW_ShoppingList`, etc.) integrate when present but are not TOC dependencies.

---

## File Tree & Load Order

The TOC loads files in this exact sequence. **Order matters**—each layer builds on the one before it.

```
Locales\enUS.lua
Locales\esES.lua
Locales\koKR.lua
Locales\frFR.lua
Locales\ruRU.lua
Locales\deDE.lua

Core\Profile.lua                   ← optional hot-path profiler (/1wbprof); used by Categories, Bag/Bank sets, ItemButton
Core\LayoutDebug.lua               ← /1wblayout ring buffer for layout-scheduler diagnostics
Core\Constants.lua                 ← OneWoW_GUI:RegisterGUIConstants, icon sizes, pool prealloc size
Core\SectionDefaults.lua           ← stable section IDs, builtin lists, OneWoW Bags catch-all section sync
Core\Database.lua                  ← DB:Init, defaults, init bridges
Core\BagEquip.lua                  ← equipped-bag pickup/swap/empty/move-contents (used by BagsBar; BagTypes via OneWoW.Inventory)
Core\Events.lua                    ← event router (RuntimeEvents; bag/bank/guild via Inventory)

Data\CategoryRefs.lua              ← CATEGORY(Name) lookup + rename rewrite; rules-changed bus (expand lives in core SearchExpand)
Data\Sorting.lua                   ← item sort comparators (SortButtons)
Data\Categories.lua                ← builtin category defs, classification engine (consumes OneWoW.PredicateEngine)
Data\BaganatorDefaultMap.lua       ← Baganator default category name map

Modules\ItemPool.lua               ← frame object pool (ItemButton recycling)
Modules\ItemButton.lua             ← ItemButtonMixin + ApplyItemButtonMixin
Modules\BagSet.lua                 ← player inventory slot management
Modules\BankSet.lua                ← personal + warband bank slots
Modules\GuildBankSet.lua           ← guild bank tab/slot management + cache
Modules\CategoryManagerBase.lua    ← section/divider/header frame pool factory
Modules\CategoryManager.lua        ← bags: category assignment + bucketing
Modules\BankCategoryManager.lua    ← bank: CategoryManagerBase instance (section pools)
Modules\GuildBankCategoryManager.lua

ImportExport\Util.lua              ← shared deep-copy and import/export helpers
ImportExport\Serializer.lua        ← native category/section bundle encode/decode (export v2; saved-search deps)
ImportExport\Backup.lua            ← pre-import snapshot / undo storage
ImportExport\SyntaxTranslators\Registry.lua
ImportExport\SyntaxTranslators\SyndicatorLocaleMap.lua
ImportExport\SyntaxTranslators\Syndicator.lua
ImportExport\Planner.lua           ← import preview plan builder
ImportExport\Applier.lua           ← import plan applier

GUI\WindowHelpers.lua              ← window shell, scroll scaffold, filtering helpers (loads before Controllers)

Integrations\OneWoWBagsIntegration.lua  ← item-button callback hooks, overlay hooks
Integrations\OneWoWTooltips.lua         ← keyword help tooltip integration
Integrations\TSMIntegration.lua         ← TSM group import
Integrations\BaganatorImport.lua        ← Baganator profile reader/parser
Integrations\Masque.lua                 ← optional Masque skinning for item icons

Controllers\WindowLayoutController.lua  ← generic layout orchestrator
Controllers\BagsController.lua
Controllers\BankController.lua
Controllers\GuildBankController.lua
Controllers\SettingsController.lua      ← setting write + side-effects + debounce
Controllers\CategoryController.lua      ← category/section CRUD, manual pin rules, Baganator import

Views\ListView.lua                 ← flat grid layout strategy
Views\CategoryViewHelpers.lua      ← shared layout pipeline: GetSectionedLayout, grouping, stacking, render dispatch
Views\CategoryView.lua             ← bags category view (thin wrapper over shared pipeline)
Views\BagView.lua                  ← per-bag sections layout strategy
Views\BankCategoryView.lua         ← bank category view (thin wrapper over shared pipeline)
Views\BankTabView.lua              ← bank per-tab layout
Views\GuildBankTabView.lua         ← guild bank per-tab layout

GUI\InfoBarFactory.lua             ← shared info bar builder (search history, saved search button, view dropdowns)
GUI\InfoBar.lua                    ← bags top bar configuration (view mode dropdown, search, expansion filter)
GUI\BagsBar.lua                    ← bags bottom bar (bag icons, gold, trackers)
GUI\BankInfoBar.lua
GUI\BarHelpers.lua                 ← shared bank/guild bank bar chrome (frame, gold, tab recycling)
GUI\BankBar.lua
GUI\BankWindow.lua
GUI\GuildBankInfoBar.lua
GUI\GuildBankBar.lua
GUI\GuildBankLog.lua               ← transaction log panel (GUILDBANKLOG_UPDATE)
GUI\GuildBankWindow.lua
GUI\ImportPreview.lua              ← import plan preview and conflict resolution
GUI\CategoryManager.lua            ← category management UI panel
GUI\Settings.lua
GUI\MainWindow.lua                 ← inventory main window

OneWoW_Bags.lua                    ← addon entry point, event frame, runtime handlers
```

---

## Architectural Pattern

OneWoW_Bags uses a **layered hybrid MVC** pattern. It is not strict MVC—some orchestration logic lives on the thin lifecycle root (`OneWoW_Bags`)—but the separation is intentional and consistent.

### Layer Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      GUI Layer                               │
│  MainWindow, BankWindow, GuildBankWindow, Settings,          │
│  CategoryManager (UI), InfoBar, BagsBar, BarHelpers,         │
│  BankBar, GuildBankBar, WindowHelpers                        │
│  ─ Creates frames, wires user interactions to controllers    │
│  ─ Delegates layout to Views via WindowLayoutController      │
└────────────────────────────┬─────────────────────────────────┘
                             │ calls
┌────────────────────────────▼─────────────────────────────────┐
│                    Controller Layer                           │
│  BagsController, BankController, GuildBankController,        │
│  SettingsController, CategoryController,                     │
│  WindowLayoutController                                      │
│  ─ Reads/writes db.global                                    │
│  ─ Calls RequestLayoutRefresh / RequestVisualRefresh          │
│  ─ Calls InvalidateCategorization                            │
└────────────────────────────┬─────────────────────────────────┘
                             │ calls
┌────────────────────────────▼─────────────────────────────────┐
│                      View Layer                              │
│  ListView, CategoryView, BagView, BankCategoryView,          │
│  BankTabView, GuildBankTabView                               │
│  CategoryViewHelpers — grids, compact bins, labels (shared)  │
│  ─ Layout: receives buttons + width, returns height          │
│  ─ Uses viewContext for sort, sections, collapse state        │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                     Module Layer                             │
│  BagSet, BankSet, GuildBankSet (slot management)             │
│  ItemPool (frame recycling), ItemButton (mixin)              │
│  CategoryManager (bags assignment + layout metadata)         │
│  CategoryManagerBase, BankCategoryManager,                   │
│  GuildBankCategoryManager (section pools)                    │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Data Layer                              │
│  SavedSearches, Categories, Sorting                          │
│  (BagTypes / BankTypes: OneWoW.Inventory.*)                  │
│  ─ Search shortcuts, classification, sort comparators        │
│  ─ Categories uses OneWoW.PredicateEngine for search     │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Core Layer                              │
│  Database (DB:Init, defaults, init bridges)                    │
│  Events (non-Inventory runtime events; bag/bank/guild via OneWoW.Inventory) │
│  Constants (GUI metrics, icon sizes)                         │
│  Profile (optional /1wbprof timings)                         │
│  SectionDefaults (section IDs, builtin ordering, OWB section)  │
└──────────────────────────────────────────────────────────────┘
```

### The Root Namespace Object

`OneWoW_Bags = {}` is a **thin lifecycle root** (colon hooks only: `OnAddonLoaded`,
`OnPlayerLogin`, `OnPlayerEnteringWorld`, `ApplyTheme`, `ApplyLanguage`). The
private namespace table comes from the vararg: `local ADDON_NAME, ns = ...`. All
modules attach to `ns`; database state lives on `ns.db` (initialized in
`Core/Database.lua`).

Cross-addon integrations use **`OneWoW_Bags_API`** (`Core/API.lua`) for
item-button callbacks, window toggles, and optional profiler access.

The `ns` object provides:

- **State flags:** `bankOpen`, `guildBankOpen`, `oneWoWHubActive`, `inventoryPresentationState` (contains `altShowActive`), `activeExpansionFilter` (bags header expansion filter; `nil` or a set of expansion IDs), `activeBankExpansionFilter`
- **Lifecycle:** `OnAddonLoaded`, `OnPlayerLogin` on the thin root; `InitializeControllers`, `InitializeDatabase` on `ns`
- **Refresh orchestration:** `RequestLayoutRefresh(target)`, `RequestVisualRefresh(target)`, `RequestWindowReset(target)`
- **Cache invalidation:** `InvalidateCategorization(scope)` — refreshes `Categories` from `customCategoriesV2` / `recentItemDuration` / `recentItems`, clears category caches (`categoryCache` + `baseCategoryCache`); if `scope == "props"` then `OneWoW.PredicateEngine:InvalidatePropsCache()`, else full `OneWoW.PredicateEngine:InvalidateCache()`. **`InvalidateItemIDs(idSet)`** — surgical eviction after coalesced `GET_ITEM_INFO_RECEIVED` so identity-tier caches survive for unrelated items while streaming completes.
- **Blizzard hooks:** `HookBlizzardBags`, `BlizzardBankHost` (`SuppressBankFrame` / `PrepareBlizzardBankPanel` / `RestoreBankFrame`), `SuppressGuildBankFrame`, `RestoreGuildBankFrame`
- **Guild bank orchestration:** `RefreshGuildBankContents`, `QueueGuildBankRefresh`, `TrackGuildBankTransferTab`, `TrackGuildBankTransferSource`, `ProcessPendingGuildBankTransferTabs`, `PurgeClearSource`, plus internal coalescing state for cross-tab moves
- **Helpers:** `GetDB`, `GetItemSortMode`, `SortButtons`, `ShouldDimJunkItem`, `ShouldStripJunkOverlays`, `EnsureCategoryModification`, `EnsureBuiltinCategoryAddedItems`, `IsAltShowActive`, `SetAltShowActive`, `IsBagsUIEnabled`, `IsBankUIEnabled`, `IsGuildBankUIEnabled`, `ReinitForLanguage`, `ApplyItemButtonMixin`, `HookPetCageTooltip`, `GetMoneyDialog`, `ShowMoneyDialog`, `UpdateSlotsForItemIDs`
- **Shared tables:** `SectionDefaults`, `CategoryViewHelpers`, `BarHelpers` (see Key Components)

---

## Data Flow

### 1. Startup Sequence

```
Suite loader force-load (LoadOnDemand) or first enable
  └─→ OnAddonLoaded
       ├─→ Lifecycle:CreateHandlerRegistry
       ├─→ InitializeDatabase (flat SV bridge + DB:Init)
       ├─→ InitializeControllers (WindowLayoutController, *Controller:Create)
       ├─→ OneWoW_GUI:MigrateSettings(db.global)
       ├─→ Masque:OnLoad (when Masque optional dep is present)
       ├─→ ApplyTheme, ApplyLanguage
       ├─→ Categories:SetCustomCategories, SetRecentItemDuration, SetRecentItems
       ├─→ RegisterSlashCommands, RegisterRuntimeEvents
       ├─→ OneWoW_GUI:RegisterSettingsCallback (theme, language, font, icon, minimap)
       └─→ OneWoW:RegisterLoadComponent("Bags", …)

PLAYER_LOGIN (or mid-session EnsureLoaded replay)
  └─→ OnPlayerLogin
       ├─→ DetectOneWoW → oneWoWHubActive
       ├─→ OneWoW:RegisterMinimap (hub minimap entry)
       ├─→ ItemPool:Preallocate(Constants.ITEM_POOL_PREALLOC_SIZE)  ← 906 at time of writing
       ├─→ BagSet:Build, BagsBar:UpdateIcons
       ├─→ HookBlizzardBags, HookPetCageTooltip
       ├─→ InstallIntegrationHooks (item-button callback RefreshLayout wraps)
       └─→ RegisterTooltipProvider, FireLoginHandlers
```

`Integrations\OneWoWBagsIntegration.lua` installs from `OnPlayerLogin` via `InstallIntegrationHooks`: wraps `GUI:RefreshLayout`, `BankGUI:RefreshLayout`, and `GuildBankGUI:RefreshLayout`, dispatching callbacks ~50 ms after layout (see Integration Points and [`ITEM_BUTTON.md`](ITEM_BUTTON.md)).

### 2. Bag Update Pipeline (Primary Data Flow)

```
Game event: BAG_UPDATE / BAG_UPDATE_DELAYED
  └─→ OneWoW.Inventory (single owner; dirty coalesce + PE:InvalidatePropsCache)
       └─→ RegisterDelayedCallback("OneWoW_Bags") → Events:OnBagUpdateDelayed(dirtyBags)
            ├─→ InvalidateCategorization("props")  ← Bags category caches (+ PE wipe already done)
            └─→ OneWoW_Bags:ProcessBagUpdate(dirtyBags)
                 ├─→ Categories:OnPlayerBagDirtySnapshot(dirtyBags) (expire GUID map; stamp GUIDs for Blizzard-new slots in player bags)
                 ├─→ BagSet:UpdateDirtyBags(dirtyBags)
                 │    ├─→ Slot count changed → RebuildBag (release + re-acquire from pool)
                 │    ├─→ Else → OWB_MarkDirty on affected buttons
                 │    └─→ ProcessDirtySlots → OWB_FullUpdate per dirty button
                 │         └─→ C_Container.GetContainerItemInfo → texture, count, quality,
                 │            cooldown, new-item glow, junk dim, unusable overlay, lock refresh
                 ├─→ GUI:RefreshLayout (if bags window built + shown)
                 └─→ BankGUI:RefreshLayout (if bank open, bank set built, window shown)
```

Main bags window visibility (`GUI:Show` / `GUI:Hide` / `GUI:FullReset` in [`GUI/MainWindow.lua`](../GUI/MainWindow.lua)):

```
GUI:Show (after init)
  └─→ Categories:BeginRecentExpiryTicker
       └─→ C_Timer.NewTicker(RECENT_EXPIRY_TICK_INTERVAL) while active
            ├─→ If GUI no longer shown → EndRecentExpiryTicker (safety)
            ├─→ CleanExpiredRecent → true if any GUID removed
            └─→ RequestLayoutRefresh("all") when removed

GUI:Hide / GUI:FullReset (start of reset)
  └─→ Categories:EndRecentExpiryTicker → cancel ticker + CleanExpiredRecent
```

Guild bank updates use a separate path: `OneWoW.Inventory` guild-slots channel
(`GUILDBANKBAGSLOTS_CHANGED`, coalesced ~0.2s) → `QueueGuildBankRefresh`
(OnUpdate-coalesced) → `RefreshGuildBankContents` → slot cache +
`GuildBankGUI:RefreshLayout` when visible. Open/closed/lock/tabs/money also
arrive via Inventory guild channels.

### 3. Layout Pipeline

`WindowLayoutController:Refresh(config)` runs only when `config.mainWindow` exists **and is shown** and `config.isBuilt()` is true. It:

1. Optionally `updateWindowWidth()` — fixed horizontal width from column count + icon size + scrollbar allowance (`UpdateFixedWidth`).
2. `beforeLayout()` — visibility, scroll anchors (`BindScrollFrame`).
3. Reparents `config.containerFrames` under `config.contentFrame` (bag container frames carry `SetID(bagID)` for secure item buttons).
4. `cleanup()` — hide/clear button anchors, `CategoryManager` / `BankCategoryManager` / `GuildBankCategoryManager`:ReleaseAllSections.
5. `getButtons()` → `filterButtons()` — **window-specific** (see below).
6. `layoutButtons(filteredButtons)` → active View’s `Layout` → content height.
7. `afterLayout()` — free slot counts, etc.

**Per-window filtering:**

| Window | Filter chain (after `getButtons`) |
|--------|-----------------------------------|
| Bags (`GUI:RefreshLayout`) | `WH:FilterBySearch` → `WH:FilterByExpansion` (`activeExpansionFilter`) |
| Bank | `WH:FilterByTab` (`bankSelectedTab`) → `WH:FilterBySearch` → `WH:FilterByExpansion` (`activeBankExpansionFilter`) |
| Guild bank | `WH:FilterByTab` (`guildBankSelectedTab`) → `WH:FilterBySearch` (no expansion filter) |

**Column keys for width and grid metrics:**

- Inventory main window: `db.global.bagColumns` (not the legacy `columns` default key, which is unused by current GUI code).
- Bank window: `db.global.bankColumns` in personal mode, `db.global.warbandBankColumns` in warband mode (selected via `BankController:ActiveKeys().columns`).
- Guild bank window: `db.global.bankColumns`.

### 4. Category Classification Pipeline

**Bags — `CategoryView` only:** at the start of `CategoryView:Layout`, `CategoryManager:AssignCategories()` runs:

```
CategoryManager:AssignCategories()
  └─→ For each BagSet button with an item:
       └─→ Categories:GetItemCategory(bagID, slotID, itemInfo)
```

**`Categories:GetItemCategory`** splits work into a **slot-keyed outer layer** and an **identity-tier base resolver** (`ResolveBaseCategory`). Slot-dependent outcomes are evaluated before the base resolver; identity-tier work (manual pins through builtin/custom predicates) is cached per **item identity + `containerType`** so duplicate stacks in the same container type reuse one verdict.

**Outer layer** (`GetItemCategory`; order matters):

1. **Missing `itemInfo`** → `"Other"`.
2. **Slot-keyed cache** (`categoryCache`, key `PE:GetItemCacheKey(...)`) — stores final results including slot-overlay hits when applicable.
3. **1W Upgrades (slot overlay)** — `OneWoW.UpgradeDetection:CheckItemUpgrade` with `ItemLocation` when available; gated by `enableUpgradeCategory`, `disabledCategories`, `CategoryAppliesTo`, and `OneWoW` presence. Runs **before** Recent Items so an upgrade wins over a recent classification on the same slot.
4. **Recent Items (slot overlay)** — `SlotMatchesRecent`; gated by `disabledCategories` + `CategoryAppliesTo`.
5. **`ResolveBaseCategory(...)`** — see below. Writes through to slot cache only when the verdict is **not tentative** (full item data + tooltip resolution succeeded).

**`ResolveBaseCategory`** (identity tier; manual pins through builtin/custom pool):

1. **Manual pins** — `customCategoriesV2[*].items` and `categoryModifications[*].addedItems` (no PredicateEngine). Same `pinnedCategoryShowsWhenDisabled` and `PickBestCandidate` rules as before; filtered by `CategoryAppliesTo` for `containerType`.
2. **1W Junk** — `PE:BuildProps(...).isJunk`; gated by `enableJunkCategory` + `disabledCategories` + `CategoryAppliesTo`.
3. **No hyperlink** → `"Other"` (cannot run predicate pool meaningfully).
4. **Streaming deferral** — if `not C_Item.IsItemDataCachedByID(itemID)`, requests load and returns **`"Other", tentative=true`** so nothing is cached until `GET_ITEM_INFO_RECEIVED` + refresh (sets `OneWoW_Bags._hasPendingTentatives` and records the item ID in `_pendingTentativeItemIDs` for the surgical catchup). A successful non-tentative resolution drops the item from `_pendingTentativeItemIDs`.
5. **`baseCategoryCache` hit** — key `PE:GetItemIdentityKey(...) .. "|" .. containerType` — reuse merged-pool result for the same identity in the same container type.
6. **`PE:BuildProps` + merged candidate pool** — `CollectCustomPredicateCandidates` + all `SEARCH_CATEGORIES` entries; `PickBestCandidate` (priority → custom beats builtin → `defaultOrder` → section index → list order → `searchOrder` → name). Builtin candidates filtered by `disabledCategories` before evaluation; pool then filtered by `CategoryAppliesTo`.
7. **Inventory slots** — if result is `Weapons` or `Armor` and `enableInventorySlots`, remap to localized equip-slot name when allowed by `CategoryAppliesTo`.
8. **Disabled fallback** — candidate-pool-derived names only; manual/Junk still return early.
9. **Tooltip tentative** — if props recorded `_tooltipDataMissing`, return category but **`tentative=true`** so slot cache is not poisoned during cold tooltip/streaming.
10. **`baseCategoryCache` write** on successful non-tentative resolution.

**Important:** Slot overlays (**Upgrades**, **Recent**) live only in `GetItemCategory`; they **never** populate `baseCategoryCache`. Manual pins, Junk, and merged-pool results **do** use `baseCategoryCache` for reuse across slots with the same identity.

**`Categories:FindManualPinForItem(itemID)`** — returns `{ kind, categoryId | categoryName, displayName }` or `nil`; used for **single-pin enforcement** when adding items (see `CategoryController`).

**`H.GetSectionedLayout(itemsByCategory, containerType)`** (in `CategoryViewHelpers.lua`)

- `IsCategoryVisible` hides a category when `disabledCategories[catName]` is set **unless** `pinnedCategoryShowsWhenDisabled` is on **and** that category has items in `itemsByCategory` (so pinned rows can still appear for disabled categories).
- Applies `categoryModifications.appliesIn[containerType]` — categories with `appliesIn[containerType] == false` are excluded. "Other" and "Empty" are always exempt.
- Section header visibility is resolved per-container: bags use `showHeader`, bank uses `showHeaderBank` (falls back to `showHeader` when nil).
- When `displayOrder` / section graph is empty, falls back to `H.GetSortedCategoryNames`; otherwise builds from `displayOrder`, `categorySections`, `sectionOrder`, optional equip-slot names when inventory slots are enabled.
- Shared by both `CategoryView` (bags) and `BankCategoryView` (bank).

**Bank — `BankCategoryView`:** walks `BankSet:GetAllButtons()`, calls `Categories:GetItemCategory` per occupied slot (which filters by `appliesIn` at assignment time), groups into `itemsByCategory`, then calls `H.GetSectionedLayout` + `H.LayoutCategoryContent` with bank settings. `BankCategoryManager` supplies **section frames only** via `viewContext`.

**List / tab views:** no `AssignCategories`; sort order comes from `viewContext.sortButtons` → `SortButtons`.

### 5. Search Pipeline

Search uses `OneWoW.PredicateEngine` (tokenizer, AST, evaluation). For full engine internals and public API, see [`OneWoW/Docs/PREDICATE_ENGINE.md`](../../OneWoW/Docs/PREDICATE_ENGINE.md).

- Keywords, properties, operators (`&` `|` `!`), parentheses, bare name text
- `SAVED(Name)` / `CATEGORY(Name)` shortcuts are expanded by core
  `OneWoW.SearchExpand` before PredicateEngine evaluation. Named expressions
  live in `OneWoW_DB.global.searchCatalog` as `saved`-kind entries.
  `CATEGORY(Name)` resolves through the same catalog as the `category` kind,
  over entries Bags contributes from `customCategoriesV2` via a registered
  provider (see SearchExpand / CategoryRefs below).
- `#recent` is registered at `Data\Categories.lua` load via `PE:RegisterKeyword` (Bags-only): GUID map + duration only. `#new` / `IsNew` in the engine use `C_NewItems` via `BuildProps` (can lag until `InvalidatePropsCache`); `#recent` does not use that cached flag for classification
- `#catalyst` / `#catalystupgrade` are registered by the engine itself with call-time `TransmogUpgradeMaster_API` checks (no-op if the addon is absent)
- `WH:FilterBySearch` uses `SearchExpand:Compile` once per refresh and evaluates per button via `PE:SafeEvaluate` / compiled predicates
- Search history is UI-owned by `InfoBarFactory` on every container search box; stored in `db.global.searchHistory` up to `db.global.searchHistoryLimit` (Settings → General → Search; `0` disables the focus dropdown).
- Save-search button (`savedSearches = true`) on bags, personal/warband bank, and guild bank info bars writes the **core** Search Shortcuts store. Manage names/aliases in **OneWoW Settings → Search Shortcuts** (Bags Search settings keep history limit + a breadcrumb deep-link).

```
InfoBar / BankInfoBar / GuildBankInfoBar: search changed
  └─→ *Controller:OnSearchChanged → *GUI:OnSearchChanged
       (dedupes: unchanged text — incl. the empty fire during open — is dropped)
  └─→ *GUI:RefreshLayout
       └─→ filterButtons → WH:FilterBySearch
            └─→ SearchExpand:Compile(expr)  -- Expand SAVED/CATEGORY then PE:Compile
                 ├─→ BuildProps(...) → cached props (+ tooltip laziness inside props)
                 └─→ Evaluate AST → true/false
```

Expansion filtering for bags/bank uses `WindowHelpers:ResolveExpansionID` (engine expansion helpers under the hood), not the same code path as the search box unless the user types expansion predicates.

### 6. Settings Pipeline

All settings writes go through `SettingsController:Apply`:

```
Settings UI interaction
  └─→ SettingsController:Apply(settingKey, value)
       └─→ appliers[settingKey](self, db, value)
            ├─→ Writes db.global[key] = value
            └─→ Triggers appropriate refresh:
                 ├─→ RequestLayoutRefresh
                 ├─→ RequestVisualRefresh (also re-layouts the same target in current code)
                 ├─→ RequestWindowReset
                 └─→ InvalidateCategorization (full cache, not props-only)
```

Layout-affecting numeric settings (e.g. `bagColumns`) use `SettingsController:Debounce` to reduce thrash.

**Category placement:** `pinnedCategoryShowsWhenDisabled` (General → Category Placement) runs applier `pinnedCategoryShowsWhenDisabled`: `InvalidateCategorization`, `RequestLayoutRefresh("all")`, and `CategoryManagerUI:Refresh` when present (same class of side effects as junk/upgrade category toggles).

---

## Key Components In Detail

### SectionDefaults (`Core\SectionDefaults.lua`)

Stable section IDs (`SEC_ONEWOW_BAGS`, `SEC_EQUIPMENT`, `SEC_CRAFTING`, `SEC_HOUSING`), default member lists per section, and `BUILTIN_SORT_PRIORITY` for ordering. `BuildOnewowMembers` / `SyncOnewowSectionCategories` maintain the **OneWoW Bags** catch-all section: builtins and custom categories not assigned elsewhere, sorted per saved `categoryOrder` or builtin priority. Used by `CategoryController`, category UI (`GUI\CategoryManager.lua`), and section sync on init.

### CategoryViewHelpers (`Views\CategoryViewHelpers.lua`)

Shared by `CategoryView` and `BankCategoryView`. Contains the full shared layout pipeline:

- `H.GetSortedCategoryNames` / `H.GetSectionedLayout` — section/display-order resolution, `appliesIn` container filtering, per-container section header visibility (`showHeader` for bags, `showHeaderBank` for bank with fallback to `showHeader` when nil)
- Grouping: `H.GroupItemsBy` handles `expansion`, `type` (class), `subtype`, `slot`, `quality`, `track`, `equipmentset`; optional `subGroupBy` composes `group / sub-group` labels
- `StackItems` / `RestoreItemButtonCounts` — item stacking logic
- `FilterItems` — per-category search filter evaluation
- `H.LayoutCategoryContent(config)` — unified entry point for the full render dispatch (sort, stack, group, grid/compact)
- Label/header object pools, localized category titles, `RenderItemGrid`, compact multi-category line packing (`LayoutCompactGroup`), `PinSpecialCategories` for Recent/Other placement

### BagEquip (`Core\BagEquip.lua`)

Equipped-bag operations for the bags bar (`GUI\BagsBar.lua`): pickup/swap bag items on character bag slots, equip from cursor or container, empty equipped bags into compatible destinations (paced `BAG_UPDATE_DELAYED` continuation), and reagent/normal bag compatibility checks via `OneWoW.Inventory.BagTypes` + `C_Item` container subclass.

### BarHelpers (`GUI\BarHelpers.lua`)

Shared bottom-bar construction for `BankBar` and `GuildBankBar`: themed bar frame, gold + free-slot font strings, tab button recycling helpers.

### Profile (`Core\Profile.lua`)

Optional sampling profiler toggled with **`/1wbprof`** (`on` / `off` / `reset` / `dump`). Used by `Categories:GetItemCategory`, `ResolveBaseCategory`, `BankSet`/`BagSet` hot paths, and `ItemButton:OWB_FullUpdate`. Disabled by default (zero overhead).

### ItemPool

Acquire/release pool for `ContainerFrameItemButtonTemplate` buttons. `Preallocate(Constants.ITEM_POOL_PREALLOC_SIZE)` at login (906 — sized for all bag/bank/guild slots). `OneWoW_GUI:SkinIconFrame` during creation; mixin applied when bound in `BagSet` / `BankSet` / `GuildBankSet`.

### ItemButtonMixin (`Modules\ItemButton.lua`)

Applied with `OneWoW_Bags:ApplyItemButtonMixin` (copies `OneWoW_Bags.ItemButtonMixin` methods onto the button once).

- `OWB_SetSlot`, `OWB_MarkDirty`, `OWB_IsDirty`, `OWB_FullUpdate`
- `OWB_UpdateNewItemGlow` — player bags only (`OneWoW.Inventory.BagTypes:IsPlayerBag`); uses `OneWoW.PredicateEngine:BuildProps(...).isNew` + template overlays; respects Masque (`Integrations\Masque.lua`) for border/glow ownership when Masque is active
- `OWB_UpdateJunkDim`, `OWB_UpdateUnusableOverlay` — junk from `BuildProps(...).isJunk`
- `OWB_RefreshCooldown`, `OWB_RefreshLock`, `OWB_SetIconSize`, `OWB_GetLink`

Per-button state includes `owb_bagID`, `owb_slotID`, `owb_itemInfo`, `owb_hasItem`, `owb_categoryName` (when categorized), `owb_isBank`, `owb_isGuildBank`, and internal junk/overlay flags.

### BagSet / BankSet / GuildBankSet

- `Build()` / `ReleaseAll()`, `UpdateDirtyBags` (bags + bank), `GetAllButtons`, `GetFreeSlotCount`, etc.
- `bagContainerFrames[bagID]` — parent frames with `SetID(bagID)` for secure behavior on container template buttons.
- **Bags:** `Ctrl+Right-click` on a bag item while the personal/warband **or guild** bank is open delegates to `BankController:DepositBagButtonStack`. Personal/warband use paced `UseContainerItem(..., bankType)`; guild uses `OneWoW.GuildBankTransfer` (partial-stack fill + empty-slot places). If "Stack identical items" produced a virtual stack, every underlying physical player-bag slot is queued.
- **Search transfer (bags ↔ personal/warband bank, bags → guild):** Info bar icons (`Banker` on bags, `hud-backpack` on bank) call `BankController:TransferSearchToBank` / `TransferSearchFromBank`. Deposit to guild while `guildBankOpen` routes through GuildBankTransfer. Withdraw from guild is not supported (different API; out of scope). Same bag search filters (`WH:FilterBySearch` + `WH:FilterByExpansion`); deposit `selectedBag` scope applies only in **bag** view mode.
- **Restriction gating:** every `UseContainerItem` move path and GuildBankTransfer enqueue gates on `OneWoW.Restriction.IsProtectedActionBlocked()` — entry points bail when blocked, and each ticker/op re-checks so a transfer that starts safely pauses (and resumes) if combat begins mid-queue. `IsProtectedActionBlocked` excludes the `Map` restriction, so bank transfers keep working inside a Delve out of combat. Money transfers (`C_Bank.WithdrawMoney`/`DepositMoney`) are not combat-protected and are left ungated, matching Blizzard's own `BankFrame` popups.
- **Guild bank:** tab/slot cache, `ApplyCacheToButtons`, money-cursor and guild-bank-specific scripts, `ClearCache` on close; fixed slot count per tab (98).

### CategoryManagerBase

`Create()` returns an instance with section/header/divider pools. Three module-level instances:

- `OneWoW_Bags.CategoryManager` — extends base with bags assignment + bucketing (`AssignCategories`, `GetItemsByCategory`)
- `OneWoW_Bags.BankCategoryManager`
- `OneWoW_Bags.GuildBankCategoryManager`

### CategoryManager (module)

- `AssignCategories` — **inventory BagSet only** (used from `CategoryView`).
- `GetItemsByCategory` — buckets assigned buttons by `owb_categoryName`.

Layout functions (`GetSortedCategoryNames`, `GetSectionedLayout`) live in `CategoryViewHelpers` and are shared by both bags and bank views.

**Naming:** not the same as `GUI\CategoryManager.lua` (category editor UI).

### Views

Each view exposes `Layout(...)` and returns total content height.

**ListView** — Grid with optional reagent-bag segment after normal bags. Computes column count from **content width** and icon spacing when not overridden by bag/category views. Honors per-container empty-slot settings via `viewContext.showEmptySlots` (`showEmptySlots` bags, `bankShowEmptySlots`, `warbandBankShowEmptySlots`, `guildBankShowEmptySlots`; List and Tab views only).

**CategoryView** — Thin wrapper: runs `CategoryManager:AssignCategories()` + `:GetItemsByCategory()`, then calls `H.GetSectionedLayout` and `H.LayoutCategoryContent` from the shared pipeline with bag-specific settings.

**BagView** — One section per physical bag; `selectedBag` filter.

**BankCategoryView** — Thin wrapper: builds `itemsByCategory` from `BankSet` via inline `Categories:GetItemCategory`, then calls `H.GetSectionedLayout` and `H.LayoutCategoryContent` from the shared pipeline with bank-specific settings.

**BankTabView** — Sections per bank tab; mode-aware selected tab (personal: `bankSelectedTab`, warband: `warbandBankSelectedTab`) and mode-aware columns (personal: `bankColumns`, warband: `warbandBankColumns`). Both read via `BankController:Get("selectedTab"/"columns")`. Respects warband vs character via `bankShowWarband`.

**GuildBankTabView** — Sections per guild tab; `guildBankSelectedTab`.

**Guild bank window view modes:** `guildBankViewMode` is `"tab"` or list (`ListView`) only—no bank-style category view for guild bank.

### WindowLayoutController

`Refresh(config)` is entirely driven by the injected `config` table (no hard-coded window branching).

`CreateViewContext(config)` returns:

- `sortButtons(buttons, overrideSortMode, overrideSubSortMode)` → `addon:SortButtons(..., overrideSortMode or config.sortMode, overrideSubSortMode)`
- `acquireSection` / `acquireSectionHeader` / `acquireDivider` — delegate to `sectionManager` when present
- `getCollapsed` / `setCollapsed` / `requestRelayout` / `containerType` / `showEmptySlots` (optional; List/Tab layout)

**Collapse `kind` values in use:**

- Bags: `"category"`, `"bag"`, `"section"` (section metadata in `categorySections`)
- Bank category mode: `"category"`, `"section"` (shared section collapse state via `categorySections`); bank tab mode: `"tab"` (with legacy fallbacks to `collapsedBankSections` in getters)
- Guild bank tab mode: `"tab"` (with legacy fallbacks to `collapsedGuildBankSections`)

### SearchExpand / CategoryRefs

Named expressions (`SAVED`) and user tokens (`#name`) live in core
`OneWoW.SearchCatalog` (`OneWoW_DB.global.searchCatalog`), fronted by
`OneWoW.SearchExpand`.

Bags `Data\CategoryRefs.lua` registers a **catalog provider** for the
`category` kind, presenting `customCategoriesV2` records as catalog entries on
demand (`EnumerateCatalogEntries` / `GetCatalogEntry`). The records themselves
stay in Bags SavedVariables, so the optional-load-unit boundary holds and
import/export stays self-contained. `NotifyRulesChanged` invalidates the kind so
the catalog's name index cannot go stale behind a Bags-side write.

A category with no rule at all — item pins only, or one whose stored type names
no longer resolve in the current locale — contributes an entry with **no body**.
That resolves as `empty` rather than `missing`, which is what lets a diagnostic
tell "you referenced a category with no rule" from "you referenced something
that does not exist".

Renaming a `SAVED` no longer rewrites anything: the catalog keeps the old name
as a former name and resolves it to the same entry. Category rename still
rewrites `CATEGORY(...)` text inside Bags SV; that goes away in the phase that
gives categories their own `formerNames`. Missing, invalid, cyclic, or too-deep
references expand to a never-match predicate.

### PredicateEngine

Lives in OneWoW core as the service `OneWoW.PredicateEngine` (`OneWoW/Services/PredicateEngine.lua`, published on the `OneWoW` global). Bags consumes it via `local PE = OneWoW.PredicateEngine`. Full reference: [`OneWoW/Docs/PREDICATE_ENGINE.md`](../../OneWoW/Docs/PREDICATE_ENGINE.md).

Used by Bags for: search filtering (`WH:FilterBySearch` via `SearchExpand:Compile`), custom category expressions and builtin category search strings in `Data/Categories.lua`, item button state (`ItemButton` junk / new / upgrade flags), and keyword tooltips in `Integrations/OneWoWTooltips.lua`.

Cache invalidation boundary: `InvalidateCategorization("props")` on `BAG_UPDATE_DELAYED` calls `PE:InvalidatePropsCache()` (props + slot-tier tooltip caches only — link-tier tooltip caches and the character-usability cache survive bag updates; see PREDICATE_ENGINE.md). Full `PE:InvalidateCache()` runs on keyword/property registration, settings changes that reshape categorization, and manual refresh. Character-context events (level up, spec/talent, skill lines) route through `PE:InvalidateCharacterContext()`.

### Categories

**28** builtin rows in `CATEGORY_DEFINITIONS` (including `1W Junk`, `1W Upgrades`, `Recent Items`, crafting split **`Mats`** / **`Reagents`**, `Other`, `Empty`, and search-driven builtins such as `Housing`, `Toys`, `Junk`, etc.). Builtin search categories are collected into `SEARCH_CATEGORIES` sorted by `searchOrder` (ties retain stable relative order from definitions).

Custom predicate categories are mirrored into **`precomputedCustomCands`** when `customCategoriesV2` mutates so per-slot classification avoids repeating filter-mode inference and string lowercasing. During **`ResolveBaseCategory`**, custom predicate hits and builtin **`SEARCH_CATEGORIES`** hits are merged into a **single candidate pool**; tie-breaking: user-facing **priority** (higher wins) → custom beats builtin at equal priority → `defaultOrder` (lower wins) → section index → **Category Manager list order** → `searchOrder` → alphabetical name.

---

## Window Architecture

Three windows share the same structural pattern (shell from `WindowHelpers:CreateWindowShell`, title bar, content area, optional settings button, scroll scaffold, resize handle).

**Guild bank:** `GuildBankLog` is a separate movable panel listening for `GUILDBANKLOG_UPDATE`, toggled from the guild bank bar; it is not a child of the main guild bank scroll content.

**Info bars:** All three windows use `InfoBarFactory:Create` via thin config modules (`InfoBar.lua`, `BankInfoBar.lua`, `GuildBankInfoBar.lua`): controller, view mode dropdown, expansion filter (bags/bank), shared search history dropdown, and `savedSearches` save button where enabled.

### Sorting (`Data\Sorting.lua` → `OneWoW_Bags:SortButtons`)

Modes: `none` (no reorder), `default` (bagID then slotID among occupied slots), `name`, `rarity`, `ilvl` (equipment item level; **containers use bag slot count**, matching the Item Level overlay), `type` (item class ID, subclass ID, then name), `expansion` (expansion ID via `WindowHelpers:ResolveExpansionID`, then quality). Empty slots are ordered last where the comparator considers `owb_hasItem`.

**Sort/group caches on buttons** (`ItemButton:OWB_FullUpdate`, mirrored in `GuildBankSet`): `_owb_sortName`, `_owb_ilvl`, `_owb_classID`, `_owb_subClassID`, `_owb_upgradeTrackStringID`, `_owb_upgradeTrackString`, `_owb_expansionID`, `_owb_itemQuality` (container `info.quality`), `_owb_reagentQuality` and `_owb_craftedQuality` (copied from `PE:BuildProps` — category grouping reads caches first; no `BuildProps` in the sort loop). Cleared in `ItemPool:ResetButton` and empty-slot updates.

**`rarity` mode** (`CompareRarity`): descending comparisons in order — (1) item quality (`_owb_itemQuality`, fallback `owb_itemInfo.quality`), (2) reagent profession tier (`_owb_reagentQuality`), (3) crafted tier (`_owb_craftedQuality`). Item rarity wins globally; profession tiers break ties (e.g. same-name common herbs with different diamond tiers).

Default in **fresh DB defaults** is `itemSort = "none"`; `GetItemSortMode` returns `db.global.itemSort or "default"` if the key were absent.

Per-category `categoryModifications[name].subSortMode` provides a secondary
criterion after `sortMode`. Optional `sortDescending` / `subSortDescending`
booleans override direction per row (`nil` = mode default). Category Manager
shows a direction toggle (`CovenantSanctum-Renown-DoubleArrow`, rotated for
asc/desc); disabled when sort/sub-sort is `none` or when sub-sort duplicates
primary. `SortButtons(buttons, sortMode, subSortMode, sortDescending, subSortDescending)`.

**Mode default direction** when `*Descending` is unset: `default`/`name`/`type` asc;
`rarity`/`ilvl`/`expansion` desc. Final bag/slot tie-break is always asc. Global
`itemSort` does not expose direction UI (always uses mode defaults).

When no explicit sub-sort is set, legacy tie-breakers remain for selected primary
modes, then all sorts fall back to `default` bag/slot order.

### Width calculation (`WindowLayoutController:UpdateFixedWidth`)

```
width = cols × (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 × outerPadding)
```

`cols` is `bagColumns` or `bankColumns` depending on the window. Vertical resizing adjusts height; horizontal size follows column settings.

Window scale (`bagScale`, `bankScale`, `warbandBankScale`, `guildBankScale`; 50–200%) is a `SetScale` transform on the window root. It does not change grid metrics and does not trigger a layout refresh. Personal and warband share one frame; `BankController:Get("scale")` picks the active mode’s percent. Resize max height uses screen size in the frame’s local units.

---

## Event System

### Dispatch

**Lifecycle** (`OnAddonLoaded`, `OnPlayerLogin`, `OnPlayerEnteringWorld`) is invoked by the OneWoW suite loader — this module does not register `ADDON_LOADED` / `PLAYER_LOGIN` on its own frame (see suite architecture docs).

**Gameplay events** use a hidden `eventFrame` in `OneWoW_Bags.lua`, registered from `RegisterRuntimeEvents` during `OnAddonLoaded`. Each event maps through `runtimeEventHandlers[event]` into `Events:*` methods and then `OneWoW_Bags:*` as needed.

### Key groups

| Group | Flow |
|--------|------|
| Bag updates | `OneWoW.Inventory` delayed → `InvalidateCategorization("props")` + `ProcessBagUpdate(dirtyBags)` |
| Lock / cooldown | `ITEM_LOCK_CHANGED` → per-button `OWB_RefreshLock`; `BAG_UPDATE_COOLDOWN` → `OnCooldownUpdate` |
| Bank | `BANKFRAME_OPENED` / `CLOSED` → suppress/restore Blizzard bank, `BankGUI`, `C_Bank.Fetch*`, `BankPanel` warband vs character |
| Guild bank | `OneWoW.Inventory` guild channels + `OneWoW.GuildBankTransfer` for bag→guild deposits |
| Merchant | `MERCHANT_SHOW` / `MERCHANT_CLOSED` (auto open/close with guards in `HookBlizzardBags`) |
| Money | `PLAYER_MONEY`, `ACCOUNT_MONEY`; guild money via Inventory guild-money channel |
| Quest | `QUEST_ACCEPTED` / `QUEST_REMOVED` → full-bag dirty rebuild |
| Predicate-related | `EQUIPMENT_SETS_CHANGED` / `PLAYER_EQUIPMENT_CHANGED` → `Events:OnPredicateInvalidation` → `InvalidateCategorization("props")` + deferred `RequestVisualRefresh` for visible windows; `GET_ITEM_INFO_RECEIVED` → trailing-debounced (~0.1s, capped 0.3s) `InvalidateItemIDs` + `UpdateSlotsForItemIDs` so a cold-streaming burst collapses into one relayout instead of one per frame-wave (no blanket categorization wipe) |

---

## Database Schema

Persisted layout and behavior state lives under `OneWoW_Bags_DB.global`. The defaults table in `Core\Database.lua` also includes `language`, `theme`, and `minimap` for `OneWoW_GUI:MigrateSettings` alignment.

### Display — bags

`viewMode`, `bagColumns`, `bagScale`, `iconSize`, `itemSort`, `compactCategories`, `compactGap`, `categorySpacing`, `showCategoryHeaders`, `showEmptySlots`, `hideScrollBar`, `showBagsBar`, `showMoneyBar`, `showCurrencyTrackerCapHighlight`, `showHeaderBar`, `showSearchBar`, `selectedBag`

### Search

`searchHistoryLimit` (0 disables history, 1-10 keeps recent committed searches),
`searchHistory`, `savedSearches` (`displayName -> predicate string` used by
`SAVED(Name)`).

### Display — personal bank / warband bank / guild bank

Personal bank: `bankViewMode`, `bankColumns`, `bankScale`, `bankCompactCategories`, `bankCompactGap`, `bankCategorySpacing`, `showBankCategoryHeaders`, `bankHideScrollBar`, `showBankBagsBar`, `showBankSearchBar`, `showBankHeaderBar`, `bankSelectedTab`, `collapsedBankTabSections`, `bankShowEmptySlots`.

Warband bank (parallel keys, selected at runtime by `bankShowWarband`): `warbandBankViewMode`, `warbandBankColumns`, `warbandBankScale`, `warbandBankCompactCategories`, `warbandBankCompactGap`, `warbandBankCategorySpacing`, `showWarbandBankCategoryHeaders`, `warbandBankHideScrollBar`, `showWarbandBankBagsBar`, `showWarbandBankSearchBar`, `showWarbandBankHeaderBar`, `warbandBankSelectedTab`, `collapsedWarbandBankTabSections`, `warbandBankShowEmptySlots`.

Guild bank: `guildBankViewMode`, `guildBankSelectedTab`, `guildBankShowEmptySlots`, `guildBankScale`.

Shared: `bankShowWarband` (active mode), `bankFramePosition`, `collapsedBankCategorySections` (categories are global across modes).

`BankController:Get(field)` / `BankController:GetFor(mode, field)` dispatches to the correct keyset based on mode.

### Behavior

`autoOpen`, `autoClose`, `autoOpenWithBank`, `locked`, `bankLocked`, `enableBagsUI`, `enableBankUI`, `enableGuildBankUI`, `enableBankOverlays`, `enableWarbandBankOverlays`, `altToShow`, `enableExpansionFilter`, `enableBankExpansionFilter`, `enableWarbandBankExpansionFilter`, `enableInventorySlots`, `stackItems`

`enableBagsUI`, `enableBankUI`, and `enableGuildBankUI` are the three replacement gates, shown together on the General settings tab. Personal and warband share one window and one `enableBankUI` key; they are not independently enabled. `bankLocked` is still mirrored on both bank tabs via cross-tab UI sync.

### Visual

`showNewItems`, `showUnusableOverlay`, `dimJunkItems`, `stripJunkOverlays`

Item rarity borders are owned by Overlays 2.0 **Quality Border** (not Bags settings). Bags keeps neutral `SkinIconFrame` chrome; bags / personal bank / warband / guild bank visibility follows the Bags overlay master toggles (`overlays` general, `enableBankOverlays`, `enableWarbandBankOverlays` — guild bank shares `enableBankOverlays` with personal bank).
### Categories

`customCategoriesV2`, `disabledCategories`, `categoryModifications` (including per-category `sortMode` and `subSortMode`), `categorySort`, `categoryOrder`, `categorySections`, `sectionOrder`, `displayOrder`, `enableJunkCategory`, `enableUpgradeCategory`, `moveRecentToTop`, `moveOtherToBottom`, `pinnedCategoryShowsWhenDisabled`, `pinnedCategories`

### Collapse

`collapsedSections`, `collapsedBagSections`, `collapsedBankSections`, `collapsedGuildBankSections`, `collapsedBankCategorySections`, `collapsedBankTabSections`, `collapsedWarbandBankTabSections`, `collapsedGuildBankTabSections`

### Other

`mainFramePosition`, `bankFramePosition`, `guildBankFramePosition`, `trackedCurrencies`, `recentItems`, `recentItemDuration`

### Legacy SV bridge

A shape-detected bridge in `Core/Database.lua` wraps a flat `OneWoW_Bags_DB` root into
`root.global` before `DB:Init` when the saved file predates the scoped layout.

---

## Integration Points

### Addon compartment

TOC hooks: `1WoW_Bags_OnAddonCompartmentClick`, `1WoW_Bags_OnAddonCompartmentEnter`, `1WoW_Bags_OnAddonCompartmentLeave` — toggle bags / tooltip.

### OneWoW hub

`RegisterLoadComponent`, `RegisterMinimap`, and suite lifecycle routing are always available (`OneWoW` is a hard dependency). Sub-features such as `ItemStatus`, `UpgradeDetection`, `OverlayEngine`, and `SettingsFeatureRegistry` are still accessed with nil-guards where the hub module may not expose them on every build.

### OneWoW_GUI

`DB:Init` / `MergeMissing`, frame and scroll factories, `SkinIconFrame`, `UpdateIconQuality`, theme and shared settings APIs, window position helpers. `Core\Constants.lua` calls `RegisterGUIConstants` at load.

### Item button callbacks (`Integrations\OneWoWBagsIntegration.lua`)

```lua
OneWoW_Bags_API.RegisterItemButtonCallback("MyAddon", function(button, bagID, slotID) ... end)
OneWoW_Bags_API.UnregisterItemButtonCallback("MyAddon")
```

After `GUI:RefreshLayout`, visible inventory buttons fire registered callbacks (~50ms delay). After `BankGUI:RefreshLayout`, bank buttons fire when `enableBankOverlays` is true. After `GuildBankGUI:RefreshLayout`, when **`db.global.enableBankOverlays`** is true, guild bank buttons fire `FireCallbacksOnGuildBankButtons` (paint via `GetGuildBankItemLink`); when off, overlays are cleared via `ClearGuildBankOverlays`. (Guild bank uses this shared key directly—not `BankController`-dispatched warband/personal overlay toggles.)

### TSM / Baganator

`TSMIntegration:Import` → `customCategoriesV2`. `CategoryController:ImportBaganator()` maps Baganator profiles into OneWoW_Bags structures when that addon is present (`OptionalDeps`).

### `API/` (documentation only)

The addon folder includes `API/` (`README.md`, `INTEGRATION_GUIDE.md`, `INDEX.md`, and `Examples/*.lua`) and the canonical reference at [`Docs/ITEM_BUTTON.md`](ITEM_BUTTON.md). These files are **not** listed in the TOC; they document `RegisterItemButtonCallback` and related integration patterns for other authors.

---

## Blizzard Frame Suppression

### Bags

`hooksecurefunc` on Blizzard open/close/toggle bag functions; `ContainerFrame1..13` and `ContainerFrameCombinedBags` OnShow hides; override bindings on a secure button where applicable. All of that stands down while `enableBagsUI` is off (`/1wbags` and the minimap still open the OneWoW window so settings stay reachable).

### Bank — `Core/BlizzardBankHost.lua`

Custom bank UI **hosts** Blizzard's `BankFrame` / `BankPanel` rather than only hiding them. Hosting is required because:

- `BankFrame_Open` → `ShowUIPanel(BankFrame)` is still the Blizzard open path
- `BankPanel:SetBankType` / `BankPanel:Show` keep bank-type state coherent
- OneWoW hitchhikes the secure `PurchaseButton` (`overrideBankType`) from `BankPanel.PurchasePrompt`

Contract while `enableBankUI` is on:

| Guarantee | How |
|-----------|-----|
| `BankFrame` stays Shown | `Host:Apply()` / `PreparePanel` |
| Never on-screen | Parked offscreen + `UIPanelLayout-enabled = false` + re-apply hooks on `BankFrame_Open` / `ShowUIPanel` / `UpdateUIPanelPositions` |
| Never steals mouse | Recursive `EnableMouse(false)` on the BankFrame tree; `SetItemDisplayEnabled(false)` + release of `BankPanel` item slots; AutoSort hidden |
| Purchase still works | `AttachBlizzardPurchaseButton` reparents the secure button into OneWoW's prompt and re-enables mouse on that button only |

API surface (also wrapped on `ns`):

- `SuppressBankFrame()` / `Host:Begin()` — install host (scripts, UIPanel, hooks, container sink) + `Apply`
- `PrepareBlizzardBankPanel(bankType)` — `Show` + `SetBankType` + `Apply` (prefer over raw `BankPanel` calls)
- `ReleaseBlizzardBankPanel()` — hide `BankPanel` on bank close; host stays installed
- `RestoreBankFrame()` / `Host:End()` — tear down when custom bank UI is disabled

**Do not** early-return past `Apply()` on later opens — `ShowUIPanel` repositions `BankFrame` every open; skipping re-park leaves an alpha-0 BankPanel grid under OneWoW (wrong tooltips / "Clean Up Bank").

### Guild bank

`SuppressGuildBankFrame` / `RestoreGuildBankFrame` — alpha and position, preserve OnHide hook. Gated by `enableGuildBankUI` (not `enableBankUI`). (Weaker than the bank host; no `BankPanel`-style item grid is shown under the custom guild UI today.)

---

## Refresh Targets

`RequestLayoutRefresh`, `RequestVisualRefresh`, and `RequestWindowReset` accept `target`:

| Target | GUI | Sets |
|--------|-----|------|
| `"bags"` | `GUI` | `BagSet` |
| `"bank"` | `BankGUI` | `BankSet` |
| `"guild"` | `GuildBankGUI` | `GuildBankSet` |
| `"bank_related"` | `BankGUI`, `GuildBankGUI` | `BankSet`, `GuildBankSet` |
| `"all"` (default) | all three | all three |

`RequestVisualRefresh` refreshes set visuals then triggers a matching layout refresh for the same target scope.

### Layout refresh hardening (post-load)

Inventory windows share `WindowLayoutController:Refresh`, which runs `cleanup` (hide all item buttons) then view layout (`Show` matching buttons). Failures between those steps produce empty chrome with valid slot counts.

| Mechanism | Location | Behavior |
|-----------|----------|----------|
| Self-healing scheduler | `EnsureFlushScheduled` | Single arm point for the coalesced flush timer. Coalesces within a frame, but re-arms when the `refreshScheduled` latch is stale (`GetTime() - lastArmTime > STALE_AFTER`, 0.05s). Prevents a permanent wedge if a zero-delay `C_Timer` callback is dropped across a loading screen. Caches `_flushClosure` to avoid per-arm allocation. |
| Scheduler kick | `KickLayoutScheduler` | Force-resets `refreshScheduled = false` and re-arms a flush if work is pending. Called on zone enter to recover a wedged latch. |
| Guarded layout | `WindowHelpers:RunGuardedLayoutRefresh` | Wraps each GUI `RefreshLayout` body in `pcall`; always clears `_layoutInProgress`. Reentrant calls schedule `RequestLayoutRefresh(..., "reentrant_followup")` instead of returning silently. |
| Guard reset | `onHide` / `FullReset` on `GUI`, `BankGUI`, `GuildBankGUI` | Clears `_layoutInProgress` so a stuck in-flight layout cannot survive window close. |
| Coalesced flush | `FlushPendingLayoutRefreshes` | Clears `pendingRefresh` only when a refresh actually runs. Skips (hidden frame, `Set._building`, or already-running `_layoutInProgress` -> `skip_in_progress`) leave pending set and reschedule via `EnsureFlushScheduled`. Bank/guild targets are not queued while their window is closed (`ShouldQueueLayoutRefresh`); stale pending is dropped on close and on flush. |
| Synchronous open | `GUI` / `BankGUI` / `GuildBankGUI` `Show()` warm path | When the backing set is already built, open lays out synchronously via `RequestLayoutRefreshNow` (after `ClearPendingLayoutRefresh`) instead of queueing, so the visible result does not depend on the coalescer. The redundant `OnShow` `show_onshow` request is suppressed for that target (`SetOnShowLayoutSuppressed`). |
| Open safety net | `ScheduleOpenSafetyNet` (bags + bank) | 0.5s after open, forces a synchronous `RequestLayoutRefreshNow` only for the two failure modes it exists to catch: the window is shown but blank (`IsWindowBlank`: items present, zero buttons shown → `safety_net_blank`), or a refresh is still queued but never flushed (`HasPendingLayoutRefresh` → `safety_net_wedged`, coalescer wedged). A healthy window that already laid out with a clear queue is left alone, so a normal cold open no longer eats a redundant full relayout here. Latch-independent, so it recovers even a wedged scheduler. |
| Zone enter | `Events:OnPlayerEnteringWorld` | After zone load (not initial login), kicks the scheduler (`KickLayoutScheduler`) then refreshes each visible built UI (`bags` / `bank` / `guild`) immediately and again after 0.1s. |
| Frame show | `WindowHelpers:AttachLayoutOnShow` | Hooks main window `OnShow` to request `show_onshow` when the backing set is already built (skipped while a warm `Show()` is laying out synchronously). |

### Layout debug (`/1wblayout`)

[`Core/LayoutDebug.lua`](../Core/LayoutDebug.lua) records a ring buffer (64 entries) of layout scheduler decisions when enabled. Use after a blank-inventory repro:

| Command | Action |
|---------|--------|
| `/1wblayout on` | Enable recording (clears ring) |
| `/1wblayout off` | Disable recording |
| `/1wblayout clear` | Clear ring |
| `/1wblayout dump` | Print scheduler snapshot, per-GUI button stats (`hasItem` vs `IsShown`), and recent events |

Hooks: `RequestLayoutRefresh`, `FlushPendingLayoutRefreshes` (exec / skip_hidden / skip_building / skip_in_progress / flush_drop_stale / reschedule), `KickLayoutScheduler` (`scheduler_kick`), `ScheduleOpenSafetyNet` (`safety_net_blank` / `safety_net_wedged`), `RunGuardedLayoutRefresh`, `RefreshLayout` early exits, `WindowLayoutController` (cleanup / filtered / layout_done / empty_filter). Ring `layout_done` rows include `filtShown`, `hasItem`, and `shown` for diagnosing blank-inventory reports via `/1wblayout dump`.

### Overlay flash debug (`/1wboverlay`)

[`Core/OverlayFlashDebug.lua`](../Core/OverlayFlashDebug.lua) — live timeline (+offsets from guild open) for guild-bank Quality Border flashes. Correlate the visible flash with chat lines instead of guessing. The historical guild-bank flash (borders off ~350ms per slot-update wave) was `HideDynamicChildren` blind-hiding renderer-owned frames — fixed via the `onewow_overlayManaged` tag (see `ITEM_BUTTON.md`); a healthy open now ends with `skip_same=N qb_update=0`.

| Command | Action |
|---------|--------|
| `/1wboverlay on` | Enable live prints + ring (epoch reset) |
| `/1wboverlay quiet` | Ring only (no live spam) |
| `/1wboverlay off` | Disable |
| `/1wboverlay mark` | Reset epoch to now |
| `/1wboverlay clear` | Clear the ring (alias: `reset`) |
| `/1wboverlay dump` | Print ring |

Events: `dirty`, `layout_begin`/`layout_end` (ms + reason), `overlay_sched_*`, `pass_begin`/`pass_end` (keep/full/clean_skip/skip_same/qb_noop/qb_create/qb_update/qb_hide/async_sched), `async_paint` (late item-data loads). Guild layout reasons now include `slots_changed`, `warm_open`, `build_done`, etc.

A wedged scheduler shows as `refreshScheduled=true` with `pending` set but no `flush_exec` following the requests. After this fix, a `scheduler_kick` on zone enter or a synchronous open/`safety_net_blank` should break that state without `/reload`.

---

## Performance Patterns

- **Pooling:** `ItemPool`, `CategoryManagerBase` section/divider/header frames, `CategoryViewHelpers` compact label pools, bank/guild tab button recycling via `BarHelpers`
- **Dirty batching:** `OneWoW.Inventory` coalesces dirty bags until `BAG_UPDATE_DELAYED`
- **Predicate / category caches** with targeted invalidation (`props` vs full) and **`InvalidateItemIDs`** for streaming item-info batches
- **Settings debounce** on high-churn sliders
- **Combat-deferred cleanup** via `OneWoW.Restriction.RunWhenUnrestricted("lockdown", ...)` when windows hide during lockdown (re-checks the window is still hidden before releasing pools)
- **Guild bank refresh coalescing** — `QueueGuildBankRefresh` uses a one-shot OnUpdate driver
- **Scoped refresh targets** — pure display settings (e.g. `bagColumns`) target `"bags"` only; category-affecting settings (e.g. junk/upgrade toggles, `stackItems`, `appliesIn` changes) target `"all"` to keep bags and bank in sync. Window scale is applied immediately via `SetScale` and does not go through the layout refresh path.

---

## Custom Category System

**Storage (`customCategoriesV2`):** per-row `items` (explicit item IDs, keyed by `tostring(itemID)`), `searchExpression` (the rule — **always** the thing that matches), `formerNames`, and `filterMode` plus `itemType` / `itemSubType` / `typeMatchMode`.

`filterMode` is a **UI hint only**: it chooses which editor the Category Manager opens, never how matching works. The type editor's fields are resolved to `class=N & subclass=M` by `Data\ItemTypeExpr.lua` at edit time and stored in `searchExpression`; the typed strings are kept so the editor can round-trip them and so an unresolvable name stays visible. Type mode previously compared *localized* class names against localized API output, which broke silently on a client language change — ids do not.

**Classification:** explicit `items` pins are resolved only in the **manual** stage of `GetItemCategory` (first). Custom predicate categories (search + type/subtype) and builtin search categories are collected into a merged candidate pool; the winner is picked by user-facing **priority** → custom-wins-ties → `defaultOrder` → section index → list order → `searchOrder` → alphabetical name.

**Manual pins (global rule):** at most **one** pin per item ID across all `customCategoriesV2[*].items` and all `categoryModifications[*].addedItems`. `CategoryController:AddItemToCategory` / `AddItemsToCategory` returns `false, owningDisplayName` if the item is already pinned elsewhere; the category manager UI shows `UIErrorsFrame` messages from locale keys `ERR_ITEM_ALREADY_MANUAL_CATEGORY` / `_GENERIC`. Adding to the **same** custom category again is a no-op. `Categories:AddItemToBuiltinCategory` enforces the same rule when called directly.

**Organization:** orphaned categories (fallback), `categorySections` + `sectionOrder`, and `displayOrder` with `"----"`, `"section:id"`, `"section_end"` markers. The **OneWoW Bags** section (`SectionDefaults.SEC_ONEWOW_BAGS`) holds a generated member list (`BuildOnewowMembers`); `CategoryController` and related UI call `SyncOnewowSectionCategories` after changes so unassigned builtins/custom rows stay in that section. Reordering sections (`CategoryController:MoveSectionOrder`) and moving categories within or between sections (`CategoryController:MoveCategoryToSection`) use default `RefreshUI()` so **categorization cache** and **`categoryListOrderMap`** invalidate when assignment depends on section or list order.

---

## View Context Pattern

`WindowLayoutController:CreateViewContext` builds the table passed into views. Callers (e.g. `MainWindow`, `BankWindow`, `GuildBankWindow`) supply `sectionManager`, `sortMode`, `containerType`, collapse getters/setters, and `requestRelayout` (typically `RefreshLayout` on that window). Category views can pass per-category `sortMode` and `subSortMode` through `viewContext.sortButtons`. Views must not assume a single global collapse table—behavior is always wired through `viewContext`.

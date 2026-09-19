# PredicateEngine

PredicateEngine is a shared expression engine published on the `OneWoW` global as `OneWoW.PredicateEngine` (a core service in `OneWoW/Services/`). It turns textual expressions such as `#epic & ilvl>=600` or `haste>=200` into compiled predicate functions over a rich per-item property table. Any OneWoW addon that has `OneWoW` as a dependency can use it.

Source: [`OneWoW/Services/PredicateEngine.lua`](../Services/PredicateEngine.lua). Curated / generated ID sets (`ItemIDOverrides`, `HearthstoneIDs`, `GearTokenIDs`, `SeasonTrackBonusListIDs`) live under [`OneWoW/Services/PredicateEngine/`](../Services/PredicateEngine/) and load before the engine via TOC (same pattern as Disenchant allow/block lists).

For the user-facing expression syntax (the full keyword catalog, operator semantics, examples), see [`OneWoW_Bags/Docs/SEARCH_SYNTAX.md`](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md). Suite architecture context: [`ARCHITECTURE.md`](ARCHITECTURE.md). This document is the **developer reference** for the API surface, caches, and extension points.

---

## Acquiring the engine

```lua
local PE = OneWoW.PredicateEngine
```

Every suite unit has `## RequiredDeps: OneWoW`, so the engine is guaranteed to be available by the time your file loads. (Inside the `OneWoW` core addon itself, take `local ADDON_NAME, ns = ...` and use the published `OneWoW.PredicateEngine` global — do not rename the namespace vararg.)

---

## Architecture

Two layers:

- **Layer 1 — `BuildProps`:** enriches an item (by `itemID`, and optionally a bag slot via `bagID/slotID`, plus an optional `itemInfo` hint) into a flat property table. It uses a two-tier cache: shared identity props first, then a per-slot overlay when slot context is supplied. Tooltip-derived, bind, and stat fields are resolved **lazily** through a metatable on first access.
- **Layer 2 — Tokenizer + Parser:** scans an expression string into a token array, then a recursive-descent parser produces a cached `function(props) -> bool`. Operators: `&` / `and`, `|` / `or`, `!` / `not`, parentheses. Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`, and `~` (contains) / `~~` (Lua pattern). Numeric ranges: `min-max`. Shorthand numeric comparisons bind to `ilvl` when bare (e.g. `>600`, `200-300`); bare money tokens (`100g`, `10s-50s`) bind to `vendorprice`.

### Design decisions (from the module header)

- Structured tooltip bind detection via `Enum.TooltipDataItemBinding` (line type 20).
- Strict soulbound: character-only; account-bound does **not** match `#soulbound`.
- `~` is literal string-contains only. Negation uses `!` or `not`.
- `${CONSTANT}` curly-brace syntax for named constants and parameters (e.g. `quality==${EPIC}` resolves to `quality==4` before tokenizing).
- Lazy tooltip metatable for the few remaining tooltip-only fields. The same metatable also drives lazy bind resolution, lazy stat resolution (`C_Item.GetItemStats` on first access), lazy `#currentseason` resolution (`isCurrentSeason`), and lazy `#midnights1` / `#midnights2` resolution (`isMidnightS1` / `isMidnightS2`).

### Tokenizer notes

- String-property comparisons accept unquoted single-token values or quoted string literals for phrases containing spaces.
- Standalone quoted `~"…"` / `~'…'` is treated as shorthand for `name~…`.
- `~` remains literal contains; `~~` uses Lua pattern matching, and malformed patterns fail safely as non-matches.
- Bare numeric sugar: `>600` → `ilvl>600`, `200-300` → `ilvl:200-300`. Bare money sugar: `>100g` → `vendorprice>1000000`, `10s-50s` → `vendorprice:1000-5000`. Money parsing accepts combinations like `5g50s10c`.
- **WoW EditBox operator encoding (agents/maintainers):** In-game search and category rule edit boxes use **single** `|`, `&`, and `!`. Users must **not** type `||` (broken in EditBoxes). SavedVariables may store `||` as WoW's pipe escape; the tokenizer accepts both `|` and `||` as OR so SV/import strings compile correctly. Do **not** recommend word-only operators or compile-path normalization unless behavior regresses. See [SEARCH_SYNTAX.md Operators — implementer note](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md#implementer--agent-note-editbox-encoding).
- `PE._STRICT_TOKENIZER` (false by default): when set truthy on the engine table, the tokenizer raises an error if it ever stalls on a character it cannot consume. Useful for catching grammar regressions in tests; leave off in production.

### Bind detection (source-aware)

`ResolveBind` consults `Enum.TooltipDataItemBinding` from a structured tooltip line. The mapping is **source-aware** so the same enum value carries different semantics depending on where the tooltip came from:

| Source | API | `BindOnPickup` interpretation |
|---|---|---|
| `"bag"` | `C_TooltipInfo.GetBagItem(bagID, slotID)` | The item is in the player's possession; `BindOnPickup` is observed only for tradeable BoP loot inside the trade timer, so it is treated as **currently bound** (`isSoulbound = true`). Preserves historical `#bop` / `#soulbound` matching. |
| `"link"` | `C_TooltipInfo.GetHyperlink(hyperlink)` | The item is being inspected out-of-container (vendor / loot / Great Vault). `BindOnPickup` is the **policy line** for unowned items; the player isn't bound to it yet, so `#bop` / `#soulbound` deliberately do **not** match. |

Other binding values (`BindOnEquip`, `BindOnUse`, `Soulbound`, account variants, `AccountUntilEquipped`) carry the same meaning in both modes.

**Asymmetry note:** in tooltip-only (link) mode, `#boe` / `#bou` / `#warbound` / `#wue` match because the policy-line state is well-defined; `#bop` / `#soulbound` do not, because we cannot infer current-bound state for an item the player does not own.

---

## Caches and invalidation

| Cache | Key | Contents | Cleared by |
|---|---|---|---|
| `propsCache` | `"bagID:slotID"` (slot context) or item-identity key (no slot) | Result of `BuildProps`: per-slot props or identity-only props | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `identityPropsCache` | item-identity key | Slot-independent base props shared by every slot holding the same item identity | `InvalidatePropsCache`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `characterUsableCache` | item-identity key | `ResolveCharacterUsable` fallback verdicts (`#usable` for bank/warband-only stacks). **Survives bag updates** — inputs are item template + character context, not bag contents. Combine-item verdicts are never stored here (they depend on live inventory counts) | `InvalidateCharacterContext`, `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| `combineSchematicCache` | `itemID` | Combine-item reagent lists (`GetItemSpell` → `C_TradeSkillUI.GetRecipeSchematic`); `false` for non-combine items. Static game data — survives bag updates **and** character-context changes | `InvalidateCache`, matching entries in `InvalidateItemIDs` |
| Tooltip data/text caches (slot + link tiers) | — | Owned by **`OneWoW.TooltipScanner`** — see [TOOLTIP_SCANNER.md](TOOLTIP_SCANNER.md) | Slot tier via `PE:InvalidatePropsCache`; both tiers via `PE:InvalidateCharacterContext` / `PE:InvalidateCache`; surgical via `PE:InvalidateItemIDs` |
| `compiledCache` | Expression string | Compiled `function(props) -> bool` | `InvalidateCache`, `RegisterKeyword`, `RegisterProperty` |
| `knownProfs` | (single set) | Lowercase profession-name set used by `#myprofs` | `InvalidateCache`, `InvalidateKnownProfessions` |

The slot/identity key strategy for `propsCache`:

- When `bagID`/`slotID` are present, the key is `"bagID:slotID"` so slot-state fields (durability, `isNew`, `isLocked`, current bind state, equipment-set membership, `isRefundable`, `isScrappable`, etc.) can vary per slot.
- Otherwise the key is an **identity key** (`itemID|hyperlink` for normal items; `itemID|species:level:quality:health:power:speed` for caged battle pets; `itemID|` fallback when no hyperlink is available) so independent calls for the same item share work.

`BuildProps` first populates or reuses `identityPropsCache`, then shallow-copies those base props into the final props table. Slot-only fields such as count, lock state, durability, equipment-set membership, refund/scrap state, quest slot fallback, and battle-pay state are applied on top. Lazy tooltip, bind, and stat fields are written to the final props table, not the shared identity base.

Use `PE:GetItemCacheKey` / `PE:GetItemIdentityKey` to compute these keys yourself.

### Invalidation methods

| Method | Effect |
|---|---|
| `PE:InvalidatePropsCache()` | Wipes props, identity-props, and **slot-tier** tooltip caches. Appropriate when item/slot state changed but the set of registered keywords/properties did not (e.g. `BAG_UPDATE_DELAYED`). Preserves `characterUsableCache` and the link-tier tooltip caches (their inputs don't change with bag contents). |
| `PE:InvalidateCharacterContext()` | Wipes `characterUsableCache` + both tooltip cache tiers, then `InvalidatePropsCache`. Fired by `PLAYER_LEVEL_UP`, `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED` (player), and `SKILL_LINES_CHANGED`. |
| `PE:InvalidateCache()` | Wipes everything above plus compiled caches and `combineSchematicCache`, and clears `knownProfs`. Use when keyword set changed or for a full reset. |
| `PE:InvalidateItemIDs(idSet) -> evictedSlotKeys` | Surgically evicts cached props, tooltip data, `characterUsableCache`, and `combineSchematicCache` entries for item IDs in `idSet` and returns the evicted `"bagID:slotID"` keys. Used by item-info streaming paths to avoid wiping unrelated cache entries. |
| `PE:InvalidateKnownProfessions()` | Clears the cached "known professions" set used by `#myprofs`. Call on `SKILL_LINES_CHANGED`. |

`RegisterKeyword` and `RegisterProperty` automatically wipe `compiledCache` (so future evaluations recompile against the new grammar) but leave item and tooltip caches intact.

---

## Public API

All functions are method-style (`PE:Func(...)`). Exported constants use dot syntax (`PE.Field`).

### Item evaluation

| Function | Purpose |
|---|---|
| `PE:BuildProps(itemID, bagID?, slotID?, itemInfo?) -> props` | Build (and cache) the enriched property table for an item. When `bagID`/`slotID` are supplied, slot-specific fields (`isNew`, `isLocked`, `count`, `isInEquipmentSet`, durability, `isRefundable`, `isScrappable`, `isBattlePayItem`, quest slot info, etc.) become available. `itemInfo` may be a hyperlink string, a container-info-shaped table with `.hyperlink`, or `nil`. Bag/slot-derived hyperlinks take precedence over `itemInfo`. Returns `{}` when no usable identity can be resolved. |
| `PE:CheckItem(expr, itemID, bagID?, slotID?, itemInfo?) -> bool` | Compile the expression (cached) and evaluate it against `BuildProps`. Returns `false` for empty `expr`, missing `itemID`, or compile failure. |
| `PE:Compile(expr) -> compiled, errorMessage?` | Compile an expression to a cached predicate function. Returns `nil` on empty input; returns `nil, errorMessage` on tokenize/parse failure (otherwise the second return is `nil`). Single-keyword and `! #keyword` expressions take a fast path that bypasses tokenization. |
| `PE:SafeEvaluate(compiled, props) -> result, errorMessage?` | Evaluate a compiled predicate inside `pcall`. Returns `false, errorMessage` on error (otherwise the second return is `nil`). |
| `PE:ResolveParams(expr, params?) -> expr'` | Substitute `${NAME}` placeholders in `expr`. The `params` table (`{ NAME = { value = ..., default = ... } }`) is consulted first, then the built-in `CONSTANT_MAP` (item-quality and expansion constants such as `EPIC`, `LEGENDARY`, `WARWITHIN`, `MIDNIGHT`). Pass `nil` to skip the params pass and resolve constants only. |

### Registries

| Function | Purpose |
|---|---|
| `PE:RegisterKeyword(nameOrNames, func)` | Register a `#keyword` (or a list of aliases — first name is canonical). `func(props)` returns truthy to match. Wipes `compiledCache`. Re-registering the same predicate function under a new name keeps the existing canonical entry. |
| `PE:RegisterProperty(nameOrNames, def)` | Register a numeric, string, or set property for comparison syntax (e.g. `haste>=200`, `forspec=73`). `def = { field = "fieldName", type = "number"\|"string"\|"set", unit = "money"? }`. `unit = "money"` enables money parsing (`100g`, `5s50c`) on the RHS for number-typed properties. A `set` property's field holds a lookup table `{ [id] = true }`; `=`/`==` test membership and `!=` non-membership (ordered comparators are meaningless for nominal IDs and return false). Wipes `compiledCache`. |
| `PE:GetAllKeywords() -> { canonical, aliases[] }[]` | Every registered **built-in** keyword in registration order. `aliases` excludes the canonical name and is alphabetically sorted. Intended for help/reference UIs. User `#token` entries are not included — use `SearchExpand:GetTokens()`. |
| `PE:GetMatchingKeywords(itemID, bagID?, slotID?, itemInfo?) -> string[]` | Return canonical built-in keyword names that match this item, in registration order. With only hyperlink context, policy bind keywords such as `#boe`, `#bou`, `#warbound`, and `#wue` can still match via tooltip fallback, while current-bound state (`#bop` / `#soulbound` / `#bound`) cannot be inferred. Current slot-state keywords such as `#new`, `#locked`, `#tradeableloot`, durability, equipment-set membership, count, refund/scrap state, and battle-pay state require `bagID`/`slotID`. User tokens are **not** included — use `SearchExpand:GetMatchingTokens`. |
| `PE:SetKeywordResolver(fn)` | Install the callback consulted for a `#token` that is not a built-in. `fn(name) -> body\|nil`; the engine compiles the returned body in place. Installed by `SearchExpand`; wipes token + compiled caches. |
| `PE:InvalidateKeywordTokens()` | Drop every resolved token predicate and the whole `compiledCache`. The resolver's owner calls this on any change to its data. |
| `PE:IsBuiltinKeyword(name) -> bool` | Whether `name` is a built-in `KEYWORD_MAP` entry (not a user token). |

### Item helpers

| Function | Purpose |
|---|---|
| `PE:GetItemCacheKey(itemID, bagID?, slotID?, hyperlink?) -> key` | Stable cache key keyed on item identity + slot context (`"bagID:slotID"` when both slot coordinates are present, otherwise identity key). |
| `PE:GetItemIdentityKey(itemID, hyperlink?) -> key` | Identity key for grouping/stacking (ignores slot). Uses `itemID|hyperlink` for normal items, `itemID|species:level:quality:health:power:speed` for caged battle pets, and `itemID|` as the fallback when no hyperlink is provided. |
| `PE:ParseItemLink(link) -> table\|nil` | Parse a full hyperlink or bare `item:...` string into a structured table (`itemID`, `enchantID`, `gems[]`, `suffixID`, `bonusIDs[]`, `modifiers`, `relicBonusIDs[1..3]`, `crafterGUID`, `extraEnchantID`, `quality`, `name`, etc.). Returns `nil` for inputs that do not match the item-link grammar. |
| `PE:GetBattlePetData(itemID, hyperlink) -> table\|nil` | Extract battle-pet fields (`speciesID`, `petName`, `petLevel`, `petQuality`, `petMaxHealth`, `petPower`, `petSpeed`, `petType`, `isWild`, `canBattle`, `isTradeable`, `isUnique`, `numCollected`, `limit`). Returns `nil` for items with no associated species. |
| `PE:GetCombineReagents(itemID) -> table\|nil` | Required reagents when the item's Use: effect is a combine/craft spell; `nil` for ordinary items. Same detector as `#combinable` / `#combineready` (identity-cached schematic; enchant scrolls and trivial single-reagent qty-1 schematics excluded). Each entry is `{ itemID?, currencyID?, quantityRequired }`. |
| `PE:GetTooltipText(bagID, slotID) -> string` | Concatenated bag-tooltip left-text for the slot, cached when non-empty. Returns `""` when bag/slot are missing or no tooltip data is available. |
| `PE:CanClassEquip(itemID?, hyperlink?, class?) -> bool` | Whether an item can be equipped by the given class. Pass a class token (`"WARRIOR"`, `"PALADIN"`, ...) to check an alt; pass `nil` to check the current player. Hyperlink is preferred over itemID because it carries modified-itemID context for reworked/tokenized gear. Treats universal gear (empty spec list) as usable; correctly rejects class-locked drops. |

### Exported constants

- `PE.BATTLE_PET_CAGE_ID` — item ID of the battle pet cage item (`82800`).
- `PE.BattlePetTypes` — map of pet family name to numeric family ID (`Humanoid = 1`, `Dragonkin = 2`, …).
- `PE.ClassID` — map of class token (`"WARRIOR"`, `"PALADIN"`, …) to numeric `classID` used by `C_Item.DoesItemContainSpec`. Useful for alt eligibility checks where the input is a stored class string.
- `PE.ParseMoney(str) -> copper\|nil` — parser that converts `"100g"`, `"5s50c"`, `"5g50s10c"`, etc. into copper. Returns `nil` for inputs without unit suffixes.

---

## Lazy field resolution

`BuildProps` returns a table with a permanent metatable that lazily populates three groups of fields on first read. This avoids paying for tooltip parsing, tooltip-data fetches, or `C_Item.GetItemStats` for items whose predicate never reads those fields.

**Character usability:** `isUsable` (`#usable` / `#unusable`) is resolved lazily via the props metatable (`ResolveCharacterUsable`, marker flag `_usableResolved`) so only expressions that reference it pay anything. Fast path is `C_Item.IsUsableItem`; when that's false for accessible bags (0–5) the item is genuinely unusable. Bank/warband-only stacks fall back in stages:

1. **Recipes** (`IdentityIsRecipeItem`) — never `#usable` via the fallback.
2. **Combine items** (Darkmoon decks, spear parts, …) — detected structurally via `GetItemSpell` → `C_TradeSkillUI.GetRecipeSchematic` (identity-cached in `combineSchematicCache`; enchant scrolls excluded; a small `COMBINE_QUANTITY_OVERRIDES` table corrects schematics that under-report quantities; trivial single-reagent qty-1 schematics such as Baleful tokens are treated as ordinary Use: items, not combines). Usable when every required reagent/currency is owned in sufficient quantity (`C_Item.GetItemCount` across bags + bank + reagent bank + warband). Readiness is recomputed on every resolution — never memoized in `characterUsableCache` — so looting the last reagent flips the verdict on the next refresh. Tooltip parsing is **not** used for combine detection: reagent lists are not present in `C_TooltipInfo` data (they come from the schematic). The same detector backs `#combinable` (schematic present), `#combineready` (shorthand for `#combinable & #usable`), and `PE:GetCombineReagents` (used by the QoL Reagents tooltip provider).
3. **Everything else** — a single contextual tooltip fetch (`GetBagItem` when the slot is known, else hyperlink/itemID template) analyzed in one pass by `TooltipScanner:GetUsabilityFacts` (direct-use + red unmet-requirement gates, plus `PE:CanClassEquip` for equipment):
   - **Teachable items** (a `Use: Teaches you …` learn line): usable only while still learnable. `TeachableStillLearnable` consults `OneWoW.Collectibles.GetItemCollectionStatus` — an uncollected mount/toy/recipe, or a pet below its collection cap (e.g. 1/3), is usable; a fully-collected one is not. Non-collectible teach items (spell tomes, …) return `nil` and keep the conservative "not usable" default. Like combine readiness, this depends on live collection counts and is **not** memoized in `characterUsableCache`.
   - **Non-teachable items**: usable when they have a direct `Use:` line (or are equippable and `PE:CanClassEquip` passes) with no red unmet-requirement line. These verdicts are cached per item identity in `characterUsableCache`, which survives bag updates and clears on `PE:InvalidateCharacterContext` (level/spec/talent/skill events), surgical item-ID eviction, and full `InvalidateCache`.

| Group | Fields | Resolver | Marker flag |
|---|---|---|---|
| Tooltip | `tooltipText`, `hasCharges`, `hasUseAbility`, `hasEquipAbility`, `isAlreadyKnown`, `isTradeableLoot`, `isUnique`, `isUniqueEquipped` | `TooltipScanner:PopulateTooltipProps` (via `ResolveTooltipFields`) | `_tooltipResolved` on success; `_tooltipDataMissing` on failure |
| Bind | `currentbind`, `isSoulbound`, `isBOE`, `isBOA`, `isBOU`, `isWUE`, `isWarbound` | `ResolveBind` (source-aware; see Architecture) | `_bindResolved` |
| Stats | `statIntellect`, `statAgility`, `statStrength`, `statStamina`, `statCrit`, `statHaste`, `statMastery`, `statVersatility`, `statSpeed`, `statLeech`, `statAvoidance`, `statArmor`, plus all `socket*` counters (`socketPrismatic`, `socketMeta`, color sockets, `socketCogwheel`, `socketHydraulic`, `socketDomination`, `socketCypher`, `socketTinker`, `socketPrimordial`, `socketFragrance`, `socketFiber`, punchcard sockets, and singing sockets) | `ResolveStats` (`C_Item.GetItemStats`) | `_statsResolved` |

Each group resolves all of its fields on the first read of any field in that group. The marker flag is set on the props table so subsequent reads skip the resolver. Tooltip resolution is the exception when no tooltip data is available: it writes safe false/empty defaults, sets `_tooltipDataMissing`, and leaves `_tooltipResolved` unset so later reads can retry after item data streams in. The metatable is left attached for the lifetime of the cached props entry.

`_bagID` / `_slotID` are stored on the props table so resolvers that need slot context (tooltip scan, bag-mode bind resolution) can recover it. Tooltip and bind resolvers prefer bag-tooltip data when slot context is available, then fall back to hyperlink-tooltip data when a caller only supplied an item identity.

---

## Optional cross-addon hooks

`BuildProps` and a few keywords consult optional globals when resolving item properties. Each check is guarded at **call time**, so any of these addons may be absent without errors.

| Hook | Used by | Effect if missing |
|---|---|---|
| `OneWoW.ItemStatus:IsItemJunk(itemID)` | `props.isJunk` (in addition to `quality == Poor`) | `isJunk` reflects only the quality check. |
| `TransmogUpgradeMaster_API.IsAppearanceMissing(hyperlink)` | `props.isCatalyst`, `props.isCatalystUpgrade` (and the `#catalyst` / `#catalystupgrade` keywords that read them) | Both fields stay `false`; the keywords therefore never match. |
| `OneWoW.Collectibles.GetItemCollectionStatus(itemID, hyperlink, context)` | `#collected`, `#uncollected`, `#collectionknown`, `#collectionmissing`, `#altcollected`, `#altuncollected` via `ResolveCollectionStatus`; `props.isCollected` | Collection keywords never match; `isCollected` stays false. |
| `OneWoW.RecipeKnownUtil:IsRecipeKnown(itemID, context)` | `props.isAlreadyKnown` for `#recipe` items when the tooltip's `ITEM_SPELL_KNOWN` line is absent; **not** used for `#collected` (collection truth is Collectibles only) | `#alreadyknown` falls back to tooltip-text detection only for recipes. |
| `OneWoW.TooltipScanner` | `#teachable`, lazy tooltip fields in `ResolveTooltipFields`, bind fallback | `#teachable` never matches; tooltip-derived fields stay at safe defaults. |

### Keywords registered by external modules

Some keywords are registered at runtime by other addons via `PE:RegisterKeyword`, so PE has no hardcoded dependency on them:

| Keyword | Registered by | Effect if module missing |
|---|---|---|
| `#upgrade` | `OneWoW.UpgradeDetection:Initialize()` → calls `OneWoW.UpgradeDetection:CheckItemUpgrade(hyperlink, itemLocation?)` | Keyword is unregistered; predicates using it evaluate to `false`. |
| `#recent` | OneWoW Bags `Data/Categories.lua` | Keyword is unregistered; predicates using it evaluate to `false`. |
| `#shoppinglist` / `#shoplist` / `#shoppinglistneeded` | OneWoW Shopping List at login (`ShoppingList:RegisterOverlayIntegration`). OverlayEngine `RebuildDefinitions` after register so shipped overlay presets recompile. | Keywords are unregistered; the Shopping List overlay preset matches nothing. |

---

## Extending the engine

### Adding a keyword

```lua
PE:RegisterKeyword({ "mykeyword", "mykw" }, function(props)
    if not props.hyperlink then return false end
    return MyAddon:SomeCheck(props.hyperlink)
end)
```

- Keyword callbacks are invoked with only `props`. If the callback needs slot context, read `props._bagID` / `props._slotID` (set when `BuildProps` was called with slot context).
- Avoid load-time gating on third-party globals. Always register the keyword, and check for the optional dependency **inside** the callback so load-order variability across `OptionalDeps` does not silently drop the keyword.
- The first name in the list is treated as canonical for `GetAllKeywords` and `GetMatchingKeywords`.

### User tokens (`#name`)

The engine holds **no** user state. Instead of a synonym table read out of SavedVariables, it holds one resolver callback:

```lua
PE:SetKeywordResolver(function(name)
    return MyStore:GetBody(name)  -- an expression string, or nil
end)
```

Resolution order for `#token`: `KEYWORD_MAP` → resolver → fail-closed always-false. Because the engine *compiles* the returned body rather than mapping to one predicate, a token body may be any expression — `#sell` can be `quality<=0 | CATEGORY(Junk)`, not just a rename of one built-in.

- **Built-ins always win.** `#upgrade`, `#combineready`, and `#disenchantable` register long after login, so a token stored earlier can be shadowed later. `RegisterKeyword` drops the token cache so the new built-in takes effect immediately, and the shadowed entry is *reported*, not deleted — see `SearchExpand:GetShadowedTokens()`.
- **Cycles fail closed.** A token reached while it is already being resolved compiles to always-false, and a resolution that hit a cycle is not cached, so an unrelated token reached through a cyclic walk does not inherit that walk's cut. Every failure mode here fails closed (matches nothing), never open.
- **Invalidation is the resolver owner's job.** Token bodies are baked into `compiledCache`, so any change to the backing store must call `PE:InvalidateKeywordTokens()`.

`SearchExpand` installs the resolver over the `token` kind of `OneWoW.SearchCatalog` (`OneWoW_DB.global.searchCatalog`), managed through **OneWoW Settings → Search Shortcuts**. It expands `SAVED(...)` / `CATEGORY(...)` in the body before handing it back, and resolves current *and* former names, so a renamed token keeps working in expressions written before the rename.

### Named expressions and CATEGORY expand (`OneWoW.SearchExpand`)

`PE:Compile` / `PE:CheckItem` stay **pure** (no `SAVED` / `CATEGORY` expand). Suite call sites that accept **user-authored** expressions should go through `OneWoW.SearchExpand`:

| Function | Purpose |
|---|---|
| `SearchExpand:Expand(expr) -> string` | Expand `SAVED(Name)` and `CATEGORY(Name)`, both from the core `SearchCatalog` (`saved` / `category` kind, current or former name); one depth/cycle guard keyed on kind + entry id; missing refs fail closed |
| `SearchExpand:Compile(expr) -> compiled, err?` | `Expand` then `PE:Compile` |
| `SearchExpand:CheckItem(...)` | `Expand` then `PE:CheckItem` |
| `SearchExpand:GetTokens() -> entry[]` | Every `token` catalog entry, sorted by name. Shadowed entries included |
| `SearchExpand:IsTokenShadowed(name) -> bool` / `GetShadowedTokens() -> entry[]` | Tokens outranked by a built-in keyword of the same name, for lint + UI |
| `SearchExpand:GetMatchingTokens(itemID, bagID?, slotID?, itemInfo?) -> string[]` | User tokens whose expression matches this item, alphabetically. The user-token counterpart to `PE:GetMatchingKeywords` |
| Saved CRUD / aliases | `SetSaved` / `RenameSaved` / `DeleteSaved` / `SetAlias` / … — hub Settings + Bags info-bar Save |

Hardcoded internal expressions (e.g. toast-loot / autoopen predicates) may keep using raw `PE:Compile`.

### Adding a property

```lua
PE:RegisterProperty("mystat", { field = "myStat", type = "number" })
PE:RegisterProperty("mygold", { field = "myGold", type = "number", unit = "money" })
PE:RegisterProperty("myname", { field = "myName", type = "string" })
PE:RegisterProperty("myset",  { field = "mySet",  type = "set" })
```

Then `mystat>=200`, `mygold>100g`, `myname~foo`, `myset=42` become valid expression tokens. The engine reads `props.<field>` at evaluation time; your addon is responsible for populating that field — typically by attaching values via a wrapper that calls `BuildProps` and then layers extra fields, or by populating fields in a custom keyword's resolver path.

String-typed properties support `=` / `==` (exact, case-insensitive), `!=`, `~` (literal contains), and `~~` (Lua pattern; malformed patterns return false). Numeric properties support `==`, `!=`, `<`, `<=`, `>`, `>=`, and the `prop:low-high` range form. With `unit = "money"`, numeric RHS values may also be money strings (`100g`, `5s50c`, `200g50s`). Set-typed properties expect the field to be a `{ [id] = true }` lookup table and support only `=` / `==` (member) and `!=` (non-member); ordered comparators and ranges return false. The built-in `forspec` / `forclass` props are set-typed — equippable gear uses `C_Item.DoesItemContainSpec`; when that yields no classes, `eligibleClasses` falls back to the tooltip `ITEM_CLASSES_ALLOWED` line via `TooltipScanner:GetAllowedClassIDs` (see [OneWoW_Bags/Docs/SEARCH_SYNTAX.md](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md) → "Spec & Class Eligibility").

### `#currentseason` (`isCurrentSeason`)

Registered keywords: `#currentseason`, `#activeseason` (verbose: `IsCurrentSeason`, `IsActiveSeason`).

Resolution is **lazy** on first read of `props.isCurrentSeason`:

1. **Expansion guard** — if `expansionID >= 0` and `expansionID ~= LE_EXPANSION_LEVEL_CURRENT`, set `false` and stop (no tooltip scan). Unknown expansion (`-1` while item data streams) defers via `_tooltipDataMissing`.
2. **Equipment** — scan identity-cached `props.bonusIDs` against `CURRENT_SEASON_BONUS_IDS`; else require `C_Item.GetItemUpgradeInfo` track + non-gray upgrade-path tooltip lines.
3. **All item types** — scan tooltip lines for the current season label (`EXPANSION_SEASON_NAME:format(expansionName, seasonNum)`). Expansion name from `LE_EXPANSION_LEVEL_CURRENT`; season ordinal from `C_MythicPlus.GetCurrentSeasonValues()` (values ≤ 12), then `GetCurrentUIDisplaySeason()`, then `GetCurrentSeason()` minus `EXPANSION_FIRST_GLOBAL_MPLUS_SEASON` for the active expansion. **Do not** use `C_SeasonInfo.GetCurrentDisplaySeasonID()` — that is a content UID (e.g. 34), not the `1` in `Midnight Season 1`. Falls back to concatenated tooltip body (same path as `tooltip~`). Gray standalone headers (entire line equals the label) are ignored so outdated season markers on old gear do not match.

Identity props also expose `bonusIDs` (parsed once per item link in `PopulateBaseProps`) so season checks do not re-parse hyperlinks.

**Maintenance (each season / expansion):**

- `CURRENT_SEASON_BONUS_IDS` — crafted/voidforged bonus IDs on item links (include Syndicator's current-season crafted suffixes such as Sporefused `13786`).
- `EXPANSION_FIRST_GLOBAL_MPLUS_SEASON` — when a new expansion starts, add its first global `C_MythicPlus.GetCurrentSeason()` ID. That value is `DisplaySeason.Season` for the expansion’s ordinal-1 row (Midnight = 17). Fallback only; primary ordinal still comes from `GetCurrentSeasonValues()` / `GetCurrentUIDisplaySeason()`.

**Debug:** `/petooltip` or `/owpetooltip` dumps `C_TooltipInfo` lines and season-label diagnostics to chat (hover a bag slot, tooltip, or pass an item link).

### Named Midnight seasons (`isMidnightS1` / `isMidnightS2`)

Registered keywords: `#midnights1` (`#midnightseason1`), `#midnights2` (`#midnightseason2`). Verbose: `IsMidnightS1`, `IsMidnightSeason1`, `IsMidnightS2`, `IsMidnightSeason2`.

These are **frozen** to Midnight PvE seasons. They do not move when the live season changes. `#currentseason` remains the shifting “whatever is live now” keyword; while Midnight S2 is live, S2 track gear typically matches both `#midnights2` and `#currentseason`.

Resolution is **lazy** on first read of `props.isMidnightS1` or `props.isMidnightS2` (one pass fills both):

1. **Expansion guard** — if `expansionID >= 0` and `expansionID ~= Enum.ExpansionLevel.Midnight`, both false.
2. **Track list IDs** — identity-cached `props.bonusIDs` against generated `ns.SeasonTrackBonusListIDs[11][ordinal]` (sequence **1–8** only). Sequence 9+ crafted stamps (Voidforged `13653`/`13654`) stay on `#currentseason`, not `#midnights1`.
3. **Tooltip label** — `EXPANSION_SEASON_NAME:format(MidnightName, ordinal)` (e.g. `Midnight Season 1`). **Gray standalone headers match** (the opposite of `#currentseason`) so leftover S1 stamps still classify.

**Maintenance:** curated group IDs live in OneWoW_Workspace `bin/season_bonus_list_ids.py`. After a new Midnight season’s `ItemBonusListGroup` block appears in OneWoW_Workspace `.warehouse/Sources/Wago`, add those groups to the mapping and run `python bin/season_bonus_list_ids.py generate` from OneWoW_Workspace. There is no DisplaySeason FK.

**Debug:** `/petooltip` also prints `#midnights1` / `#midnights2` hits.

---

## Performance notes

- Compiled predicate functions are cached. Recompile cost is only paid on the first evaluation of a new expression or after an invalidation.
- `BuildProps` is cached per slot-or-identity key and reused across `CheckItem`, `GetMatchingKeywords`, and direct-read call sites. Call `InvalidatePropsCache` when slot contents change.
- The lazy-resolution metatable means a predicate that never references stat / bind / tooltip fields never pays for `C_Item.GetItemStats`, `C_TooltipInfo.GetBagItem`, or tooltip text concatenation.
- Registering a new keyword or property wipes `compiledCache` (future evaluations recompile). Props and tooltip caches are untouched.
- `GetMatchingKeywords` and `GetAllKeywords` iterate every registered keyword. Use them for tooltip/diagnostic paths and help UIs, not for hot filter loops — use `CheckItem` with a targeted expression there.
- User tokens resolve once and are cached by name, so the resolver runs on first use, not per evaluation. A token that resolves to nothing caches that fact too. Any change to the backing store wipes both that cache and `compiledCache`, so an edit costs a full recompile of everything currently in flight.

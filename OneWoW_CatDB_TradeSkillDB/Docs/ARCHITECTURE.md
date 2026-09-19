# OneWoW_CatDB_TradeSkillDB — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)
>
> Catalog pointer: [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md).
> This is the Catalog Tradeskills store. Known recipes live on AltTracker
> Professions.

## Overview

Load-on-demand profession / recipe store. Catalog's pack resolver loads
it for the `"tradeskills"` role.

Owns recipe rows (spell ID, reagents, learn source). Item identity is
ItemDB. Trainer pins live on NPCDB. Quest text is QuestDB. Live "what this
character knows" is AltTracker Professions (`GetKnownRecipes` /
`GetRecipeKnownBy` / `IsRecipeKnown`). This pack does not ship or own
`scanCache`.

**SavedVariable:** `OneWoW_CatDB_TradeSkillDB_DB`

**RequiredDeps:** `OneWoW`, `OneWoW_Catalog`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).
Catalog marks CatDB packs `lazyStores`.

**Public API:** `OneWoW_CatDB_TradeSkillDB_API`

## Modules

| Module | Role |
|--------|------|
| `Core/DataLoader.lua` | `RegisterProfessionData` / `RegisterRecipeData` → `ns.Professions`, `ns.Recipes`, `ns.RecipesByItem` |
| `Core/Database.lua` | SavedVariables init (`ns.db`) |
| `Core/API.lua` | Public API (`GetRecipe`, `GetRecipesByItem`, `GetRecipesByProfession`, …) |
| `Core/Core.lua` | `BootStore` lifecycle (`savedVar`, `withScanCallbacks`) |
| `OneWoW_CatDB_TradeSkillDB.lua` | Comment stub (no public globals) |

`ns` stays private. Cross-unit callers use the `_API` global only.

## BootStore

```lua
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_TradeSkillDB_DB",
    withScanCallbacks = true,
})
```

`InitializeDatabase` runs through BootStore. `GetSettings()` reads
`ns.db.global.settings`. Known-recipe reads go through
`OneWoW_AltTracker_Professions_API` at call time.

## Data Layout

One file per profession under `Data/`:

`Tradeskills_Alchemy.lua` … `Tradeskills_Tailoring.lua` plus
`Tradeskills_HousingDyes.lua` (14 files). Archaeology is not in this pack.

Each file builds a profession header (`pid`, `name`, `icon`, `r`) and
calls `ns:RegisterProfessionData`.

## Tools (offline / Workspace)

Emit lives in OneWoW_Workspace (`bin/catdb_tradeskill_emit.py`,
`bin/catdb_status.py tradeskill`). `--from-db2` rebuilds from warehouse
CSVs. Not loaded by the addon TOC.

Static schema: [TRADESKILL_DATA.md](TRADESKILL_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.

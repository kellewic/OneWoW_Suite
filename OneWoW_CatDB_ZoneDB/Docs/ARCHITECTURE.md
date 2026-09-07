# OneWoW_CatDB_ZoneDB — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)
>
> Catalog pointer: [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md).
> This is the Catalog Zones store (Journal tab).

## Overview

Load-on-demand place / encounter store. Catalog's pack resolver loads it
for the `"journal"` / `"zones"` role.

Owns **places** (zone / instance / delve / hub / world) and **encounters**
(bosses, world rares, general-loot buckets). Item identity is ItemDB. NPC
pins and looks are NPCDB. Quest text is QuestDB.

**SavedVariable:** `OneWoW_CatDB_ZoneDB_DB`

**RequiredDeps:** `OneWoW`. **OptionalDeps:** `AllTheThings` (live extras
overlay only; never force-loaded). **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).
Catalog marks CatDB packs `lazyStores`: they parse when a tab or resolver
loads them, not at login.

**Public API:** `OneWoW_CatDB_ZoneDB_API`

## Modules

| Module | Role |
|--------|------|
| `Core/DataLoader.lua` | Registrars: `RegisterPlaceData`, `RegisterEncounterData`, `RegisterDifficultyData`, `RegisterTierMembership`, `RegisterListingOverrides` |
| `Core/Database.lua` | SavedVariables init (`ns.db`) |
| `Core/API.lua` | Public API (`GetPlace`, `GetEncounter`, `GetInstanceByMapID`, …) |
| `Modules/JournalCard.lua` | Card mutation helpers for live overlay (sort / totals / place extra) |
| `Modules/EJLiveLoot.lua` | Live EJ scaled links + per-card merge (`GetScaledLootLink`, `MergeInstance`) |
| `Modules/ATTLiveExtras.lua` | Live ATT extras overlay when ATT is already loaded (fallback only) |
| `Core/Core.lua` | `BootStore` lifecycle (`savedVar`, `withScanCallbacks`) |
| `OneWoW_CatDB_ZoneDB.lua` | Comment stub (no public globals) |

`ns` stays private. Cross-unit callers use the `_API` global only.

## BootStore

```lua
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_ZoneDB_DB",
    withScanCallbacks = true,
})
```

`InitializeDatabase` runs through BootStore. `GetSettings()` reads
`ns.db.global.settings`. Live EJ merge fires scan callbacks (`ej_merge`).
ATT extras overlay only runs when AllTheThings is already loaded
(`OptionalDeps`); it never LoadAddOn / EnsureLoaded.

## Data Layout

Per-expansion shards under `Data/`:

- `Places_<Expansion>.lua` — `ns:RegisterPlaceData` (Classic through Midnight)
- `Encounters_<Expansion>.lua` — `ns:RegisterEncounterData`
- `Difficulties.lua`, `TierMembership.lua`, `ListingOverrides.lua`

Merged into `ns.Places` (place key) and `ns.Encounters` (encounterID).

## Tools (offline / Workspace)

Emit lives in OneWoW_Workspace (`bin/catdb_zone_emit.py`,
`bin/catdb_status.py zone`). Not loaded by the addon TOC.

Static schema: [ZONE_DATA.md](ZONE_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.

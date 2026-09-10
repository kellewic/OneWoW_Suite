# CatDB Tradeskills — data rules

Runtime rules for `OneWoW_CatDB_TradeSkillDB` and how profession files are
built. Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog Tradeskills store. Known recipes live on AltTracker
Professions.

## One home

TradeSkillDB owns the **recipe**: spell ID, reagents, skill band, learn
source. Item / NPC / quest facts are IDs.

| Fact | Home | On the recipe row |
|------|------|-------------------|
| Output / reagent identity | ItemDB | `item`, `items`, `rg[].itemID` |
| Trainer / source pin | NPCDB | `npc` (map/xy omitted when `npc` is set) |
| Learn quest text | QuestDB | `quest` |

`map` + `xy` stay on the recipe only when there is no npcID (object / drop
location).

## What it owns

All playable retail recipes for the shipped professions (Alchemy through
Tailoring + Housing Dyes). Skip DNT / NYI / UNUSED / `[PH]` / TEST recipe
names. Skip each profession's SpellBookSpellID.

`prof` is the English identifier (`Alchemy`, `HousingDyes`, …). `exp` is
the English expansion key (`Classic`, `TheWarWithin`, `Midnight`, …),
same table as `GetExpansions()` in `Core/API.lua`.

Known-recipe state is **not** shipped. Live known-by is AltTracker
Professions, not a `scanCache` on this pack.

Opening a profession window flags **missing** recipes (and missing
reagents) with `sync = true` on `global.learned`. CompSync Contribute
reads those rows only. See [CATDB_CONTRIBUTE](../../OneWoW/Docs/CATDB_CONTRIBUTE.md).

## IDs only

`item` / `items` / `rg` itemIDs → ItemDB. `npc` → NPCDB. `quest` → QuestDB.
`taught` is the recipe-scroll itemID (identity in ItemDB).

## Schema

Profession header: `{ pid, name, icon, r }` where `r[recipeID] = recipe`.

Recipe fields (all included when present):

| Group | Keys |
| --- | --- |
| Identity | `id`, `item`, `items`, `icon`, `cat`, `prof`, `exp`, `pid` |
| Craft | `rg` (`{ itemID, qty, required }` with required `1` or `0`), `sl` (optional slots) |
| Band | `prev`, `next`, `qual`, `maxQ`, `min`, `lo`, `hi` |
| Learn | `taught`, `learn`, `npc`, `quest`, `map`, `xy`, `cost`, `fcq`, `mask` |

`learn` is `trainer` / `quest` / `item` / `drop` / `vendor` / `auto` /
`spec` when known. Locale-baked item `link` fields are omitted.

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/catdb_tradeskill_emit.py
python bin/catdb_tradeskill_emit.py --from-db2
python bin/catdb_status.py tradeskill
```

Emit writes TradeSkillDB. `--from-db2` rebuilds from warehouse CSVs.
`map` / `xy` are stripped when `npc` is set.
